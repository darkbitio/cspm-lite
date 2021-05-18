#!/usr/bin/env bash

IMAGE_PATH="gcr.io/opencspm/cspm-lite:latest"
CURRENT_DIR="$(PWD)"
COMMAND="${@:-rake -T}"
HOMEDIR="${HOME}"
START_DATE="2021-03-15"
#PROJECT_ID="$(gcloud config get-value project)"
PROJECT_ID="db-tenant-32d72099"
BUCKET_NAME="db-tenant-32d72099-us-opencspm"
docker run --rm -it --net="docker_cspm" \
  -v "${CURRENT_DIR}/data:/app/data" \
  -v "${CURRENT_DIR}/../opencspm-controls:/opencspm-controls" \
  -v "${HOMEDIR}/.config/gcloud:/root/.config/gcloud" \
  -e RAKE_START_DATE="${START_DATE}" \
  -e RAKE_PROJECT_ID="${PROJECT_ID}" \
  -e RAKE_BUCKET_NAME="${BUCKET_NAME}" \
  -e GOOGLE_AUTH_SUPPRESS_CREDENTIALS_WARNINGS=true \
  "${IMAGE_PATH}" ${COMMAND}
