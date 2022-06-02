#!/bin/sh

git --version > /dev/null 2>&1 || { echo >&2 "[ERROR] git is missing. Aborting..."; exit 1; }

if [ -z "${CICD_TEMP_VARS}" ]; then
  echo "[ERROR] Environment variable 'CICD_TEMP_VARS' is missing. Aborting..."
  exit 1
elif [ -f "${CICD_TEMP_VARS}" ]; then
  echo "[EXEC] source ${CICD_TEMP_VARS}"
  . "${CICD_TEMP_VARS}"
fi

if [ -n "${CICD_REPOSITORY_URL}" ]; then
  echo "[EXEC] git clone ${CICD_REPOSITORY_URL}"
  git clone ${CICD_REPOSITORY_URL}

  echo "[EXEC] cd $(echo ${CICD_REPOSITORY_URL} | rev | cut -d '/' -f 1 | rev | cut -d '.' -f 1)"
  cd "$(echo ${CICD_REPOSITORY_URL} | rev | cut -d '/' -f 1 | rev | cut -d '.' -f 1)" || exit 1
elif [ -n "${CICD_REPOSITORY_DIR}" ]; then
  echo "[EXEC] cd ${CICD_REPOSITORY_DIR}"
  cd "${CICD_REPOSITORY_DIR}" || exit 1
fi

CICD_BRANCH_DEFAULT="$(git branch | grep -oE 'main|master')"
if [ -z "${CICD_BRANCH_TO}" ]; then CICD_BRANCH_TO=${CICD_BRANCH_DEFAULT}; fi
if [ -z "${CICD_BRANCH_FROM}" ]; then CICD_BRANCH_FROM=${CICD_BRANCH_DEFAULT}; fi

echo "export CICD_BRANCH_TO=\"${CICD_BRANCH_TO}\"" >> "${CICD_TEMP_VARS}"
echo "export CICD_BRANCH_FROM=\"${CICD_BRANCH_FROM}\"" >> "${CICD_TEMP_VARS}"
echo "export CICD_BRANCH_DEFAULT=\"${CICD_BRANCH_DEFAULT}\"" >> "${CICD_TEMP_VARS}"
echo "export CICD_REPOSITORY_DIR=\"$(pwd -P)\"" >> "${CICD_TEMP_VARS}"

if [ -n "${CICD_BRANCH_TO}" ]; then
  echo "[EXEC] git checkout ${CICD_BRANCH_TO}"
  git checkout ${CICD_BRANCH_TO}
fi

if [ -n "${CICD_BRANCH_FROM}" ]; then
  echo "[EXEC] git checkout ${CICD_BRANCH_FROM}"
  git checkout ${CICD_BRANCH_FROM}
fi

###########################################
### DO NOT ADD COMMANDS AFTER THIS LINE ###
###########################################
