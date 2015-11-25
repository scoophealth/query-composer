#!/bin/bash

# This script adds a command to the NRPE service, command names must be compatible with 
# 	the command names used by the Nagios server to access the NRPE commands. 
# 
# This script takes 3 arguments: $ ./add_nrpe_command.sh <PATH_TO_SCRIPT> <ENDPOINT_NUMBER> <PATH_TO_NRPE_CONFIG>, for example: 
# 
# 	$ ./add_nrpe_command.sh /usr/local/lib/nagios/check_processes.sh 5 /etc/nagios/nrpe_local.cfg
# 
# If the PATH_TO_NRPE_CONFIG argument is not given a default /etc/nagios/nrpe_local.cfg is used. 
#
# Exit Codes for the script are: 
#
# 	0 - Completed noramally, command succcessfully added.
# 	1 - Error due to invalid parameters
# 	2 - Did not complete due to command already being installed. 

if [ $# -ne 2 ] && [ $# -ne 3 ]; then
	echo ""
	echo "ERROR: Invalid number of parameters to script, received "$#" parameters, expected 2 or 3". 
	echo "Usage: $ ./add_nrpe_command.sh <PATH_TO_SCRIPT> <ENDPOINT_NUMBER> <PATH_TO_NRPE_CONFIG>"
	echo ""
	exit 1
fi

CMD_SCRIPT=$1
EP=$2

if [ $# == 3 ]; then 
	NRPE_CONFIG=$3
else
	NRPE_CONFIG=/etc/nagios/nrpe_local.cfg
fi 

# Check that all files exist as expected. 

# Check that config file is in place.
if ! [ -w $NRPE_CONFIG ]; then
	echo "ERROR: no such file: $NRPE_CONFIG"	
	exit 1
fi

# Check that nrpe script file is in place.
if ! [ -x $CMD_SCRIPT ]; then
	echo "ERROR: no such file: $CMD_SCRIPT"
	exit 1
fi

# Do some manipulation of the names.
# TODO: Update this to use PDC-XXXX naming scheme; changes need to occur on Nagios server side aswell. 

SCRIPT_NAME=$(basename $CMD_SCRIPT)
EP_NUM=$(printf "%03d" $EP)
EP_NAME="pdc"$EP_NUM
CMD_NAME=${SCRIPT_NAME%.*}"_"$EP_NAME
CMD="command["$CMD_NAME"]="$CMD_SCRIPT" "$EP

# Check if the script is already installed. 

if grep -q $CMD_NAME $NRPE_CONFIG; then
	# The command is already installed, we will not overwrite this.
	#
	echo "WARNING: $CMD_NAME is already in the $NRPE_CONFIG file, will not overwrite."	
	exit 2
else
	# The command is not already installed, will append this to the config file.
	#
	echo $CMD >> $NRPE_CONFIG
	echo "INFO: Adding $CMD to $NRPE_CONFIG file. "
	exit 0 
fi
