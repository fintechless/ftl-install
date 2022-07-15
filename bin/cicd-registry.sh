#!/bin/bash

if [ -z "${FTL_CLOUD_PROVIDER}" ]; then
  echo "[ERROR] Environment variable 'FTL_CLOUD_PROVIDER' is missing. Aborting..."
  exit 1
fi

if [ "${FTL_CLOUD_PROVIDER}" != "aws" ]; then
  echo "[ERROR] Environment variable 'FTL_CLOUD_PROVIDER' temporarily supports only 'aws'. Aborting..."
  exit 1
fi

if [ -z "${FTL_RUNTIME_BUCKET}" ]; then
  echo "[ERROR] Environment variable 'FTL_RUNTIME_BUCKET' is missing. Aborting..."
  exit 1
fi

if [ -n "${CODEBUILD_SRC_DIR}" ]; then
  CWD=${CODEBUILD_SRC_DIR}
else
  CWD="$( cd "$(dirname "$0")/.." >/dev/null 2>&1 || exit 1; pwd -P )"
fi

LWD="$( cd "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

REPOS="${CWD}/allrepos"
mkdir -p ${REPOS} && cd ${REPOS}
curl -s https://api.github.com/users/fintechless/repos | grep -w clone_url | grep -o '[^"]\+://.*ftl-msa.\+.git' | xargs -L1 git clone
git clone https://github.com/fintechless/ftl-install
git clone https://github.com/fintechless/ftl-api
git clone https://github.com/fintechless/ftl-mgr

_run()
{
  cd ${1}

  if [ -f "${2}/bin/cicd-pipeline.sh" ]; then
    echo "[EXEC] /bin/bash ${2}/bin/cicd-pipeline.sh"
    export CODEBUILD_SRC_DIR=$(pwd -P) && export CICD_THUB_INCLUDE=aws_ecr_repository && /bin/bash "${2}/bin/cicd-pipeline.sh"
  else
    echo "[EXEC] /bin/bash ${3}/cicd-pipeline.sh"
    export CODEBUILD_SRC_DIR=$(pwd -P) && export CICD_THUB_INCLUDE=aws_ecr_repository && /bin/bash "${3}/cicd-pipeline.sh"
  fi || { echo >&2 "[ERROR] Failed to run 'cicd-pipeline.sh'. Aborting..."; exit 1; }

  if [ -f "${2}/bin/cicd-docker.sh" ]; then
    echo "[EXEC] /bin/bash ${2}/bin/cicd-docker.sh"
    export CODEBUILD_SRC_DIR=$(pwd -P) && /bin/bash "${2}/bin/cicd-docker.sh"
  else
    echo "[EXEC] /bin/bash ${3}/cicd-docker.sh"
    export CODEBUILD_SRC_DIR=$(pwd -P) && /bin/bash "${3}/cicd-docker.sh"
  fi || { echo >&2 "[ERROR] Failed to run 'cicd-docker.sh'. Aborting..."; exit 1; }

  if [ -f "${2}/bin/cicd-pipeline.sh" ]; then
    echo "[EXEC] /bin/bash ${2}/bin/cicd-pipeline.sh"
    export CODEBUILD_SRC_DIR=$(pwd -P) && export CICD_THUB_INCLUDE=aws_ && /bin/bash "${2}/bin/cicd-pipeline.sh"
  else
    echo "[EXEC] /bin/bash ${3}/cicd-pipeline.sh"
    export CODEBUILD_SRC_DIR=$(pwd -P) && export CICD_THUB_INCLUDE=aws_ && /bin/bash "${3}/cicd-pipeline.sh"
  fi || { echo >&2 "[ERROR] Failed to run 'cicd-pipeline.sh'. Aborting..."; exit 1; }
}

_run ${REPOS}/ftl-api ${CWD} ${LWD}
_run ${REPOS}/ftl-msa-msg-in ${CWD} ${LWD}
_run ${REPOS}/ftl-msa-msg-out ${CWD} ${LWD}
_run ${REPOS}/ftl-msa-msg-pacs-008 ${CWD} ${LWD}
_run ${REPOS}/ftl-msa-rmq-in ${CWD} ${LWD}
_run ${REPOS}/ftl-msa-rmq-out ${CWD} ${LWD}

cd ${REPOS}/ftl-mgr
if [ -f "${CWD}/bin/cicd-pipeline.sh" ]; then
  echo "[EXEC] /bin/bash ${CWD}/bin/cicd-pipeline.sh"
  export CODEBUILD_SRC_DIR=$(pwd -P) && export CICD_THUB_BUILD=true && /bin/bash "${CWD}/bin/cicd-pipeline.sh"
else
  echo "[EXEC] /bin/bash ${LWD}/cicd-pipeline.sh"
  export CODEBUILD_SRC_DIR=$(pwd -P) && export CICD_THUB_BUILD=true && /bin/bash "${LWD}/cicd-pipeline.sh"
fi || { echo >&2 "[ERROR] Failed to run 'cicd-pipeline.sh'. Aborting..."; exit 1; }

cd ${REPOS}
for i in $(ls -d */ | grep ftl-msa); do
  aws s3 sync --exclude "^\." ./${i%%/} s3://${FTL_RUNTIME_BUCKET}/git/fintechless/${i%%/}/main
done

###########################################
### DO NOT ADD COMMANDS AFTER THIS LINE ###
###########################################
