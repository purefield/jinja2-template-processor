#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8000}"
APP_MODULE="${APP_MODULE:-app.main:app}"

if [[ "${DEV_MODE:-0}" == "1" ]]; then
  exec uvicorn "${APP_MODULE}" \
    --host "${HOST}" \
    --port "${PORT}" \
    --reload \
    --reload-dir /app/app \
    --reload-dir /app/static
fi

exec uvicorn "${APP_MODULE}" \
  --host "${HOST}" \
  --port "${PORT}"
