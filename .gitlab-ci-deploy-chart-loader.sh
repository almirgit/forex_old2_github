#/usr/bin/env bash
set -e

CI_REGISTRY=$1
CI_REGISTRY_USER=$2
CI_REGISTRY_PASSWORD=$3

BASTION_USER=$4
BASTION_HOST=$5
DEFAULT_TARGET_USER=$6

IMAGE_NAME=$7
IMAGE_VERSION=$8
CONTAINER_NAME=$9
DATA_DIR=${10}
CONF_FILE=${11}

#for targethostname in sof1.kodera.hr mos4.kodera.hr mos6.kodera.hr; do
#    echo "Deploy on ${DEFAULT_TARGET_USER}@${targethostname}"
#    echo "Jump over ${BASTION_USER}@${BASTION_HOST}"
#    echo "-->"
#    ssh -o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p ${BASTION_USER}@${BASTION_HOST}" -o StrictHostKeyChecking=no ${DEFAULT_TARGET_USER}@${targethostname} "cat /home/${DEFAULT_TARGET_USER}/.CI_REGISTRY_PASSWORD | docker login -u gitlab-ci-token --password-stdin gitlab.kodera.hr:5050 && docker pull $CI_REGISTRY/almir/forex-python/${IMAGE_NAME}:${IMAGE_VERSION}"
#    ssh ${DEFAULT_TARGET_USER}@${targethostname} "mkdir -p ${DATA_DIR} && (docker stop ${CONTAINER_NAME} || true && docker rm ${CONTAINER_NAME} || true) && mkdir -p ${DATA_DIR} && docker run -d -e HOST_HOSTNAME=${targethostname} -e CONTAINER_NAME=${CONTAINER_NAME} --name ${CONTAINER_NAME} --mount type=bind,source=${DATA_DIR},target=/data/app $CI_REGISTRY/almir/forex-python/${IMAGE_NAME}:${IMAGE_VERSION}"
#    echo ""
#done

for targethostname in sof1.kodera.hr; do
#for targethostname in sof1.kodera.hr mos4.kodera.hr mos6.kodera.hr; do
    echo "Deploy on ${DEFAULT_TARGET_USER}@${targethostname}"
    echo "Jump over ${BASTION_USER}@${BASTION_HOST}"
    echo "-->"

    ssh -o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p ${BASTION_USER}@${BASTION_HOST}" -o StrictHostKeyChecking=no ${DEFAULT_TARGET_USER}@${targethostname} "cat /home/${DEFAULT_TARGET_USER}/.CI_REGISTRY_PASSWORD | docker login -u gitlab-ci-token --password-stdin gitlab.kodera.hr:5050 && docker pull $CI_REGISTRY/almir/forex-python/${IMAGE_NAME}:${IMAGE_VERSION}"

    csv_str=`ssh -o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p ${BASTION_USER}@${BASTION_HOST}" -o StrictHostKeyChecking=no ${DEFAULT_TARGET_USER}@${targethostname} "cat ${CONF_FILE} |grep container_sufixes | cut -d= -f 2"`

    IFS=','
    read -ra CSV <<< "$csv_str"   # str is read into an array as tokens separated by IFS
    for container_suffix in "${CSV[@]}";
    do
        container_suffix="_$container_suffix"
        this_container_name=${CONTAINER_NAME}$container_suffix
        printf "Deploying $this_container_name...\n"
        ssh ${DEFAULT_TARGET_USER}@${targethostname} "mkdir -p ${DATA_DIR} && (docker stop ${this_container_name} || true && docker rm ${this_container_name} || true) && mkdir -p ${DATA_DIR} && docker run -d -e HOST_HOSTNAME=${targethostname} -e CONTAINER_NAME=${this_container_name} --name ${this_container_name} --mount type=bind,source=${DATA_DIR},target=/data/app $CI_REGISTRY/almir/forex-python/${IMAGE_NAME}:${IMAGE_VERSION}"
    done
    echo ""
done


