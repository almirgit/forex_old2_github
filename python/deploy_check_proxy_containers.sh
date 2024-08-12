#!/usr/bin/env bash

set -e # show errors !!?
set -x # debug

targethostname=$1

homedir=/home/almir

cd ~/forex/python/
. ./env_vars.sh

#dname=$docker_container_name_get_proxies
#dimage=$docker_image_name_get_proxies
#dversion=$docker_image_version_get_proxies
#docker build -f "dockerfiles/Dockerfile--$dname" -t $dimage:$dversion .
#docker stop $dname || true
#docker rm   $dname || true
#docker run -d \
#    -e HOST_HOSTNAME=${targethostname} -e CONTAINER_NAME=${dname} \
#    --name $dname \
#    --mount type=bind,source=${docker_dir},target=/data2 \
#    --restart unless-stopped \
#    --log-driver local \
#    --log-opt max-size=10m \
#    --log-opt max-file=5 \
#    $dimage:$dversion




dname=$docker_container_name_check_proxies
dimage=$docker_image_name_check_proxies
dversion=$docker_image_version_check_proxies

docker build -f "dockerfiles/Dockerfile--$dname" -t $dimage:$dversion .

for (( instance_nr=1; instance_nr<=$docker_container_check_proxies_spawn_number; instance_nr++ ));
do
  dname=${docker_container_name_check_proxies}__${instance_nr}
  docker stop $dname || true
  docker rm   $dname || true
  docker run -d \
      -e HOST_HOSTNAME=${targethostname} -e CONTAINER_NAME=${dname} \
      --name $dname \
      --mount type=bind,source=${docker_dir},target=/data2 \
      --restart unless-stopped \
      --log-driver local \
      --log-opt max-size=10m \
      --log-opt max-file=5 \
      $dimage:$dversion
done
