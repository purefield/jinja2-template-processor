#!/bin/bash
# Clusterfile Editor - Runner Script
# Starts the Clusterfile Editor container

set -euo pipefail

# Container runtime detection
if command -v podman &>/dev/null; then
    RUNTIME="podman"
elif command -v docker &>/dev/null; then
    RUNTIME="docker"
else
    echo "Error: No container runtime found. Install podman or docker."
    exit 1
fi

# Find the clusterfile-editor image
IMAGE=$(${RUNTIME} images --format "{{.Repository}}:{{.Tag}}" | grep "clusterfile-editor" | head -1)

if [ -z "${IMAGE}" ]; then
    echo "Error: clusterfile-editor image not found."
    echo "Run ./load.sh first to load the container image."
    exit 1
fi

# Default port
PORT="${PORT:-8000}"

echo "Starting Clusterfile Editor"
echo "Image: ${IMAGE}"
echo "URL: http://localhost:${PORT}"
echo ""
echo "Press Ctrl+C to stop"
echo ""

${RUNTIME} run --rm --network=host "${IMAGE}"
