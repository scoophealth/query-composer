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
#
FROM phusion/passenger-ruby19
MAINTAINER derek.roberts@gmail.com


# Enable ssh and create user for autossh tunnel
#
RUN rm -f /etc/service/sshd/down; \
    adduser --quiet --disabled-password --home /home/autossh autossh 2>&1


# Prepare /app/ folder
#
WORKDIR /app/
COPY . .
RUN sed -i -e "s/localhost:27017/hubdb:27017/" config/mongoid.yml; \
    chown -R app:app /app/; \
    /sbin/setuser app bundle install --path vendor/bundle


# Create startup script and make it executable
#
RUN SRV=rails; \
    mkdir -p /etc/service/${SRV}/; \
    ( \
      echo "#!/bin/bash"; \
      echo ""; \
      echo ""; \
      echo "# Create Endpoint public keys file (authorized_keys), if necessary"; \
      echo "#"; \
      echo "mkdir -p /home/autossh/.ssh/"; \
      echo "touch /home/autossh/.ssh/authorized_keys"; \
      echo "chown -R autossh:autossh /home/autossh/.ssh/"; \
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
      echo "/sbin/setuser app bundle exec /app/script/delayed_job stop > /dev/null"; \
    )  \
      >> /etc/service/${SRV}/run; \
    chmod +x /etc/service/${SRV}/run



# Batch query scheduling in cron
#
RUN ( \
      echo "# Run batch queries (23 PST = y UTC)"; \
      echo "0 7 * * * /app/util/run_batch_queries.sh"; \
    ) \
      | crontab -


# Run Command
#
CMD ["/sbin/my_init"]


# Ports and volumes
#
EXPOSE 2774
EXPOSE 3002
#
VOLUME /app/util/job_params/
VOLUME /home/autossh/.ssh/
VOLUME /etc/ssh/
VOLUME /root/.ssh/


################################################################################
# Temporary fix until ssh bug is patched (http://undeadly.org/cgi?action=article&sid=20160114142733)
################################################################################


RUN ( \
      echo ""; \
      echo "# Temporary ssh bug fix"; \
      echo "# "; \
      echo "Host *"; \
      echo "UseRoaming no"; \
  ) | tee -a /etc/ssh/ssh_config
