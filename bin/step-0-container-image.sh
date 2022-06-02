#!/bin/bash

set -o pipefail

aws --version > /dev/null 2>&1 || { echo >&2 "[ERROR] aws is missing. Aborting..."; exit 1; }
docker --version > /dev/null 2>&1 || { echo >&2 "[ERROR] docker is missing. Aborting..."; exit 1; }
jq --version > /dev/null 2>&1 || { echo >&2 "[ERROR] jq is missing. Aborting..."; exit 1; }
yq --version > /dev/null 2>&1 || { echo >&2 "[ERROR] yq is missing. Aborting..."; exit 1; }

if [ -z "${CICD_TEMP_VARS}" ]; then
  echo "[ERROR] Environment variable 'CICD_TEMP_VARS' is missing. Aborting..."
  exit 1
elif [ -f "${CICD_TEMP_VARS}" ]; then
  echo "[EXEC] source ${CICD_TEMP_VARS}"
  . "${CICD_TEMP_VARS}"
fi

if [ -z "${CICD_ECR_REPOSITORY}" ]; then
  if [ -n "${1}" ]; then CICD_ECR_REPOSITORY="${1}"; else CICD_ECR_REPOSITORY="ftl/msa"; fi
fi

if [ -z "${CICD_ECR_VERSION}" ]; then
  if [ -n "${2}" ]; then CICD_ECR_VERSION="${2}"; else CICD_ECR_VERSION="latest"; fi
fi

if [ -z "${CICD_ECR_PLATFORM}" ]; then
  if [ -n "${3}" ]; then CICD_ECR_PLATFORM="${3}"; else CICD_ECR_PLATFORM="linux/amd64"; fi
fi

if [ -f "${CICD_REPOSITORY_DIR}/.dockercontainers" ]; then
  DOCKER_CONTAINERS="$(cat ${CICD_REPOSITORY_DIR}/.dockercontainers)"
else
  DOCKER_CONTAINERS="$(cat << EOM
msa:
  docker:
    name: ftl_docker.msa
    port: 5000
EOM
)"
fi

echo "[INFO] Docker login to AWS ECR"
CICD_ECR_ENDPOINT=${CICD_CLOUD_ACCOUNT}.dkr.ecr.${CICD_CLOUD_REGION}.amazonaws.com
aws ecr get-login-password | docker login --username AWS --password-stdin ${CICD_ECR_ENDPOINT}

echo "[INFO] Process FTL-API microservices (identified by 'msa' keyword)"
MICROSERVICES=($(echo "${DOCKER_CONTAINERS}" | yq e -o=json | jq -r '.msa|keys' | tr -d '[],"'))
for MSA in "${MICROSERVICES[@]}"; do
  MSA="$(echo ${MSA} | xargs)"
  
  CICD_ECR_REPOSITORY="ftl/msa"
  CICD_ECR_REPOSITORY="${CICD_ECR_REPOSITORY}/${MSA}"

  BUILD_ARGS=""
  CONTAINER_NAME="$(echo "${DOCKER_CONTAINERS}" | yq e -o=json | jq --arg name ${MSA} -r '.msa[$name].name')"
  if [ -n "${CONTAINER_NAME}" ]; then
    BUILD_ARGS="${BUILD_ARGS} --build-arg DOCKER_CONTAINER_NAME=${CONTAINER_NAME}"
  fi
  CONTAINER_PORT="$(echo "${DOCKER_CONTAINERS}" | yq e -o=json | jq --arg name ${MSA} -r '.msa[$name].port')"
  if [ -n "${CONTAINER_PORT}" ]; then
    BUILD_ARGS="${BUILD_ARGS} --build-arg DOCKER_CONTAINER_PORT=${CONTAINER_PORT}"
  fi

  echo "[INFO] Build Docker image for '${MSA}'"
  docker build \
    -t ${CICD_ECR_REPOSITORY}:${CICD_ECR_VERSION} \
    -f ${CICD_REPOSITORY_DIR}/Dockerfile ${CICD_REPOSITORY_DIR} \
    --platform ${CICD_ECR_PLATFORM} ${BUILD_ARGS}

  echo "[INFO] Tag Docker image for '${MSA}'"
  docker tag ${CICD_ECR_REPOSITORY}:${CICD_ECR_VERSION} ${CICD_ECR_ENDPOINT}/${CICD_ECR_REPOSITORY}:${CICD_ECR_VERSION}

  echo "[INFO] Push Docker image for '${MSA}'"
  docker push ${CICD_ECR_ENDPOINT}/${CICD_ECR_REPOSITORY}:${CICD_ECR_VERSION}
done

echo "[INFO] Process FTL-MGR microservices (identified by 'mgr' keyword)"
MICROSERVICES=($(echo "${DOCKER_CONTAINERS}" | yq e -o=json | jq -r '.mgr|keys' | tr -d '[],"'))
for MSA in "${MICROSERVICES[@]}"; do
  MSA="$(echo ${MSA} | xargs)"

  CICD_ECR_REPOSITORY="ftl/mgr"
  CICD_ECR_REPOSITORY="${CICD_ECR_REPOSITORY}/${MSA}"

  BUILD_ARGS=""
  CONTAINER_NAME="$(echo "${DOCKER_CONTAINERS}" | yq e -o=json | jq --arg name ${MSA} -r '.mgr[$name].name')"
  if [ -n "${CONTAINER_NAME}" ]; then
    BUILD_ARGS="${BUILD_ARGS} --build-arg DOCKER_CONTAINER_NAME=${CONTAINER_NAME}"
  fi
  CONTAINER_PORT="$(echo "${DOCKER_CONTAINERS}" | yq e -o=json | jq --arg name ${MSA} -r '.mgr[$name].port')"
  if [ -n "${CONTAINER_PORT}" ]; then
    BUILD_ARGS="${BUILD_ARGS} --build-arg DOCKER_CONTAINER_PORT=${CONTAINER_PORT}"
  fi

  echo "[INFO] Build Docker image for '${MSA}'"
  docker build \
    -t ${CICD_ECR_REPOSITORY}:${CICD_ECR_VERSION} \
    -f ${CICD_REPOSITORY_DIR}/Dockerfile ${CICD_REPOSITORY_DIR} \
    --platform ${CICD_ECR_PLATFORM} ${BUILD_ARGS}

  echo "[INFO] Tag Docker image for '${MSA}'"
  docker tag ${CICD_ECR_REPOSITORY}:${CICD_ECR_VERSION} ${CICD_ECR_ENDPOINT}/${CICD_ECR_REPOSITORY}:${CICD_ECR_VERSION}

  echo "[INFO] Push Docker image for '${MSA}'"
  docker push ${CICD_ECR_ENDPOINT}/${CICD_ECR_REPOSITORY}:${CICD_ECR_VERSION}
done

###########################################
### DO NOT ADD COMMANDS AFTER THIS LINE ###
###########################################
