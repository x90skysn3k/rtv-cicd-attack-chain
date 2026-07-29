#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_env LAMBDA_EXEC_ROLE_ARN
require_command zip
caller_arn="$(preflight_account)"

NAME_PREFIX="rtv-take-home"
FUNCTION_NAME="${NAME_PREFIX}-persistence"
RULE_NAME="${NAME_PREFIX}-persistence-trigger"
LOG_GROUP_NAME="/aws/lambda/${FUNCTION_NAME}"
SCHEDULE_EXPRESSION="rate(1 minute)"

[[ "$LAMBDA_EXEC_ROLE_ARN" =~ ^arn:([^:]+):iam::([0-9]{12}):role/${NAME_PREFIX}-lambda-execution$ ]] || fail "LAMBDA_EXEC_ROLE_ARN is not the fixed take-home execution role"
[[ "${BASH_REMATCH[2]}" == "$EXPECTED_AWS_ACCOUNT_ID" ]] || fail "LAMBDA_EXEC_ROLE_ARN belongs to another account"

if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  fail "${FUNCTION_NAME} already exists; run 99-teardown.sh rather than overwriting it"
fi
if aws events describe-rule --name "$RULE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  fail "${RULE_NAME} already exists; run 99-teardown.sh rather than overwriting it"
fi

build_dir="$(mktemp -d)"
response_file="$(mktemp)"
trap 'rm -rf "$build_dir" "$response_file"' EXIT
cp "${SCRIPT_DIR}/lambda-src/index.py" "${build_dir}/index.py"
(
  cd "$build_dir"
  zip -q lambda.zip index.py
)

printf 'Creating fixed Lambda as %s\n' "$caller_arn"
aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime python3.12 \
  --role "$LAMBDA_EXEC_ROLE_ARN" \
  --handler index.lambda_handler \
  --zip-file "fileb://${build_dir}/lambda.zip" \
  --timeout 10 \
  --region "$AWS_REGION" >/dev/null
aws lambda wait function-active-v2 --function-name "$FUNCTION_NAME" --region "$AWS_REGION"

lambda_arn="$(aws lambda get-function --function-name "$FUNCTION_NAME" --query 'Configuration.FunctionArn' --output text --region "$AWS_REGION")"
aws events put-rule \
  --name "$RULE_NAME" \
  --schedule-expression "$SCHEDULE_EXPRESSION" \
  --state ENABLED \
  --region "$AWS_REGION" >/dev/null
rule_arn="$(aws events describe-rule --name "$RULE_NAME" --query Arn --output text --region "$AWS_REGION")"
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "${RULE_NAME}-invoke" \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn "$rule_arn" \
  --region "$AWS_REGION" >/dev/null
aws events put-targets \
  --rule "$RULE_NAME" \
  --targets "Id=persistence-proof,Arn=${lambda_arn}" \
  --region "$AWS_REGION" >/dev/null

target_count="$(aws events list-targets-by-rule --rule "$RULE_NAME" --query 'length(Targets)' --output text --region "$AWS_REGION")"
[[ "$target_count" == "1" ]] || fail "expected exactly one EventBridge target"

start_ms="$(( $(date +%s) * 1000 ))"
aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --cli-binary-format raw-in-base64-out \
  --payload '{"source":"manual-proof"}' \
  --region "$AWS_REGION" \
  "$response_file" >/dev/null

log_message=""
for _ in {1..15}; do
  log_message="$(aws logs filter-log-events \
    --log-group-name "$LOG_GROUP_NAME" \
    --start-time "$start_ms" \
    --filter-pattern '"RTV_TAKE_HOME_INVOCATION"' \
    --query 'events[0].message' \
    --output text \
    --region "$AWS_REGION" 2>/dev/null || true)"
  [[ -n "$log_message" && "$log_message" != "None" ]] && break
  sleep 2
done
[[ -n "$log_message" && "$log_message" != "None" ]] || fail "Lambda invoked, but the proof log was not visible before timeout"

printf 'Persistence proof complete: one fixed rule targets one fixed Lambda.\n'
printf 'CloudWatch proof: %s\n' "$log_message"
printf 'Next: %s/02-assume-one-role.sh\n' "$SCRIPT_DIR"
