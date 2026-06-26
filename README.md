# Trust the Pipeline, Lose the Kingdom

Hands on cloud native CI/CD red team lab for DEF CON 34 Red Team Village.

This repository contains the public reproduction bundle for the workshop and paired tactic. It deploys a deliberately vulnerable GitHub Actions and AWS lab that demonstrates pull request poisoning, GitHub OIDC to AWS STS credential theft, Secrets Manager pivoting, Lambda and EventBridge persistence, IAM role chaining, and CloudTrail based detections.

Live training landing page: `https://x90sky.sh/rtv`. The same static page lives in `docs/index.html` for GitHub Pages or any external redirect. Print or project `docs/rtv-qr.png` for quick attendee access.

## Safety model

Use a dedicated AWS account, a throwaway GitHub organization, and a dedicated throwaway GitHub user that owns nothing except the demo org and repo. Do not run this in an account, organization, or repository that contains real work.

The attendee role is intentionally narrow. It can call `secretsmanager:GetSecretValue` on one secret. The speaker demo uses a separate Terraform root and separate credentials for the persistence and pivot stages.

## Prerequisites

* Terraform 1.5 or newer
* AWS CLI authenticated to a dedicated demo account
* GitHub CLI authenticated as the dedicated throwaway GitHub user that owns the demo organization
* jq, curl, and zip on the speaker machine
* A classic GitHub PAT with `repo` scope minted by that throwaway user. Do not use a personal or work account token.
* A laptop or LAN attached host for 10 to 15 self hosted GitHub Actions runners

## Part A: attendee hands on lab

Provision the student facing AWS side.

```bash
cp terraform/demo-account/terraform.tfvars.example terraform/demo-account/terraform.tfvars
# Edit terraform/demo-account/terraform.tfvars before apply:
#   aws_account_id = "223744800916"
#   github_org = "pipeline-demo-lab"
#   github_repo = "cicd-demo"
terraform -chdir=terraform/demo-account init
terraform -chdir=terraform/demo-account apply
```

Bootstrap the public demo repository, seed the PAT into Secrets Manager, and enable the GitHub Pages trophy wall.
The setup script copies `github/workflow.yml` into the demo repo as `.github/workflows/ci.yml`, then copies `github/demo-repo/` as the safe trophy wall app.

```bash
export DEMO_ORG=pipeline-demo-lab
export DEMO_REPO=cicd-demo
export AWS_REGION=us-east-1
export AWS_ROLE_ARN=$(terraform -chdir=terraform/demo-account output -raw role_arn)
export SECRET_NAME=$(terraform -chdir=terraform/demo-account output -raw secret_name)
export EXPECTED_AWS_ACCOUNT_ID=223744800916
export EXPECTED_GITHUB_USER=x90skysn3k
export PAT_VALUE=classic_pat_value_from_x90skysn3k
./github/setup-repo.sh
```

Enable the required repository settings in GitHub.

* Actions general settings: run workflows from fork pull requests
* Actions general settings: do not require approval for all outside collaborators
* Actions runners page: confirm all demo runners are idle before attendees begin
* Pages: confirm the trophy wall workflow is available at `https://pipeline-demo-lab.github.io/cicd-demo/`

Install and start the runner pool.

```bash
export DEMO_ORG=pipeline-demo-lab
export DEMO_REPO=cicd-demo
export RUNNER_COUNT=10
./runner-pool/install-runners.sh
./runner-pool/start-runners.sh
```

Walk `attendee-runbook.md` with a separate GitHub account before the session.

## Part B: speaker projector lab

Provision the speaker side.

```bash
cp terraform/speaker-demo/terraform.tfvars.example terraform/speaker-demo/terraform.tfvars
# Edit terraform/speaker-demo/terraform.tfvars before apply:
#   aws_account_id = "223744800916"
#   name_prefix = "rtv-speaker-demo"
terraform -chdir=terraform/speaker-demo init
terraform -chdir=terraform/speaker-demo apply
```

Export script inputs.

```bash
export LAMBDA_EXEC_ROLE_ARN=$(terraform -chdir=terraform/speaker-demo output -raw lambda_exec_role_arn)
export ELEVATED_ROLE_ARN=$(terraform -chdir=terraform/speaker-demo output -raw elevated_chain_target_arn)
export AWS_REGION=$(terraform -chdir=terraform/speaker-demo output -raw aws_region)
export NAME_PREFIX=$(terraform -chdir=terraform/speaker-demo output -raw name_prefix)
```

Run the projector sequence.

```bash
./speaker-scripts/01-deploy-persistence.sh
./speaker-scripts/02-abuse-iam-chain.sh
source /tmp/.rtv-demo-chain-creds
./speaker-scripts/03-pivot-secrets.sh
./speaker-scripts/99-teardown.sh
```

Rehearse the full sequence twice, including teardown.

## Detection validation

Deploy the detection pack before rehearsal.

```bash
cp terraform/detection-rules/terraform.tfvars.example terraform/detection-rules/terraform.tfvars
# Edit terraform/detection-rules/terraform.tfvars before apply:
#   aws_account_id = "223744800916"
#   name_prefix = "rtv-cicd-detect"
terraform -chdir=terraform/detection-rules init
terraform -chdir=terraform/detection-rules apply
```

This module creates a CloudTrail management event trail, EventBridge rules, an SNS topic, and a CloudWatch Logs target. The EventBridge rules are enabled for read and write management events so STS and Secrets Manager reads are covered.

See `detections/README.md` for the signal map, raw EventBridge patterns, and Athena hunts.

## Session cleanup

After each run:

```bash
./github/cleanup-runs.sh
./runner-pool/stop-runners.sh
```

Then rotate the PAT.

```bash
export NEW_PAT_VALUE=classic_pat_value_from_x90skysn3k
export EXPECTED_AWS_ACCOUNT_ID=223744800916
./github/rotate-pat.sh
```

Revoke the old PAT in the GitHub UI. Destroy Terraform resources when the session series is complete.

```bash
terraform -chdir=terraform/detection-rules destroy
terraform -chdir=terraform/speaker-demo destroy
terraform -chdir=terraform/demo-account destroy
```

## Repository layout

* `attendee-runbook.md`: attendee hands on instructions
* `terraform/demo-account/`: public repo, OIDC role, and one PAT secret
* `terraform/speaker-demo/`: Lambda persistence role, elevated chain role, and pivot secrets
* `terraform/detection-rules/`: EventBridge and SNS detection pack
* `github/`: repo bootstrap, PAT rotation, and workflow cleanup scripts
* `runner-pool/`: self hosted runner install, start, and stop scripts
* `speaker-scripts/`: live projector demo scripts
* `detections/`: raw detections and CloudTrail hunts
* `handout/`: architecture and one page reference material
