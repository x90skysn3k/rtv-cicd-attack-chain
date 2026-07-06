# RTV CI/CD Attack Chain Public Bundle

The public repository `x90skysn3k/rtv-cicd-attack-chain` is the attendee-safe export for the Red Team Village lab.

## Intended public story

The conference-room flow is submission-compatible:

```text
Live hands-on: PR-controlled step → OIDC/STS → demo PAT merge → trophy wall
Advanced chain: persistence → IAM graph → pivot secrets → detections via slides/logs/code
Take-home: Terraform/code bundle to reproduce the full chain later
```

Terraform in the public repository is the **take-home reproduction path** for attendees to run later in their own dedicated, empty AWS account. It is not a live-session student step.

## Include

- `README.md`, `.gitignore`, and `LICENSE`.
- `attendee-runbook.md` for the live PR-to-merge room path and artifact/code walkthrough.
- `docs/` public landing-page redirect and QR code.
- `handout/` attendee reference material and diagrams.
- `detections/` public detection examples and hunts.
- `github/workflow.yml` intentionally vulnerable lab workflow.
- `github/demo-repo/` safe trophy wall demo application.
- Terraform needed to reproduce the full bounded lab in an empty AWS account after the session.
- Student-safe lab scripts only after they enforce handle/session scoping and cleanup.

## Exclude

- unpublished presentation/source materials;
- private planning and rehearsal material;
- live credentials or credential-shaped examples;
- token-handling utilities used for the live conference environment;
- Terraform state, `.tfvars`, generated plans, caches, `.terraform/`, runtime logs;
- legacy/private live-ops scripts unless rewritten as student-safe examples;
- private employer/client/vendor/product identifiers;
- exact private account IDs, runner hostnames, or local paths.

## Packaging

Run from `build/`:

```bash
./package-public-bundle.sh
```

The packager should stage into `dist/rtv-cicd-attack-chain`, verify required public paths, reject forbidden private paths and runtime artifacts, and print staged files. It should not push to GitHub or run Terraform.

## Verification before publishing

```bash
grep -RIniE 'private employer|private client|private vendor|private product' dist/rtv-cicd-attack-chain || true
grep -RIniE 'terraform.tfstate|terraform.tfvars|gho_|github_pat_' dist/rtv-cicd-attack-chain && exit 1 || true
```

Also manually search for any real employer/client/vendor/product names before pushing.
