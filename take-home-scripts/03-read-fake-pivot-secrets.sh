#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_env CHAIN_CREDENTIALS_FILE
require_env CHAIN_TARGET_ROLE_ARN
require_env PIVOT_CODE_HOSTING_SECRET_NAME
require_env PIVOT_CI_PLATFORM_SECRET_NAME
require_env PIVOT_DATA_WAREHOUSE_SECRET_NAME
require_env PIVOT_SAAS_API_SECRET_NAME
preflight_account >/dev/null

NAME_PREFIX="rtv-take-home"
expected_path="/tmp/${NAME_PREFIX}-chain-creds-${UID}"
[[ "$CHAIN_CREDENTIALS_FILE" == "$expected_path" && -f "$CHAIN_CREDENTIALS_FILE" && ! -L "$CHAIN_CREDENTIALS_FILE" && -O "$CHAIN_CREDENTIALS_FILE" ]] || fail "CHAIN_CREDENTIALS_FILE is not the fixed, owned credential file"

names=(
  "$PIVOT_CODE_HOSTING_SECRET_NAME"
  "$PIVOT_CI_PLATFORM_SECRET_NAME"
  "$PIVOT_DATA_WAREHOUSE_SECRET_NAME"
  "$PIVOT_SAAS_API_SECRET_NAME"
)
expected_names=(
  "${NAME_PREFIX}/pivot/code-hosting-admin-token"
  "${NAME_PREFIX}/pivot/ci-platform-admin-key"
  "${NAME_PREFIX}/pivot/data-warehouse-creds"
  "${NAME_PREFIX}/pivot/saas-api-key"
)
for index in "${!names[@]}"; do
  [[ "${names[$index]}" == "${expected_names[$index]}" ]] || fail "pivot secret output does not match the fixed fake-secret allowlist"
done

# The file is generated locally by 02-assume-one-role.sh with mode 0600.
# shellcheck disable=SC1090
source "$CHAIN_CREDENTIALS_FILE"
chained_arn="$(aws sts get-caller-identity --query Arn --output text --region "$AWS_REGION")"
[[ "$chained_arn" == *":assumed-role/${NAME_PREFIX}-pivot-reader/${NAME_PREFIX}-chain" ]] || fail "temporary credentials are not for the fixed pivot-reader role"

for secret_name in "${names[@]}"; do
  value="$(aws secretsmanager get-secret-value \
    --secret-id "$secret_name" \
    --query SecretString \
    --output text \
    --region "$AWS_REGION")"
  [[ "$value" == *"NOT-A-REAL-"* || "$value" == *"FAKE_DEMO_VALUE"* ]] || fail "secret value is not visibly fake; stopping"
  printf '%s = %s\n' "$secret_name" "$value"
done

printf 'Read exactly four Terraform-created fake pivot secrets with GetSecretValue only.\n'
