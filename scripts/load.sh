#!/bin/bash
# Clusterfile Editor - Offline Image Loader
# Loads the container image into podman/docker for air-gapped environments

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Container runtime detection
if command -v podman &>/dev/null; then
    RUNTIME="podman"
elif command -v docker &>/dev/null; then
    RUNTIME="docker"
else
    echo "Error: No container runtime found. Install podman or docker."
    exit 1
fi

# Find the image tarball
IMAGE_TAR=$(find "${SCRIPT_DIR}/images" -name "clusterfile-editor-*.tar" -type f | head -1)

if [ -z "${IMAGE_TAR}" ]; then
    echo "Error: No container image found in images/ directory"
    exit 1
fi

echo "Loading container image from: $(basename "${IMAGE_TAR}")"
echo "Using runtime: ${RUNTIME}"
echo ""

${RUNTIME} load -i "${IMAGE_TAR}"

echo ""
echo "Image loaded successfully!"
echo "Run ./run.sh to start the Clusterfile Editor"
