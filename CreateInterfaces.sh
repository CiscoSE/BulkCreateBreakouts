# Copyright (c) 2019 Cisco and/or its affiliates.

# This software is licensed to you under the terms of the Cisco Sample
# Code License, Version 1.0 (the "License"). You may obtain a copy of the
# License at

#               https://developer.cisco.com/docs/licenses

# All use of the material herein must be in accordance with the terms of
# the License. All rights not expressly granted by the License are
# reserved. Unless required by applicable law or agreed to separately in
# writing, software distributed under the License is distributed on an "AS
# IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied.

# Items you should probably change - Configurable by Aurgument 
apicDefault='';             apic=''							# Can be a DNS name or IP depending on your environment
userNameDefault='';         userName=''					# User Name to Logon to the APIC
aepNameDefault=''           aepName=''	        # AEP Name for configuration
startInterfaceDefault='';   startInterface=''	  # First interface in a range to configure
lastInterfaceDefault='';    lastInterface=''    # Last interface in a range to configure
interfaceProfileDefault=''; interfaceProfile=''	# Policy Groups and Profiles are named with this value.

# Constants used through out the script
breakoutPortGroup='4x10-Breakout'	# This gets used for a lot of created object names
breakoutType='10g-4x'			# This is a constant that must not change It must be 10g-4x or 25g-4x
aepDnPrefix='uni/infra/attentp-'; aepDn=''

#Debug Variables
writeLogFile="./$(date +%Y%m%d-%H%M%S)-xmlLogFile.log"	#Time stamped file name.
writeLog='enabled'					#When enabled, XML is logged to the file system along with any status messages. 
#writeLog='disabled'


argumentExit(){
  # Required for help processing
  printf '%s\n' "$1" >&2
	exit 1
}

#Help File
showHelp() {
  cat << EOF
  Usage: ${0##*/} [--apic [IP]] [--user [User]] [--aepName [DN]] --interfaceName [Name] [--start [Num]] [--last [Num]]...

  Where:

      -h               Display this help and exit
      --apic           IP or fqdn of APIC to be changed
      --user           Username to access APIC
      --aepName        DN of Attachable Entity Profile
      --start          Port number of first interface in range to configure
      --last           Port number of last interface in range to configure
      --interfaceName  Prefix used to name all interfaces.
      -v               verbose mode. 
EOF
}


#Color Coding for screen output.
green="\e[1;32m"
red="\e[1;31m"
yellow="\e[1;33m"
normal="\e[1;0m"


function exitRoutine () {
  #Use this instead of the exit command to ensure we clean up the cookies.
  if [ -f cookie.txt ]; then
    rm -f cookie.txt
    printf "%5s[ ${green} INFO ${normal} ] Removing APIC cookie\n"
  fi
  exit
}

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
	printf "Type: ${1}"
	printf "URL: ${2}"
	printf "XML Sent:\n${3}\n\n"
	printf "XML Result:\n${XMLResult}\n\n"
	exitRoutine
  fi
  if [ "${writeLog}" = 'enabled' ]; then
    	printf "Type: ${1}" >> $writeLogFile
	printf "URL: ${2}" >> $writeLogFile		
	printf "XML Sent:\n${3}\n\n" >> $writeLogFile
	printf "XML Result:\n${XMLResult}\n\n" >> $writeLogFile
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
    exitRoutine
  fi
  
  printf "%5s[ ${green} INFO ${normal} ] ${1}\n"

  if [ "${writeLog}" = 'enabled' ]; then
    printf "%5s[ ${green} INFO ${normal} ] ${1}\n" >> $writeLogFile
  fi
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
				name='${interfaceProfle}-S1-P${1}' 
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
	local policyGroupDN="uni/infra/funcprof/accbundle-${name}-VPC"

	intPolGrpXML="
	<infraFuncP>
	<infraAccBndlGrp 
	dn='${policyGroupDN}'
	lagT='node' 
	name='${name}-VPC'>
	<infraRsAttEntP 
		annotation='' 
		tDn='${aepDn}'/>
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
		<fabricHIfPol autoNeg='on' descr='' dn='uni/infra/hintfpol-25G'  fecMode='inherit' linkDebounce='100' name='25G'  nameAlias='' ownerKey='' ownerTag='' speed='25G'/>	
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

#Log File Start
if [ "${writeLog}" = 'enabled' ]; then
  printf 'Starting Log file' > $writeLogFile
fi

while :; do
  case $1 in 
    -h|-\?|--help)
		  showHelp			# Display help in formation in showHelp
			exit
		  ;;
		--apic)
		  if [ "$2" ]; then
			  apic=$2
				shift
			fi
		  ;;
		--user)
		  if [ "$2" ]; then
			  userName=$2
				shift
			fi
			;;
		--aep[nN]ame)
		  if [ $2 ]; then
			  aepDn="${aepDnPrefix}${2}"
				shift
			fi
			;;
		--interface[Nn]ame)
		  if [ $2 ]; then
			  interfaceProfile=$2
				shift
			fi
			;;
		--start)
		  if [ $2 ]; then
			  startInterface=$2
				shift
			fi
			;;
		--last)
		  if [ $2 ]; then
			  lastInterface=$2
				shift
			fi
		  ;;
		-v|--verbose)
		  verbose=$((verbose + 1))
		  ;;
		*)
		  break
  esac
	shift
done

#Set defaults if the value isnt set by argument. 
if [[ ( -z ${apic} && -n ${apicDefault} ) ]]; then
  apic=$apicDefault
elif [[ -z ${apic} ]]; then
  writeStatus "Required value (APIC) not present" 'FAIL'
fi

if [[ ( -z ${userName} && -n ${userNameDefault} ) ]]; then
  userName=$userNameDefault
elif [[ -z ${userName} ]]; then
  writeStatus "Required value (user) not present" 'FAIL'
fi

if [[ ( -z ${aepDn} && -n ${aepNameDefault} ) ]]; then
  aepDn="${aepDnPrefix}${aepNameDefault}"
elif [[ -z ${aepDn} ]]; then
  writeStatus "Required value (aepName) not present" 'FAIL'
fi

if [[ ( -z ${interfaceProfile} && -n ${interfaceProfileDefault} ) ]]; then
  interfaceProfile=$interfaceProfileDefault
elif [[ -z ${interfaceProfile} ]]; then
  writeStatus "Required value (interfaceProfile) not present" 'FAIL'
fi

if [[ ( -z ${startInterface} && -n ${startInterfaceDefault} ) ]]; then
  startInterface=$startInterfaceDefault
elif [[ -z ${startInterface} ]]; then
  writeStatus "Required value (start) not present" 'FAIL'
fi

if [[ ( -z ${lastInterface} && -n ${lastInterfaceDefault} ) ]]; then
  lastInterface=$lastInterfaceDefault
elif [[ -z ${lastInterface} ]]; then
  writeStatus "Required value (last) not present" 'FAIL'
fi

writeStatus "APIC Value: \t\t${apic}"
writeStatus "userName Value: \t${userName}"
writeStatus "aepDn Value: \t\t${aepDn}"
writeStatus "start Value: \t\t${startInterface}"
writeStatus "last Value: \t\t${lastInterface}"
writeStatus "interfaceProfile Value\t${interfaceProfile}"
writeStatus "verbose Value:\t\t${verbose}"

#These are needed later, and probably shouldn't be changed.
interfaceProfileDN="uni/infra/accportprof-${interfaceProfile}"
breakoutPolicyDN="uni/infra/funcprof/brkoutportgrp-${breakoutPortGroup}"
#Get cookie

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

for ((interface=startInterface; interface <= lastInterface; interface++))
  do
    addPortToBreakout $interface
    configureBreakoutInterface
  done

#Removing the cookie used for access to the APIC
exitRoutine


