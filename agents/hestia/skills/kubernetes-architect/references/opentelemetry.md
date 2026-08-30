# Kubernetes / OpenTelemetry Observability

This reference provides comprehensive OpenTelemetry guidance for Kubernetes, covering automatic instrumentation,
resource attributes configuration, collector deployment, and observability best practices.

## Overview

OpenTelemetry (OTel) is a vendor-neutral observability framework that provides APIs, SDKs, and tools for collecting
distributed traces, metrics, and logs. The OpenTelemetry Operator for Kubernetes automates instrumentation of
applications running in Kubernetes clusters.

## Core Components

**OpenTelemetry Operator** - Manages OpenTelemetry Collector and auto-instrumentation
**OpenTelemetry Collector** - Receives, processes, and exports telemetry data
**Instrumentation** - Automatically injects language-specific instrumentation
**Resource Attributes** - Contextual information about telemetry data source

## Installation

### OpenTelemetry Operator

```bash
# Install using kubectl
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Or using Helm
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace opentelemetry-operator-system \
  --create-namespace

# Verify installation
kubectl get pods -n opentelemetry-operator-system
```

### Certificate Manager (Required)

The OpenTelemetry Operator requires cert-manager for webhook certificates:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
```

## Resource Attributes with Annotations

Configure resource attributes for OpenTelemetry telemetry data using pod/namespace annotations. These attributes provide
context about where telemetry data originates.

Reference:
<https://github.com/open-telemetry/opentelemetry-operator?tab=readme-ov-file#configure-resource-attributes-with-annotations>

### Pod Annotations

Add resource attributes to individual pods:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: payment-service
  namespace: production
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
    resource.opentelemetry.io/service.name: payment-service
    resource.opentelemetry.io/service.version: "2.1.0"
    resource.opentelemetry.io/environment: "production"
spec:
  containers:
    - name: app
      image: myapp:1.0.0
```

### Deployment with Resource Attributes

Production-ready deployment with OpenTelemetry annotations:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: production
  labels:
    app.kubernetes.io/name: payment-service
    app.kubernetes.io/version: "2.1.0"
    app.kubernetes.io/component: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: payment-service
  template:
    metadata:
      labels:
        app.kubernetes.io/name: payment-service
        app.kubernetes.io/version: "2.1.0"
      annotations:
        # Enable auto-instrumentation for Java
        instrumentation.opentelemetry.io/inject-java: "true"
        # Setup resource attributes
        resource.opentelemetry.io/service.name: payment-service
        resource.opentelemetry.io/service.version: "2.1.0"
        resource.opentelemetry.io/environment: "production"
    spec:
      containers:
        - name: payment-service
          image: payment-service:2.1.0
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: OTEL_SERVICE_NAME
              value: payment-service
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: deployment.environment=production,service.version=2.1.0
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
```

### Resource Attribute Best Practices

**Standard Attributes:**

- `service.name` - Service identifier (automatically set from pod name)
- `service.version` - Application version
- `service.namespace` - Kubernetes namespace
- `deployment.environment` - Environment (dev/staging/prod)
- `k8s.cluster.name` - Cluster identifier
- `k8s.namespace.name` - Kubernetes namespace
- `k8s.pod.name` - Pod name
- `k8s.container.name` - Container name

**Custom Attributes:**

- Use annotation prefix: `resource.opentelemetry.io/`
- Keep attribute names consistent across services
- Use kebab-case for attribute names
- Add business context: team, cost-center, service-tier
- Include operational metadata: region, availability-zone

## Automatic Instrumentation

Configure automatic instrumentation for applications without code changes. The OpenTelemetry Operator injects
language-specific instrumentation automatically.

Reference: <https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/#configure-automatic-instrumentation>

### Instrumentation Resource

Create an `Instrumentation` resource to define auto-instrumentation configuration:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: default-instrumentation
  namespace: opentelemetry-operator-system
spec:
  # Exporter configuration - where to send telemetry
  exporter:
    endpoint: http://otel-collector.observability.svc.cluster.local:4318

  # Propagators define how context is propagated across service boundaries
  propagators:
    - tracecontext
    - baggage
    - b3

  # Sampler configuration - control sampling rate
  sampler:
    type: parentbased_traceidratio
    argument: "1.0" # Sample 100% of traces (reduce in production)

  # Java instrumentation configuration
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
    env:
      - name: OTEL_JAVAAGENT_DEBUG
        value: "false"
      - name: OTEL_INSTRUMENTATION_JDBC_ENABLED
        value: "true"
      - name: OTEL_INSTRUMENTATION_KAFKA_ENABLED
        value: "true"
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi

  # Python instrumentation configuration
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
    env:
      - name: OTEL_EXPORTER_OTLP_TIMEOUT
        value: "20"
      - name: OTEL_EXPORTER_OTLP_TRACES_PROTOCOL
        value: "http/protobuf"
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi

  # Node.js instrumentation configuration
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
    env:
      - name: OTEL_NODEJS_DEBUG
        value: "false"
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi

  # .NET instrumentation configuration
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:latest
    env:
      - name: OTEL_DOTNET_AUTO_TRACES_CONSOLE_EXPORTER_ENABLED
        value: "false"
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi

  # Go instrumentation configuration (requires manual SDK integration)
  go:
    image: ghcr.io/open-telemetry/opentelemetry-go-instrumentation/autoinstrumentation-go:latest
    env:
      - name: OTEL_GO_AUTO_TARGET_EXE
        value: "/app/main"
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 100m
        memory: 128Mi
```

### Enabling Auto-Instrumentation per Pod

Enable auto-instrumentation for specific pods using annotations:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
      annotations:
        # Enable Java auto-instrumentation
        instrumentation.opentelemetry.io/inject-java: "true"

        # Optional: Use specific Instrumentation resource
        instrumentation.opentelemetry.io/inject-java: "opentelemetry-operator-system/default-instrumentation"

        # Optional: Override container name for multi-container pods
        instrumentation.opentelemetry.io/container-names: "user-service,sidecar"

        # Resource attributes
        resource.opentelemetry.io/team: "identity"
        resource.opentelemetry.io/service-tier: "tier-1"
    spec:
      containers:
      - name: user-service
        image: user-service:1.5.0
        ports:
        - containerPort: 8080
```

### Language-Specific Annotations

**Java:**

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-java: "true"
```

**Python:**

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-python: "true"
```

**Node.js:**

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-nodejs: "true"
```

**.NET:**

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-dotnet: "true"
```

**Go:**

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-go: "true"
```

### Namespace-Wide Auto-Instrumentation

Enable auto-instrumentation for all pods in a namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  annotations:
    # All Java pods in this namespace get auto-instrumented
    instrumentation.opentelemetry.io/inject-java: "true"

    # Use specific Instrumentation resource
    instrumentation.opentelemetry.io/inject-java: "opentelemetry-operator-system/production-instrumentation"
```

### Multi-Container Pod Instrumentation

Specify which containers to instrument in multi-container pods:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container-app
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
    # Only instrument specific containers
    instrumentation.opentelemetry.io/container-names: "api-server,worker"
spec:
  containers:
    - name: api-server
      image: api-server:1.0.0
    - name: worker
      image: worker:1.0.0
    - name: nginx # This container won't be instrumented
      image: nginx:1.25
```

## OpenTelemetry Collector

Deploy the OpenTelemetry Collector to receive, process, and export telemetry data:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: observability
spec:
  mode: deployment # or: daemonset, statefulset, sidecar
  replicas: 3

  # Collector configuration
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      # Kubernetes metrics
      k8s_cluster:
        auth_type: serviceAccount
        node_conditions_to_report:
          [Ready, MemoryPressure, DiskPressure, PIDPressure]
        allocatable_types_to_report: [cpu, memory, storage, ephemeral-storage]

    processors:
      # Add resource attributes from Kubernetes metadata
      k8sattributes:
        auth_type: serviceAccount
        passthrough: false
        extract:
          metadata:
            - k8s.namespace.name
            - k8s.deployment.name
            - k8s.statefulset.name
            - k8s.daemonset.name
            - k8s.cronjob.name
            - k8s.job.name
            - k8s.node.name
            - k8s.pod.name
            - k8s.pod.uid
            - k8s.pod.start_time
          labels:
            - tag_name: app.kubernetes.io/name
              key: app.kubernetes.io/name
              from: pod
            - tag_name: app.kubernetes.io/version
              key: app.kubernetes.io/version
              from: pod
          annotations:
            - tag_name: service.tier
              key: resource.opentelemetry.io/service-tier
              from: pod
            - tag_name: team
              key: resource.opentelemetry.io/team
              from: pod

      # Memory limiter prevents OOM
      memory_limiter:
        check_interval: 1s
        limit_mib: 1024
        spike_limit_mib: 256

      # Batch processor reduces export overhead
      batch:
        send_batch_size: 1024
        timeout: 10s
        send_batch_max_size: 2048

      # Resource detection adds cloud provider metadata
      resourcedetection:
        detectors: [env, system, docker, gcp, eks, aks]
        timeout: 5s

    exporters:
      # Export to Prometheus for metrics
      prometheus:
        endpoint: 0.0.0.0:9090

      # Export to OTLP endpoint (Grafana, Jaeger, etc.)
      otlp:
        endpoint: tempo.observability.svc.cluster.local:4317
        tls:
          insecure: false

      # Export to logging for debugging
      logging:
        loglevel: info

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, resourcedetection, batch]
          exporters: [otlp, logging]

        metrics:
          receivers: [otlp, k8s_cluster]
          processors: [memory_limiter, k8sattributes, resourcedetection, batch]
          exporters: [prometheus, otlp]

        logs:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, batch]
          exporters: [otlp, logging]

  # Resource requirements
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 2Gi

  # Service configuration
  service:
    type: ClusterIP

  # Pod configuration
  podAnnotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "9090"
```

## Production Deployment Patterns

### Gateway + Sidecar Architecture

Deploy collectors as both gateway and sidecar for optimal performance:

**Gateway Collector** - Centralized processing and export

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-gateway
  namespace: observability
spec:
  mode: deployment
  replicas: 3
  # ... gateway configuration
```

**Sidecar Collector** - Co-located with applications for low latency

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-sidecar
  namespace: production
spec:
  mode: sidecar
  # Inject as sidecar into matching pods
  podAnnotations:
    sidecar.opentelemetry.io/inject: "true"
```

### DaemonSet for Node Metrics

Deploy collector as DaemonSet for node-level metrics collection:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-agent
  namespace: observability
spec:
  mode: daemonset
  hostNetwork: true
  config:
    receivers:
      hostmetrics:
        collection_interval: 30s
        scrapers:
          cpu: {}
          disk: {}
          filesystem: {}
          load: {}
          memory: {}
          network: {}
```

## RBAC Configuration

Grant necessary permissions for the collector to access Kubernetes API:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-collector
  namespace: observability
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-collector
rules:
  - apiGroups: [""]
    resources:
      - events
      - namespaces
      - namespaces/status
      - nodes
      - nodes/spec
      - pods
      - pods/status
      - replicationcontrollers
      - replicationcontrollers/status
      - resourcequotas
      - services
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources:
      - daemonsets
      - deployments
      - replicasets
      - statefulsets
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources:
      - jobs
      - cronjobs
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otel-collector
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: otel-collector
subjects:
  - kind: ServiceAccount
    name: otel-collector
    namespace: observability
```

## Best Practices

### Resource Attributes

**DO:**

- ✅ Use namespace-level annotations for shared attributes
- ✅ Use pod-level annotations for service-specific attributes
- ✅ Follow OpenTelemetry semantic conventions
- ✅ Add business context (team, cost-center, tier)
- ✅ Keep attribute names consistent across services
- ✅ Use kebab-case for custom attribute names

**DON'T:**

- ❌ Hardcode resource attributes in application code
- ❌ Use inconsistent attribute naming across services
- ❌ Add high-cardinality attributes (user IDs, request IDs)
- ❌ Duplicate information already captured by Kubernetes metadata

### Auto-Instrumentation

**DO:**

- ✅ Use namespace-level annotations for consistent instrumentation
- ✅ Pin instrumentation image versions in production
- ✅ Set resource limits for instrumentation containers
- ✅ Configure appropriate sampling rates for production
- ✅ Test instrumentation in dev/staging before production
- ✅ Monitor instrumentation overhead (CPU, memory)

**DON'T:**

- ❌ Use `latest` tag for instrumentation images
- ❌ Enable debug mode in production
- ❌ Sample 100% of traces in high-traffic production
- ❌ Instrument every pod (focus on business-critical services)
- ❌ Ignore instrumentation resource consumption

### Collector Deployment

**DO:**

- ✅ Deploy collectors with high availability (3+ replicas)
- ✅ Use memory limiter to prevent OOM
- ✅ Enable batch processor for efficiency
- ✅ Set appropriate resource requests/limits
- ✅ Monitor collector health and performance
- ✅ Use persistent storage for StatefulSet deployments

**DON'T:**

- ❌ Run single-replica collector in production
- ❌ Deploy without memory limits
- ❌ Skip batch processing (increases export overhead)
- ❌ Ignore collector metrics and logs
- ❌ Use insecure export endpoints

## Example: Complete Microservices Setup

### 1. Install OpenTelemetry Operator

```bash
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
```

### 2. Create Instrumentation Configuration

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: production
  namespace: opentelemetry-operator-system
spec:
  exporter:
    endpoint: http://otel-collector.observability.svc.cluster.local:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "0.1" # 10% sampling
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.11.0
```

### 3. Deploy OpenTelemetry Collector

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: observability
spec:
  mode: deployment
  replicas: 3
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
          http:
    processors:
      k8sattributes:
      batch:
      memory_limiter:
        limit_mib: 1024
    exporters:
      otlp:
        endpoint: tempo.observability.svc.cluster.local:4317
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, k8sattributes, batch]
          exporters: [otlp]
```

### 4. Configure Namespace with Resource Attributes

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  annotations:
    instrumentation.opentelemetry.io/inject-java: "opentelemetry-operator-system/production"
    resource.opentelemetry.io/environment: "production"
    resource.opentelemetry.io/cluster: "prod-us-west-2"
```

### 5. Deploy Instrumented Application

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
      annotations:
        # Auto-instrumentation enabled via namespace annotation
        resource.opentelemetry.io/team: "backend"
        resource.opentelemetry.io/service-tier: "tier-1"
    spec:
      containers:
        - name: api-service
          image: api-service:1.0.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

## Troubleshooting

### Auto-Instrumentation Not Working

```bash
# Check operator logs
kubectl logs -n opentelemetry-operator-system -l app.kubernetes.io/name=opentelemetry-operator

# Verify Instrumentation resource
kubectl get instrumentation -A

# Check pod annotations
kubectl get pod <pod-name> -o jsonpath='{.metadata.annotations}'

# Verify injected init container
kubectl describe pod <pod-name> | grep -A 10 "Init Containers"
```

### Collector Issues

```bash
# Check collector status
kubectl get otelcol -A

# View collector logs
kubectl logs -n observability -l app.kubernetes.io/name=otel-collector

# Verify collector configuration
kubectl get otelcol otel-collector -n observability -o yaml

# Test collector endpoint
kubectl run test-pod --rm -it --image=curlimages/curl -- \
  curl -v http://otel-collector.observability.svc.cluster.local:4318/v1/traces
```

### Missing Resource Attributes

```bash
# Verify annotations are applied
kubectl get pod <pod-name> -o yaml | grep -A 10 "annotations"

# Check k8sattributes processor logs
kubectl logs -n observability -l app.kubernetes.io/name=otel-collector | grep k8sattributes

# Verify RBAC permissions
kubectl auth can-i get pods --as=system:serviceaccount:observability:otel-collector
```

## Anti-Patterns

**DON'T:**

- ❌ Sample 100% of production traces (causes performance issues)
- ❌ Use `latest` tag for instrumentation images
- ❌ Deploy single-replica collectors in production
- ❌ Add PII or sensitive data to resource attributes
- ❌ Instrument every pod (focus on critical services)
- ❌ Ignore collector resource consumption
- ❌ Mix manual and auto-instrumentation approaches
- ❌ Skip testing instrumentation overhead
- ❌ Deploy without memory limiters
- ❌ Use insecure export endpoints

## Additional Resources

### Official Documentation

- [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator)
- [OpenTelemetry Kubernetes](https://opentelemetry.io/docs/platforms/kubernetes/)
- [Automatic Instrumentation](https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/)
- [Resource Attributes](https://github.com/open-telemetry/opentelemetry-operator/tree/v0.116.0?tab=readme-ov-file#configure-resourceibutes-with-annotations)

### Semantic Conventions

- [Resource Conventions](https://opentelemetry.io/docs/specs/semconv/resource/)
- [Kubernetes Conventions](https://opentelemetry.io/docs/specs/semconv/resource/k8s/)
- [Cloud Provider Conventions](https://opentelemetry.io/docs/specs/semconv/resource/cloud/)

### Tools

- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [Jaeger](https://www.jaegertracing.io/) - Distributed tracing backend
- [Tempo](https://grafana.com/oss/tempo/) - Grafana tracing backend
- [Prometheus](https://prometheus.io/) - Metrics collection and alerting
