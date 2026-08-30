# Kubernetes / Security

This reference provides comprehensive Kubernetes security guidance, covering Pod Security Standards, RBAC, security
contexts, and defense-in-depth strategies.

## Security Context Requirements

### Required Settings

Check for:

- `securityContext` settings on Pods and containers
- `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`
- Absence of `privileged: true`

### Network and Access Controls

Ensure:

- No use of `hostNetwork: true` unless justified
- RBAC is scoped minimally (`Role`, not `ClusterRole`)
- ServiceAccount usage is explicit and not `default`

### Recommended Security Enhancements

Recommend:

- PodSecurityStandards enforcement
- Limiting access via `PodSecurityPolicy` (if legacy) or `OPA/Gatekeeper`

## Pod Security Standards

Kubernetes Pod Security Standards define three levels of security policies:

### Privileged (Unrestricted)

**Use case:** System-level workloads only (CNI plugins, CSI drivers, logging agents)

**Allows:** All capabilities, host access, privilege escalation

**Warning:** Never use for application workloads

### Baseline (Minimally Restrictive)

**Use case:** Applications that need some flexibility but basic security

**Prohibits:**

- `privileged: true`
- `hostNetwork: true`, `hostPID: true`, `hostIPC: true`
- Most dangerous capabilities

**Example namespace enforcement:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: app-namespace
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Restricted (Heavily Restricted)

**Use case:** Production applications (recommended default)

**Requires:**

- `runAsNonRoot: true`
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true`
- Drop all capabilities
- Seccomp profile

**Example namespace enforcement:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Security Context Examples

### Pod-Level Security Context

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: app:1.0.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
```

### Container-Level Security Context

```yaml
containers:
- name: app
  securityContext:
    # Run as non-root (container-level)
    runAsNonRoot: true
    runAsUser: 1000
    # Prevent privilege escalation
    allowPrivilegeEscalation: false
    # Read-only root filesystem
    readOnlyRootFilesystem: true
    # Drop all Linux capabilities
    capabilities:
      drop:
      - ALL
      # Add only required capabilities if needed
      add:
      - NET_BIND_SERVICE  # Only if binding to ports < 1024
```

## RBAC Best Practices

### Principle of Least Privilege

Create minimal Roles/ClusterRoles:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: production
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
  # NO "delete", "create", "update" unless required
```

### Avoid Cluster-Wide Permissions

❌ **Bad:**

```yaml
kind: ClusterRole  # Cluster-wide access
metadata:
  name: app-role
```

✅ **Good:**

```yaml
kind: Role  # Namespace-scoped
metadata:
  name: app-role
  namespace: production
```

### Explicit ServiceAccount Binding

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: production
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### Pod Using ServiceAccount

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app
spec:
  serviceAccountName: app-sa  # Explicit, not "default"
  automountServiceAccountToken: false  # Disable if not needed
```

## Network Policies

### Default Deny All

Start with default deny:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Allow Specific Traffic

Then allow only required traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: frontend
    ports:
    - protocol: TCP
      port: 8080
```

## Secrets Management

### Never Hardcode Secrets

❌ **Bad:**

```yaml
env:
- name: DB_PASSWORD
  value: "mypassword123"  # NEVER
```

✅ **Good:**

```yaml
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password
```

### External Secrets Operator

For production, integrate with vault systems:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: db-credentials
  data:
  - secretKey: password
    remoteRef:
      key: prod/db/password
```

## Common Security Anti-Patterns

### ❌ Running as Root

```yaml
# Missing securityContext - runs as root by default
containers:
- name: app
  image: app:latest
```

### ❌ Privileged Containers

```yaml
securityContext:
  privileged: true  # NEVER for apps
```

### ❌ Host Network Access

```yaml
spec:
  hostNetwork: true  # Avoid unless absolutely required
```

### ❌ Using Default ServiceAccount

```yaml
spec:
  # Missing serviceAccountName - uses "default"
```

### ❌ Wildcard RBAC Rules

```yaml
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]  # Too permissive
```

## Security Scanning and Validation

### Image Scanning

Scan images before deployment:

```bash
# Trivy
trivy image registry/app:1.0.0

# Grype
grype registry/app:1.0.0
```

### Manifest Scanning

Validate security of manifests:

```bash
# Kubesec
kubesec scan deployment.yaml

# Checkov
checkov -f deployment.yaml
```

### Runtime Security

Monitor runtime behavior:

- Falco for runtime threat detection
- OPA Gatekeeper for policy enforcement
- Admission controllers for validation

## Compliance and Auditing

### Enable Audit Logging

Configure audit policy:

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets", "configmaps"]
```

### Regular Security Reviews

- Review RBAC permissions quarterly
- Audit ServiceAccount usage
- Scan for over-privileged pods
- Check for outdated security contexts

## Additional Resources

- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)

For complete RBAC examples, see `assets/rbac-example.yaml`.
For NetworkPolicy patterns, see `assets/networkpolicy-example.yaml`.
