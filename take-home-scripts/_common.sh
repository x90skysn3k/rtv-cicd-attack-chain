#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "set ${name} from terraform output before running this script"
}

normalize_caller_arn() {
  local arn="$1"
  if [[ "$arn" =~ ^arn:([^:]+):sts::([0-9]{12}):assumed-role/(.+)/([^/]+)$ ]]; then
    printf 'arn:%s:iam::%s:role/%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
  else
    printf '%s\n' "$arn"
  fi
}

preflight_account() {
  require_command aws
  require_env AWS_REGION
  require_env EXPECTED_AWS_ACCOUNT_ID
  [[ "$EXPECTED_AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]] || fail "EXPECTED_AWS_ACCOUNT_ID must be a 12-digit account ID"

  export AWS_PAGER=""
  local identity account caller
  identity="$(aws sts get-caller-identity --query '[Account,Arn]' --output text --region "$AWS_REGION")" || fail "unable to read the active AWS identity"
  read -r account caller <<< "$identity"
  [[ "$account" == "$EXPECTED_AWS_ACCOUNT_ID" ]] || fail "active AWS account does not match EXPECTED_AWS_ACCOUNT_ID"
  [[ -n "$caller" && "$caller" != "None" ]] || fail "AWS returned no caller ARN"
  printf '%s\n' "$caller"
}
