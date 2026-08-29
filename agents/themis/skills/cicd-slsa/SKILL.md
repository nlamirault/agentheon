---
name: "cicd-slsa"
description: "Use this skill when implementing SLSA provenance, build attestation, artifact signing, or software supply chain integrity in CI/CD pipelines. Trigger when the user mentions 'SLSA', 'provenance', 'supply chain security', 'artifact attestation', 'sigstore', 'cosign', or 'reproducible builds'."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - slsa
  - github-actions
  task: [secure, audit, configure]
  persona: [devops, developer]
  workload: [developer-tools]
---

# CI/CD - SLSA (Supply-chain Levels for Software Artifacts)

## Purpose

Ensure software supply chain integrity by following SLSA levels.

## Best Practices

- Generate provenance metadata for every build.
- Store provenance alongside artifacts.
- Ensure reproducible builds.
- Verify provenance before deployment.
- Use ephemeral build environments.

## Example

- GitHub Actions provenance with SLSA generator:

```yaml
- name: Generate provenance
  uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v1
```

## Gotchas

- **SLSA Level 3 requires hermetic builds — any network access during the build breaks it.** If your build fetches
  dependencies at build time (npm install, go mod download, pip install), the build is not hermetic and cannot achieve
  L3. Pre-fetch and cache dependencies before the build step.
- **The SLSA generator must be called as a reusable workflow (`workflow_call`), not as an inline step.** Running the
  generator as a step in your own workflow does not produce a verifiable SLSA L3 provenance — it must be a separate
  reusable workflow invocation.
- **Pinning the SLSA generator to a tag breaks SLSA guarantees.** The example `@v1` tag is mutable. Pin to a specific
  SHA for the generator itself, otherwise an attacker who compromises the generator repo can modify provenance
  generation.
- **`slsa-verifier` requires the exact source URI used during the build.** If your workflow runs from a fork, a renamed
  repo, or a different branch than expected, verification will fail with a confusing mismatch error.
- **`id-token: write` must be scoped to the workflow that generates provenance.** Setting it at the wrong job level or
  forgetting it causes a `OIDC token could not be generated` error that is hard to diagnose.
