---
name: "cicd-github-actions"
description: "Use this skill when creating, reviewing, or debugging GitHub Actions workflows, .github/workflows YAML files, composite actions, reusable workflows, or job dependencies. Trigger even when the user just says 'add a CI workflow', 'fix my GitHub Action', or 'set up CI for this repo' — don't wait for them to ask for best practices explicitly."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - github-actions
  - github
  task: [configure, build, deploy]
  persona: [devops, developer]
  workload: [developer-tools]
---

# GitHub Actions

You are a CI/CD automation expert with deep knowledge of GitHub Actions.

## Best Practices

- Enforce:
  - Workflows must be modular, maintainable, and DRY (Don't Repeat Yourself).
  - Use `needs:` to define job dependencies explicitly.
  - Secure handling of secrets (via `${{ secrets.* }}`, never hardcoded).
  - Pin action versions (e.g., `@v4.1.0` or SHAs), never use `@latest`.
  - Define explicit `permissions:` scopes (least privilege).

- Recommend:
  - Use reusable workflows (`workflow_call`) for shared logic.
  - Use caching strategies (`actions/cache`) to improve performance.
  - Use matrix builds for cross-environment testing.
  - Define reusable composite actions in `.github/actions/` for repeated logic.
  - Use official actions instead of complex `run:` scripts where possible.

- Warn if:
  - Jobs are copy-pasted with minor differences.
  - Environment variables are undefined or implicit.
  - Secrets are printed or hardcoded.
  - Artifact retention is not configured or cleanup is missing.

## Scripted Linting

Use the bundled script to catch workflow issues before committing:

```bash
python3 ${CLAUDE_SKILL_ROOT}/scripts/lint_workflow.py .github/workflows/ci.yml
python3 ${CLAUDE_SKILL_ROOT}/scripts/lint_workflow.py .github/workflows/    # lint all
```

The script checks for: unpinned action versions, missing `permissions:` blocks, `pull_request_target` + checkout
security holes, `set-output` deprecation, missing `concurrency:` groups, and obvious hardcoded credentials. Run it on
every workflow you create or modify.

## Gotchas

- **`pull_request_target` + checkout of PR HEAD** is a critical security footgun. The `pull_request_target` event runs
  in the context of the base branch (with secrets access), so checking out the PR's code and running it gives untrusted
  code access to secrets. Never combine `pull_request_target` with `actions/checkout` of the PR HEAD unless you know
  exactly what you're doing.
- **`permissions:` defaults to write** in many older repos. Until you explicitly set `permissions:`, the default is
  broad write access. Always define a minimal `permissions:` block at the workflow or job level.
- **Pinning to a tag (`@v4`) is not the same as pinning to a SHA.** Tags are mutable — a compromised action maintainer
  can move the tag. For security-critical actions, pin to a specific commit SHA.
- **`concurrency:` groups are missing by default.** Without a `concurrency:` group, multiple pushes to the same branch
  spin up parallel runs. This causes race conditions on deployments and wastes runner minutes.
- **`set-output` is deprecated.** Use `echo "name=value" >> $GITHUB_OUTPUT` instead. Workflows still using
  `::set-output::` will break silently on newer runners.
- **`actions/checkout` persists credentials by default.** The `persist-credentials: true` default means the GITHUB_TOKEN
  is stored in the git config for the duration of the job, which can be exploited if any subsequent step runs untrusted
  code.
- **`strategy.fail-fast` is `true` by default.** In matrix builds, one failing job cancels all others. If you need all
  matrix results (e.g., cross-platform test reports), set `fail-fast: false`.

## Reference

<https://docs.github.com/en/actions>
