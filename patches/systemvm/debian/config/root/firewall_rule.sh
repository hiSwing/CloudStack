#!/usr/bin/env bash
#
# Copyright (C) 2010 Cloud.com, Inc.  All rights reserved.
# 
# This software is licensed under the GNU General Public License v3 or later.
# 
# It is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# firewall_rule.sh -- allow some ports / protocols to vm instances
#
#
# @VERSION@
echo $* >> /tmp/jana.log 
usage() {
  printf "Usage: %s:  -a <public ip address:protocol:startport:endport:sourcecidrs>  \n" $(basename $0) >&2
  printf "sourcecidrs format:  cidr1-cidr2-cidr3-...\n"
}
#set -x
#FIXME: eating up the error code during execution of iptables
fw_remove_backup() {
  local pubIp=$1
  sudo iptables -t mangle -F _FIREWALL_$pubIp 2> /dev/null
  sudo iptables -t mangle -D PREROUTING   -j _FIREWALL_$pubIp -d $pubIp 2> /dev/null
  sudo iptables -t mangle -X _FIREWALL_$pubIp 2> /dev/null
}

fw_restore() {
  local pubIp=$1
  sudo iptables -t mangle -F FIREWALL_$pubIp 2> /dev/null
  sudo iptables -t mangle -D PREROUTING   -j FIREWALL_$pubIp -d  $pubIp 2> /dev/null
  sudo iptables -t mangle -X FIREWALL_$pubIp 2> /dev/null
  sudo iptables -t mangle -E _FIREWALL_$pubIp FIREWALL_$pubIp 2> /dev/null
}
fw_chain_for_ip () {
  local pubIp=$1
  fw_remove_backup $1
  sudo iptables -t mangle -E FIREWALL_$pubIp _FIREWALL_$pubIp 2> /dev/null
  sudo iptables -t mangle -N FIREWALL_$pubIp 2> /dev/null
  # drop if no rules match (this will be the last rule in the chain)
  sudo iptables -t mangle -A FIREWALL_$pubIp -j DROP> /dev/null
  # ensure outgoing connections are maintained (first rule in chain)
  sudo iptables -t mangle -I FIREWALL_$pubIp -m state --state RELATED,ESTABLISHED -j ACCEPT> /dev/null
  sudo iptables -t mangle -I PREROUTING -d $pubIp -j FIREWALL_$pubIp
}

fw_entry_for_public_ip() {
  local rules=$1

  local pubIp=$(echo $rules | cut -d: -f1)
  local prot=$(echo $rules | cut -d: -f2)
  local sport=$(echo $rules | cut -d: -f3)    
  local eport=$(echo $rules | cut -d: -f4)    
  local scidrs=$(echo $rules | cut -d: -f5 | sed 's/-/ /g')
  
  logger -t cloud "$(basename $0): enter apply firewall rules for public ip $pubIp:$prot:$sport:$eport:$scidrs"  


  # note that rules are inserted after the RELATED,ESTABLISHED rule but before the DROP rule
  for src in $scidrs
  do
    if [ "$prot" == "icmp" ]
    then
    # TODO  icmp code need to be implemented
    # sport is icmpType , dport is icmpcode 
      if [ "$sport" == "-1" ]
      then
           sudo iptables -t mangle -I FIREWALL_$pubIp 2 -s $src -p $prot  -j RETURN
       else
           sudo iptables -t mangle -I FIREWALL_$pubIp 2 -s $src -p $prot --icmp-type $sport  -j RETURN
       fi
    else
       sudo iptables -t mangle -I FIREWALL_$pubIp 2 -s $src -p $prot --dport $sport:$eport -j RETURN
  fi
  done
  result=$?
      
  logger -t cloud "$(basename $0): exit apply firewall rules for public ip $pubIp"  
  return $result
}

get_vif_list() {
  local vif_list=""
  for i in /sys/class/net/eth*; do 
    vif=$(basename $i);
    if [ "$vif" != "eth0" ] && [ "$vif" != "eth1" ]
    then
      vif_list="$vif_list $vif";
    fi
  done
  if [ "$vif_list" == "" ]
  then
      vif_list="eth0"
  fi
  
  logger -t cloud "FirewallRule public interfaces = $vif_list"
  echo $vif_list
}

shift 
rules=
while getopts 'a:' OPTION
do
  case $OPTION in
  a)	aflag=1
		rules="$OPTARG"
		;;
  ?)	usage
		exit 2
		;;
  esac
done

VIF_LIST=$(get_vif_list)

if [ "$rules" == "" ]
then
  rules="none"
fi

#-a 172.16.92.44:tcp:80:80:0.0.0.0/0:,172.16.92.44:tcp:220:220:0.0.0.0/0:,172.16.92.44:tcp:222:222:192.168.10.0/24-75.57.23.0/22-88.100.33.1/32

#FIXME: rule leak: when there are multiple ip address, there will chance that entry will be left over if the ipadress  does not appear in the current execution when compare to old one 
# example :  In the below first transaction have 2 ip's whereas in second transaction it having one ip, so after the second trasaction 200.1.2.3 ip will have rules in mangle table.
#  1)  -a 172.16.92.44:tcp:80:80:0.0.0.0/0:,200.16.92.44:tcp:220:220:0.0.0.0/0:,
#  2)  -a 172.16.92.44:tcp:80:80:0.0.0.0/0:,172.16.92.44:tcp:220:220:0.0.0.0/0:,


success=0
publicIps=
rules_list=$(echo $rules | cut -d, -f1- --output-delimiter=" ")
for r in $rules_list
do
  pubIp=$(echo $r | cut -d: -f1)
  publicIps="$pubIp $publicIps"
done

unique_ips=$(echo $publicIps| tr " " "\n" | sort | uniq | tr "\n" " ")

for u in $unique_ips
do
  fw_chain_for_ip $u
done

for r in $rules_list
do
  pubIp=$(echo $r | cut -d: -f1)
  fw_entry_for_public_ip $r
  success=$?
  if [ $success -gt 0 ]
  then
    logger -t cloud "$(basename $0): failure to apply fw rules for ip $pubIp"
    break
  else
    logger -t cloud "$(basename $0): successful in applying fw rules for ip $pubIp"
  fi
done

if [ $success -gt 0 ]
then
    for p in $unique_ips
    do
      logger -t cloud "$(basename $0): restoring from backup for ip: $p"
      fw_restore $p
    done
fi 
for p in $unique_ips
do
   logger -t cloud "$(basename $0): deleting backup for ip: $p"
   fw_remove_backup $p
done
exit $success

