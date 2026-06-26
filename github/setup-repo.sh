#!/usr/bin/env bash
# Bootstraps the demo repo and seeds the PAT into Secrets Manager.
#
# Prereqs:
#   - Terraform applied (role_arn, secret_name outputs available)
#   - gh CLI authenticated as the dedicated throwaway org owner
#   - aws CLI configured for the demo account
#   - A classic GitHub PAT with `repo` scope, minted by the throwaway owner
#
# Required env:
#   DEMO_ORG       - throwaway GitHub org name
#   DEMO_REPO      - repo name (default: cicd-demo)
#   AWS_REGION     - default: us-east-1
#   AWS_ROLE_ARN   - from terraform output role_arn
#   PAT_VALUE      - GitHub PAT minted by the throwaway owner; never use a personal or work token
#   EXPECTED_AWS_ACCOUNT_ID - dedicated demo AWS account ID
#   EXPECTED_GITHUB_USER    - dedicated throwaway GitHub user login
#
# Optional:
#   SECRET_NAME    - default: demo/github-pat

set -euo pipefail

: "${DEMO_ORG:?set DEMO_ORG}"
: "${AWS_ROLE_ARN:?set AWS_ROLE_ARN from terraform output}"
: "${PAT_VALUE:?set PAT_VALUE (classic PAT minted by the throwaway demo user)}"
: "${EXPECTED_AWS_ACCOUNT_ID:?set EXPECTED_AWS_ACCOUNT_ID to the dedicated demo AWS account ID}"
: "${EXPECTED_GITHUB_USER:?set EXPECTED_GITHUB_USER to the dedicated throwaway GitHub user login}"

DEMO_REPO="${DEMO_REPO:-cicd-demo}"
AWS_REGION="${AWS_REGION:-us-east-1}"
SECRET_NAME="${SECRET_NAME:-demo/github-pat}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_SRC="${SCRIPT_DIR}/workflow.yml"
DEMO_TEMPLATE="${SCRIPT_DIR}/demo-repo"

if [ ! -f "$WORKFLOW_SRC" ]; then
  echo "FATAL: workflow.yml not found at $WORKFLOW_SRC" >&2
  exit 1
fi
if [ ! -d "$DEMO_TEMPLATE" ]; then
  echo "FATAL: demo repo template not found at $DEMO_TEMPLATE" >&2
  exit 1
fi


echo "[preflight] Verifying active AWS and GitHub identities..."
ACTUAL_AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account --output text \
  --region "${AWS_REGION}")
if [ "$ACTUAL_AWS_ACCOUNT_ID" != "$EXPECTED_AWS_ACCOUNT_ID" ]; then
  echo "FATAL: active AWS account is ${ACTUAL_AWS_ACCOUNT_ID}, expected ${EXPECTED_AWS_ACCOUNT_ID}" >&2
  exit 1
fi

ACTUAL_GITHUB_USER=$(gh api user --jq .login)
if [ "$ACTUAL_GITHUB_USER" != "$EXPECTED_GITHUB_USER" ]; then
  echo "FATAL: active GitHub user is ${ACTUAL_GITHUB_USER}, expected ${EXPECTED_GITHUB_USER}" >&2
  exit 1
fi
echo "      AWS account and GitHub user match expected demo identities"

echo "[1/7] Creating public repo ${DEMO_ORG}/${DEMO_REPO}..."
if gh repo view "${DEMO_ORG}/${DEMO_REPO}" >/dev/null 2>&1; then
  echo "      repo exists, reusing"
else
  gh repo create "${DEMO_ORG}/${DEMO_REPO}" --public --description "DEF CON RTV demo. Intentionally vulnerable. Do not fork for anything real."
fi

echo "[2/7] Cloning and seeding repo contents..."
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"
gh repo clone "${DEMO_ORG}/${DEMO_REPO}"
cd "${DEMO_REPO}"

cp -R "$DEMO_TEMPLATE"/. .

mkdir -p .github/workflows
cp "$WORKFLOW_SRC" .github/workflows/ci.yml
git add .
git commit -m "Refresh demo repo lab files" || echo "      demo repo unchanged, skipping commit"
git branch -M main
git push -u origin main

echo "[3/7] Setting repo variables..."
gh variable set AWS_ROLE_ARN --repo "${DEMO_ORG}/${DEMO_REPO}" --body "${AWS_ROLE_ARN}"
gh variable set AWS_REGION   --repo "${DEMO_ORG}/${DEMO_REPO}" --body "${AWS_REGION}"
gh variable set SECRET_NAME  --repo "${DEMO_ORG}/${DEMO_REPO}" --body "${SECRET_NAME}"

echo "[4/7] Configuring GitHub Pages workflow publishing..."
if ! gh api -X POST "repos/${DEMO_ORG}/${DEMO_REPO}/pages" \
  -f build_type=workflow >/dev/null 2>&1; then
  gh api -X PUT "repos/${DEMO_ORG}/${DEMO_REPO}/pages" \
    -f build_type=workflow >/dev/null
fi

echo "[5/7] Writing PAT into Secrets Manager (${SECRET_NAME})..."
aws secretsmanager put-secret-value \
  --secret-id "${SECRET_NAME}" \
  --secret-string "${PAT_VALUE}" \
  --region "${AWS_REGION}" \
  >/dev/null

echo "[6/7] Verifying secret is readable..."
aws secretsmanager get-secret-value \
  --secret-id "${SECRET_NAME}" \
  --query 'SecretString' --output text \
  --region "${AWS_REGION}" >/dev/null
echo "      OK"

echo "[7/7] Done."
echo ""
echo "Manual follow-ups required (GitHub does not expose these settings via API):"
echo ""
echo "  Repo → Settings → Actions → General"
echo "    - Fork pull request workflows from outside collaborators:"
echo "        select 'Run workflows from fork pull requests'"
echo "    - Require approval for all outside collaborators: UNCHECK"
echo "    - Allow GitHub Actions to create and approve pull requests: your call"
echo ""
echo "  Repo → Settings → Actions → Runners"
echo "    - Confirm self-hosted runners are registered and idle"
echo ""
echo "  Repo → Settings → Pages"
echo "    - Confirm source is GitHub Actions"
echo "    - Trophy wall URL: https://${DEMO_ORG}.github.io/${DEMO_REPO}/"
echo ""
echo "Repo URL: https://github.com/${DEMO_ORG}/${DEMO_REPO}"
