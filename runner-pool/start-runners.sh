#!/usr/bin/env bash
# Starts all installed lab runners in the background.
set -euo pipefail

RUNNER_BASE="${RUNNER_BASE:-${HOME}/actions-runners}"

if [ ! -d "$RUNNER_BASE" ]; then
  echo "FATAL: $RUNNER_BASE does not exist. Run install-runners.sh first." >&2
  exit 1
fi

STARTED=0
for dir in "$RUNNER_BASE"/runner-*; do
  [ -d "$dir" ] || continue
  runner=$(basename "$dir")
  pid_file="${dir}/runner.pid"

  if [ -f "$pid_file" ]; then
    pid=$(cat "$pid_file")
    if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
      echo "[*] ${runner}: already running as pid ${pid}"
      continue
    fi
    rm -f "$pid_file"
  fi

  echo "[*] Starting ${runner}..."
  (
    cd "$dir"
    nohup ./run.sh >"${dir}/runner.log" 2>&1 &
    echo $! >"$pid_file"
  )
  STARTED=$((STARTED + 1))
done

sleep 2
echo ""
echo "[*] Started ${STARTED} runner(s)."
echo "[*] Tracked running lab runner processes:"
VISIBLE=0
for pid_file in "$RUNNER_BASE"/runner-*/runner.pid; do
  [ -f "$pid_file" ] || continue
  pid=$(cat "$pid_file")
  runner_dir=$(dirname "$pid_file")
  if [ -n "$pid" ] && kill -0 "$pid" >/dev/null 2>&1; then
    echo "    $(basename "$runner_dir"): pid ${pid}"
    VISIBLE=$((VISIBLE + 1))
  fi
done
[ "$VISIBLE" -gt 0 ] || echo "    (none visible)"
echo ""
echo "[*] Logs: ${RUNNER_BASE}/runner-*/runner.log"
echo "[*] Stop with: ./runner-pool/stop-runners.sh"
