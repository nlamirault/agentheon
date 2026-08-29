---
name: "security-network-policies"
description: "Restrict network communication between workloads to enforce least privilege."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - network
  - firewall
  task: [configure, secure, audit]
  persona: [security-engineer, devops]
  workload: [security]
---

# Security - Network Policies

## Best Practices

- Default deny all ingress/egress; allow only required flows.
- Use labels to group workloads in NetworkPolicies.
- Segment environments by namespace or subnet.
- Encrypt all traffic (TLS/mTLS).
- Use service mesh for zero-trust enforcement where needed.

## Example (Kubernetes NetworkPolicy)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: prod
spec:
  podSelector:
    matchLabels:
      app: backend
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
```
