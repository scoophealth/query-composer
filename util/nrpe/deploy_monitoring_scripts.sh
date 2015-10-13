#!/bin/bash

# This script deploys the scripts required for NRPE to monitor endpoints.
# 
# Assumptions: 
# 	
# 	* This script assumes that the PDC composer code is deployed within the /app directory of this host.
#
# In summary this script: 
# 
# 	1) Creates (or clears) the directory /usr/local/lib/nagios/
# 	2) Copies the monitoring scripts from ./monitoring_scripts/ into /usr/local/lib/nagios/	
# 	3) Sets up commands in /etc/nagios/nrpe_local.cfg to use the scripts.
# 	4) Restarts the NRPE server.
# 
# This scripts takes a list of endpoint id's to deploy monitoring for example: 
#
#	$ deploy_monitoring_scripts.sh 1 2 3 4 5
#
# Will set up the scripts for endpoints 1 through 5

# Set up some variables

BASE_DIR=/app/util/nrpe/
SCRIPT_DEPLOY_DIR=/usr/local/lib/nagios
NRPE_CFG_FILE=/etc/nagios/nrpe_local.cfg

# 1) Remove any existing scripts within the /usr/local/lib/nagios/ directory.

rm -rf $SCRIPT_DEPLOY_DIR

mkdir -p $SCRIPT_DEPLOY_DIR

# 2) Copy in the default scripts from within the ./monitoring_scripts/ directory. 

cp -r $BASE_DIR""monitoring_scripts/* $SCRIPT_DEPLOY_DIR

# 3) Set up the commands in /etc/nagios/nrpe_local.cfg, we use another script to support this.

for ep in $@ #gets all arguments to the script.
do
	echo "Configuring scripts for endpoint: "$ep

	for f in $SCRIPT_DEPLOY_DIR/* #get all executable filese
	do
		if [[ -x $f ]]; then
			./add_nrpe_command.sh $NRPE_CFG_FILE $f $ep
		fi
	done
done

exit 0
