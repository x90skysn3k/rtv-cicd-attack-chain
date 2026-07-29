#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_env EXPECTED_SOURCE_PRINCIPAL_ARN
require_env CHAIN_TARGET_ROLE_ARN
caller_arn="$(preflight_account)"
normalized_caller_arn="$(normalize_caller_arn "$caller_arn")"

NAME_PREFIX="rtv-take-home"
[[ "$EXPECTED_SOURCE_PRINCIPAL_ARN" =~ ^arn:([^:]+):iam::([0-9]{12}):(user|role)/.+$ ]] || fail "EXPECTED_SOURCE_PRINCIPAL_ARN must be an IAM user or role ARN"
[[ "${BASH_REMATCH[2]}" == "$EXPECTED_AWS_ACCOUNT_ID" ]] || fail "EXPECTED_SOURCE_PRINCIPAL_ARN belongs to another account"
[[ "$normalized_caller_arn" == "$EXPECTED_SOURCE_PRINCIPAL_ARN" ]] || fail "active principal does not match the constrained Terraform trust principal"
[[ "$CHAIN_TARGET_ROLE_ARN" =~ ^arn:([^:]+):iam::([0-9]{12}):role/${NAME_PREFIX}-pivot-reader$ ]] || fail "CHAIN_TARGET_ROLE_ARN is not the fixed take-home target"
[[ "${BASH_REMATCH[2]}" == "$EXPECTED_AWS_ACCOUNT_ID" ]] || fail "CHAIN_TARGET_ROLE_ARN belongs to another account"

credentials_path="/tmp/${NAME_PREFIX}-chain-creds-${UID}"
temporary_path="$(mktemp "${credentials_path}.tmp.XXXXXX")"
trap 'rm -f "$temporary_path"' EXIT
umask 077

read -r access_key secret_key session_token expiration <<< "$(aws sts assume-role \
  --role-arn "$CHAIN_TARGET_ROLE_ARN" \
  --role-session-name "${NAME_PREFIX}-chain" \
  --duration-seconds 900 \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]' \
  --output text \
  --region "$AWS_REGION")"
[[ -n "$access_key" && -n "$secret_key" && -n "$session_token" && -n "$expiration" ]] || fail "AssumeRole did not return complete temporary credentials"

{
  printf 'export AWS_ACCESS_KEY_ID=%q\n' "$access_key"
  printf 'export AWS_SECRET_ACCESS_KEY=%q\n' "$secret_key"
  printf 'export AWS_SESSION_TOKEN=%q\n' "$session_token"
  printf 'export AWS_SESSION_EXPIRATION=%q\n' "$expiration"
} > "$temporary_path"
chmod 600 "$temporary_path"
mv -f "$temporary_path" "$credentials_path"

chained_arn="$(AWS_ACCESS_KEY_ID="$access_key" AWS_SECRET_ACCESS_KEY="$secret_key" AWS_SESSION_TOKEN="$session_token" \
  aws sts get-caller-identity --query Arn --output text --region "$AWS_REGION")"
[[ "$chained_arn" == *":assumed-role/${NAME_PREFIX}-pivot-reader/${NAME_PREFIX}-chain" ]] || fail "unexpected chained identity"

printf 'Traversed exactly one intended IAM edge.\n'
printf 'Chained identity: %s\n' "$chained_arn"
printf 'export CHAIN_CREDENTIALS_FILE=%q\n' "$credentials_path"
printf 'Next: export CHAIN_CREDENTIALS_FILE as printed, then run %s/03-read-fake-pivot-secrets.sh\n' "$SCRIPT_DIR"
