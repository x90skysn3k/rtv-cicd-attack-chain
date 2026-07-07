# RTV CI/CD Attack Chain Lab

Attendee-safe materials for **Trust the Pipeline, Lose the Kingdom**.

## Lab shape

The live Red Team Village room flow is:

```text
PR-controlled step → OIDC/STS → demo PAT merge → trophy wall
```

The advanced cloud-native chain is taught with logs, diagrams, and code artifacts during the hour:

```text
bounded persistence → one IAM graph edge → controlled pivot secrets → detections
```

The public Terraform/code bundle is the take-home path for reproducing the full chain later in a dedicated, empty AWS account. Students should not run Terraform during the live 60-minute session.

## Student start here

Use `attendee-runbook.md` as the copy/paste path. Run the live room steps in this order:

1. Fork the demo repo.
2. Review `.github/workflows/ci.yml`.
2.5. Spot the vulnerable `pull_request_target`, PR checkout, and `bash "$STUDENT_STEP"` lines.
3. Create `submissions/YOUR_HANDLE.json` in GitHub web.
3.5. Create `ci/student-steps/YOUR_HANDLE.sh` in GitHub web.
4. Open a pull request back to the room demo repo.
5. Download `sts-credentials` and paste the export lines from `sts-creds.sh`.
6. Verify the temporary AWS identity.
7. Read the demo GitHub token from Secrets Manager into `PAT`.
8. Merge your own PR with the GitHub API.
9. Refresh the trophy wall.

Do **not** run Terraform during the live room session. Terraform is only for the take-home reproduction path in an empty AWS account you control.

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
