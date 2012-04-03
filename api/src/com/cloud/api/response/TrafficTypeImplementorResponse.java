// Copyright 2012 Citrix Systems, Inc. Licensed under the
// Apache License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.  Citrix Systems, Inc.
// reserves all rights not expressly granted by the License.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 
// Automatically generated by addcopyright.py at 04/02/2012
package com.cloud.api.response;

import com.cloud.api.ApiConstants;
import com.cloud.serializer.Param;
import com.google.gson.annotations.SerializedName;

public class TrafficTypeImplementorResponse extends BaseResponse {
	 @SerializedName(ApiConstants.TRAFFIC_TYPE) @Param(description="network traffic type")
	 private String trafficType;
	 
	 @SerializedName(ApiConstants.TRAFFIC_TYPE_IMPLEMENTOR) @Param(description="implementor of network traffic type")
	 private String implementor;
	 
	 public void setTrafficType(String type) {
		 this.trafficType = type;
	 }
	 
	 public void setImplementor(String impl) {
		 this.implementor = impl;
	 }
}