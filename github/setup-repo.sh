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

if [ ! -f "$WORKFLOW_SRC" ]; then
  echo "FATAL: workflow.yml not found at $WORKFLOW_SRC" >&2
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

echo "[1/6] Creating public repo ${DEMO_ORG}/${DEMO_REPO}..."
if gh repo view "${DEMO_ORG}/${DEMO_REPO}" >/dev/null 2>&1; then
  echo "      repo exists, reusing"
else
  gh repo create "${DEMO_ORG}/${DEMO_REPO}" --public --description "DEF CON RTV demo. Intentionally vulnerable. Do not fork for anything real."
fi

echo "[2/6] Cloning and seeding repo contents..."
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"
gh repo clone "${DEMO_ORG}/${DEMO_REPO}"
cd "${DEMO_REPO}"

# Initial commit if empty
if ! git rev-parse HEAD >/dev/null 2>&1; then
  cat > README.md <<EOF
# ${DEMO_REPO}

Deliberately vulnerable CI/CD demo repo for the DEF CON 34 Red Team Village workshop.

Fork this repo and open a pull request to see the \`pull_request_target\` misconfiguration in action. Your workflow run will print live AWS STS credentials to the log — by design. This is the real-world CVE pattern used in tj-actions, GhostAction, and TeamPCP.

Do not copy this workflow into anything you care about.
EOF
  git add README.md
  git commit -m "Initial demo setup"
fi

mkdir -p .github/workflows
cp "$WORKFLOW_SRC" .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m "Add vulnerable pull_request_target workflow" || echo "      workflow unchanged, skipping commit"
git branch -M main
git push -u origin main

echo "[3/6] Setting repo variables..."
gh variable set AWS_ROLE_ARN --repo "${DEMO_ORG}/${DEMO_REPO}" --body "${AWS_ROLE_ARN}"
gh variable set AWS_REGION   --repo "${DEMO_ORG}/${DEMO_REPO}" --body "${AWS_REGION}"
gh variable set SECRET_NAME  --repo "${DEMO_ORG}/${DEMO_REPO}" --body "${SECRET_NAME}"

echo "[4/6] Writing PAT into Secrets Manager (${SECRET_NAME})..."
aws secretsmanager put-secret-value \
  --secret-id "${SECRET_NAME}" \
  --secret-string "${PAT_VALUE}" \
  --region "${AWS_REGION}" \
  >/dev/null

echo "[5/6] Verifying secret is readable..."
aws secretsmanager get-secret-value \
  --secret-id "${SECRET_NAME}" \
  --query 'SecretString' --output text \
  --region "${AWS_REGION}" >/dev/null
echo "      OK"

echo "[6/6] Done."
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
echo "Repo URL: https://github.com/${DEMO_ORG}/${DEMO_REPO}"
