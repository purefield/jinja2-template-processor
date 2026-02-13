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
  release   Full release: bump version, sync all 5 locations, commit, tag, push, build, deploy, verify
  package   Create offline distribution tarball for air-gapped deployment
  standalone Build standalone HTML file (browser-only, no backend)
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

    # Commit all version/changelog changes
    if command -v git >/dev/null 2>&1; then
        if [ -n "$(git -C "${SCRIPT_DIR}" status --porcelain)" ]; then
            echo "Committing version and changelog updates..."
            git -C "${SCRIPT_DIR}" add \
                "${APP_VERSION_FILE}" \
                "${EDITOR_DIR}/Containerfile" \
                "${EDITOR_DIR}/static/changelog.md" \
                "${EDITOR_DIR}/static/js/app.js" \
                "${SCRIPT_DIR}/CHANGELOG.md"
            git -C "${SCRIPT_DIR}" commit -m "Release v${APP_VERSION}"
        fi
    fi

    tag_release

    # Push commit and tags
    if command -v git >/dev/null 2>&1; then
        echo "Pushing to remote..."
        git -C "${SCRIPT_DIR}" push
        git -C "${SCRIPT_DIR}" push --tags
    fi

    build_image
    push_image
    echo "Tag and push :latest to ${IMAGE_REGISTRY}"
    ${CONTAINER_RUNTIME} tag "${IMAGE_REF}" "${IMAGE_REGISTRY}/${IMAGE_NAME}:latest"
    ${CONTAINER_RUNTIME} push "${IMAGE_REGISTRY}/${IMAGE_NAME}:latest"

    # Restart running container
    echo "Restarting running app..."
    ${CONTAINER_RUNTIME} run -d --replace --network host --name "${IMAGE_NAME}" "${IMAGE_REF}" || true

    # Verify health
    echo "Verifying deployment..."
    sleep 2
    local health
    health="$(curl -s http://localhost:8000/healthz 2>/dev/null || echo "unreachable")"
    echo "Health: ${health}"
}

run_image() {
    # Pull image from registry (works with mirrored registries in disconnected environments)
    pull_image

    echo ""
    echo "Starting Clusterfile Editor v${IMAGE_TAG}"
    echo "Open http://localhost:8000 in your browser"
    echo ""

    # Image is self-contained - no volume mounts needed
    # Templates, samples, and schema are embedded at build time
    ${CONTAINER_RUNTIME} run --rm --network=host "${IMAGE_REF}"
}

sync_version() {
    # Update all version locations to match APP_VERSION
    local version="${APP_VERSION}"
    local containerfile="${EDITOR_DIR}/Containerfile"
    local appjs="${EDITOR_DIR}/static/js/app.js"
    local repo_changelog="${SCRIPT_DIR}/CHANGELOG.md"

    echo "Syncing version ${version} across all locations..."

    # 1. APP_VERSION file (already written by release_image)

    # 2. Containerfile header comment and build example
    if [ -f "${containerfile}" ]; then
        sed -i "s|^# Clusterfile Editor v.*|# Clusterfile Editor v${version}|" "${containerfile}"
        sed -i "s|quay.io/dds/clusterfile-editor:v[0-9.]*|quay.io/dds/clusterfile-editor:v${version}|" "${containerfile}"
    fi

    # 3. Repo-level CHANGELOG.md — add version heading if missing
    if [ -f "${repo_changelog}" ]; then
        if ! grep -q "^## v${version}" "${repo_changelog}"; then
            local today
            today="$(date +%Y-%m-%d)"
            sed -i "/^## Unreleased$/a\\\\n## v${version} (${today})" "${repo_changelog}"
        fi
    fi

    echo "Version ${version} synced to APP_VERSION, Containerfile, CHANGELOG.md"
    echo "Note: static/changelog.md is updated by update_changelog; app.js CHANGELOG array must be updated manually or by Claude"
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

package_offline() {
    echo "Creating offline distribution package..."

    # Build the image first
    build_image

    # Create dist directory
    local dist_dir="${SCRIPT_DIR}/dist"
    local pkg_name="clusterfile-editor-${APP_VERSION}-offline"
    local pkg_dir="${dist_dir}/${pkg_name}"

    rm -rf "${pkg_dir}"
    mkdir -p "${pkg_dir}/images"

    # Save container image
    echo "Saving container image..."
    ${CONTAINER_RUNTIME} save -o "${pkg_dir}/images/clusterfile-editor-${APP_VERSION}.tar" "${IMAGE_REF}"

    # Copy scripts
    echo "Copying scripts..."
    cp "${SCRIPT_DIR}/scripts/load.sh" "${pkg_dir}/"
    cp "${SCRIPT_DIR}/scripts/run.sh" "${pkg_dir}/"
    cp "${SCRIPT_DIR}/scripts/README.txt" "${pkg_dir}/"
    chmod +x "${pkg_dir}/load.sh" "${pkg_dir}/run.sh"

    # Create tarball
    echo "Creating tarball..."
    tar -czvf "${dist_dir}/${pkg_name}.tar.gz" -C "${dist_dir}" "${pkg_name}"

    # Cleanup
    rm -rf "${pkg_dir}"

    echo ""
    echo "Offline package created: ${dist_dir}/${pkg_name}.tar.gz"
    echo ""
    echo "To use on an air-gapped system:"
    echo "  1. Copy ${pkg_name}.tar.gz to the target system"
    echo "  2. Extract: tar -xzf ${pkg_name}.tar.gz"
    echo "  3. Load image: cd ${pkg_name} && ./load.sh"
    echo "  4. Run: ./run.sh"
}

build_standalone() {
    echo "Building standalone HTML file..."
    bash "${EDITOR_DIR}/build-standalone.sh"
}

case "${1:-run}" in
    build) build_image ;;
    push) push_image ;;
    run) run_image ;;
    all) build_image; push_image ;;
    release) release_image "${2:-}" ;;
    package) package_offline ;;
    standalone) build_standalone ;;
    -h|--help|help) usage ;;
    *) echo "Unknown command: $1"; usage; exit 1 ;;
esac
