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
* `../terraform/detection-rules/` deploys a CloudTrail management event trail, EventBridge rules, and an SNS topic for live demo alerts.

## Demo usage

Deploy the Terraform rule pack in the same AWS account as the demo before rehearsal. From the public bundle root:

```bash
cd terraform/detection-rules
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

The module creates a CloudTrail trail with read and write management events enabled. The EventBridge rules use `ENABLED_WITH_ALL_CLOUDTRAIL_MANAGEMENT_EVENTS` so read style signals such as `GetSecretValue`, `AssumeRole`, and `AssumeRoleWithWebIdentity` can reach the SNS topic.

The rules are intentionally high signal for the lab account. In production, scope them to known build role ARNs, known GitHub OIDC providers, approved workflow subjects, and high value secret tags.
