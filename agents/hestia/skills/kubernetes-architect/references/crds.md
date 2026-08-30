# Kubernetes / Custom Resource Definitions (CRDs)

This reference provides comprehensive guidance for creating, managing, and operating Custom Resource Definitions in
Kubernetes, including validation, versioning, conversion, and controller patterns.

## Overview

Custom Resource Definitions (CRDs) extend the Kubernetes API with custom resources. They enable declarative APIs for
domain-specific objects while leveraging Kubernetes' built-in features like RBAC, storage, and API serving.

## Basic CRD Structure

### Simple CRD

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: applications.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: Application
    listKind: ApplicationList
    plural: applications
    singular: application
    shortNames:
    - app
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            required:
            - image
            - replicas
            properties:
              image:
                type: string
              replicas:
                type: integer
                minimum: 1
                maximum: 100
          status:
            type: object
            properties:
              phase:
                type: string
              conditions:
                type: array
                items:
                  type: object
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
```

### CRD with Advanced Validation

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.data.example.com
spec:
  group: data.example.com
  names:
    kind: Database
    plural: databases
    singular: database
    shortNames:
    - db
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        required:
        - spec
        properties:
          spec:
            type: object
            required:
            - engine
            - version
            properties:
              engine:
                type: string
                enum:
                - postgres
                - mysql
                - mongodb
              version:
                type: string
                pattern: '^[0-9]+\.[0-9]+$'
              storage:
                type: object
                required:
                - size
                properties:
                  size:
                    type: string
                    pattern: '^[0-9]+[GM]i$'
                  storageClass:
                    type: string
              backup:
                type: object
                properties:
                  enabled:
                    type: boolean
                  schedule:
                    type: string
                    pattern: '^(@(annually|yearly|monthly|weekly|daily|hourly))|(@every (\d+(ns|us|µs|ms|s|m|h))+)|((((\d+,)+\d+|(\d+(\/|-)\d+)|\d+|\*) ?){5,7})$'
                  retention:
                    type: integer
                    minimum: 1
                    maximum: 365
              replicas:
                type: integer
                minimum: 1
                maximum: 5
                default: 1
          status:
            type: object
            properties:
              phase:
                type: string
                enum:
                - Pending
                - Creating
                - Ready
                - Failed
              endpoint:
                type: string
              conditions:
                type: array
                items:
                  type: object
                  required:
                  - type
                  - status
                  properties:
                    type:
                      type: string
                    status:
                      type: string
                    reason:
                      type: string
                    message:
                      type: string
                    lastTransitionTime:
                      type: string
                      format: date-time
    subresources:
      status: {}
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
    additionalPrinterColumns:
    - name: Engine
      type: string
      jsonPath: .spec.engine
    - name: Version
      type: string
      jsonPath: .spec.version
    - name: Replicas
      type: integer
      jsonPath: .spec.replicas
    - name: Status
      type: string
      jsonPath: .status.phase
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
```

## Version Management

### Multiple Versions

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backends.api.example.com
spec:
  group: api.example.com
  names:
    kind: Backend
    plural: backends
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              port:
                type: integer
              config:
                type: object
                x-kubernetes-preserve-unknown-fields: true
  - name: v1beta1
    served: true
    storage: false
    deprecated: true
    deprecationWarning: "api.example.com/v1beta1 Backend is deprecated; use api.example.com/v1 Backend"
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              servicePort:
                type: integer
```

### Conversion Webhook

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: backends.api.example.com
spec:
  group: api.example.com
  names:
    kind: Backend
    plural: backends
  scope: Namespaced
  conversion:
    strategy: Webhook
    webhook:
      clientConfig:
        service:
          namespace: conversion-webhook
          name: backend-converter
          path: /convert
          port: 443
        caBundle: LS0tLS1CRUdJTi...
      conversionReviewVersions:
      - v1
      - v1beta1
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              port:
                type: integer
  - name: v1beta1
    served: true
    storage: false
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              image:
                type: string
              servicePort:
                type: integer
```

## Advanced Features

### Subresources

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: services.app.example.com
spec:
  group: app.example.com
  names:
    kind: Service
    plural: services
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
              image:
                type: string
          status:
            type: object
            properties:
              availableReplicas:
                type: integer
              readyReplicas:
                type: integer
              conditions:
                type: array
                items:
                  type: object
    subresources:
      # Status subresource
      status: {}
      # Scale subresource
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.readyReplicas
        labelSelectorPath: .status.labelSelector
```

### Printer Columns

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: clusters.infra.example.com
spec:
  group: infra.example.com
  names:
    kind: Cluster
    plural: clusters
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              provider:
                type: string
              region:
                type: string
              nodes:
                type: integer
          status:
            type: object
            properties:
              phase:
                type: string
              endpoint:
                type: string
    additionalPrinterColumns:
    - name: Provider
      type: string
      jsonPath: .spec.provider
      description: Cloud provider
    - name: Region
      type: string
      jsonPath: .spec.region
      priority: 1
    - name: Nodes
      type: integer
      jsonPath: .spec.nodes
    - name: Status
      type: string
      jsonPath: .status.phase
    - name: Endpoint
      type: string
      jsonPath: .status.endpoint
      priority: 1
    - name: Age
      type: date
      jsonPath: .metadata.creationTimestamp
```

### Validation Rules (CEL)

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: deployments.app.example.com
spec:
  group: app.example.com
  names:
    kind: Deployment
    plural: deployments
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              minReplicas:
                type: integer
              maxReplicas:
                type: integer
              port:
                type: integer
              image:
                type: string
            x-kubernetes-validations:
            - rule: "self.minReplicas <= self.maxReplicas"
              message: "minReplicas must be less than or equal to maxReplicas"
            - rule: "self.port >= 1024 && self.port <= 65535"
              message: "port must be between 1024 and 65535"
            - rule: "self.image.contains(':')"
              message: "image must include a tag"
```

## Custom Resource Examples

### Using Simple CR

```yaml
apiVersion: platform.example.com/v1
kind: Application
metadata:
  name: web-frontend
  namespace: production
spec:
  image: myregistry/frontend:v1.2.3
  replicas: 3
```

### Using Complex CR

```yaml
apiVersion: data.example.com/v1
kind: Database
metadata:
  name: production-db
  namespace: production
spec:
  engine: postgres
  version: "15.0"
  storage:
    size: 100Gi
    storageClass: fast-ssd
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: 30
  replicas: 3
```

## Controller Pattern

### Basic Controller Logic

```go
// Simplified controller pattern
type DatabaseReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

func (r *DatabaseReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // Fetch the Database instance
    var database datav1.Database
    if err := r.Get(ctx, req.NamespacedName, &database); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Handle deletion
    if !database.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, &database)
    }

    // Add finalizer
    if !controllerutil.ContainsFinalizer(&database, finalizerName) {
        controllerutil.AddFinalizer(&database, finalizerName)
        if err := r.Update(ctx, &database); err != nil {
            return ctrl.Result{}, err
        }
    }

    // Reconcile database
    if err := r.reconcileDatabase(ctx, &database); err != nil {
        database.Status.Phase = "Failed"
        r.Status().Update(ctx, &database)
        return ctrl.Result{}, err
    }

    // Update status
    database.Status.Phase = "Ready"
    if err := r.Status().Update(ctx, &database); err != nil {
        return ctrl.Result{}, err
    }

    return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}
```

## RBAC for CRDs

### ClusterRole for CRD

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: database-editor
rules:
- apiGroups:
  - data.example.com
  resources:
  - databases
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - data.example.com
  resources:
  - databases/status
  verbs:
  - get
  - patch
  - update
```

### Controller RBAC

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: database-controller
rules:
- apiGroups:
  - data.example.com
  resources:
  - databases
  verbs:
  - get
  - list
  - watch
  - update
  - patch
- apiGroups:
  - data.example.com
  resources:
  - databases/status
  verbs:
  - get
  - update
  - patch
- apiGroups:
  - ""
  resources:
  - secrets
  - services
  - persistentvolumeclaims
  verbs:
  - create
  - delete
  - get
  - list
  - watch
  - update
  - patch
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - create
  - delete
  - get
  - list
  - watch
  - update
  - patch
```

## Common Anti-Patterns

### ❌ No Validation

```yaml
# Bad - no validation
schema:
  openAPIV3Schema:
    type: object
    x-kubernetes-preserve-unknown-fields: true
```

```yaml
# Good - explicit validation
schema:
  openAPIV3Schema:
    type: object
    required:
    - spec
    properties:
      spec:
        type: object
        required:
        - image
        properties:
          image:
            type: string
            pattern: '^[a-z0-9.-]+/[a-z0-9.-]+:[a-z0-9.-]+$'
```

### ❌ Missing Status Subresource

```yaml
# Bad - no status subresource
versions:
- name: v1
  schema:
    openAPIV3Schema:
      properties:
        status:
          type: object
```

```yaml
# Good - status subresource enabled
versions:
- name: v1
  schema:
    openAPIV3Schema:
      properties:
        status:
          type: object
  subresources:
    status: {}
```

### ❌ Poor Naming

```yaml
# Bad - unclear names
kind: Thing
plural: things
shortNames:
- t
```

```yaml
# Good - descriptive names
kind: Database
plural: databases
singular: database
shortNames:
- db
```

### ❌ No Printer Columns

```yaml
# Bad - only shows NAME and AGE
versions:
- name: v1
  schema:
    openAPIV3Schema:
      type: object
```

```yaml
# Good - useful printer columns
versions:
- name: v1
  schema:
    openAPIV3Schema:
      type: object
  additionalPrinterColumns:
  - name: Status
    type: string
    jsonPath: .status.phase
  - name: Engine
    type: string
    jsonPath: .spec.engine
  - name: Age
    type: date
    jsonPath: .metadata.creationTimestamp
```

### ❌ No Finalizers

```yaml
# Bad - resources deleted immediately
# Controller can't cleanup external resources
```

```go
// Good - use finalizers
const finalizerName = "data.example.com/finalizer"

if !database.DeletionTimestamp.IsZero() {
    if controllerutil.ContainsFinalizer(&database, finalizerName) {
        // Cleanup external resources
        if err := r.cleanupExternalResources(ctx, &database); err != nil {
            return ctrl.Result{}, err
        }

        // Remove finalizer
        controllerutil.RemoveFinalizer(&database, finalizerName)
        if err := r.Update(ctx, &database); err != nil {
            return ctrl.Result{}, err
        }
    }
    return ctrl.Result{}, nil
}
```

### ❌ Mutable Storage Version

```yaml
# Bad - changing storage version without conversion
versions:
- name: v1
  storage: false  # Was true before
- name: v2
  storage: true  # New storage version
```

```yaml
# Good - use conversion webhook for migration
conversion:
  strategy: Webhook
  webhook:
    clientConfig:
      service:
        name: conversion-webhook
```

## Validation Commands

```bash
# Create CRD
kubectl apply -f crd.yaml

# List CRDs
kubectl get crds

# Describe CRD
kubectl describe crd databases.data.example.com

# Check versions
kubectl get crd databases.data.example.com -o jsonpath='{.spec.versions[*].name}'

# Create custom resource
kubectl apply -f database.yaml

# List custom resources
kubectl get databases
kubectl get databases -o wide

# Describe custom resource
kubectl describe database production-db

# Check status
kubectl get database production-db -o jsonpath='{.status.phase}'

# Delete CRD (deletes all instances)
kubectl delete crd databases.data.example.com

# Validate CRD schema
kubectl apply --dry-run=server -f crd.yaml

# Test validation
kubectl apply --dry-run=server -f database.yaml
```

## Additional Resources

- [Kubernetes CRD Documentation](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- [Kubebuilder](https://book.kubebuilder.io/)
- [Operator SDK](https://sdk.operatorframework.io/)
- [Controller Runtime](https://github.com/kubernetes-sigs/controller-runtime)
- [API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
- [CEL in Kubernetes](https://kubernetes.io/docs/reference/using-api/cel/)
