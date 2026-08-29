# Kubernetes / Naming Conventions

This reference provides comprehensive naming conventions for Kubernetes resources, labels, annotations, and identifiers
to ensure consistency, clarity, and maintainability across clusters.

## Overview

Consistent naming conventions improve resource discovery, automation, and team collaboration. Names should be
descriptive, follow patterns, and use standard prefixes/suffixes to indicate resource type and purpose.

## General Principles

**Lowercase** - Use lowercase letters, numbers, and hyphens
**Descriptive** - Names should indicate purpose and context
**Consistent** - Apply patterns uniformly across resources
**Hierarchical** - Include context from broad to specific
**Length** - Keep under 63 characters for most resources
**DNS-Safe** - Compatible with DNS naming requirements

## Resource Naming Patterns

### Namespaces

```yaml
# Pattern: <environment>-<team>-<purpose>
# or: <environment>-<purpose>

# Good examples
prod-backend-api
staging-frontend
dev-data-processing
platform-monitoring
shared-logging

# Application-specific
apiVersion: v1
kind: Namespace
metadata:
  name: prod-payment-service
  labels:
    environment: production
    team: payments
    cost-center: engineering
```

### Deployments

```yaml
# Pattern: <app-name>-<component>

# Good examples
frontend-web
backend-api
payment-processor
user-service
cache-redis

apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-processor
  namespace: prod-backend-api
  labels:
    app: payment-processor
    component: processor
    version: v1
```

### Services

```yaml
# Pattern: <app-name>-<type>
# Types: api, web, grpc, internal, external

# Good examples
frontend-web
backend-api
database-internal
cache-redis
metrics-grpc

apiVersion: v1
kind: Service
metadata:
  name: backend-api
  namespace: prod-backend-api
  labels:
    app: backend
    component: api
    service-type: rest
```

### ConfigMaps and Secrets

```yaml
# Pattern: <app-name>-<purpose>-<type>
# Types: config, env, certs, credentials

# ConfigMap examples
frontend-app-config
backend-api-env
nginx-server-config
app-feature-flags

# Secret examples
backend-db-credentials
frontend-api-keys
tls-wildcard-cert
oauth-client-secret

apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-api-config
  namespace: prod-backend-api
  labels:
    app: backend
    config-type: application
---
apiVersion: v1
kind: Secret
metadata:
  name: backend-db-credentials
  namespace: prod-backend-api
  labels:
    app: backend
    secret-type: database
```

### StatefulSets

```yaml
# Pattern: <app-name>-<stateful-component>

# Good examples
postgres-primary
redis-cluster
elasticsearch-data
kafka-broker
zookeeper-ensemble

apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
  namespace: prod-database
  labels:
    app: postgres
    component: database
    role: primary
```

### Jobs and CronJobs

```yaml
# Job pattern: <action>-<target>-<timestamp>
# CronJob pattern: <action>-<target>-<schedule>

# Job examples
backup-database-20260218
migrate-schema-v2
import-users-batch1

# CronJob examples
backup-database-daily
cleanup-logs-hourly
sync-data-weekly
report-generation-nightly

apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-database-daily
  namespace: prod-database
  labels:
    app: backup
    target: database
    schedule: daily
spec:
  schedule: "0 2 * * *"
```

### Ingress / HTTPRoute

```yaml
# Pattern: <app-name>-<environment>-<protocol>

# Good examples
frontend-prod-https
api-staging-http
admin-prod-grpc

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-prod-https
  namespace: prod-frontend
  labels:
    app: frontend
    environment: production
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: backend-api-route
  namespace: prod-backend-api
  labels:
    app: backend
    protocol: http
```

### PersistentVolumeClaims

```yaml
# Pattern: <app-name>-<data-type>-<purpose>

# Good examples
postgres-data-primary
redis-data-cache
elasticsearch-data-hot
application-logs-storage

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-primary
  namespace: prod-database
  labels:
    app: postgres
    storage-type: database
    tier: hot
```

## Label Conventions

### Standard Labels

```yaml
# Kubernetes recommended labels
metadata:
  labels:
    # Application identification
    app.kubernetes.io/name: backend
    app.kubernetes.io/instance: backend-prod
    app.kubernetes.io/version: "1.2.3"
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: payment-platform
    app.kubernetes.io/managed-by: helm

    # Environment and team
    environment: production
    team: backend
    cost-center: engineering

    # Technical metadata
    tier: backend
    layer: application
    language: golang

    # Operational
    monitoring: enabled
    backup: daily
```

### Label Patterns

```yaml
# Pattern examples for different scenarios

# Microservices
labels:
  app.kubernetes.io/name: user-service
  app.kubernetes.io/version: "2.1.0"
  app.kubernetes.io/component: service
  app.kubernetes.io/part-of: user-management
  service-mesh: istio

# Multi-tenant
labels:
  tenant: customer-abc
  tenant-tier: premium
  isolation: namespace

# Data classification
labels:
  data-classification: confidential
  compliance: pci-dss
  encryption: required

# Resource management
labels:
  resource-tier: guaranteed
  priority-class: high
  scaling-group: autoscale

# GitOps
labels:
  gitops.flux.io/managed-by: flux
  kustomize.toolkit.fluxcd.io/name: apps
  kustomize.toolkit.fluxcd.io/namespace: flux-system
```

### Selector Labels

```yaml
# Use simple, stable selectors
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-api
spec:
  selector:
    matchLabels:
      app: backend
      component: api
  template:
    metadata:
      labels:
        # Selector labels (required, immutable)
        app: backend
        component: api
        # Additional labels (optional, mutable)
        version: v1.2.3
        deployment: backend-api
```

## Annotation Conventions

### Standard Annotations

```yaml
metadata:
  annotations:
    # Documentation
    description: "Backend API service handling payment processing"
    documentation: "https://wiki.example.com/backend-api"
    contact: "backend-team@example.com"

    # CI/CD
    build.git.commit: "abc123def"
    build.git.branch: "main"
    build.ci.pipeline: "12345"
    build.timestamp: "2026-02-18T10:30:00Z"

    # Monitoring
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
    prometheus.io/path: "/metrics"

    # Service mesh
    sidecar.istio.io/inject: "true"
    sidecar.istio.io/proxyCPU: "100m"
    sidecar.istio.io/proxyMemory: "128Mi"

    # Scaling
    autoscaling.kubernetes.io/min-replicas: "3"
    autoscaling.kubernetes.io/max-replicas: "10"

    # Security
    seccomp.security.alpha.kubernetes.io/pod: "runtime/default"
    container.apparmor.security.beta.kubernetes.io/app: "runtime/default"
```

### Custom Annotations

```yaml
# Organization-specific patterns
metadata:
  annotations:
    # Change management
    example.com/change-ticket: "CHG-12345"
    example.com/deployment-window: "2026-02-18T22:00:00Z"
    example.com/rollback-plan: "https://runbook.example.com/rollback"

    # Cost allocation
    example.com/cost-center: "CC-1234"
    example.com/project-code: "PROJ-5678"
    example.com/budget-owner: "engineering-director"

    # Compliance
    example.com/data-classification: "confidential"
    example.com/retention-period: "7years"
    example.com/compliance-frameworks: "sox,pci-dss"

    # Operations
    example.com/on-call-team: "backend-oncall"
    example.com/escalation-policy: "EP-001"
    example.com/sla-tier: "tier1"
```

## Container Names

```yaml
# Pattern: descriptive, single-word or hyphenated

spec:
  containers:
  # Application containers
  - name: app
  - name: backend
  - name: frontend
  - name: api-server

  # Supporting containers
  - name: nginx
  - name: envoy-proxy
  - name: log-forwarder

  initContainers:
  # Init containers with purpose
  - name: migration
  - name: config-loader
  - name: wait-for-db
  - name: setup-permissions

  # Sidecar containers
  - name: istio-proxy
  - name: cloud-sql-proxy
  - name: vault-agent
```

## Volume Names

```yaml
# Pattern: <purpose>-<type>

spec:
  volumes:
  # Configuration volumes
  - name: config-volume
  - name: secrets-volume
  - name: env-config

  # Data volumes
  - name: data-storage
  - name: cache-volume
  - name: logs-volume

  # Special purpose
  - name: tls-certs
  - name: service-account-token
  - name: shared-data
```

## Port Names

```yaml
# Pattern: <protocol>-<purpose>

spec:
  ports:
  # Standard protocols
  - name: http
    port: 8080
  - name: https
    port: 8443
  - name: grpc
    port: 9090

  # Specific purposes
  - name: http-metrics
    port: 9091
  - name: http-health
    port: 8081
  - name: tcp-redis
    port: 6379
  - name: tcp-postgres
    port: 5432
```

## ServiceAccount Names

```yaml
# Pattern: <app-name>-<purpose>

# Good examples
backend-api
frontend-web
database-operator
backup-job
monitoring-agent

apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-api
  namespace: prod-backend-api
  labels:
    app: backend
    component: api
```

## Common Anti-Patterns

### ❌ Generic Names

```yaml
# Bad - too generic
name: app
name: service
name: deployment-1
name: test
```

```yaml
# Good - specific and descriptive
name: payment-processor
name: user-authentication-api
name: frontend-web-app
name: integration-test-db
```

### ❌ Inconsistent Casing

```yaml
# Bad - mixed casing
name: BackendAPI
name: frontend_web
name: Payment.Processor
```

```yaml
# Good - consistent lowercase with hyphens
name: backend-api
name: frontend-web
name: payment-processor
```

### ❌ Version in Name

```yaml
# Bad - version in resource name
name: backend-v1
name: api-v2-5
```

```yaml
# Good - version in label
name: backend
labels:
  app.kubernetes.io/version: "1.0"
  version: v1
```

### ❌ Environment in Name

```yaml
# Bad - environment in resource name within namespaced resource
name: backend-prod
namespace: production
```

```yaml
# Good - environment in namespace or label
name: backend
namespace: prod-backend-api
labels:
  environment: production
```

### ❌ Abbreviations

```yaml
# Bad - unclear abbreviations
name: be-api
name: fe-svc
name: db-sts
```

```yaml
# Good - clear, full words
name: backend-api
name: frontend-service
name: database-statefulset
```

### ❌ No Context in Labels

```yaml
# Bad - minimal labels
labels:
  app: backend
```

```yaml
# Good - comprehensive labels
labels:
  app.kubernetes.io/name: backend
  app.kubernetes.io/instance: backend-prod
  app.kubernetes.io/version: "1.2.3"
  app.kubernetes.io/component: api
  app.kubernetes.io/part-of: payment-platform
  environment: production
  team: backend
```

## Validation Commands

```bash
# Check resource names
kubectl get all --all-namespaces -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'

# List resources with labels
kubectl get pods --show-labels
kubectl get deployments --show-labels -A

# Find resources by label
kubectl get pods -l app=backend
kubectl get all -l environment=production

# Check naming patterns
kubectl get namespaces | grep -E '^(prod|staging|dev)-'

# Validate label keys
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.labels}{"\n"}{end}'

# List annotations
kubectl get pod <pod-name> -o jsonpath='{.metadata.annotations}' | jq

# Find resources without required labels
kubectl get pods -A -o json | jq -r '.items[] | select(.metadata.labels."app.kubernetes.io/name" == null) | .metadata.name'
```

## Additional Resources

- [Kubernetes Naming Conventions](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/)
- [Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [Kubernetes Object Names and IDs](https://kubernetes.io/docs/concepts/overview/working-with-objects/names/)
- [Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)
