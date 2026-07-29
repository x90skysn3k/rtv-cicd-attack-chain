#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

caller_arn="$(preflight_account)"
NAME_PREFIX="rtv-take-home"
FUNCTION_NAME="${NAME_PREFIX}-persistence"
RULE_NAME="${NAME_PREFIX}-persistence-trigger"

printf 'Cleaning only fixed take-home resources as %s\n' "$caller_arn"
if aws events describe-rule --name "$RULE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  aws events remove-targets --rule "$RULE_NAME" --ids persistence-proof --region "$AWS_REGION" >/dev/null
  aws events delete-rule --name "$RULE_NAME" --region "$AWS_REGION"
fi
if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  aws lambda delete-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION"
fi
rm -f "/tmp/${NAME_PREFIX}-chain-creds-${UID}"
printf 'Fixed script-created resources removed. Run terraform destroy from terraform/advanced-chain next.\n'
