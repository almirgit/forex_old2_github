#!/usr/bin/env bash

. python/env_vars.sh

for targethostname in nur3.kodera.hr sof3.dakataki.de; 
do
  echo ":)"
#  rsync -va --delete -e "ssh -o ProxyCommand=\"ssh -W %h:%p ${bastionusername}@${bastionhostname}\" -o StrictHostKeyChecking=no" proxy_loader_secret.yml ${targetusername}@${targethostname}:${docker_dir}
done

