# RTV CI/CD demo

Deliberately vulnerable demo repository for the DEF CON 34 Red Team Village lab.

## Training flow

1. Fork this repository.
2. Add one JSON file under `submissions/`.
3. Open a pull request from your fork.
4. Copy the STS credentials from the workflow log.
5. Pull the GitHub PAT from Secrets Manager.
6. Merge your own pull request with the PAT.
7. Refresh the trophy wall after GitHub Pages deploys.

## Live room quick path

Use the full `attendee-runbook.md` from the public bundle for screenshots, expected results, and fallback notes. The short command sequence is:

```bash
export RTV_HANDLE="replace_with_your_assigned_handle"
mkdir -p submissions
cat > "submissions/${RTV_HANDLE}.json" <<EOF
{
  "handle": "${RTV_HANDLE}",
  "message": "I controlled the pipeline."
}
EOF
```

Then:

1. Open a PR from your fork back to the room demo repo.
2. Copy the workflow log's AWS export lines into your terminal.
3. Verify with `aws sts get-caller-identity`.
4. Set `RTV_PAT` from `aws secretsmanager get-secret-value`.
5. Set `DEMO_ORG`, `DEMO_REPO`, and `PR_NUMBER`.
6. Merge with `curl -X PUT .../pulls/${PR_NUMBER}/merge`.
7. Refresh the trophy wall.

## Submission format

Create `submissions/${RTV_HANDLE}.json` with this shape:

Replace `${RTV_HANDLE}` with your assigned handle, for example `alice`.

```json
{
  "handle": "alice",
  "message": "pipeline owned"
}
```

Rules:

* The filename must match `handle`.
* `handle` may use letters, numbers, underscores, and hyphens.
* `message` must be 96 characters or fewer.
* HTML and extra fields are rejected.

## Safety note

This repository is intentionally unsafe. Do not copy the workflow into a real repository.
