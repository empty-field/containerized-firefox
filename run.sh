#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="firefox-esr-f"
DOCKERFILE_PATH="${SCRIPT_DIR}/image/Dockerfile"
COMPOSE_DIR="${SCRIPT_DIR}/compose"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

if ! docker info >/dev/null 2>&1; then
    echo "Docker is unavailable for current user."
    exit 1
fi

if ! command -v apt-cache >/dev/null; then
    echo "apt-cache not found"
    exit 1
fi

FF_FULL_VERSION=$(apt-cache policy firefox-esr 2>/dev/null | awk '/Кандидат:/ {print $2}')
if [[ -z "$FF_FULL_VERSION" || "$FF_FULL_VERSION" == "(none)" ]]; then
    echo "Unable to determine available firefox version"
    exit 1
fi

FF_VERSION=$(echo "$FF_FULL_VERSION" | cut -d'-' -f1)

IMAGE_TAG="${IMAGE_NAME}:${FF_VERSION}"
IMAGE_LATEST="${IMAGE_NAME}:latest"

if docker image inspect "${IMAGE_TAG}" >/dev/null 2>&1; then
    echo "Tag ${IMAGE_TAG} already exists at local cache"
else
    echo "Tag ${IMAGE_TAG} not found, building..."

    if [[ ! -f "${DOCKERFILE_PATH}" ]]; then
        echo "Dockerfile not found ${DOCKERFILE_PATH}"
        exit 1
    fi

    docker build \
        --build-arg USER_ID="$(id -u)" \
        --build-arg GROUP_ID="$(id -g)" \
        -t "${IMAGE_TAG}" \
        -t "${IMAGE_LATEST}" \
        -f "${DOCKERFILE_PATH}" \
        "${SCRIPT_DIR}/image"
fi

docker tag "${IMAGE_TAG}" "${IMAGE_LATEST}" 2>/dev/null || true

if ! xhost | grep -q "LOCAL:"; then
    xhost +local:docker >/dev/null 2>&1
fi

if [[ ! -f "${COMPOSE_FILE}" ]]; then
    echo "docker-compose.yml not found at ${COMPOSE_FILE}"
    exit 1
fi

echo "Starting Firefox..."
cd "${COMPOSE_DIR}"

docker compose up --abort-on-container-exit --remove-orphans

# Force stop when main window closed
docker compose stop
