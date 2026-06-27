# Trust the Pipeline, Lose the Kingdom
## DEF CON 34 Red Team Village — Shane Young — `@x90sky`

---

### What you just did live

Force-merged a pull request you did not own, using AWS credentials that did not exist when you opened the PR. Six commands. No C2. No implant.

### The live chain

1. **Fork** the demo repo and **open a PR** from your fork
2. `pull_request_target` workflow fires on the lab runner with GitHub OIDC trust
3. Workflow mints STS credentials and prints copy-ready exports to the log
4. You read the credentials from your own PR's Actions page
5. `aws secretsmanager get-secret-value` pulls a demo GitHub PAT
6. `curl -X PUT .../pulls/N/merge` merges your own PR

### The advanced chain we walk through with artifacts/code

7. Native cloud persistence can be built with services such as serverless functions and schedules
8. `sts:AssumeRole` trust chains can turn a scoped build role into a broader role
9. `GetSecretValue` on higher-value secrets is where cloud compromise can become enterprise compromise

The public Terraform/code bundle is the take-home path for reproducing the full chain later in a dedicated, empty AWS account.

### Real-world precedent

| Technique | Incident | Year |
|-----------|----------|------|
| Compromised CI with downstream blast radius | SolarWinds | 2020 |
| CI credential exfil via bash uploader | Codecov | 2021 |
| CI platform compromise with widespread impact | CircleCI | 2023 |
| Compromised GitHub Action, log-based exfil | tj-actions/changed-files | March 2025 |
| Mass GitHub Actions secret exfil | GhostAction | September 2025 |
| Turning Trivy and Checkmarx Actions into credential stealers | TeamPCP | March 2026 |

### Detection signals deployable today

**CloudTrail filters**
- `GetSecretValue` from OIDC build session ID, targeting admin-class secret names
- `AssumeRoleWithWebIdentity` from unexpected source IPs against OIDC-trusted roles
- `CreateFunction` or `PutRule` where the principal is any build role

**GitHub audit log / workflow telemetry**
- PR merge events where the actor is a PAT caller and the PR has zero human reviews
- `pull_request_target` workflow invocations from first-time contributors

**Config audit**
- Any workflow using `pull_request_target` with `actions/checkout` on `github.event.pull_request.head.sha`
- OIDC-trusted IAM roles with permissions broader than a single build use case

### Trust boundaries that need to exist

- Build infrastructure should not have access to admin-class secrets.
- OIDC-trusted roles should be scoped per-workflow, per-repo, per-branch — never shared, never broad.
- CI roles should not create durable cloud compute or schedules by default.
- The merge API is not a security boundary if your PAT has `repo` scope. Gate merges through branch protection + required reviews that cannot be self-approved, and treat every admin PAT as infrastructure.

### Live training docs

Attendee landing page: **`https://x90sky.sh/rtv`**

![QR code for https://x90sky.sh/rtv](../docs/rtv-qr.png)

### Reproduce the full chain at home

Public bundle: **`https://github.com/x90skysn3k/rtv-cicd-attack-chain`**

Use it with a dedicated, empty AWS account you control to review the live lab, safe demo repository, advanced chain artifacts/code, and public detection examples. Only attendee-safe material is published in the bundle.

### Contact

- GitHub: `x90skysn3k`
- Twitter/X: `@x90sky`
