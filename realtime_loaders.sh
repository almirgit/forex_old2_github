#!/bin/bash
start_stop=$1

echo $start_stop

if [ "$start_stop" == "" ]; then
  echo "No argument: start | stop"
fi


targetusername="almir"
bastionhostname="sof1.kodera.hr"
bastionusername="bastion4"
#bastionusername="gitlab-runner"
for targethostname in nur3.kodera.hr; do
  if [ "$start_stop" == "start" ]; then
    ssh -o ProxyCommand="ssh -W %h:%p ${bastionusername}@${bastionhostname}" -o StrictHostKeyChecking=no ${targetusername}@${targethostname} 'docker start `docker ps -a |grep realtime |cut -d " " -f 1`'
  fi
  if [ "$start_stop" == "stop" ]; then
    ssh -o ProxyCommand="ssh -W %h:%p ${bastionusername}@${bastionhostname}" -o StrictHostKeyChecking=no ${targetusername}@${targethostname} 'docker stop `docker ps -a |grep realtime |cut -d " " -f 1`'
  fi
done
