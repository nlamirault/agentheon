# Kubernetes / Kubernetes Resource Orchestrator (KRO)

This reference provides comprehensive guidance for using Kubernetes Resource Orchestrator (KRO) to create higher-level
abstractions and composite resources, simplifying complex multi-resource deployments.

## Overview

Kubernetes Resource Orchestrator (KRO) enables creation of custom, higher-level resources that orchestrate multiple
Kubernetes resources. It simplifies complex deployments by allowing platform teams to define reusable abstractions that
encapsulate best practices and organizational standards.

## Installation

### Install KRO

```bash
# Install using kubectl
kubectl apply -f https://github.com/kubernetes-sigs/kro/releases/latest/download/install.yaml

# Verify installation
kubectl get pods -n kro-system
kubectl wait --for=condition=Available --timeout=300s -n kro-system deployment/kro-controller-manager

# Check CRDs
kubectl get crds | grep kro.run
```

### Helm Installation

```bash
# Add KRO Helm repository
helm repo add kro https://kubernetes-sigs.github.io/kro
helm repo update

# Install KRO
helm install kro kro/kro \
  --namespace kro-system \
  --create-namespace

# Verify
kubectl get pods -n kro-system
```

## ResourceGroup Basics

### Simple ResourceGroup

```yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: simple-application
spec:
  schema:
    apiVersion: v1alpha1
    kind: Application
    spec:
      properties:
        name:
          type: string
        image:
          type: string
        replicas:
          type: integer
          default: 3
  resources:
  - apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${schema.spec.name}
    spec:
      replicas: ${schema.spec.replicas}
      selector:
        matchLabels:
          app: ${schema.spec.name}
      template:
        metadata:
          labels:
            app: ${schema.spec.name}
        spec:
          containers:
          - name: app
            image: ${schema.spec.image}
            ports:
            - containerPort: 8080
  - apiVersion: v1
    kind: Service
    metadata:
      name: ${schema.spec.name}
    spec:
      selector:
        app: ${schema.spec.name}
      ports:
      - port: 80
        targetPort: 8080
```

### Using the ResourceGroup

```yaml
apiVersion: v1alpha1
kind: Application
metadata:
  name: frontend
  namespace: production
spec:
  name: frontend
  image: myregistry/frontend:v1.2.3
  replicas: 5
```

## Advanced ResourceGroups

### Web Application with Database

```yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: web-app-with-db
spec:
  schema:
    apiVersion: v1alpha1
    kind: WebApplication
    spec:
      properties:
        name:
          type: string
        image:
          type: string
        replicas:
          type: integer
          default: 3
        database:
          type: object
          properties:
            engine:
              type: string
              enum: [postgres, mysql]
            storage:
              type: string
              default: 10Gi
        ingress:
          type: object
          properties:
            enabled:
              type: boolean
              default: true
            host:
              type: string
  resources:
  # Application Deployment
  - apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${schema.spec.name}
      labels:
        app: ${schema.spec.name}
        component: web
    spec:
      replicas: ${schema.spec.replicas}
      selector:
        matchLabels:
          app: ${schema.spec.name}
      template:
        metadata:
          labels:
            app: ${schema.spec.name}
        spec:
          containers:
          - name: app
            image: ${schema.spec.image}
            ports:
            - containerPort: 8080
            env:
            - name: DB_HOST
              value: ${schema.spec.name}-db
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${schema.spec.name}-db-secret
                  key: password

  # Application Service
  - apiVersion: v1
    kind: Service
    metadata:
      name: ${schema.spec.name}
    spec:
      selector:
        app: ${schema.spec.name}
      ports:
      - port: 80
        targetPort: 8080

  # Database StatefulSet
  - apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: ${schema.spec.name}-db
      labels:
        app: ${schema.spec.name}
        component: database
    spec:
      serviceName: ${schema.spec.name}-db
      replicas: 1
      selector:
        matchLabels:
          app: ${schema.spec.name}-db
      template:
        metadata:
          labels:
            app: ${schema.spec.name}-db
        spec:
          containers:
          - name: database
            image: ${schema.spec.database.engine}:latest
            ports:
            - containerPort: 5432
            volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
            env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ${schema.spec.name}-db-secret
                  key: password
      volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          accessModes: [ "ReadWriteOnce" ]
          resources:
            requests:
              storage: ${schema.spec.database.storage}

  # Database Service
  - apiVersion: v1
    kind: Service
    metadata:
      name: ${schema.spec.name}-db
    spec:
      clusterIP: None
      selector:
        app: ${schema.spec.name}-db
      ports:
      - port: 5432

  # Database Secret
  - apiVersion: v1
    kind: Secret
    metadata:
      name: ${schema.spec.name}-db-secret
    type: Opaque
    stringData:
      password: ${generatePassword()}

  # Ingress (conditional)
  - apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ${schema.spec.name}
    spec:
      rules:
      - host: ${schema.spec.ingress.host}
        http:
          paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${schema.spec.name}
                port:
                  number: 80
    when: ${schema.spec.ingress.enabled}
```

### Using Advanced ResourceGroup

```yaml
apiVersion: v1alpha1
kind: WebApplication
metadata:
  name: user-service
  namespace: production
spec:
  name: user-service
  image: myregistry/user-service:v2.0.0
  replicas: 5
  database:
    engine: postgres
    storage: 50Gi
  ingress:
    enabled: true
    host: users.example.com
```

## Microservices Platform

### Platform ResourceGroup

```yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: microservice-platform
spec:
  schema:
    apiVersion: v1alpha1
    kind: Microservice
    spec:
      properties:
        name:
          type: string
        image:
          type: string
        port:
          type: integer
          default: 8080
        replicas:
          type: object
          properties:
            min:
              type: integer
              default: 2
            max:
              type: integer
              default: 10
        resources:
          type: object
          properties:
            cpu:
              type: string
              default: 100m
            memory:
              type: string
              default: 128Mi
        monitoring:
          type: object
          properties:
            enabled:
              type: boolean
              default: true
            path:
              type: string
              default: /metrics
        serviceAccount:
          type: string
        configMap:
          type: object
          properties:
            data:
              type: object
  resources:
  # Deployment
  - apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${schema.spec.name}
      labels:
        app: ${schema.spec.name}
        managed-by: kro
    spec:
      replicas: ${schema.spec.replicas.min}
      selector:
        matchLabels:
          app: ${schema.spec.name}
      template:
        metadata:
          labels:
            app: ${schema.spec.name}
          annotations:
            prometheus.io/scrape: "${schema.spec.monitoring.enabled}"
            prometheus.io/port: "${schema.spec.port}"
            prometheus.io/path: ${schema.spec.monitoring.path}
        spec:
          serviceAccountName: ${schema.spec.serviceAccount}
          containers:
          - name: app
            image: ${schema.spec.image}
            ports:
            - containerPort: ${schema.spec.port}
              name: http
            resources:
              requests:
                cpu: ${schema.spec.resources.cpu}
                memory: ${schema.spec.resources.memory}
              limits:
                cpu: ${multiply(schema.spec.resources.cpu, 2)}
                memory: ${multiply(schema.spec.resources.memory, 2)}
            envFrom:
            - configMapRef:
                name: ${schema.spec.name}-config
            livenessProbe:
              httpGet:
                path: /health
                port: http
              initialDelaySeconds: 30
              periodSeconds: 10
            readinessProbe:
              httpGet:
                path: /ready
                port: http
              initialDelaySeconds: 5
              periodSeconds: 5

  # Service
  - apiVersion: v1
    kind: Service
    metadata:
      name: ${schema.spec.name}
      labels:
        app: ${schema.spec.name}
    spec:
      selector:
        app: ${schema.spec.name}
      ports:
      - port: 80
        targetPort: ${schema.spec.port}
        name: http

  # ConfigMap
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ${schema.spec.name}-config
    data: ${schema.spec.configMap.data}

  # ServiceAccount
  - apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: ${schema.spec.serviceAccount}

  # HorizontalPodAutoscaler
  - apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    metadata:
      name: ${schema.spec.name}
    spec:
      scaleTargetRef:
        apiVersion: apps/v1
        kind: Deployment
        name: ${schema.spec.name}
      minReplicas: ${schema.spec.replicas.min}
      maxReplicas: ${schema.spec.replicas.max}
      metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 70
      - type: Resource
        resource:
          name: memory
          target:
            type: Utilization
            averageUtilization: 80

  # PodDisruptionBudget
  - apiVersion: policy/v1
    kind: PodDisruptionBudget
    metadata:
      name: ${schema.spec.name}
    spec:
      minAvailable: 1
      selector:
        matchLabels:
          app: ${schema.spec.name}
```

### Using Microservice Platform

```yaml
apiVersion: v1alpha1
kind: Microservice
metadata:
  name: payment-service
  namespace: production
spec:
  name: payment-service
  image: myregistry/payment-service:v1.5.0
  port: 8080
  replicas:
    min: 3
    max: 15
  resources:
    cpu: 200m
    memory: 256Mi
  monitoring:
    enabled: true
    path: /metrics
  serviceAccount: payment-service-sa
  configMap:
    data:
      ENVIRONMENT: production
      LOG_LEVEL: info
      PAYMENT_GATEWAY_URL: https://gateway.example.com
```

## Cloud-Native Application

### Complete Application Stack

```yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: cloud-native-app
spec:
  schema:
    apiVersion: v1alpha1
    kind: CloudNativeApp
    spec:
      properties:
        name:
          type: string
        components:
          type: array
          items:
            type: object
            properties:
              name:
                type: string
              image:
                type: string
              replicas:
                type: integer
              port:
                type: integer
        database:
          type: object
          properties:
            enabled:
              type: boolean
            type:
              type: string
        cache:
          type: object
          properties:
            enabled:
              type: boolean
        messageBroker:
          type: object
          properties:
            enabled:
              type: boolean
        observability:
          type: object
          properties:
            tracing:
              type: boolean
            metrics:
              type: boolean
  resources:
  # Generate deployment for each component
  - apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${schema.spec.name}-${component.name}
    spec:
      replicas: ${component.replicas}
      selector:
        matchLabels:
          app: ${schema.spec.name}
          component: ${component.name}
      template:
        metadata:
          labels:
            app: ${schema.spec.name}
            component: ${component.name}
        spec:
          containers:
          - name: ${component.name}
            image: ${component.image}
            ports:
            - containerPort: ${component.port}
    forEach: ${schema.spec.components}

  # Redis Cache (conditional)
  - apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ${schema.spec.name}-cache
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: ${schema.spec.name}
          component: cache
      template:
        metadata:
          labels:
            app: ${schema.spec.name}
            component: cache
        spec:
          containers:
          - name: redis
            image: redis:7-alpine
            ports:
            - containerPort: 6379
    when: ${schema.spec.cache.enabled}
```

## Conditional Resources

### Environment-Specific Configuration

```yaml
apiVersion: kro.run/v1alpha1
kind: ResourceGroup
metadata:
  name: environment-aware-app
spec:
  schema:
    apiVersion: v1alpha1
    kind: EnvironmentApp
    spec:
      properties:
        name:
          type: string
        environment:
          type: string
          enum: [development, staging, production]
        image:
          type: string
  resources:
  # Development resources
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ${schema.spec.name}-config
    data:
      DEBUG: "true"
      LOG_LEVEL: debug
    when: ${schema.spec.environment == "development"}

  # Production resources
  - apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ${schema.spec.name}-config
    data:
      DEBUG: "false"
      LOG_LEVEL: info
    when: ${schema.spec.environment == "production"}

  # Production-only PodDisruptionBudget
  - apiVersion: policy/v1
    kind: PodDisruptionBudget
    metadata:
      name: ${schema.spec.name}
    spec:
      minAvailable: 2
      selector:
        matchLabels:
          app: ${schema.spec.name}
    when: ${schema.spec.environment == "production"}
```

## Common Anti-Patterns

### ❌ Overly Complex Abstractions

```yaml
# Bad - too many nested properties
spec:
  schema:
    spec:
      properties:
        deployment:
          properties:
            container:
              properties:
                resources:
                  properties:
                    limits:
                      properties:
                        cpu:
                          type: string
```

```yaml
# Good - simplified, sensible defaults
spec:
  schema:
    spec:
      properties:
        resources:
          type: string
          enum: [small, medium, large]
          default: medium
```

### ❌ Hardcoded Values

```yaml
# Bad - hardcoded namespace
resources:
- apiVersion: v1
  kind: Service
  metadata:
    name: ${schema.spec.name}
    namespace: production
```

```yaml
# Good - use instance namespace
resources:
- apiVersion: v1
  kind: Service
  metadata:
    name: ${schema.spec.name}
    namespace: ${instance.namespace}
```

### ❌ No Validation

```yaml
# Bad - no property validation
spec:
  schema:
    spec:
      properties:
        replicas:
          type: integer
```

```yaml
# Good - validation rules
spec:
  schema:
    spec:
      properties:
        replicas:
          type: integer
          minimum: 1
          maximum: 100
          default: 3
```

### ❌ Missing Status Feedback

```yaml
# Bad - no status reporting
spec:
  schema:
    spec:
      properties:
        name:
          type: string
```

```yaml
# Good - include status
spec:
  schema:
    spec:
      properties:
        name:
          type: string
    status:
      properties:
        phase:
          type: string
        conditions:
          type: array
        resourcesCreated:
          type: integer
```

### ❌ Ignoring Dependencies

```yaml
# Bad - no resource ordering
resources:
- apiVersion: apps/v1
  kind: Deployment
  # Uses secret that might not exist
- apiVersion: v1
  kind: Secret
```

```yaml
# Good - explicit dependencies
resources:
- apiVersion: v1
  kind: Secret
  metadata:
    name: ${schema.spec.name}-secret
- apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: ${schema.spec.name}
  dependsOn:
  - Secret/${schema.spec.name}-secret
```

## Validation Commands

```bash
# Check KRO installation
kubectl get pods -n kro-system
kubectl get crds | grep kro.run

# List ResourceGroups
kubectl get resourcegroups

# Describe ResourceGroup
kubectl describe resourcegroup simple-application

# List custom resources created by ResourceGroup
kubectl get applications

# Check generated resources
kubectl get all -l managed-by=kro

# View ResourceGroup status
kubectl get resourcegroup simple-application -o jsonpath='{.status}'

# Validate ResourceGroup
kubectl apply --dry-run=server -f resourcegroup.yaml

# Test custom resource creation
kubectl apply --dry-run=server -f application.yaml

# Debug ResourceGroup controller
kubectl logs -n kro-system -l app=kro-controller -f

# Delete custom resource (cascades to managed resources)
kubectl delete application frontend
```

## Additional Resources

- [KRO GitHub Repository](https://github.com/kubernetes-sigs/kro)
- [KRO Documentation](https://kubernetes-sigs.github.io/kro/)
- [Kubernetes API Conventions](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md)
- [Composition Patterns](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Operator Pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
