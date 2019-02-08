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
AepDN='uni/infra/attentp-L2ColumbiaLab'	# This must be the DN of an existing AEP. I don't check to see if it is there.
breakoutPortGroup='4x10-Breakout'	# This gets used for a lot of created object names
breakoutType='10g-4x'			# This is a constant that must not change It must be 10g-4x or 25g-4x
#breakoutType='25g-4x'
interfaceProfile='201'			# Policy Groups and Profiles are named with this value.
startInterface=1			# First interface in a range to configure
lastInterface=14			# Last interface in a range to configure

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
  #used only for debuging
  if [ "${4}" = 'TRUE' ]; then
	echo "Type: ${1}"
	echo "URL: ${2}"
	echo "XML Sent:\n${3}\n\n"
	echo "XML Result:\n${XMLResult}\n\n"
	exit
  fi
}



function getCookie () {
	#Remove a cookie if it exists
	rm -f cookie.txt
	echo -n Enter the password for the APIC.
	read -s password
	cookieResult=$(curl -sk https://${apic}/api/aaaLogin.xml -d "<aaaUser name='${userName}' pwd='${password}'/>" -c cookie.txt)
	printf "\n"
	writeStatus "%5s Cookie Obtained - Access to APIC established"
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
				fromPort='${1}'
				name='${interfaceProfile}-S1-P${1}' 
				nameAlias='' 
				toCard='1' 
				toPort='${1}'/>
		</infraHPortS>
	</infraAccPortP> 
  "
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
	local policyGroupDN="uni/infra/funcprof/accbundle-${name}"

	intPolGrpXML="
	<infraFuncP>
	<infraAccBndlGrp 
	dn='${policyGroupDN}'
	lagT='node' 
	name='${name}'>
	<infraRsAttEntP 
		annotation='' 
		tDn='${AepDN}'/>
	<infraRsCdpIfPol 
		annotation='' 
		tnCdpIfPolName='CDP-Enabled'/>
	<infraRsHIfPol 
		annotation='' 
		tnFabricHIfPolName='10G'/>
	<infraRsLacpPol 
		annotation='' 
		tnLacpLagPolName='LACP-Active'/>
	<infraRsLldpIfPol 
		annotation='' 
		tnLldpIfPolName='LLDP-Enabled'/>
	</infraAccBndlGrp>
	</infraFuncP>
	"      
	accessAPIC 'POST' " https://${apic}/api/node/mo/uni/infra.xml" "${intPolGrpXML}"
	writeStatus "%15s interface Policy Group Configured"
	intProfXML="
	<infraHPortS 
		dn='uni/infra/accportprof-${interfaceProfile}/hports-${name}-typ-range' 
		name='${name}' 
		type='range'>
		<infraSubPortBlk 
			fromCard='1' 
			fromPort='${interface}' 
			fromSubPort='${i}' 
			name='${name}' 
			toCard='1' 
			toPort='${interface}' 
			toSubPort='${i}'/>
			<infraRsAccBaseGrp 
				tDn='${policyGroupDN}'/>
	</infraHPortS>
	"
	accessAPIC 'POST' "https://${apic}/api/node/mo/uni/infra/accportprof-${interfaceProfile}.xml" "${intProfXML}" 
	writeStatus "%15s Interface Port Selector Configured for VPC"
    done 
}

function createDefaultPolicies () {
  writeStatus "%5s Creating dependency requirements"
  defaultPolicyXML="
  <polUni>
  	<infraInfra>
		<fabricHIfPol autoNeg='on' descr='' dn='uni/infra/hintfpol-10G'  fecMode='inherit' linkDebounce='100' name='10G'  nameAlias='' ownerKey='' ownerTag='' speed='10G'/>
		<fabricHIfPol autoNeg='on' descr='' dn='uni/infra/hintfpol-100G' fecMode='inherit' linkDebounce='100' name='100G' nameAlias='' ownerKey='' ownerTag='' speed='100G'/>	
		<fabricHIfPol autoNeg='on' descr='' dn='uni/infra/hintfpol-40G'  fecMode='inherit' linkDebounce='100' name='40G'  nameAlias='' ownerKey='' ownerTag='' speed='40G'/>	
		<cdpIfPol adminSt='enabled'  descr='' dn='uni/infra/cdpIfP-CDP-Enabled'  name='CDP-Enabled'  nameAlias='' ownerKey='' ownerTag=''/>
		<cdpIfPol adminSt='disabled' descr='' dn='uni/infra/cdpIfP-CDP-Disabled' name='CDP-Disabled' nameAlias='' ownerKey='' ownerTag=''/>
		<lldpIfPol adminRxSt='disabled' adminTxSt='disabled' descr='' dn='uni/infra/lldpIfP-LLDP-Disabled' name='LLDP-Disabled' nameAlias='' ownerKey='' ownerTag=''/>	
		<lldpIfPol adminRxSt='enabled'  adminTxSt='enabled'  descr='' dn='uni/infra/lldpIfP-LLDP-Enabled'  name='LLDP-Enabled'  nameAlias='' ownerKey='' ownerTag=''/>
		<lacpLagPol ctrl='fast-sel-hot-stdby,graceful-conv,susp-individual' dn='uni/infra/lacplagp-LACP-Active' maxLinks='16' minLinks='1' mode='active' name='LACP-Active' nameAlias='' ownerKey='' ownerTag=''/>
		<mcpInstPol adminSt='enabled' dn='uni/infra/mcpInstP-default' initDelayTime='180' loopDetectMult='3' loopProtectAct='port-disable' name='default' ownerKey='DefaultOwnerKey' txFreq='2'/>
		<edrErrDisRecoverPol dn='uni/infra/edrErrDisRecoverPol-default' errDisRecovIntvl='300' name='default'>
			<edrEventP descr='' event='event-mcp-loop'  name='' nameAlias='' recover='yes'/>
			<edrEventP descr='' event='event-bpduguard' name='' nameAlias='' recover='yes'/>
			<edrEventP descr='' event='event-ep-move'   name='' nameAlias='' recover='yes'/>

		</edrErrDisRecoverPol>
		
	</infraInfra>
  </polUni>
  "
  accessAPIC 'POST' "https://${apic}/api/node/mo.xml" "${defaultPolicyXML}"
}

getCookie

createDefaultPolicies

writeStatus "Ensure a breakout policy exists."

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

accessAPIC 'POST' "https://${apic}/api/node/mo/uni/infra/funcprof.xml" "${breakoutPolicyXML}"

writeStatus "Start loop through each interface"

for ((interface=1; interface <= lastInterface; interface++))
  do
    addPortToBreakout $interface
    configureBreakoutInterface
    #TODO Create Interface selector for each breakout interface and associate with VPC Policy Group
  done

#Removing the cookie used for access to the APIC
rm -f ./cookie.txt


