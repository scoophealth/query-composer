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


# Enable and configure SSH (for AutoSSH user/tunnel)
#
RUN rm -f /etc/service/sshd/down; \
    adduser --quiet --disabled-password --home /home/autossh autossh 2>&1


# Prepare /app/ folder
#
WORKDIR /app/
COPY . .
RUN chown -R app:app /app/
USER app
RUN bundle install --path vendor/bundle
RUN sed -i -e "s/localhost:27017/hubdb:27017/" config/mongoid.yml


# Batch query scheduling in cron
#
USER root
RUN ( \
      echo "# Run batch queries"; \
      echo "0 23 * * * /app/util/scheduled_job_post.py /app/util/job_params/job_params.json"; \
    ) \
      | crontab -


# Create startup script and make it executable
#
RUN SRV=rails; \
    mkdir -p /etc/service/${SRV}/; \
    ( \
      echo "#!/bin/bash"; \
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
      echo "exec /sbin/setuser app bundle exec rails server -p 3002"; \
    )  \
      >> /etc/service/${SRV}/run; \
    chmod +x /etc/service/${SRV}/run


# Startup script for Delayed Job app
#
RUN SRV=delayed_job; \
    mkdir -p /etc/service/${SRV}/; \
    ( \
      echo "#!/bin/bash"; \
      echo ""; \
      echo ""; \
      echo "# Start delayed job"; \
      echo "#"; \
      echo "cd /app/"; \
      echo "rm /app/tmp/pids/server.pid > /dev/null"; \
      echo "exec /sbin/setuser app bundle exec /app/script/delayed_job run"; \
      echo "#/sbin/setuser app bundle exec /app/script/delayed_job stop > /dev/null"; \
    )  \
      >> /etc/service/${SRV}/run; \
    chmod +x /etc/service/${SRV}/run


# Ports and volumes
#
EXPOSE 2774
EXPOSE 3002
#
VOLUME /app/util/job_params/
VOLUME /home/autossh/.ssh/
VOLUME /etc/ssh/
VOLUME /root/.ssh/


# Run Command
#
CMD ["/sbin/my_init"]
