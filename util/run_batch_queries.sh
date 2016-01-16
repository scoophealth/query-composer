#!/bin/bash
#
set -e -o nounset


# Prep job_params, if necessary
#
[ -s ./job_params/job_params.json ]|| \
  echo cp ./job_params.json-sample ./job_params/job_params.json


# Run batch queries
#
./scheduled_job_post.py ./job_params/job_params.json > /batch_queries.log
