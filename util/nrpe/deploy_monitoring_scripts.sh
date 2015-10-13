#!/bin/bash

# This script deploys the scripts required for NRPE to monitor endpoints.
#
# !!!!!!!!!!!!!!!!! THIS SCRIPT WILL REMOVE ANY EXISTING NRPE CONFIGURATIONS !!!!!!!!!!!!!!!!!!!!!!!
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

echo ""
echo ""
echo "---------------------------------------------------"
echo "THIS SCRIPT WILL REMOVE ANY EXISTING NRPE CONFIGURATIONS"
read -p "Press ENTER to continue, CTRL-C to halt."
echo "---------------------------------------------------"
echo ""
echo ""

if [ $# == 0 ]; then
	echo "ERROR: This script takes endpoint number arguments, $# were provided, exiting..."
	echo ""
	exit 1
	
fi

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

# 3.1) Remove existing config file

rm -rf $NRPE_CFG_FILE
touch $NRPE_CFG_FILE

for ep in $@ #gets all arguments to the script.
do
	echo ""
	echo "Configuring scripts for endpoint: "$ep
	echo "---------------------------------"

	for f in $SCRIPT_DEPLOY_DIR/* #get all executable filese
	do
		if [[ -x $f ]]; then
			./add_nrpe_command.sh $f $ep $NRPE_CFG_FILE
		fi
	done
	echo "================================"
done

# 4) Restart nagios-nrpe server

echo ""
echo "Restarting NRPE Server: "
echo "------------------------"

sudo service nagios-nrpe-server restart

echo ""
echo "-----------------------"
echo "All Done, Exiting..."

exit 0
