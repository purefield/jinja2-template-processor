#!/bin/bash
# Wrapper to run process.py in a container with safe path mapping

set -euo pipefail

# Detect container runtime
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
else
    echo "Error: Neither podman nor docker found"
    exit 1
fi

# Check if we have arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <template> [-p param=value...]"
    echo "   or: $0 <data_file> <template> [-p param=value...]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(pwd)"
IMAGE_REF="${IMAGE_REF:-quay.io/dds/process:latest}"

RUN_ARGS=(run --rm)
if [[ "$CONTAINER_CMD" == "podman" ]]; then
    RUN_ARGS+=(-v "${SCRIPT_DIR}:/repo:Z")
    RUN_ARGS+=(-v "${WORK_DIR}:/work:Z")
else
    RUN_ARGS+=(-v "${SCRIPT_DIR}:/repo")
    RUN_ARGS+=(-v "${WORK_DIR}:/work")
fi

EXTRA_MOUNT_INDEX=0

map_path() {
    local path="$1"
    local abs_path
    local rel_path
    abs_path="$(realpath "$path")"

    if rel_path="$(realpath --relative-to="$SCRIPT_DIR" "$abs_path" 2>/dev/null)" && [[ "$rel_path" != ..* ]]; then
        printf '/repo/%s\n' "$rel_path"
        return
    fi

    if rel_path="$(realpath --relative-to="$WORK_DIR" "$abs_path" 2>/dev/null)" && [[ "$rel_path" != ..* ]]; then
        printf '/work/%s\n' "$rel_path"
        return
    fi

    local parent_dir
    parent_dir="$(dirname "$abs_path")"
    local mount_point="/ext${EXTRA_MOUNT_INDEX}"
    EXTRA_MOUNT_INDEX=$((EXTRA_MOUNT_INDEX + 1))
    if [[ "$CONTAINER_CMD" == "podman" ]]; then
        RUN_ARGS+=(-v "${parent_dir}:${mount_point}:Z")
    else
        RUN_ARGS+=(-v "${parent_dir}:${mount_point}")
    fi
    printf '%s/%s\n' "$mount_point" "$(basename "$abs_path")"
}

ARGS=()
for arg in "$@"; do
    if [[ -f "$arg" ]]; then
        ARGS+=("$(map_path "$arg")")
    else
        ARGS+=("$arg")
    fi
done

exec "$CONTAINER_CMD" "${RUN_ARGS[@]}" \
    --workdir /work \
    --entrypoint python3 \
    "$IMAGE_REF" \
    /app/process.py "${ARGS[@]}"
