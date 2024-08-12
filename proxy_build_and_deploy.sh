#!/usr/bin/env bash

. python/env_vars.sh

for targethostname in nur3.kodera.hr; 
do
  rsync -va --delete -e "ssh -o ProxyCommand=\"ssh -W %h:%p ${bastionusername}@${bastionhostname}\" -o StrictHostKeyChecking=no" "${targethostname}__get_forex_realtime_data.conf" ${targetusername}@${targethostname}:~/get_forex_realtime_data.conf
  #rsync -vr --delete --exclude={'.git','.gitignore','.gitlab-ci.yml'} -e ssh . $USERNAME@$HOSTNAME:$DESTINATION
  rsync -va --delete --exclude={'.git','.gitignore'} -e "ssh -o ProxyCommand=\"ssh -W %h:%p ${bastionusername}@${bastionhostname}\" -o StrictHostKeyChecking=no" ./python ${targetusername}@${targethostname}:~/forex/
  ssh -o ProxyCommand="ssh -W %h:%p ${bastionusername}@${bastionhostname}" -o StrictHostKeyChecking=no ${targetusername}@${targethostname} "bash ~/forex/python/deploy_get_proxy_containers.sh ${targethostname}"

done

for targethostname in nur3.kodera.hr sof2.dakataki.de; 
do
  rsync -va --delete --exclude={'.git','.gitignore'} -e "ssh -o ProxyCommand=\"ssh -W %h:%p ${bastionusername}@${bastionhostname}\" -o StrictHostKeyChecking=no" ./python ${targetusername}@${targethostname}:~/forex/
  ssh -o ProxyCommand="ssh -W %h:%p ${bastionusername}@${bastionhostname}" -o StrictHostKeyChecking=no ${targetusername}@${targethostname} "bash ~/forex/python/deploy_check_proxy_containers.sh ${targethostname}"
done
