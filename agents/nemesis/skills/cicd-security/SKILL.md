---
name: "cicd-security"
description: "Use this skill when hardening CI/CD pipelines, reviewing pipeline secret management, evaluating OIDC authentication for cloud providers, or auditing supply chain security in GitHub Actions, GitLab CI, CircleCI, or any other CI system. Trigger when the user mentions 'secure my pipeline', 'CI secrets', 'OIDC for CI', 'pinning actions', or 'supply chain attacks'."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - github-actions
  - security
  task: [secure, audit, review]
  persona: [devops, developer]
  workload: [developer-tools]
---

# CI/CD - Security

## Purpose

Ensure pipelines are secure, protect secrets, and prevent supply chain attacks.

## Best Practices

- Do not hardcode secrets in pipelines.
- Use OIDC for cloud provider authentication.
- Pin dependencies and actions by version or digest.
- Scan container images for vulnerabilities.
- Run static analysis (SAST) and dependency scanning.

## Gotchas

- **OIDC doesn't work out-of-the-box with self-hosted runners.** OIDC token exchange requires the runner to reach
  `token.actions.githubusercontent.com`. Self-hosted runners behind a firewall will silently fail or produce cryptic
  `Error: Credentials could not be loaded` messages. The cloud IAM trust policy also needs to explicitly allow the
  correct `sub` claim format.
- **`permissions: write-all` as a quick fix exposes everything.** It's tempting to silence permission errors with
  `write-all`, but this grants the GITHUB_TOKEN write access to your entire repo, packages, deployments, and more.
  Always grant only the minimum required permission.
- **Secrets are not masked if split across multiple log lines or base64-encoded.** The secret masking only replaces
  exact string matches. A secret that gets URL-encoded, base64-encoded, or split by a newline in a `run:` step will
  appear in plaintext in the logs.
- **Dependabot PRs don't have access to repository secrets.** Workflows triggered by Dependabot run with read-only
  permissions and cannot access `secrets.*`. Patterns that rely on secrets for Dependabot auto-merge will silently fail.
- **Third-party actions pinned to a tag can still be tampered with after the fact.** Tags are mutable references. Pin to
  a specific commit SHA for any action that has access to secrets or runs in a privileged context.
