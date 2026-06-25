#!/usr/bin/env bash
# Starts all installed runners in the background.
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

  if pgrep -f "Runner.Listener.*${dir}" >/dev/null 2>&1; then
    echo "[*] ${runner}: already running"
    continue
  fi

  echo "[*] Starting ${runner}..."
  (
    cd "$dir"
    nohup ./run.sh >"${dir}/runner.log" 2>&1 &
  )
  STARTED=$((STARTED + 1))
done

sleep 2
echo ""
echo "[*] Started ${STARTED} runner(s)."
echo "[*] Running runner processes:"
pgrep -fa "Runner.Listener" 2>/dev/null | sed 's/^/    /' || echo "    (none visible)"
echo ""
echo "[*] Logs: ${RUNNER_BASE}/runner-*/runner.log"
echo "[*] Stop with: ./runner-pool/stop-runners.sh"
