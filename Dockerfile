# Dockerfile for the PDC's Composer (a.k.a. Hub) service
#
#
# Composer for aggregate data queries. Links to HubDB.
#
# Example:
# sudo docker pull pdcbc/composer
# sudo docker run -d --name=composer -h composer --restart=always \
#   --link hubdb:hubdb \
#   -p 2774:22 \
#   -p 3002:3002 \
#   -v /pdc/data/config/ssh/authorized_keys/:/home/autossh/.ssh/:ro \
#   -v /pdc/data/config/ssh/known_hosts/:/root/.ssh/:rw \
#   -v /pdc/data/config/ssh/ssh_keys_hub/:/etc/ssh/:rw \
#   -v /pdc/data/config/scheduled_jobs/:/app/util/job_params:rw  \
#   pdcbc/dclapi
#
# Linked containers
# - HubDB:           --link hubdb:hubdb
#
# External ports
# - AutoSSH:         -p <hostPort>:22
# - Web UI:          -p <hostPort>:3002
#
# Folder paths
# - authorized_keys: -v </path/>:/home/autossh/.ssh/:ro
# - known_hosts:     -v </path/>:/root/.ssh/:rw
# - SSH keys:        -v </path/>:/etc/ssh/:rw
# - job params:      -v </path/>:/app/util/job_params/:rw
#
# Releases
# - https://github.com/PDCbc/composer/releases
#
#
FROM phusion/passenger-ruby19
MAINTAINER derek.roberts@gmail.com
ENV RELEASE 0.1.3


# Packages
#
RUN apt-get update; \
    apt-get install -y \
      git; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Enable and configure SSH (for AutoSSH user/tunnel)
#
RUN rm -f /etc/service/sshd/down; \
    adduser --quiet --disabled-password --home /home/autossh autossh 2>&1


# Prepare /app/ folder
#
WORKDIR /app/
RUN git clone https://github.com/pdcbc/composer.git . -b ${RELEASE}; \
    chown -R app:app /app/; \
    /sbin/setuser app bundle install --path vendor/bundle; \
    sed -i -e "s/localhost:27017/hubdb:27017/" config/mongoid.yml


# Batch query scheduling in cron
#
RUN ( \
      echo "# Run batch queries"; \
      echo "0 23 * * * /app/util/scheduled_job_post.py /app/util/job_params/job_params.json"; \
    ) \
      | crontab -


# Create startup script and make it executable
#
RUN mkdir -p /etc/service/app/; \
    ( \
      echo "#!/bin/bash"; \
      echo "#"; \
      echo "set -e -o nounset"; \
      echo ""; \
      echo ""; \
      echo "# Create Endpoint public keys file (authorized_keys)"; \
      echo "#"; \
      echo "mkdir -p /home/autossh/.ssh/"; \
      echo "touch /home/autossh/.ssh/authorized_keys"; \
      echo "chown -R autossh:autossh /home/autossh/.ssh/"; \
      echo ""; \
      echo ""; \
      echo "# Create job_params.json, if necessary"; \
      echo "#"; \
      echo "if [ ! -f /app/util/job_params/job_params.json ]"; \
      echo "then"; \
      echo "  mkdir -p /app/util/job_params/"; \
      echo "  cp /app/util/job_params.json /app/util/job_params/"; \
      echo "fi"; \
      echo ""; \
      echo ""; \
      echo "# Start service"; \
      echo "#"; \
      echo "cd /app/"; \
      echo "chown -R app:app /app/"; \
      echo "/sbin/setuser app bundle install"; \
      echo "/sbin/setuser app bundle exec script/delayed_job start"; \
      echo "/sbin/setuser app bundle exec rails server -p 3002"; \
      echo "/sbin/setuser app bundle exec script/delayed_job stop"; \
    )  \
      >> /etc/service/app/run; \
    chmod +x /etc/service/app/run


# Volumes
#
VOLUME /app/util/job_params/
VOLUME /home/autossh/.ssh/


# Run Command
#
CMD ["/sbin/my_init"]
