#!/bin/bash

PWD=$(pwd)

NRPE_PORT=3010 
NRPE_CONFIG=/etc/nagios/nrpe.cfg

# install the NRPE service

sudo apt-get update
sudo apt-get install nagios-nrpe-plugin -y 

# Set the port for NRPE to listen on: 

sed -i 's/server_port=[0-9]\+/server_port='$NRPE_PORT'/g' $NRPE_CONFIG

# Make the /usr/local/lib/nagios directory for storing plugin scripts

mkdir -p /usr/local/lib/nagios

# Make a nrpe_local.cfg file if it does not already exist

touch /etc/nagios/nrpe_local.cfg 

# Move into the working directory

cd /app/util/nrpe/

# Use the file endpoints.txt as a list of endpoint numbers to use.

./deploy_monitoring_scripts.sh $(cat endpoints.txt)

# Move back to original directory

cd $PWD
