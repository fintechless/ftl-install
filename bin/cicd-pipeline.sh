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

if [ -n "${CODECOMMIT_BASE_REF}" ]; then CICD_BRANCH_TO="${CODECOMMIT_BASE_REF/refs\/heads\//}";
elif [ -n "${CODEBUILD_WEBHOOK_BASE_REF}" ]; then CICD_BRANCH_TO="${CODEBUILD_WEBHOOK_BASE_REF/refs\/heads\//}";
elif [ -n "${CICD_BASE_REF}" ]; then CICD_BRANCH_TO="${CICD_BASE_REF/refs\/heads\//}"; fi

if [ -n "${CODECOMMIT_HEAD_REF}" ]; then CICD_BRANCH_FROM="${CODECOMMIT_HEAD_REF/refs\/heads\//}";
elif [ -n "${CODEBUILD_WEBHOOK_HEAD_REF}" ]; then CICD_BRANCH_FROM="${CODEBUILD_WEBHOOK_HEAD_REF/refs\/heads\//}";
elif [ -n "${CICD_HEAD_REF}" ]; then CICD_BRANCH_FROM="${CICD_HEAD_REF/refs\/heads\//}"; fi

if printf "%s\n" "${CICD_BRANCH_TO}" | grep -q "workspace\/"; then
  echo "export CICD_BUILD_TARGET=\"${CICD_BRANCH_TO/workspace\//}\"" >> "${CICD_TEMP_VARS}"
fi

echo "export CICD_BRANCH_TO=\"${CICD_BRANCH_TO}\"" >> "${CICD_TEMP_VARS}"
echo "export CICD_BRANCH_FROM=\"${CICD_BRANCH_FROM}\"" >> "${CICD_TEMP_VARS}"
echo "export CICD_REPOSITORY_DIR=\"${CWD}\"" >> "${CICD_TEMP_VARS}"

LWD="$( cd "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

if [ -f "${CWD}/bin/step-1-provider-auth.sh" ]; then
  echo "[EXEC] /bin/bash ${CWD}/bin/step-1-provider-auth.sh"
  /bin/bash "${CWD}/bin/step-1-provider-auth.sh"
else
  echo "[EXEC] /bin/bash ${LWD}/step-1-provider-auth.sh"
  /bin/bash "${LWD}/step-1-provider-auth.sh"
fi || { echo >&2 "[ERROR] Failed to run 'step-1-provider-auth.sh'. Aborting..."; exit 1; }

if [ -f "${CWD}/bin/step-2-code-repository.sh" ]; then
  echo "[EXEC] /bin/bash ${CWD}/bin/step-2-code-repository.sh"
  /bin/bash "${CWD}/bin/step-2-code-repository.sh"
else
  echo "[EXEC] /bin/bash ${LWD}/step-2-code-repository.sh"
  /bin/bash "${LWD}/step-2-code-repository.sh"
fi || { echo >&2 "[ERROR] Failed to run 'step-2-code-repository.sh'. Aborting..."; exit 1; }

if [ -f "${CWD}/bin/step-3-terraform-backend.sh" ]; then
  echo "[EXEC] /bin/bash ${CWD}/bin/step-3-terraform-backend.sh"
  /bin/bash "${CWD}/bin/step-3-terraform-backend.sh"
else
  echo "[EXEC] /bin/bash ${LWD}/step-3-terraform-backend.sh"
  /bin/bash "${LWD}/step-3-terraform-backend.sh"
fi || { echo >&2 "[ERROR] Failed to run 'step-3-terraform-backend.sh'. Aborting..."; exit 1; }

if [ -f "${CWD}/bin/step-4-custom-exec.sh" ]; then
  echo "[EXEC] /bin/bash ${CWD}/bin/step-4-custom-exec.sh"
  /bin/bash "${CWD}/bin/step-4-custom-exec.sh"
else
  echo "[EXEC] /bin/bash ${LWD}/step-4-custom-exec.sh"
  /bin/bash "${LWD}/step-4-custom-exec.sh"
fi || { echo >&2 "[ERROR] Failed to run 'step-4-custom-exec.sh'. Aborting..."; exit 1; }

if [ -f "${CICD_TEMP_VARS}" ]; then
  rm -f "${CICD_TEMP_VARS}"
fi

###########################################
### DO NOT ADD COMMANDS AFTER THIS LINE ###
###########################################
