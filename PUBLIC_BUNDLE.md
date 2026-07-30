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
- `terraform/demo-account/` for the live-path OIDC/STS/PAT infrastructure reproduced after the session.
- `terraform/advanced-chain/` for the fixed Lambda role, one constrained IAM edge, fake pivot secrets, log retention, and management-event detections.
- `take-home-scripts/` for fixed-name persistence deployment, attendee-controlled TLS credential proof, one-edge role assumption, allowlisted fake-secret reads, and teardown.

## Exclude

- unpublished presentation/source materials;
- private planning and rehearsal material;
- live credentials or credential-shaped examples;
- token-handling utilities used for the live conference environment;
- Terraform state, `.tfvars`, generated plans, caches, `.terraform/`, runtime logs;
- legacy/private live-ops scripts unless rewritten as student-safe examples;
- private employer/client/vendor/product identifiers;
- exact private account IDs, runner hostnames, or local paths.
- private `speaker-scripts/` and `terraform/speaker-demo/` originals.

## Packaging

Run from `build/`:

```bash
./package-public-bundle.sh
```

The packager stages into `dist/rtv-cicd-attack-chain`, requires both take-home paths, verifies the public allowlist, rejects the private speaker paths and runtime artifacts, and prints staged files. It does not push to GitHub, mutate AWS, or run Terraform.

## Verification before publishing

```bash
grep -RIniE 'private employer|private client|private vendor|private product' dist/rtv-cicd-attack-chain || true
grep -RIniE 'terraform.tfstate|terraform.tfvars|gho_|github_pat_' dist/rtv-cicd-attack-chain && exit 1 || true
```

Also manually search for any real employer/client/vendor/product names before pushing.
