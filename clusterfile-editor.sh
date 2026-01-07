#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDITOR_DIR="${SCRIPT_DIR}/apps/editor"

IMAGE_REGISTRY="${IMAGE_REGISTRY:-quay.io/dds}"
IMAGE_NAME="${IMAGE_NAME:-clusterfile-editor}"
APP_VERSION_FILE="${APP_VERSION_FILE:-${EDITOR_DIR}/APP_VERSION}"
APP_VERSION="${APP_VERSION:-$(cat "${APP_VERSION_FILE}")}"
IMAGE_TAG="${IMAGE_TAG:-${APP_VERSION}}"
IMAGE_REF="${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

usage() {
    cat <<EOF
Usage: $0 [build|push|run|all]

Environment overrides:
  IMAGE_REGISTRY=quay.io/dds
  IMAGE_NAME=clusterfile-editor
  APP_VERSION_FILE=apps/editor/APP_VERSION
  APP_VERSION=0.1.0
  IMAGE_TAG=0.1.0
EOF
}

build_image() {
    sync_version
    podman build -t "${IMAGE_REF}" -f "${EDITOR_DIR}/Containerfile" "${SCRIPT_DIR}"
}

push_image() {
    podman push "${IMAGE_REF}"
}

run_image() {
    podman run -p 8000:8000 \
        -v "${SCRIPT_DIR}/templates:/app/templates" \
        -v "${SCRIPT_DIR}/data:/app/samples" \
        -v "${SCRIPT_DIR}/schema:/app/schema" \
        "${IMAGE_REF}"
}

sync_version() {
    local version="${APP_VERSION}"
    sed -i "s/version=\"[^\"]*\"/version=\"${version}\"/" "${EDITOR_DIR}/app/main.py"
    sed -i "s/<span class=\"app-version\">v[^<]*<\\/span>/<span class=\"app-version\">v${version}<\\/span>/" "${EDITOR_DIR}/static/index.html"
}

case "${1:-run}" in
    build) build_image ;;
    push) push_image ;;
    run) run_image ;;
    all) build_image; push_image ;;
    -h|--help) usage ;;
    *) echo "Unknown command: $1"; usage; exit 1 ;;
esac
