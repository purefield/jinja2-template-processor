#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_DIR="${REPO_ROOT}/apps/editor"

export SAMPLES_DIR="${REPO_ROOT}/data"
export TEMPLATES_DIR="${REPO_ROOT}/templates"
export SCHEMA_DIR="${REPO_ROOT}/schema"

exec python3 -m uvicorn app.main:app \
  --app-dir "${APP_DIR}" \
  --reload \
  --reload-dir "${APP_DIR}/app" \
  --host 0.0.0.0 \
  --port 8000
