# Session Setup Checklist

Use this checklist for rehearsal, conference setup, and teardown. Run every command from the bundle root unless the command says otherwise.

## One week before

* Create or verify the dedicated AWS account.
* Add a $50 AWS budget alert.
* Create or verify the throwaway GitHub organization.
* Mint a classic GitHub PAT with `repo` scope for the throwaway organization.
* Confirm the PAT expires within 30 days.
* Confirm local tools are present: `terraform`, `gh`, `aws`, `jq`, `curl`, and `zip`.

## Build Part A

```bash
cp terraform/demo-account/terraform.tfvars.example terraform/demo-account/terraform.tfvars
terraform -chdir=terraform/demo-account init
terraform -chdir=terraform/demo-account apply

export DEMO_ORG=<throwaway org>
export DEMO_REPO=cicd-demo
export AWS_REGION=us-east-1
export AWS_ROLE_ARN=$(terraform -chdir=terraform/demo-account output -raw role_arn)
export PAT_VALUE=<classic PAT with repo scope>
./github/setup-repo.sh
```

GitHub UI settings for the demo repo:

* Actions general settings: run workflows from fork pull requests.
* Actions general settings: disable approval requirement for outside collaborators.
* Actions runners: confirm no runner is stale before attendees arrive.

## Start runner pool

```bash
export DEMO_ORG=<throwaway org>
export DEMO_REPO=cicd-demo
export RUNNER_COUNT=10
./runner-pool/install-runners.sh
./runner-pool/start-runners.sh
```

Confirm at least 10 runners are idle in the GitHub UI.

## Build Part B

```bash
cp terraform/speaker-demo/terraform.tfvars.example terraform/speaker-demo/terraform.tfvars
terraform -chdir=terraform/speaker-demo init
terraform -chdir=terraform/speaker-demo apply

export LAMBDA_EXEC_ROLE_ARN=$(terraform -chdir=terraform/speaker-demo output -raw lambda_exec_role_arn)
export ELEVATED_ROLE_ARN=$(terraform -chdir=terraform/speaker-demo output -raw elevated_chain_target_arn)
export AWS_REGION=$(terraform -chdir=terraform/speaker-demo output -raw aws_region 2>/dev/null || echo us-east-1)
```

## Build detection pack

```bash
cp terraform/detection-rules/terraform.tfvars.example terraform/detection-rules/terraform.tfvars
terraform -chdir=terraform/detection-rules init
terraform -chdir=terraform/detection-rules apply
```

The detection module creates the CloudTrail management event trail required for the SNS alerts and raw CloudWatch Logs matches. It enables read and write management events so STS and Secrets Manager reads are visible to EventBridge.

If you set `alert_email`, confirm the SNS subscription before rehearsal.

## Rehearsal gate

* Walk `attendee-runbook.md` with a separate GitHub account.
* Open at least 5 concurrent PRs and confirm the runner pool clears the queue.
* Run the projector scripts twice, including teardown.
* Confirm the detection SNS topic or CloudWatch log group receives events from Part A and Part B. Use `terraform -chdir=terraform/detection-rules output -raw cloudwatch_log_group` for the log group and `terraform -chdir=terraform/detection-rules output -raw sns_topic_arn` for the topic.
* Confirm `handout/one-pager.md` has the public bundle URL.

Projector run order:

```bash
./speaker-scripts/01-deploy-persistence.sh
./speaker-scripts/02-abuse-iam-chain.sh
source /tmp/.rtv-demo-chain-creds
./speaker-scripts/03-pivot-secrets.sh
./speaker-scripts/99-teardown.sh
```

## After each session

```bash
./github/cleanup-runs.sh
./runner-pool/stop-runners.sh
```

Rotate the PAT.

```bash
export NEW_PAT_VALUE=<new classic PAT>
./github/rotate-pat.sh
```

Revoke the old PAT in the GitHub UI.

## Final teardown

```bash
terraform -chdir=terraform/detection-rules destroy
terraform -chdir=terraform/speaker-demo destroy
terraform -chdir=terraform/demo-account destroy
```

Review CloudTrail for unexpected activity before deleting the AWS account.
