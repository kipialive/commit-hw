#!/usr/bin/env bash
set -e

CHART_VERSION="37.0.0"
CHART_NAME="traefik"
CHART_REPO="https://traefik.github.io/charts"

# Add the Traefik Helm repository
helm repo add ${CHART_NAME} ${CHART_REPO}
helm repo update

# Remove old chart directory if it exists
rm -rf ${CHART_NAME}

# Pull and untar the specified chart version
helm pull ${CHART_NAME}/${CHART_NAME} --version ${CHART_VERSION} --untar