#!/bin/bash
# Wrapper to run process.py in container with file path mapping
# Usage: ./process-wrapper.sh data.yaml template.yaml.tpl [-p overrides...]

set -e

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

# Determine current directory (for volume mount)
WORK_DIR="$(pwd)"

# Build volume mounts and transform file paths
VOLUMES="-v ${WORK_DIR}:/workspace:Z"

# Collect arguments, transforming local paths to container paths
ARGS=()
for arg in "$@"; do
    # Check if argument is a file that exists
    if [[ -f "$arg" ]]; then
        # Convert to absolute path
        abs_path="$(cd "$(dirname "$arg")" && pwd)/$(basename "$arg")"
        # Transform to container path
        container_path="/workspace/$(realpath --relative-to="$WORK_DIR" "$abs_path" 2>/dev/null || basename "$arg")"
        ARGS+=("$container_path")
    else
        # Not a file, pass as-is (could be -p override)
        ARGS+=("$arg")
    fi
done

# Run the container
$CONTAINER_CMD run --rm $VOLUMES quay.io/dds/process:latest \
    "python3 /app/process.py ${ARGS[*]}"
