#!/usr/bin/env bash
# Rotates the GitHub PAT stored in Secrets Manager.
#
# GitHub does not expose classic-PAT creation via API, so the new PAT must
# be minted manually in the GitHub UI (Settings > Developer settings >
# Personal access tokens > Classic) with `repo` scope on the throwaway demo
# org. Expiry <= 30 days is recommended.
#
# This script takes the freshly-minted PAT and:
#   1. Writes it into Secrets Manager (overwriting the old value)
#   2. Verifies the write round-trips correctly
#
# It does NOT revoke the old PAT (GitHub UI only, or gh api if you know the
# PAT id).
#
# Required env:
#   NEW_PAT_VALUE  - the new classic PAT
#
# Optional env:
#   AWS_REGION     - default us-east-1
#   SECRET_NAME    - default demo/github-pat

set -euo pipefail

: "${NEW_PAT_VALUE:?set NEW_PAT_VALUE to the newly-minted classic PAT}"

AWS_REGION="${AWS_REGION:-us-east-1}"
SECRET_NAME="${SECRET_NAME:-demo/github-pat}"

echo "[1/3] Writing new PAT to Secrets Manager (${SECRET_NAME})..."
aws secretsmanager put-secret-value \
  --secret-id "${SECRET_NAME}" \
  --secret-string "${NEW_PAT_VALUE}" \
  --region "${AWS_REGION}" \
  >/dev/null

echo "[2/3] Verifying round-trip..."
PULLED=$(aws secretsmanager get-secret-value \
  --secret-id "${SECRET_NAME}" \
  --query SecretString --output text \
  --region "${AWS_REGION}")

if [ "$PULLED" != "$NEW_PAT_VALUE" ]; then
  echo "FATAL: value pulled from Secrets Manager does not match submitted value" >&2
  exit 1
fi

echo "[3/3] Rotation complete."
echo ""
echo "Remaining manual steps:"
echo "  1. Revoke the old PAT in GitHub:"
echo "     https://github.com/settings/tokens"
echo "  2. Walk the attendee runbook once to confirm the new PAT merges PRs."
echo "  3. Note the expiry date so you rotate again before the next session."
