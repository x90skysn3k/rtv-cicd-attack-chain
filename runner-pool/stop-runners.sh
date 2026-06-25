#!/usr/bin/env bash
# Stops only lab runners started from RUNNER_BASE.
set -euo pipefail

RUNNER_BASE="${RUNNER_BASE:-${HOME}/actions-runners}"

if [ ! -d "$RUNNER_BASE" ]; then
  echo "    (runner base does not exist)"
  exit 0
fi

echo "[*] Stopping tracked lab runner processes..."
STOPPED=0
for pid_file in "$RUNNER_BASE"/runner-*/runner.pid; do
  [ -f "$pid_file" ] || continue
  pid=$(cat "$pid_file")
  runner_dir=$(dirname "$pid_file")
  if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
    echo "    stopping $(basename "$runner_dir") pid ${pid}"
    kill "$pid" >/dev/null 2>&1 || true
    STOPPED=$((STOPPED + 1))
  else
    rm -f "$pid_file"
  fi
done

if [ "$STOPPED" -eq 0 ]; then
  echo "    (no tracked lab runners running)"
  exit 0
fi

sleep 2

FAILED=0
for pid_file in "$RUNNER_BASE"/runner-*/runner.pid; do
  [ -f "$pid_file" ] || continue
  pid=$(cat "$pid_file")
  runner_dir=$(dirname "$pid_file")
  if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
    echo "WARNING: $(basename "$runner_dir") pid ${pid} still alive. Sending SIGKILL..." >&2
    kill -9 "$pid" >/dev/null 2>&1 || true
    sleep 1
  fi
  if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
    echo "FATAL: could not stop $(basename "$runner_dir") pid ${pid}" >&2
    FAILED=1
  else
    rm -f "$pid_file"
  fi
done

[ "$FAILED" -eq 0 ] || exit 1
echo "[*] Lab runners stopped."
