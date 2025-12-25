#!/usr/bin/env bash

set -euo pipefail

PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"

if command -v pgrep >/dev/null 2>&1; then
  PIDS="$(pgrep -f "uvicorn .*app\.main:app" || true)"
else
  PIDS=""
fi

if [ -n "$PIDS" ]; then
  echo "Stopping existing uvicorn process(es): $PIDS"
  for PID in $PIDS; do
    kill "$PID" 2>/dev/null || true
  done
  sleep 1
fi

if command -v lsof >/dev/null 2>&1; then
  BUSY_PIDS="$(lsof -tiTCP:"$PORT" -sTCP:LISTEN || true)"
elif command -v fuser >/dev/null 2>&1; then
  BUSY_PIDS="$(fuser "$PORT"/tcp 2>/dev/null || true)"
else
  BUSY_PIDS=""
fi

if [ -n "$BUSY_PIDS" ]; then
  echo "Port $PORT is still in use (PID(s): $BUSY_PIDS)."
  echo "Stop those processes or set PORT to a different value."
  exit 1
fi

exec uvicorn app.main:app --reload --host "$HOST" --port "$PORT" "$@"
