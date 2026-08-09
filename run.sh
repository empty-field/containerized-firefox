#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="firefox-esr-f"
APP_NAME="Isolated Browser"
APP_COMMENT="Firefox in docker container"
DOCKERFILE_PATH="${SCRIPT_DIR}/image/Dockerfile"
COMPOSE_DIR="${SCRIPT_DIR}/compose"
COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

refresh_icon_cache() {
    local desktop_dir="${HOME}/.local/share/applications"
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$desktop_dir" 2>/dev/null || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
    fi
}

remove_application_images() {
    local images
    images=$(docker images --filter=reference="${IMAGE_NAME}" -q | sort -u | tr '\n' ' ')
    images=${images%% }
    if [[ -n "$images" ]]; then
        # shellcheck disable=SC2086
        docker rmi -f $images 2>/dev/null || true
    fi
}



install_desktop_entry() {
    local script_path
    script_path="$(readlink -f "$0")"
    local script_dir
    script_dir="$(dirname "$script_path")"
    local desktop_dir="${HOME}/.local/share/applications"
    local icon_dir="${HOME}/.local/share/icons/hicolor/scalable/apps"
    local icon_src="${script_dir}/assets/icon.svg"
    local icon_file="${icon_dir}/${APP_NAME,,}.svg"
    local desktop_file="${desktop_dir}/${APP_NAME,,}.desktop"
    mkdir -p "$desktop_dir" "$icon_dir"
    cp -f "$icon_src" "$icon_file"
    chmod 644 "$icon_file"
    cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Comment=${APP_COMMENT}
Exec="${script_path}" %F
Icon=${APP_NAME,,}
Terminal=false
Categories=Utility;
StartupNotify=true
EOF
    chmod 644 "$desktop_file"
}

uninstall_desktop_entry() {
    local desktop_dir="${HOME}/.local/share/applications"
    local icon_dir="${HOME}/.local/share/icons/hicolor/scalable/apps"
    local icon_file="${icon_dir}/${APP_NAME,,}.svg"
    local desktop_file="${desktop_dir}/${APP_NAME,,}.desktop"
    if [[ -f "$desktop_file" ]]; then
        rm -f "$desktop_file"
    fi
    if [[ -f "$icon_file" ]]; then
        rm -f "$icon_file"
    fi
}

case "${1:-}" in
    --install)
        install_desktop_entry
        refresh_icon_cache
        exit 0
        ;;
    --uninstall)
        uninstall_desktop_entry
        refresh_icon_cache
        remove_application_images
        exit 0
        ;;
esac

if ! docker info >/dev/null 2>&1; then
    echo "Docker is unavailable for current user."
    exit 1
fi

if ! command -v apt-cache >/dev/null; then
    echo "apt-cache not found"
    exit 1
fi

FF_FULL_VERSION=$(LC_ALL=C apt-cache policy firefox-esr 2>/dev/null | awk '/Candidate:/ {print $2}')
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

env HOST_UID="$(id -u)" docker compose up --abort-on-container-exit --remove-orphans

# Force stop when main window closed
docker compose stop
