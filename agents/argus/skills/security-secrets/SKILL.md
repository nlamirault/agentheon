---
name: "security-secrets"
description: "Ensure application and infrastructure secrets are stored, accessed, and rotated securely."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - secrets
  - vault
  task: [configure, secure, audit]
  persona: [security-engineer, devops]
  workload: [security]
---

# Security - Secrets Management

## Best Practices

- Never hardcode secrets in code or configs.
- Use secret managers (Vault, AWS Secrets Manager, GCP Secret Manager, Azure Key Vault).
- Rotate secrets regularly and automate expiry.
- Encrypt secrets at rest and in transit.
- Audit and log all secret access.

## Example

```hcl
resource "aws_secretsmanager_secret" "db_password" {
  name        = "db_password"
  description = "Database password for app"
}
```
