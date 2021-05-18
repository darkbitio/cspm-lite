#!/usr/bin/env bash

IMAGE_PATH="gcr.io/opencspm/cspm-lite:latest"
docker build -f docker/Dockerfile -t "${IMAGE_PATH}" "$(pwd)"
