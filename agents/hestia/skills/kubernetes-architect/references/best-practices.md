# Kubernetes / Best Practices

This reference provides comprehensive Kubernetes best practices for production workloads, focusing on reliability,
security, and operational excellence.

## Core Requirements

### Mandatory Configuration

Enforce the following in all production workloads:

- `readinessProbe` and `livenessProbe` on all containers
- `resources.requests` and `resources.limits`
- `imagePullPolicy: IfNotPresent` or `Always`, based on versioning

### Configuration to Avoid

Warn against:

- `image: latest`
- missing `securityContext` and `runAsNonRoot: true`
- `hostPath` volumes (except for debugging)

### Recommended Practices

Recommend:

- Namespace scoping
- NetworkPolicy for pod-level security
- Prefer `RollingUpdate` strategy for Deployments for zero-downtime updates. Configure `maxUnavailable` and `maxSurge`
  appropriately
- PodDisruptionBudget for HA
- Externalize configuration using ConfigMaps and sensitive data using Secrets. Mount them as volumes or environment
  variables; avoid hardcoding in Pod specs.
- Using `apps/v1` for Deployments
- Define Roles/ClusterRoles and RoleBindings/ClusterRoleBindings to enforce least privilege access for users and service
  accounts.
- Use stable API versions (`apiVersion`) where available (e.g., `apps/v1` for Deployments) instead of beta or alpha
  versions for production workloads.

## Kubernetes Recommended Labels

Check **Kubernetes recommended common labels**
(<https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/>).

### Required Labels

Verify presence and correctness of these labels where applicable:
    - `app.kubernetes.io/component` — component within the architecture
    - `app.kubernetes.io/instance` — unique name identifying the instance
    - `app.kubernetes.io/name` — the name of the application
    - `app.kubernetes.io/managed-by` — tool managing this resource (e.g., Helm)
    - `app.kubernetes.io/part-of` — higher level application this is part of
    - `app.kubernetes.io/version` — current version of the app

### Label Placement

Ensure these labels exist and are consistent in:
    - `metadata.labels`
    - `metadata.template.metadata.labels` (for controllers like Deployments, StatefulSets)
    - Pod selector labels (`spec.selector.matchLabels` or `spec.selector`)
    - Service selector labels (`spec.selector`)

### Label Validation

Warn if:
    - Any required common label is missing or empty
    - Label values contain invalid characters or uppercase letters

## Annotations

**Usage:** Use annotations for non-identifying metadata, tool-specific configurations, or descriptions.

**Common annotations:**

- `kubernetes.io/description` - Human-readable resource description
- `prometheus.io/scrape`, `prometheus.io/port`, `prometheus.io/path` - Prometheus monitoring
- `nginx.ingress.kubernetes.io/*` - NGINX Ingress controller config
- `cert-manager.io/*` - Certificate management

## Examples

### Minimal Compliant Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
  labels:
    app.kubernetes.io/name: example-app
    app.kubernetes.io/version: "1.0.0"
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: example-app
  template:
    metadata:
      labels:
        app.kubernetes.io/name: example-app
        app.kubernetes.io/version: "1.0.0"
    spec:
      containers:
      - name: app
        image: registry/app:1.0.0
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        securityContext:
          runAsNonRoot: true
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          periodSeconds: 5
```

### Production-Grade Deployment

See `assets/deployment-example.yaml` for a comprehensive production-ready example including:

- Pod anti-affinity for high availability
- Topology spread constraints
- Security contexts at pod and container level
- Proper volume mounts for read-only filesystem
- All recommended labels and annotations

## Common Anti-Patterns

### ❌ Missing Resource Limits

```yaml
containers:
- name: app
  image: app:latest  # Also: don't use 'latest'
  # Missing: resources.requests and resources.limits
```

**Problem:** Can lead to resource contention and node instability.

### ❌ Running as Root

```yaml
spec:
  containers:
  - name: app
    # Missing: securityContext with runAsNonRoot
```

**Problem:** Security vulnerability if container is compromised.

### ❌ No Health Checks

```yaml
containers:
- name: app
  # Missing: livenessProbe and readinessProbe
```

**Problem:** Kubernetes can't detect unhealthy containers or when they're ready for traffic.

### ❌ Incomplete Labels

```yaml
metadata:
  labels:
    app: myapp  # Only legacy label, missing recommended labels
```

**Problem:** Poor observability and difficult to manage at scale.

## Validation Commands

Validate manifests before applying:

```bash
# Dry-run validation
kubectl apply --dry-run=client -f manifest.yaml

# Server-side validation (includes admission controllers)
kubectl apply --dry-run=server -f manifest.yaml

# Check for deprecated APIs
kubectl apply --dry-run=server --validate=true -f manifest.yaml
```

## Target Kubernetes Version

**Target:** 1.29+

Ensure all manifests use stable API versions compatible with Kubernetes 1.29 or later.
