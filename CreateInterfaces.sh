#Copyright (c) 2019 Cisco and/or its affiliates.

#This software is licensed to you under the terms of the Cisco Sample
#Code License, Version 1.0 (the "License"). You may obtain a copy of the
#License at

#               https://developer.cisco.com/docs/licenses

# All use of the material herein must be in accordance with the terms of
#the License. All rights not expressly granted by the License are
# reserved. Unless required by applicable law or agreed to separately in
# writing, software distributed under the License is distributed on an "AS
# IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied.

apic='10.82.6.165'
userName='admin'
aep=''
breakoutPortGroup='4x10-Breakout'
breakoutType='10g-4x'
#breakoutType='25g-4x'
interfaceProfile='201'
startInterface=1
lastInterface=14

function createPortSelect () {
  #Create Interface Access Port Selector
  for i in {1..4}
    do
	echo $i      
    done 
}

function getCookie () {
	echo -n Enter the password for the APIC.
	read -s password
	curl -kX POST https://10.82.6.165/api/aaaLogin.xml -d "<aaaUser name='${userName}' pwd='${password}'/>" -c cookie.txt	
}
getCookie


breakoutPolicy="
			<infraBrkoutPortGrp
			annotation='' 
			brkoutMap='${breakoutType}' 
			descr='' 
			dn='uni/infra/funcprof/brkoutportgrp-${breakoutPortGroup}' 
			name='${breakoutPortGroup}' 
			nameAlias='' 
			ownerKey='' 
			ownerTag=''>
			<infraRsMonBrkoutInfraPol 
				annotation='' 
				tnMonInfraPolName=''/>
			</infraBrkoutPortGrp>
"

##########################
#
# Ensure a policy exists Breakout. 
#
##########################


curl -b cookie.txt -kX POST https://${apic}/api/node/mo/uni/infra/funcprof.xml -d "${breakoutPolicy}" --header "content-type: appliation/xml, accept: application/xml" -v

echo $breakoutPolicy

for ((interface=1; interface <= lastInterface; interface++))
  do
    echo $interface    
  done



