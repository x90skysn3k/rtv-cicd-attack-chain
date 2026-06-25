# Speaker Projector Scripts (Part B)

Runs on the speaker's laptop during the slide/demo portion of the Tactic,
after the attendee hands-on portion (Part A) concludes.

Demonstrates the stages of the chain that are not hands-on for attendees:
persistence (Lambda + EventBridge), IAM trust chain abuse, and the pivot
out of AWS via Secrets Manager.

## One-time setup

```
cd ../terraform/speaker-demo
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
```

Exports needed in the speaker's shell:

```
export LAMBDA_EXEC_ROLE_ARN=$(cd ../terraform/speaker-demo && terraform output -raw lambda_exec_role_arn)
export ELEVATED_ROLE_ARN=$(cd ../terraform/speaker-demo && terraform output -raw elevated_chain_target_arn)
export AWS_REGION=$(cd ../terraform/speaker-demo && terraform output -raw aws_region 2>/dev/null || echo us-east-1)
```

Speaker also needs active AWS admin credentials (the "starting point" session
representing a compromised build role that has already chained up). These can
be the speaker's own admin IAM user, an AssumeRole session, or anything with
the authority to CreateFunction, PutRule, and AssumeRole.

## Run order during the talk

```
./01-deploy-persistence.sh      # creates Lambda + EventBridge schedule, fires once
./02-abuse-iam-chain.sh         # assumes the elevated role, writes chained creds
source /tmp/.rtv-demo-chain-creds
./03-pivot-secrets.sh           # reads the pivot secrets
./99-teardown.sh                # cleans up Lambda + EventBridge after the talk
```

## Rehearsal

Run the full sequence once start-to-finish, including the teardown. Then run
it again. Both should complete with no errors and the logs should look clean
before attempting on stage.

Optional: tail the persistence Lambda's CloudWatch logs in a second terminal
during 01 and 02 so you can narrate "see, it just fired again" mid-demo.

```
aws logs tail "/aws/lambda/rtv-speaker-demo-cred-relay" --since 5m --follow --region "$AWS_REGION"
```

## What each script shows the audience

- **01-deploy-persistence.sh**: A build role (which a poisoned workflow gave an
  attacker) just deployed a Lambda function and scheduled it with EventBridge.
  Every 2 minutes, the Lambda wakes up, prints fresh access evidence to
  CloudWatch, and goes back to sleep. No traffic leaves the account. No
  endpoint exists to block.

- **02-abuse-iam-chain.sh**: An sts:AssumeRole call turns the compromised
  session into an elevated session. The starting point was tight. The landing
  point is not.

- **03-pivot-secrets.sh**: Secrets Manager holds the credentials that unlock
  everything outside AWS: code hosting admin tokens, CI platform admin keys,
  data warehouse credentials, and SaaS API keys. The AWS compromise is the
  pivot, not the destination.

- **99-teardown.sh**: Removes the Lambda and EventBridge rule. Terraform still
  owns the IAM roles, pivot secrets, and log group; `terraform destroy` in
  the module directory tears those down.
