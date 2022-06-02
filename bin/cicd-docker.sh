#!/bin/bash

set -o pipefail

if [ -z "${FTL_CLOUD_PROVIDER}" ]; then
  echo "[ERROR] Environment variable 'FTL_CLOUD_PROVIDER' is missing. Aborting..."
  exit 1
fi

if [ "${FTL_CLOUD_PROVIDER}" != "aws" ]; then
  echo "[ERROR] Environment variable 'FTL_CLOUD_PROVIDER' temporarily supports only 'aws'. Aborting..."
  exit 1
fi

if [ -n "${CODEBUILD_SRC_DIR}" ]; then
  CWD=${CODEBUILD_SRC_DIR}
else
  CWD="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 || exit 1; pwd -P )"
fi

export CICD_TEMP_VARS="/tmp/cicd-temp-vars-$(date '+%Y%m%d%H%M%S%N%Z').sh"
touch "${CICD_TEMP_VARS}"

echo "[EXEC] env | grep FTL_"
env | grep FTL_ | while read EACH; do
  echo "export TF_VAR_${EACH}" >> "${CICD_TEMP_VARS}"
done

echo "export CICD_REPOSITORY_DIR=\"${CWD}\"" >> "${CICD_TEMP_VARS}"

LWD="$( cd "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

if [ -f "${CWD}/bin/step-1-provider-auth.sh" ]; then
  echo "[EXEC] /bin/bash ${CWD}/bin/step-1-provider-auth.sh"
  /bin/bash "${CWD}/bin/step-1-provider-auth.sh"
else
  echo "[EXEC] /bin/bash ${LWD}/step-1-provider-auth.sh"
  /bin/bash "${LWD}/step-1-provider-auth.sh"
fi || { echo >&2 "[ERROR] Failed to run 'step-1-provider-auth.sh'. Aborting..."; exit 1; }

if [ -f "${CWD}/bin/step-0-container-image.sh" ]; then
  echo "[EXEC] /bin/bash ${CWD}/bin/step-0-container-image.sh"
  /bin/bash "${CWD}/bin/step-0-container-image.sh"
else
  echo "[EXEC] /bin/bash ${LWD}/step-0-container-image.sh"
  /bin/bash "${LWD}/step-0-container-image.sh"
fi || { echo >&2 "[ERROR] Failed to run 'step-0-container-image.sh'. Aborting..."; exit 1; }

if [ -f "${CICD_TEMP_VARS}" ]; then
  rm -f "${CICD_TEMP_VARS}"
fi

###########################################
### DO NOT ADD COMMANDS AFTER THIS LINE ###
###########################################
