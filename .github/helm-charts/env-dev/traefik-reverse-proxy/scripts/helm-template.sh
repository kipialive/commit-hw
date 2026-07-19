#!/usr/bin/env bash
set -o errexit
set -o noglob
set -o nounset
set -o pipefail

cd "$(dirname "$0")"

source ./helm-template.env

helm repo add ${REPO_NAME} ${REPO_URL}
helm repo update
# echo $(pwd)
helm template "${CHART_NAME}" --repo "${REPO_URL}" --name-template "${RELEASE_NAME}" --namespace "${NAMESPACE}" --version "${CHART_VERSION}" --values "${VALUES_FILE}" --include-crds >chart.yaml
