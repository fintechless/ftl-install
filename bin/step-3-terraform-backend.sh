#!/bin/sh

terrahub --version > /dev/null 2>&1 || { npm install -g terrahub; }
terrahub --version > /dev/null 2>&1 || { echo >&2 "[ERROR] terrahub is missing. Aborting..."; exit 1; }

if [ -z "${CICD_TEMP_VARS}" ]; then
  echo "[ERROR] Environment variable 'CICD_TEMP_VARS' is missing. Aborting..."
  exit 1
elif [ -f "${CICD_TEMP_VARS}" ]; then
  echo "[EXEC] source ${CICD_TEMP_VARS}"
  . "${CICD_TEMP_VARS}"
fi

if [ -n "${CICD_REPOSITORY_DIR}" ]; then
  echo "[EXEC] cd ${CICD_REPOSITORY_DIR}"
  cd "${CICD_REPOSITORY_DIR}" || exit 1
fi

if [ -n "${FTL_CLOUD_BUCKET}" ]; then
  echo "[EXEC] terrahub configure -c terraform.backendConfig.bucket=${FTL_CLOUD_BUCKET}"
  terrahub configure -c terraform.backendConfig.bucket="${FTL_CLOUD_BUCKET}"
fi

if [ -n "${FTL_CLOUD_REGION}" ]; then
  echo "[EXEC] terrahub configure -c terraform.backendConfig.region=${FTL_CLOUD_REGION}"
  terrahub configure -c terraform.backendConfig.region="${FTL_CLOUD_REGION}"
fi

if [ -n "${FTL_CLOUD_ROLE}" ]; then
  echo "[EXEC] terrahub configure -c terraform.backendConfig.role_arn=${FTL_CLOUD_ROLE}"
  terrahub configure -c terraform.backendConfig.role_arn="${FTL_CLOUD_ROLE}"
fi

###########################################
### DO NOT ADD COMMANDS AFTER THIS LINE ###
###########################################
