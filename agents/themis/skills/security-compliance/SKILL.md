---
name: "security-compliance"
description: "Ensure infrastructure and software meet regulatory and industry compliance requirements."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - compliance
  - policy
  task: [audit, review]
  persona: [security-engineer, devops]
  workload: [security]
---

# Security - Compliance

## Best Practices

- Automate compliance checks with tools (e.g., OpenSCAP, InSpec, OPA/Gatekeeper).
- Maintain an evidence trail (audit logs, change history).
- Apply CIS Benchmarks for cloud/Kubernetes.
- Enforce encryption (at rest, in transit).
- Document and periodically review policies.
