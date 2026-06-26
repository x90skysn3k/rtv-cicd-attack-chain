# Public Bundle Boundary

The public repository `x90skysn3k/rtv-cicd-attack-chain` is a curated attendee-safe export from this private source tree. It is intended to let attendees review and reproduce the public CI/CD lab path without publishing operator runbooks, rehearsal notes, presenter operations, capacity-test tooling, token-handling utilities, Terraform state, caches, screenshots, or local runtime material.

## Published

These paths are public-safe and are staged by `./package-public-bundle.sh`:

* `README.md`, `.gitignore`, and `LICENSE`: public overview, local artifact guards, safety model, and license.
* `attendee-runbook.md`: attendee hands-on instructions for the public lab path.
* `docs/`: public landing-page redirect and QR code.
* `handout/`: attendee reference material and high-level diagrams.
* `detections/`: public detection examples and hunts.
* `github/workflow.yml`: the intentionally vulnerable lab workflow.
* `github/demo-repo/`: the safe trophy wall demo application.
* `terraform/demo-account/`: the dedicated-account Terraform root for the attendee lab.

## Not published

Private source-only material must not be staged into the public repository:

* operator runbooks and rehearsal plans
* presenter scripts and presenter-only Terraform roots
* live alerting deployment modules
* runner operations and capacity-test tooling
* repository setup, cleanup, and token-rotation utilities
* presenter deck files, screenshots, caches, local exports, Terraform state, `.tfvars`, generated plans, logs, and other runtime artifacts

## Enforcement

Run `./package-public-bundle.sh` from this directory. By default it stages into `dist/rtv-cicd-attack-chain`, verifies the required public paths, rejects forbidden private paths and runtime artifacts, and prints the staged file list. It does not push to GitHub or run Terraform, GitHub CLI, tests, builds, or formatters.
