# RTV CI/CD Attack Chain Lab

Attendee-safe materials for **Trust the Pipeline, Lose the Kingdom**.

## Lab shape

The live Red Team Village room flow is:

```text
PR/OIDC/STS → demo PAT merge → trophy wall
```

The advanced cloud-native chain is taught with logs, diagrams, and code artifacts during the hour:

```text
bounded persistence → one IAM graph edge → controlled pivot secrets → detections
```

The public Terraform/code bundle is the take-home path for reproducing the full chain later in a dedicated, empty AWS account. Students should not run Terraform during the live 60-minute session.

## What is here

- `attendee-runbook.md` — attendee-facing room path and artifact/code walkthrough.
- `PUBLIC_BUNDLE.md` — public export policy.
- `github/workflow.yml` — intentionally vulnerable workflow.
- `github/demo-repo/` — safe trophy wall app.
- `terraform/demo-account/` — public reproduction infrastructure.
- `detections/` — public detection examples.
- `handout/` — public attendee handouts.
- `docs/` — public redirect/QR support.

## Packaging

```bash
./package-public-bundle.sh
```

Then verify staged output before pushing anywhere:

```bash
grep -RIniE 'terraform.tfstate|terraform.tfvars|gho_|github_pat_' dist/rtv-cicd-attack-chain && exit 1 || true
```
