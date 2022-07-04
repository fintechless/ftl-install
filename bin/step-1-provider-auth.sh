#!/bin/bash

set -o pipefail

aws --version > /dev/null 2>&1 || { pip3 install awscli; }
aws --version > /dev/null 2>&1 || { echo >&2 "[ERROR] aws is missing. Aborting..."; exit 1; }
jq --version > /dev/null 2>&1 || { echo >&2 "[ERROR] jq is missing. Aborting..."; exit 1; }

if [ -z "${CICD_TEMP_VARS}" ]; then
  echo "[ERROR] Environment variable 'CICD_TEMP_VARS' is missing. Aborting..."
  exit 1
elif [ -f "${CICD_TEMP_VARS}" ]; then
  echo "[EXEC] source ${CICD_TEMP_VARS}"
  . "${CICD_TEMP_VARS}"
fi

if [ "${FTL_CLOUD_PROVIDER}" != "aws" ]; then
  echo "[ERROR] Expected 'FTL_CLOUD_PROVIDER' to be 'aws', instead received '${FTL_CLOUD_PROVIDER}'. Aborting..."
  exit 1
fi

ACCESS_KEY="AWS_ACCESS_KEY_ID"
SECRET_KEY="AWS_SECRET_ACCESS_KEY"

if [ -n "${CICD_BUILD_TARGET}" ]; then
  ACCESS_KEY="${ACCESS_KEY}_$(echo ${CICD_BUILD_TARGET} | tr [a-z] [A-Z])"
  SECRET_KEY="${SECRET_KEY}_$(echo ${CICD_BUILD_TARGET} | tr [a-z] [A-Z])"
  echo "export CICD_SWITCH_TARGET=\"${CICD_BUILD_TARGET}\"" >> "${CICD_TEMP_VARS}"
fi

if [ -n "${CICD_RELEASE_TARGET}" ]; then
  ACCESS_KEY="${ACCESS_KEY}_$(echo ${CICD_RELEASE_TARGET} | tr [a-z] [A-Z])"
  SECRET_KEY="${SECRET_KEY}_$(echo ${CICD_RELEASE_TARGET} | tr [a-z] [A-Z])"
  echo "export CICD_SWITCH_TARGET=\"${CICD_RELEASE_TARGET}\"" >> "${CICD_TEMP_VARS}"
fi

if [ -n "${!ACCESS_KEY}" ] && [ -n "${!SECRET_KEY}" ]; then
  echo "[WARN] Switching to provider with credentials '${ACCESS_KEY}' and '${SECRET_KEY}'."

  mkdir -p ~/.aws
  if [ -f ~/.aws/config ]; then mv -f ~/.aws/config ~/.aws/config-$(date '+%Y%m%d%H%M%S%N%Z').bkp; fi
  touch ~/.aws/config

  echo "[default]" > ~/.aws/config
  echo "aws_access_key_id=${!ACCESS_KEY}" >> ~/.aws/config
  echo "aws_secret_access_key=${!SECRET_KEY}" >> ~/.aws/config
else
  echo "[INFO] Environment variables '${ACCESS_KEY}' and '${SECRET_KEY}' are NOT defined. Skipping..."
fi

if [ -n "${FTL_CLOUD_ROLE}" ]; then
  echo "[EXEC] aws sts assume-role --role-arn ${FTL_CLOUD_ROLE}"
  ASSUME_ROLE="$(aws sts assume-role --role-arn ${FTL_CLOUD_ROLE} --role-session-name awscli | jq '.Credentials')"
  ACCESS_KEY="$(echo ${ASSUME_ROLE} | jq '.AccessKeyId')"
  SECRET_KEY="$(echo ${ASSUME_ROLE} | jq '.SecretAccessKey')"
  SESSION_TOKEN="$(echo ${ASSUME_ROLE} | jq '.SessionToken')"

  mkdir -p ~/.aws
  if [ -f ~/.aws/config ]; then mv -f ~/.aws/config ~/.aws/config-$(date '+%Y%m%d%H%M%S%N%Z').bkp; fi
  touch ~/.aws/config

  echo "[default]" > ~/.aws/config
  echo "aws_access_key_id=${ACCESS_KEY//\"/}" >> ~/.aws/config
  echo "aws_secret_access_key=${SECRET_KEY//\"/}" >> ~/.aws/config
  echo "aws_session_token=${SESSION_TOKEN//\"/}" >> ~/.aws/config
fi

echo "[EXEC] aws sts get-caller-identity"
CICD_CLOUD_CALLER="$(aws sts get-caller-identity)"
CICD_CLOUD_ACCOUNT="$(echo ${CICD_CLOUD_CALLER} | jq '.Account')"
CICD_CLOUD_ACCOUNT="${CICD_CLOUD_ACCOUNT//\"/}"

echo "[EXEC] aws ec2 describe-availability-zones"
CICD_CLOUD_DESCRIBE="$(aws ec2 describe-availability-zones --query 'AvailabilityZones[0]')"
CICD_CLOUD_REGION="$(echo ${CICD_CLOUD_DESCRIBE} | jq '.RegionName')"
CICD_CLOUD_ALIAS="$(echo ${CICD_CLOUD_DESCRIBE} | jq '.ZoneId' | cut -d '-' -f 1)"

echo "export CICD_CLOUD_ACCOUNT=\"${CICD_CLOUD_ACCOUNT}\"" >> "${CICD_TEMP_VARS}"
echo "export CICD_CLOUD_REGION=\"${CICD_CLOUD_REGION//\"/}\"" >> "${CICD_TEMP_VARS}"
echo "export CICD_CLOUD_ALIAS=\"${CICD_CLOUD_ALIAS//\"/}\"" >> "${CICD_TEMP_VARS}"

###########################################
### DO NOT ADD COMMANDS AFTER THIS LINE ###
###########################################
