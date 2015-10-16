## NRPE Monitoring Scripts

Each of these scripts makes a call to the endpoint to request information about that system's health. 

Each script should take exactly 1 argument and must be executable, the endpont number make the request to, for example: 

`./check_processes.sh 4`

Will check the number of processes running on the PDC-0004 endpoint. 

Any modications to this paradigm (1 argument) will require adjustments to the scripts that manage this scripts, in the parent directory.
