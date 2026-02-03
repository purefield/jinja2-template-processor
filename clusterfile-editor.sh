#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EDITOR_DIR="${SCRIPT_DIR}/apps/editor"

# Default registry - override for disconnected/mirrored environments
# Example: IMAGE_REGISTRY=registry.local:5000/clusterfile
IMAGE_REGISTRY="${IMAGE_REGISTRY:-quay.io/dds}"
IMAGE_NAME="${IMAGE_NAME:-clusterfile-editor}"
APP_VERSION_FILE="${APP_VERSION_FILE:-${EDITOR_DIR}/APP_VERSION}"
APP_VERSION="${APP_VERSION:-$(cat "${APP_VERSION_FILE}" 2>/dev/null || echo "2.0.0")}"
IMAGE_TAG="${IMAGE_TAG:-${APP_VERSION}}"
IMAGE_REF="${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Container runtime detection (podman preferred, fallback to docker)
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-}"
if [ -z "${CONTAINER_RUNTIME}" ]; then
    if command -v podman &>/dev/null; then
        CONTAINER_RUNTIME="podman"
    elif command -v docker &>/dev/null; then
        CONTAINER_RUNTIME="docker"
    else
        echo "Error: No container runtime found. Install podman or docker."
        exit 1
    fi
fi

usage() {
    cat <<EOF
Clusterfile Editor - Schema-driven cluster configuration editor

Usage: $0 [command] [options]

Commands:
  run       Run the editor (default) - pulls image from registry
  build     Build container image locally
  push      Push built image to registry
  release   Release new version (bump, build, push, tag)
  all       Build and push

Default: run (pulls and runs image from ${IMAGE_REGISTRY})

Environment Variables:
  IMAGE_REGISTRY    Registry URL (default: quay.io/dds)
                    For disconnected: registry.local:5000/myorg
  IMAGE_NAME        Image name (default: clusterfile-editor)
  IMAGE_TAG         Image tag (default: version from APP_VERSION)
  CONTAINER_RUNTIME Runtime to use (default: auto-detect podman/docker)

Disconnected/Air-Gap Usage:
  1. Mirror the image to your local registry:
     skopeo copy docker://quay.io/dds/clusterfile-editor:2.0 \\
       docker://registry.local:5000/clusterfile-editor:2.0

  2. Run with your registry:
     IMAGE_REGISTRY=registry.local:5000 $0

Examples:
  $0                                    # Pull from quay.io and run
  $0 run                                # Same as above
  $0 build                              # Build locally
  IMAGE_TAG=dev $0 build                # Build with custom tag
  IMAGE_REGISTRY=myregistry:5000 $0     # Run from mirrored registry
EOF
}

build_image() {
    sync_version
    echo "Building image: ${IMAGE_REF}"
    ${CONTAINER_RUNTIME} build -t "${IMAGE_REF}" -f "${EDITOR_DIR}/Containerfile" "${SCRIPT_DIR}"
}

push_image() {
    echo "Pushing image: ${IMAGE_REF}"
    ${CONTAINER_RUNTIME} push "${IMAGE_REF}"
}

pull_image() {
    echo "Pulling image: ${IMAGE_REF}"
    if ! ${CONTAINER_RUNTIME} pull "${IMAGE_REF}" 2>/dev/null; then
        echo ""
        echo "Failed to pull ${IMAGE_REF}"
        echo ""
        echo "Options:"
        echo "  1. Build locally:  $0 build && $0 run"
        echo "  2. Use mirror:     IMAGE_REGISTRY=your-registry:5000 $0"
        echo "  3. Check network:  Ensure you can reach ${IMAGE_REGISTRY}"
        echo ""
        exit 1
    fi
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
    ${CONTAINER_RUNTIME} tag "${IMAGE_REF}" "${IMAGE_REGISTRY}/${IMAGE_NAME}:latest"
    ${CONTAINER_RUNTIME} push "${IMAGE_REGISTRY}/${IMAGE_NAME}:latest"
}

run_image() {
    # Pull image from registry (works with mirrored registries in disconnected environments)
    pull_image

    echo ""
    echo "Starting Clusterfile Editor v${IMAGE_TAG}"
    echo "Open http://localhost:8000 in your browser"
    echo ""

    ${CONTAINER_RUNTIME} run --rm --network=host \
        -v "${SCRIPT_DIR}/templates:/app/templates:ro,z" \
        -v "${SCRIPT_DIR}/data:/app/samples:ro,z" \
        -v "${SCRIPT_DIR}/schema:/app/schema:ro,z" \
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
    -h|--help|help) usage ;;
    *) echo "Unknown command: $1"; usage; exit 1 ;;
esac
