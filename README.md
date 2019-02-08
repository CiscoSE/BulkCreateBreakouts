CAUTION!
Scripts in this area were written to specific customer needs and are potentially destructive if not properly understood. These scripts do not run without customization and will make substantial changes into your environment. It is critical that you take a backup of your ACI environment prior to running this script. For most environments, the script is a template for how to work with the Cisco ACI API from bash rather than a tool for actual deployment. 

Intended Purpose (Create Interfaces)
This script is for bulk loading interface configurations. We make a lot of assumptions in this file about what is wanted. Specially:

-	CDP is enabled
-	LLDP is enabled
-	All interfaces are LACP enabled – Though the script only does one interface as stored in GIT HUB, it is really intended to do two interfaces. Whatever name you give to interfaceProfile should be mapped by switch profile to two switches in a VPC configuration. Configuration is Mode Active
-	 AEP needs the DN from an AEP in your environment. 

Each breakout port and VPC pair is a single entry, both for the Policy Group, and the port selector. This is done so you can remove individual interfaces later without having to delete large groups of configured interfaces. 

All ports are breakouts, and as configured, all interfaces are assumed to be 10G instead of 25. Future changes may put a method in to change quickly between the two, but that doesn’t exist today. You will need to change several locations to make this change. 

Global policies are modified in this script. Specifically, the mis-cabling protocol and the error Disabled Recovery Protocol. 

Several sections have been created as functions so they can be reused. The top four functions are intended to always be together and probably won’t work effectively unless you include them as a group. They include:

-	exitRoutine: Used so that you always clean up the cookie on exit. Otherwise curl will leave it on the drive.
-	accessAPIC: used for all API Calls to the APIC except the authentication call. That call is slightly modified for cookie operations.
-	getCookie: Used for the initial authentication. Writes a cookie file down to the file system that is good for a short period of time and does not contain the password used for authentication. All API calls used the cookie file after initial authentication. 
-	writeStatus: used for sending messages to the console or the log file. Will also end the script if a FAIL state is reported. 

