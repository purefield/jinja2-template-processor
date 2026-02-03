Clusterfile Editor - Offline Distribution
=========================================

This package contains everything needed to run the Clusterfile Editor
in air-gapped or disconnected environments.

Contents:
  - images/clusterfile-editor-*.tar  Container image
  - load.sh                          Script to load image into podman/docker
  - run.sh                           Script to run the editor
  - README.txt                       This file

Requirements:
  - Linux with podman or docker installed
  - Network access to localhost:8000 (or configure PORT env var)

Quick Start:
  1. Extract the tarball:
     tar -xzf clusterfile-editor-*-offline.tar.gz

  2. Load the container image:
     cd clusterfile-editor-*-offline
     ./load.sh

  3. Run the editor:
     ./run.sh

  4. Open in browser:
     http://localhost:8000

Configuration:
  - PORT: Change the port (default: 8000)
    Example: PORT=9000 ./run.sh

Troubleshooting:
  - "No container runtime found": Install podman or docker
  - "Image not found": Run ./load.sh first
  - Port conflict: Use PORT=XXXX ./run.sh with different port

For more information:
  https://github.com/purefield/jinja2-template-processor
