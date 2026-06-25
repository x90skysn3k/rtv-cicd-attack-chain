#!/usr/bin/env bash
# Post-session cleanup for the demo repo.
#
# Deletes all workflow runs (and their logs, which contain stale STS creds)
# and closes any still-open PRs. Runs that have already been deleted don't
# come back, so it's safe to run multiple times.
#
# Required env:
#   DEMO_ORG  - throwaway org
#   DEMO_REPO - default: cicd-demo

set -euo pipefail

: "${DEMO_ORG:?set DEMO_ORG}"
DEMO_REPO="${DEMO_REPO:-cicd-demo}"
REPO="${DEMO_ORG}/${DEMO_REPO}"

echo "[1/2] Deleting workflow runs in ${REPO}..."
RUN_IDS=$(gh api "repos/${REPO}/actions/runs" --paginate --jq '.workflow_runs[].id')

if [ -z "$RUN_IDS" ]; then
  echo "      no runs to delete"
else
  COUNT=$(printf '%s\n' "$RUN_IDS" | wc -l | tr -d ' ')
  echo "      deleting ${COUNT} runs..."
  while IFS= read -r run_id; do
    [ -z "$run_id" ] && continue
    gh api -X DELETE "repos/${REPO}/actions/runs/${run_id}" 2>/dev/null \
      && echo "        deleted run $run_id" \
      || echo "        failed run $run_id (continuing)"
  done <<< "$RUN_IDS"
fi

echo ""
echo "[2/2] Closing any still-open PRs..."
OPEN_PRS=$(gh pr list --repo "${REPO}" --state open --json number --jq '.[].number' 2>/dev/null || true)

if [ -z "$OPEN_PRS" ]; then
  echo "      no open PRs"
else
  while IFS= read -r pr_num; do
    [ -z "$pr_num" ] && continue
    gh pr close "$pr_num" --repo "${REPO}" --comment "Session ended; closing demo PR." 2>/dev/null \
      && echo "      closed PR #${pr_num}" \
      || echo "      failed to close PR #${pr_num}"
  done <<< "$OPEN_PRS"
fi

echo ""
echo "Cleanup complete. Consider also:"
echo "  - Rotate the PAT: ./github/rotate-pat.sh"
echo "  - Review CloudTrail for anything unexpected"
