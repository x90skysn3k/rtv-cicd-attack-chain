# RTV CI/CD demo

Deliberately vulnerable demo repository for the DEF CON 34 Red Team Village lab.

## Training flow

1. Fork this repository.
2. Add one JSON file under `submissions/`.
3. Open a pull request from your fork.
4. Copy the STS credentials from the workflow log.
5. Pull the GitHub PAT from Secrets Manager.
6. Merge your own pull request with the PAT.
7. Refresh the trophy wall after GitHub Pages deploys.

## Submission format

Create `submissions/<handle>.json` with this shape:

```json
{
  "handle": "alice",
  "message": "pipeline owned"
}
```

Rules:

* The filename must match `handle`.
* `handle` may use letters, numbers, underscores, and hyphens.
* `message` must be 96 characters or fewer.
* HTML and extra fields are rejected.

## Safety note

This repository is intentionally unsafe. Do not copy the workflow into a real repository.
