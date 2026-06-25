# RTV Demo Build Plan

Working tree for building the DEF CON 34 Red Team Village demo environment.

## Goal

Each of 10 to 15 attendees forks a public demo repo, opens a PR against it, reads live STS credentials from their own workflow log, pulls a GitHub admin PAT from Secrets Manager, and force-merges their own PR. Zero AWS blast radius beyond the single-secret pull. Persistence, IAM chain, and pivot are speaker-demoed on projector in Part B (not scaffolded here yet).

## Prerequisites (one-time)

- AWS account dedicated to this demo. Nothing else in it. Budget alert at $50.
- Throwaway GitHub org (free tier fine). No other repos, no other members. Admin user = speaker.
- GitHub PAT (classic) with `repo` scope on the demo org. Create via GitHub UI, paste into `PAT_VALUE` env var for `setup-repo.sh`. Expiry: 30 days or less.
- Local tools: `terraform`, `gh` CLI authenticated as org admin, `aws` CLI, `jq`.
- Demo laptop or travel-router-attached machine for the runner pool.

## Phase 1 build order (what's in this tree now)

1. **Terraform up the AWS side** (`terraform/demo-account/`)
   - OIDC provider for GitHub Actions (once per account)
   - IAM role trusted for OIDC from `<org>/<repo>` on `pull_request`
   - Permissions policy: `secretsmanager:GetSecretValue` on one ARN only
   - Secrets Manager secret (empty, populated by setup-repo.sh)
   ```
   cd terraform/demo-account
   cp terraform.tfvars.example terraform.tfvars  # set github_org and github_repo
   terraform init && terraform apply
   ```

2. **Bootstrap the demo repo** (`github/setup-repo.sh`)
   - Creates public demo repo in the throwaway org
   - Pushes `workflow.yml` to `.github/workflows/ci.yml`
   - Sets repo variables `AWS_ROLE_ARN` and `AWS_REGION`
   - Seeds Secrets Manager with the PAT
   ```
   export DEMO_ORG=<org>
   export DEMO_REPO=cicd-demo
   export AWS_REGION=us-east-1
   export PAT_VALUE=<github-pat-classic-with-repo-scope>
   export AWS_ROLE_ARN=<terraform output role_arn>
   ./github/setup-repo.sh
   ```

3. **Install and start runners** (`runner-pool/`)
   - Installs N self-hosted runners on this machine
   - Starts them in the background
   ```
   export DEMO_ORG=<org> DEMO_REPO=cicd-demo RUNNER_COUNT=10
   ./runner-pool/install-runners.sh
   ./runner-pool/start-runners.sh
   ```

4. **Post-bootstrap repo settings (manual, GitHub UI)**
   - Settings → Actions → General → "Fork pull request workflows from outside collaborators" → **"Run workflows from fork pull requests"**
   - Settings → Actions → General → **uncheck** "Require approval for all outside collaborators" (so fork PRs fire without speaker approval)
   - Settings → Actions → Runners → confirm runners are registered and idle

5. **End-to-end validation**
   Follow `attendee-runbook.md` using a separate test GitHub account. If it works for one, it works for 15.

## Phase 3: Speaker projector demo (built)

1. **Terraform up the elevated side** (`terraform/speaker-demo/`)
   - Lambda execution role, elevated chain target role, pivot secrets, Lambda log group
   ```
   cd terraform/speaker-demo
   cp terraform.tfvars.example terraform.tfvars
   terraform init && terraform apply
   ```

2. **Rehearse the Part B scripts** (`speaker-scripts/`)
   - `01-deploy-persistence.sh` — creates Lambda + EventBridge from the projector
   - `02-abuse-iam-chain.sh` — assumes elevated role, writes chained creds
   - `03-pivot-secrets.sh` — reads all pivot secrets
   - `99-teardown.sh` — removes the live-created Lambda + rule

   See `speaker-scripts/README.md` for run order and narrative cues.

## Phase 4: Operational hygiene and public bundle (built)

- **PAT rotation**: `github/rotate-pat.sh` swaps the PAT in Secrets Manager; manual UI step to revoke the old PAT
- **Run cleanup**: `github/cleanup-runs.sh` deletes workflow runs and closes open PRs after each session
- **Architecture diagrams**: `handout/architecture.md` contains Mermaid diagrams of Part A, Part B, and detection signal placement
- **One-page handout**: `handout/one-pager.md` is the attendee take-home
- **Public bundle root**: `README.md` and `LICENSE` make `build/` publishable as a standalone repository
- **Detection rule pack**: `detections/` and `terraform/detection-rules/` provide CloudTrail hunts, EventBridge patterns, and SNS-backed rules
- **Session checklist**: `SESSION_SETUP.md` is the runbook for rehearsal, conference setup, and teardown

## Phase 5 live gates

- Runner pool stress test with 5 or more concurrent PRs
- End-to-end attendee test with a separate GitHub account
- Speaker projector rehearsal twice, including teardown

## OPSEC notes

- The PAT has `repo` scope on the demo org. Anyone who pulls the secret can push code, create branches, or merge PRs in the demo org. Keep the org empty.
- Workflow logs are public. STS creds are visible to anyone on the internet for their session lifetime (15 min). The role is scoped to `GetSecretValue`, so stolen creds can only pull the same PAT students already have.
- GitHub's `configure-aws-credentials` action masks creds. Do NOT use it. This workflow calls `aws sts assume-role-with-web-identity` directly.
- STS credentials use `ASIA` prefix (not `AKIA`), so GitHub's pattern-based log scrubbing typically does not catch them. Verify with a dry run before the session.
- Rotate the PAT and the Secrets Manager value after each session.
