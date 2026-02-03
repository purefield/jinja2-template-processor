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
Usage: $0 [build|push|run|all|release] [major|minor|patch|x.y.z]
Default: run

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

release_image() {
    local bump="${1:-}"
    local current="${APP_VERSION}"
    local next="${current}"

    if [ -z "${bump}" ]; then
        echo "Select version bump: major, minor, patch, or x.y.z"
        read -r bump
    fi

    if [[ "${bump}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        next="${bump}"
    else
        IFS='.' read -r major minor patch <<< "${current}"
        case "${bump}" in
            major) major=$((major + 1)); minor=0; patch=0 ;;
            minor) minor=$((minor + 1)); patch=0 ;;
            patch) patch=$((patch + 1)) ;;
            *)
                echo "Invalid bump: ${bump}"
                exit 1
                ;;
        esac
        next="${major}.${minor}.${patch}"
    fi

    echo "${next}" > "${APP_VERSION_FILE}"
    APP_VERSION="${next}"
    IMAGE_TAG="${APP_VERSION}"
    IMAGE_REF="${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

    sync_version
    update_changelog
    tag_release
    build_image
    push_image
    podman tag "${IMAGE_REF}" "${IMAGE_REGISTRY}/${IMAGE_NAME}:latest"
    podman push "${IMAGE_REGISTRY}/${IMAGE_NAME}:latest"
}

run_image() {
    # Build fresh image before running
    echo "Building image: ${IMAGE_REF}"
    build_image

    echo "Running image: ${IMAGE_REF}"
    podman run --rm -p 8080:8000 \
        -v "${SCRIPT_DIR}/templates:/app/templates:ro" \
        -v "${SCRIPT_DIR}/data:/app/samples:ro" \
        -v "${SCRIPT_DIR}/schema:/app/schema:ro" \
        "${IMAGE_REF}"
}

sync_version() {
    # Version is read from APP_VERSION file by main.py and fetched by JS from /healthz
    # Just ensure the file exists
    local version="${APP_VERSION}"
    echo "Version: ${version}"
}

update_changelog() {
    local changelog="${EDITOR_DIR}/static/changelog.md"
    local tmp_file
    local insert_file
    local last_tag=""
    local range=""
    local editor="${EDITOR:-vi}"

    if command -v git >/dev/null 2>&1; then
        last_tag="$(git -C "${SCRIPT_DIR}" describe --tags --abbrev=0 2>/dev/null || true)"
    fi

    if [ -n "${last_tag}" ]; then
        range="${last_tag}..HEAD"
    else
        range="HEAD"
    fi

    if [ -f "${changelog}" ] && rg -q "^## ${APP_VERSION}$" "${changelog}"; then
        echo "Changelog already contains version ${APP_VERSION}"
        return
    fi

    tmp_file="$(mktemp)"
    {
        echo "## ${APP_VERSION}"
        if command -v git >/dev/null 2>&1; then
            git -C "${SCRIPT_DIR}" log ${range} --pretty=format:"- %s"
        else
            echo "- TODO: summarize changes"
        fi
    } > "${tmp_file}"

    "${editor}" "${tmp_file}"

    if [ ! -f "${changelog}" ]; then
        printf "# Clusterfile Editor Changelog\n\n" > "${changelog}"
    fi

    insert_file="$(mktemp)"
    awk -v insert_file="${tmp_file}" '
        NR==1 {
            print;
            print "";
            while ((getline line < insert_file) > 0) print line;
            print "";
            next
        }
        { print }
    ' "${changelog}" > "${insert_file}"
    mv "${insert_file}" "${changelog}"
    rm -f "${tmp_file}"
}

tag_release() {
    local tag="v${APP_VERSION}"
    if ! command -v git >/dev/null 2>&1; then
        echo "git not available; skipping tag ${tag}"
        return
    fi
    if [ -n "$(git -C "${SCRIPT_DIR}" status --porcelain)" ]; then
        echo "Working tree has uncommitted changes; commit before tagging ${tag}"
        exit 1
    fi
    git -C "${SCRIPT_DIR}" tag -a "${tag}" -m "Release ${tag}"
}

case "${1:-run}" in
    build) build_image ;;
    push) push_image ;;
    run) run_image ;;
    all) build_image; push_image ;;
    release) release_image "${2:-}" ;;
    -h|--help) usage ;;
    *) echo "Unknown command: $1"; usage; exit 1 ;;
esac
