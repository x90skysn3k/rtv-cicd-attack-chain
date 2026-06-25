# Detection Rule Pack

This pack turns the Red Team Village demo into detection validation material. It covers the control plane events produced by the attendee flow and the speaker projector flow.

## Signals

* `AssumeRoleWithWebIdentity` against the GitHub OIDC trusted role
* `GetSecretValue` from a build or chained session
* `CreateFunction` or `UpdateFunctionCode` from a build style identity
* `PutRule` or `PutTargets` from a build style identity
* `AssumeRole` into a broader role after the build identity is compromised

## Files

* `cloudtrail-athena.sql` contains copy ready CloudTrail Lake or Athena style hunts. Replace table and account values before use.
* `eventbridge-patterns.json` contains raw EventBridge event patterns that mirror the Terraform module.
* `../terraform/detection-rules/` deploys EventBridge rules and an SNS topic for live demo alerts.

## Demo usage

Deploy the Terraform rule pack in the same AWS account as the demo before rehearsal.

```bash
cd defcon_34_red_team_village/build/terraform/detection-rules
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

The rules are intentionally high signal for the lab account. In production, scope them to known build role ARNs, known GitHub OIDC providers, approved workflow subjects, and high value secret tags.
