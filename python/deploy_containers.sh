#!/usr/bin/env bash

set -e # show errors !!?
set -x # debug

targethostname=$1

cd ~/forex/python/
. ./env_vars.sh
docker build -f dockerfiles/${getfxrealtimedata_dockerfile} -t ${getfxrealtimedata_imagename}:${getfxrealtimedata_imageversion} .

csv_str=`cat ${getfxrealtimedata_containername_conf} |grep container_sufixes | cut -d= -f 2`
echo "csv_str: $csv_str"

#HOST_HOSTNAME=`hostname -f`
#HOST_HOSTNAME=$targethostname
CONTAINER_NAME=$getfxrealtimedata_containername
IMAGE_NAME=$getfxrealtimedata_imagename
IMAGE_VERSION=$getfxrealtimedata_imageversion
#DATA_DIR=$getfxrealtimedata_datadir
DATA_DIR=$docker_datadir

IFS=','
read -ra CSV <<< "$csv_str"   # str is read into an array as tokens separated by IFS
for container_suffix in "${CSV[@]}";
do
    container_suffix="_$container_suffix"
    #printf "$container_suffix!\n"
    this_container_name=${CONTAINER_NAME}$container_suffix
    printf "Deploying $this_container_name...\n"
    # TODO: check if use of () and 'true' is correct!!
    mkdir -p ${DATA_DIR} && (docker stop ${this_container_name} || true && docker rm ${this_container_name} || true) && mkdir -p ${DATA_DIR} && docker run -d -e HOST_HOSTNAME=${targethostname} -e CONTAINER_NAME=${this_container_name} --name ${this_container_name} --mount type=bind,source=${DATA_DIR},target=/data/app --log-opt max-size=20m --log-opt max-file=5 --restart unless-stopped ${IMAGE_NAME}:${IMAGE_VERSION}
done

#echo ""

