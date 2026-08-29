---
name: "security-iam"
description: "Define principles for managing user and service identities securely."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - iam
  - rbac
  task: [configure, secure, audit]
  persona: [security-engineer, devops]
  workload: [security]
---

# Security - IAM

## Best Practices

- Apply the principle of least privilege.
- Use role-based access instead of user-based policies.
- Prefer short-lived credentials (OIDC, STS).
- Enforce MFA for human users.
- Regularly audit unused roles/policies.

## Example (AWS IAM policy)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": ["arn:aws:s3:::my-bucket"]
    }
  ]
}
```
