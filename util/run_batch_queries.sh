#!/bin/bash
#
set -e -o nounset


# Find and chanbge to script directory
#
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}


# Prep job_params, if necessary
#
[ -s ./job_params/job_params.json ]|| \
  echo cp ./job_params.json-sample ./job_params/job_params.json


# Run batch queries
#
./scheduled_job_post.py ./job_params/job_params.json > /batch_queries.log
