#!/usr/bin/env bash

. python/env_vars.sh

for targethostname in nur3.kodera.hr; 
do
  rsync -va --delete --exclude={'.git','.gitignore'} -e "ssh -o ProxyCommand=\"ssh -W %h:%p ${bastionusername}@${bastionhostname}\" -o StrictHostKeyChecking=no" ./python ${targetusername}@${targethostname}:~/forex/
  ssh -o ProxyCommand="ssh -W %h:%p ${bastionusername}@${bastionhostname}" -o StrictHostKeyChecking=no ${targetusername}@${targethostname} "bash ~/forex/python/deploy_containers.sh ${targethostname}"
done
