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

#These are needed later, and probably shouldn't be changed.
interfaceProfileDN="uni/infra/accportprof-${interfaceProfile}"
breakoutPolicyDN="uni/infra/funcprof/brkoutportgrp-${breakoutPortGroup}"


function getCookie () {
	echo -n Enter the password for the APIC.
	read -s password
	curl -kX POST https://10.82.6.165/api/aaaLogin.xml -d "<aaaUser name='${userName}' pwd='${password}'/>" -c cookie.txt	
}

function writeStatus (){	
  echo ""
  echo "##########################"
  echo "# $1"
  echo "##########################"


}

getCookie


breakoutPolicy="
			<infraBrkoutPortGrp
			annotation='' 
			brkoutMap='${breakoutType}' 
			descr='' 
			dn='${breakoutPolicyDN}' 
			name='${breakoutPortGroup}' 
			nameAlias='' 
			ownerKey='' 
			ownerTag=''>
			<infraRsMonBrkoutInfraPol 
				annotation='' 
				tnMonInfraPolName=''/>
			</infraBrkoutPortGrp>
"

writeStatus "Ensure a breakout policy exists."

curl -b cookie.txt -kX POST https://${apic}/api/node/mo/uni/infra/funcprof.xml -d "${breakoutPolicy}" --header "content-type: appliation/xml, accept: application/xml" 

writeStatus "Ensure Interface Profile is available"

#interfaceProfileXML="<
#  infraAccPortP annotation='' 
#  descr='' 
#  dn='${interfaceProfileDN}' 
#  name='${interfaceProfile}' 
#  nameAlias='' 
#  ownerKey='' 
#  ownerTag=''/>"
#curl -b cookie.txt -kX POST https://${apic}/api/node/mo/uni/infra.xml -d "${interfaceProfileXML}" --header "content-type: appliation/xml, accept: application/xml"

writeStatus "Start loop through each interface"

function addPortToBreakout () {
  writeStatus "Processing interface $1 for Breakout"
  portBreakoutXML="
  <infraAccPortP 
		annotation='' 
		descr='' 
		dn='${interfaceProfileDN}' 
		name='${interfaceProfile}' 
		nameAlias='' 
		ownerKey='' 
		ownerTag=''>
		<infraHPortS 
			annotation='' 
			descr='' 
			name='${interfaceProfile}-Breakout' 
			nameAlias='' 
			ownerKey='' 
			ownerTag='' 
			type='range'>
			<infraRsAccBaseGrp 
				annotation='' 
				tDn='${breakoutPolicyDN}'/>
			<infraPortBlk 
				annotation='' 
				descr='' 
				fromCard='1' 
				fromPort='$1'
				name='$interfaceProfile-S1-P$1' 
				nameAlias='' 
				toCard='1' 
				toPort='$1'/>
		</infraHPortS>
	</infraAccPortP> 
"
  curl -b cookie.txt -kX POST https://${apic}/api/node/mo/uni/infra.xml -d "${portBreakoutXML}" --header "content-type: appliation/xml, accept: application/xml"

}


function createPortSelect () {
  #
  for i in {1..4}
    do
	writeStatus "Configuring interface ${interface}, port ${i}"
	if [ ${#interface} -lt 2 ]; then
		port="0${interface}"
	else
		port=$interface
	fi
	local name="${interfaceProfile}-P1.${port}.${i}"
	#TODO where do we get teh AEP DN from?

	intPolGrpXML="
	<infraFuncP>
	<infraAccBndlGrp 
	annotation='' 
	descr='' 
	dn='uni/infra/funcprof/accbundle-${name}'
	lagT='node' 
	name='${name}' 
	nameAlias='' 
	ownerKey='' 
	ownerTag=''>
	<infraRsAttEntP 
		annotation='' 
		tDn='uni/infra/attentp-L2ColumbiaLab'/>
	<infraRsCdpIfPol 
		annotation='' 
		tnCdpIfPolName='CDPEnabled'/>
	<infraRsHIfPol 
		annotation='' 
		tnFabricHIfPolName='10G'/>
	<infraRsLacpPol 
		annotation='' 
		tnLacpLagPolName='LACPActive'/>
	<infraRsLldpIfPol 
		annotation='' 
		tnLldpIfPolName='LLDPEnabled'/>
	</infraAccBndlGrp>
	</infraFuncP>
	"      
	echo $intPolGrpXML
        curl -b cookie.txt -kX POST https://${apic}/api/node/mo/uni/infra.xml -d "${intPolGrpXML}" --header "content-type: appliation/xml, accept: application/xml"
	writeStatus "Port Configured"
    done 
}

#TODO Write Default LLDP, CDP, LACP and Link Level policies, or require them to be manually populated by user.  
for ((interface=1; interface <= lastInterface; interface++))
  do
    addPortToBreakout $interface
    createPortSelect
    #TODO Create VPC Policy Group for each breakout interace
    #TODO Create Interface selector for each breakout interface and associate with VPC Policy Group
  done

#Removing the cookie used for access to the APIC
rm -f ./cookie.txt


