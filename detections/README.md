# Detection Examples

This public pack turns the Red Team Village lab into detection validation
material. It focuses on the control-plane events produced by the attendee flow
and the high-level post-compromise behaviors discussed in the workshop.

## Signals

* `AssumeRoleWithWebIdentity` against the GitHub OIDC trusted role
* `GetSecretValue` from a build or chained session
* `CreateFunction` or `UpdateFunctionCode` from a build-style identity
* `PutRule` or `PutTargets` from a build-style identity
* `AssumeRole` into a broader role after the build identity is compromised

## Files

* `cloudtrail-athena.sql` contains copy-ready CloudTrail Lake or Athena-style
  hunts. Replace table names, account values, role names, and regions before
  use.
* `eventbridge-patterns.json` contains raw EventBridge event patterns that can
  be adapted to your own alerting pipeline.

## Usage

The public bundle intentionally does not include the operator-only Terraform
module that deploys live alerting infrastructure for the conference lab. Use the
SQL and JSON examples here as review material or adapt them into your own
CloudTrail, EventBridge, SIEM, or SOAR deployment process.

The patterns are intentionally high signal for a dedicated lab account. In
production, scope them to known build role ARNs, known GitHub OIDC providers,
approved workflow subjects, protected branch policies, and high-value secret
tags.
