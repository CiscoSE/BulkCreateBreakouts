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

#Color Coding for screen output.
green="\e[1;32m"
red="\e[1;31m"
yellow="\e[1;33m"
normal="\e[1;0m"

#These are needed later, and probably shouldn't be changed.
interfaceProfileDN="uni/infra/accportprof-${interfaceProfile}"
breakoutPolicyDN="uni/infra/funcprof/brkoutportgrp-${breakoutPortGroup}"

function accessAPIC () {
  XMLResult=''
  errorReturn=''
  XMLResult=$(curl -b cookie.txt -skX ${1} ${2} -d "${3}"  --header "content-type: appliation/xml, accept: application/xml" )
  errorCode=$(echo $XMLResult | grep -oE "error code=\".*"  | sed "s/error code=\"//" | sed "s/\".*//")
  errorText=$(echo $XMLResult | grep -oE "text=\".*"  | sed "s/text=\"//" | sed "s/\".*//")
  if [ "$errorCode" != '' ]; then
    writeStatus "APIC Call Failed.\nError Code: ${errorCode}\nXML Result: ${XMLResult}\nType: ${1}\nURL: ${2}\nXML: \n${3}" 'FAIL'
  fi
}



function getCookie () {
	#Remove a cookie if it exists
	rm -f cookie.txt
	echo -n Enter the password for the APIC.
	read -s password
	cookieResult=$(curl -sk https://${apic}/api/aaaLogin.xml -d "<aaaUser name='${userName}' pwd='${password}'/>" -c cookie.txt)
}

function writeStatus (){	
  if [ "${2}" = "FAIL" ]; then 
    printf "%5s[ ${red} FAIL ${normal} ] ${1}\n"
    # Begin Exit Reroutine
    if [ -f cookie.txt ]; then
      printf "%5s[ ${green} INFO ${normal} ] Removing APIC cookie\n"
      rm -f cookie.txt
    fi
    exit
  fi
  
  printf "%5s[ ${green} INFO ${normal} ] ${1}\n"

}

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
  #local portBreakoutResult=$(curl -b cookie.txt -sk https://${apic}/api/node/mo/uni/infra.xml -d "${portBreakoutXML}" --header "content-type: appliation/xml, accept: application/xml")
  accessAPIC 'POST' "https://${apic}/api/node/mo/uni/infra.xml" "${portBreakoutXML}"
  writeStatus "%10s Breakout Created Successfully"
}

function configureBreakoutInterface () {
  #
  for i in {1..4}
    do
	inPolGrpResult=''
	writeStatus "%10s Configuring breakout interface ${interface}, port ${i}"
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
	accessAPIC 'POST' " https://${apic}/api/node/mo/uni/infra.xml" "${intPolGrpXML}"
	writeStatus "%15s interface Policy Group Configured"

    done 
}

getCookie

breakoutPolicyXML="
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

writeStatus "\nEnsure a breakout policy exists.\n"
accessAPIC 'POST' "https://${apic}/api/node/mo/uni/infra/funcprof.xml" "${breakoutPolicyXML}"
#curl -b cookie.txt -kX POST https://${apic}/api/node/mo/uni/infra/funcprof.xml -d "${breakoutPolicyXML}" --header "content-type: appliation/xml, accept: application/xml" -v

writeStatus "Start loop through each interface"

#TODO Write Default LLDP, CDP, LACP and Link Level policies, or require them to be manually populated by user.  
for ((interface=1; interface <= lastInterface; interface++))
  do
    addPortToBreakout $interface
    configureBreakoutInterface
    #TODO Create VPC Policy Group for each breakout interace
    #TODO Create Interface selector for each breakout interface and associate with VPC Policy Group
  done

#Removing the cookie used for access to the APIC
rm -f ./cookie.txt


