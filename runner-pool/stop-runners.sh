#!/usr/bin/env bash
# Stops all running self-hosted runners on this machine.
set -euo pipefail

echo "[*] Stopping runner processes..."
if pgrep -f "Runner.Listener" >/dev/null 2>&1; then
  pkill -f "Runner.Listener" || true
  sleep 2
else
  echo "    (none running)"
  exit 0
fi

if pgrep -f "Runner.Listener" >/dev/null 2>&1; then
  echo "WARNING: some runner processes still alive. Sending SIGKILL..." >&2
  pkill -9 -f "Runner.Listener" || true
  sleep 1
fi

if pgrep -f "Runner.Listener" >/dev/null 2>&1; then
  echo "FATAL: could not stop runners" >&2
  pgrep -fa "Runner.Listener" >&2
  exit 1
fi

echo "[*] All runners stopped."
