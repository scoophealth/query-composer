#!/bin/bash

# This script takes 1 argument, the endpoint number to check. 

# Check the number of arguments and make sure it is as expected. 

if [ $# -ne 1 ]; then 
	echo ""
	echo "ERROR: Script takes exactly 1 argument, the endpoint to connect to."
	echo "Sample usage: $ ./check_users.sh 5"
	echo ""
	exit 1
fi

# Get the port by adding the endpoint number base port.
PORT=$((40000+$1)) 

URL="http://localhost:"$PORT"/sysinfo/users"

TMPFILE=`/bin/tempfile -p_PDC_`
CMD=`/usr/bin/curl -sSf $URL > $TMPFILE 2>&1`
STATUS=$?

if [ $STATUS -ne 0 ]; then
  /bin/echo "UNKNOWN - For $URL got $(cat $TMPFILE)"
  /bin/rm $TMPFILE
  exit 3
fi
# Expect two lines of output from call to web server
# first line should be Nagios message
NAGIOSMSG=`/usr/bin/head -1 $TMPFILE`
# second line should be Nagios status code
STATUSSTR=`/bin/cat $TMPFILE | /usr/bin/head -2 | /usr/bin/tail -1`
/bin/rm $TMPFILE
NAGIOSSTATUS=-1
if [ "$STATUSSTR" == "Status Code: 0" ]; then
  NAGIOSSTATUS=0
fi
if [ "$STATUSSTR" == "Status Code: 1" ]; then
  NAGIOSSTATUS=1
fi
if [ "$STATUSSTR" == "Status Code: 2" ]; then
  NAGIOSSTATUS=2
fi
if [ "$STATUSSTR" == "Status Code: 3" ]; then
  NAGIOSSTATUS=3
fi
if [ "$NAGIOSSTATUS" -ge 0 -a "$NAGIOSSTATUS" -le 3 ]; then
  echo $NAGIOSMSG
  exit $NAGIOSSTATUS
else
  # shouldn't get here unless there was a completely unexpected response
  /bin/echo "UNKNOWN - Unexpected response from \"$URL\". Return status $STATUS"
  exit 3
fi
