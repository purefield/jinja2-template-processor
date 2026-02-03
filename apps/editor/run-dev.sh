#!/bin/bash
# Development server for Clusterfile Editor v2.0
# Run from the editor-v2 directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

export SAMPLES_DIR="${REPO_ROOT}/data"
export TEMPLATES_DIR="${REPO_ROOT}/templates"
export SCHEMA_DIR="${REPO_ROOT}/schema"

cd "$SCRIPT_DIR"

echo "Starting Clusterfile Editor v2.0..."
echo "  Samples: $SAMPLES_DIR"
echo "  Templates: $TEMPLATES_DIR"
echo "  Schema: $SCHEMA_DIR"
echo ""
echo "Open http://localhost:8000 in your browser"
echo ""

python3 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
