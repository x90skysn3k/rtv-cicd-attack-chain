# Trust the Pipeline, Lose the Kingdom

Hands-on cloud native CI/CD red team lab for DEF CON 34 Red Team Village.

This private source tree contains both attendee-safe material and operator-only
preparation material. The public repository at
`x90skysn3k/rtv-cicd-attack-chain` is intentionally curated from this tree; it
does not publish presenter operations, rehearsal notes, runner operations,
capacity-test tooling, Terraform state, local artifacts, or token handling utilities.

Live training landing page and source of truth: `https://x90sky.sh/rtv`.
`docs/index.html` redirects there so old GitHub Pages links do not become
stale. Print or project `docs/rtv-qr.png` for quick attendee access.

## Public bundle boundary

Use `./package-public-bundle.sh` from this directory to stage the public-safe
bundle. The script copies only the allowlisted files and directories, refuses to
publish into a Git checkout, excludes runtime artifacts and caches, verifies
that private paths are absent, and prints the exact staged file list. It does
not push to GitHub or run any Terraform, GitHub, test, build, or formatter
commands.

The public bundle includes:

* `README.md`, `.gitignore`, and `LICENSE`
* `PUBLIC_BUNDLE.md`
* `attendee-runbook.md`
* `docs/`
* `handout/`
* `detections/`
* `github/workflow.yml`
* `github/demo-repo/`
* `terraform/demo-account/`

The private source tree may also contain operator runbooks, rehearsal plans,
presenter materials, runner operations, capacity-test tooling, repository setup
and cleanup scripts, and speaker-only Terraform. Those files are not part of the
public bundle.

## Safety model

Use a dedicated AWS account, a throwaway GitHub organization, and a dedicated
throwaway GitHub user that owns nothing except the demo organization and demo
repository. Do not run this in an account, organization, or repository that
contains real work.

The attendee-facing role is intentionally narrow. It can call
`secretsmanager:GetSecretValue` on one lab secret in a dedicated demo account.
The public bundle is designed to demonstrate the CI/CD trust-boundary failure
without shipping presenter-only infrastructure or operations material.

## Public lab contents

### Attendee hands-on lab

`attendee-runbook.md` walks attendees through the public flow:

1. Fork the deliberately vulnerable demo repository.
2. Open a pull request that triggers the lab workflow.
3. Read short-lived AWS credentials from the workflow log.
4. Retrieve the lab GitHub token from Secrets Manager.
5. Use that token to merge the pull request and update the trophy wall.

`github/workflow.yml` is the intentionally vulnerable workflow used for the
exercise, and `github/demo-repo/` is the safe trophy wall application copied
into the demo repository.

### Public Terraform root

`terraform/demo-account/` contains the attendee-safe AWS resources for a
dedicated, empty demo account:

* a GitHub OIDC-trusted IAM role scoped to the demo repository
* one Secrets Manager secret for the lab token
* outputs needed by the lab operator to configure the demo workflow

Use placeholder values from `terraform.tfvars.example`; never commit live
account IDs, real token values, `.tfvars`, state, or plan files.

### Detection material

`detections/` contains public-safe CloudTrail/Athena hunts and EventBridge event
patterns for the behaviors discussed in the workshop. The operator-only
Terraform module that deploys live alerting rules is not published in the public
bundle.

### Handouts and landing page

`handout/` contains attendee reference material. `docs/` contains the public
landing-page redirect and QR code.

## Repository layout

Public bundle:

* `attendee-runbook.md`: attendee hands-on instructions
* `docs/`: public landing-page redirect and QR code
* `handout/`: public architecture and one-page reference material
* `detections/`: public detection examples and hunts
* `github/workflow.yml`: lab workflow
* `github/demo-repo/`: safe trophy wall app
* `terraform/demo-account/`: attendee-safe AWS lab root

Private source-only material stays out of the public repository:

* operator runbooks and rehearsal plans
* presenter scripts and presenter-only Terraform roots
* live alerting deployment modules
* runner operations and capacity-test tooling
* repository setup, cleanup, and token-rotation utilities
* presenter deck assets, screenshots, caches, local exports, Terraform state,
  `.tfvars`, generated plans, logs, and other runtime artifacts
