#!/usr/bin/env bash
# Tears down the live-created speaker demo resources (Lambda + EventBridge).
# Terraform owns everything else; run `terraform destroy` in speaker-demo/ to
# fully remove the environment.
set -euo pipefail

: "${AWS_REGION:?set AWS_REGION}"

NAME_PREFIX="${NAME_PREFIX:-rtv-speaker-demo}"
FUNCTION_NAME="${NAME_PREFIX}-cred-relay"
RULE_NAME="${NAME_PREFIX}-cred-relay-trigger"

echo "[1/4] Removing EventBridge targets..."
aws events remove-targets \
  --rule "$RULE_NAME" \
  --ids "1" \
  --region "$AWS_REGION" 2>/dev/null || echo "      (rule not found)"

echo "[2/4] Deleting EventBridge rule..."
aws events delete-rule \
  --name "$RULE_NAME" \
  --region "$AWS_REGION" 2>/dev/null || echo "      (rule not found)"

echo "[3/4] Deleting Lambda function..."
aws lambda delete-function \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" 2>/dev/null || echo "      (function not found)"

echo "[4/4] Clearing local chained-session file..."
rm -f /tmp/.rtv-demo-chain-creds

echo ""
echo "Live-created resources cleaned up."
echo "To also destroy Terraform-managed resources:"
echo "  cd terraform/speaker-demo && terraform destroy"
