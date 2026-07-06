# Architecture Diagrams

## Part A: Attendee hands-on flow

```mermaid
flowchart TD
    A["Attendee<br/>(GitHub account)"] -->|fork| B[Demo repo]
    A -->|open PR from fork| C["Pull request<br/>(submission JSON +<br/>handle-scoped script)"]
    C -->|pull_request_target fires| D[Self-hosted lab runner]
    D -->|checkout PR code| E["PR-controlled script<br/>ci/student-steps/YOUR_HANDLE.sh"]
    D -->|getIDToken| F["GitHub OIDC token<br/>aud=sts.amazonaws.com<br/>sub=repo:${DEMO_ORG}/${DEMO_REPO}:pull_request"]
    F -->|assume-role-with-web-identity| G["AWS IAM role<br/>rtv-demo-oidc-role<br/>(GetSecretValue only)"]
    G -->|temporary STS env vars| E
    E -->|print exports + upload artifact| H["Workflow log / sts-credentials artifact"]
    H -->|copy/paste| I[Attendee terminal]
    I -->|GetSecretValue| J["Secrets Manager<br/>demo/github-pat"]
    J -->|GitHub admin PAT| I
    I -->|"curl PUT /pulls/${PR_NUMBER}/merge<br/>Authorization: token ${PAT}"| K[GitHub API]
    K -->|force-merge| C
    C -->|"status: Merged"| L["PR flipped<br/>no human reviewed"]

    style G fill:#ffe6e6
    style J fill:#ffcccc
    style L fill:#ff9999
```

Key points:
- The trusted target workflow constructs `ci/student-steps/YOUR_HANDLE.sh`
  from the submission handle and executes that PR-controlled script.
- The IAM role has exactly one permission. Zero blast radius outside the
  single PAT pull.
- The force-merge call uses a credential that did not exist when the PR was
  opened.

## Post-compromise discussion flow (presenter implementation not published)

```mermaid
flowchart TD
    A["Compromised build role<br/>(conceptual)"] -->|"CreateFunction<br/>PutRule<br/>PutTargets"| B["Lambda-style persistence<br/>scheduled execution"]
    B -->|"fires every 2 min"| C["CloudWatch Logs<br/>(access evidence refreshed<br/>indefinitely)"]
    A -->|"sts:AssumeRole"| D["Elevated role<br/>(cross-account,<br/>broader perms)"]
    D -->|"GetSecretValue x N"| E["Pivot secrets<br/>(code hosting,<br/>CI platform,<br/>data warehouse,<br/>SaaS)"]
    E -.->|"extends reach<br/>outside AWS"| F["Code hosting admin<br/>CI platform admin<br/>Customer data<br/>SaaS admin"]

    style B fill:#fff2cc
    style D fill:#ffe6e6
    style E fill:#ffcccc
    style F fill:#ff9999
```

Key points:
- Persistence is built from native AWS services. No external infrastructure.
- IAM trust chain abuse turns a scoped role into a broad one via a single
  AssumeRole call.
- Secrets Manager is where "AWS compromise" becomes "enterprise compromise."

## Detection signal placement

```mermaid
flowchart LR
    subgraph "Part A signals"
      A1["CloudTrail:<br/>GetSecretValue from<br/>OIDC build session"]
      A2["GitHub audit log:<br/>PR merged by PAT-based<br/>caller, no human review"]
      A3["Config audit:<br/>pull_request_target +<br/>checkout of PR code"]
    end
    subgraph "Post-compromise discussion signals"
      B1["CloudTrail:<br/>CreateFunction<br/>from build role"]
      B2["CloudTrail:<br/>PutRule from<br/>build role"]
      B3["CloudTrail:<br/>AssumeRole chain<br/>from OIDC session"]
      B4["CloudTrail:<br/>GetSecretValue on<br/>admin-class secrets<br/>from build session"]
    end
```

All of these are deployable against logs every AWS-using organization already
collects. The gap is not data availability; it is that nobody is writing the
rules.
