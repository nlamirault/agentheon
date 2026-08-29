# OpenTelemetry Operator

The OpenTelemetry Operator is a Kubernetes Operator that manages the lifecycle of the OpenTelemetry Collector and
auto-instrumentation of workloads. It introduces two custom resources: `OpenTelemetryCollector` and `Instrumentation`.

## Prerequisites

The Operator uses cert-manager for TLS certificate management for its admission webhooks.

### Install cert-manager

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
kubectl wait --for=condition=Available deployment --all -n cert-manager --timeout=120s
```

### Install the OpenTelemetry Operator via Helm

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace opentelemetry-operator-system \
  --create-namespace \
  --set manager.collectorImage.repository=otel/opentelemetry-collector-contrib \
  --wait
```

Verify the operator is running:

```bash
kubectl get pods -n opentelemetry-operator-system
kubectl get crd | grep opentelemetry
```

---

## OpenTelemetryCollector CRD

The `OpenTelemetryCollector` CRD configures and deploys the Collector. The key field is `spec.mode`, which controls the
deployment strategy.

| Mode | Kubernetes workload | Typical use case |
|------|---------------------|------------------|
| `daemonset` | DaemonSet | Node-level log and metric collection, agent-side batching |
| `deployment` | Deployment | Gateway aggregation, tail sampling |
| `statefulset` | StatefulSet | Tail sampling (requires sticky routing) |
| `sidecar` | Sidecar container | Per-pod isolation |

### Agent Mode (DaemonSet)

An agent Collector runs on every node, collecting logs, host metrics, and receiving OTLP telemetry from local workloads
before forwarding to a gateway.

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-agent
  namespace: observability
spec:
  mode: daemonset

  # Resource requests and limits
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Mount host paths for log collection
  volumeMounts:
    - name: varlog
      mountPath: /var/log
      readOnly: true
    - name: varlibdockercontainers
      mountPath: /var/lib/docker/containers
      readOnly: true

  volumes:
    - name: varlog
      hostPath:
        path: /var/log
    - name: varlibdockercontainers
      hostPath:
        path: /var/lib/docker/containers

  # Service account with k8sattributes RBAC permissions
  serviceAccount: otel-agent

  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      filelog:
        include:
          - /var/log/pods/*/*/*.log
        start_at: beginning
        include_file_path: true
        include_file_name: false
        operators:
          - type: router
            id: get-format
            routes:
              - output: parser-docker
                expr: 'body matches "^\\{"'
              - output: parser-crio
                expr: 'body matches "^[^ Z]+ "'
          - type: json_parser
            id: parser-docker
            output: extract-metadata-from-filepath
          - type: regex_parser
            id: parser-crio
            regex: '^(?P<time>[^ Z]+) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) ?(?P<log>.*)$'
            output: extract-metadata-from-filepath
          - type: regex_parser
            id: extract-metadata-from-filepath
            regex: '^.*\/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<uid>[a-f0-9\-]+)\/(?P<container_name>[^\._]+)\/(?P<restart_count>\d+)\.log$'
            parse_from: attributes["log.file.path"]

      hostmetrics:
        collection_interval: 30s
        scrapers:
          cpu:
          memory:
          disk:
          network:
          filesystem:

    processors:
      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 20

      resourcedetection:
        detectors: [env, k8snode]
        timeout: 5s
        override: false

      k8sattributes:
        auth_type: serviceAccount
        passthrough: false
        extract:
          metadata:
            - k8s.namespace.name
            - k8s.pod.name
            - k8s.pod.uid
            - k8s.pod.start_time
            - k8s.deployment.name
            - k8s.replicaset.name
            - k8s.daemonset.name
            - k8s.statefulset.name
            - k8s.container.name
            - k8s.node.name
        pod_association:
          - sources:
              - from: resource_attribute
                name: k8s.pod.ip
          - sources:
              - from: resource_attribute
                name: k8s.pod.uid
          - sources:
              - from: connection

      batch:
        send_batch_size: 512
        timeout: 10s

    exporters:
      otlp:
        endpoint: otel-gateway:4317
        tls:
          insecure: false

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, resourcedetection, k8sattributes, batch]
          exporters: [otlp]
        metrics:
          receivers: [otlp, hostmetrics]
          processors: [memory_limiter, resourcedetection, k8sattributes, batch]
          exporters: [otlp]
        logs:
          receivers: [otlp, filelog]
          processors: [memory_limiter, resourcedetection, k8sattributes, batch]
          exporters: [otlp]
```

### Gateway Mode (Deployment)

A gateway Collector receives telemetry from agents, applies centralised processing (tail sampling, enrichment), and
forwards to the backend.

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-gateway
  namespace: observability
spec:
  mode: deployment

  replicas: 2

  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

  autoscaler:
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilization: 70

  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

    processors:
      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 20

      batch:
        send_batch_size: 1024
        timeout: 10s
        send_batch_max_size: 2048

    exporters:
      otlp:
        endpoint: https://otlp-backend.example.com:4317
        headers:
          authorization: "${env:OTLP_BACKEND_TOKEN}"
        retry_on_failure:
          enabled: true
          initial_interval: 5s
          max_interval: 30s
          max_elapsed_time: 300s
        sending_queue:
          enabled: true
          num_consumers: 10
          queue_size: 5000

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
```

---

## Instrumentation CRD

The `Instrumentation` CRD injects the OpenTelemetry SDK and auto-instrumentation libraries into application pods via a
mutating admission webhook. No application code changes are required.

### Complete Instrumentation Example

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: otel-instrumentation
  namespace: observability
spec:
  # Exporter endpoint — points to the agent DaemonSet service
  exporter:
    endpoint: http://otel-agent-collector:4317

  # W3C Trace Context and Baggage propagation
  propagators:
    - tracecontext
    - baggage

  # Sampler: respect parent decision, sample 10% of new roots
  sampler:
    type: parentbased_traceidratio
    argument: "0.1"

  # Resource attributes added to every span/metric/log
  resource:
    addK8sUIDAttributes: true
    resourceAttributes:
      deployment.environment: production

  # Java auto-instrumentation
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
    env:
      - name: OTEL_INSTRUMENTATION_JDBC_ENABLED
        value: "true"
      - name: OTEL_INSTRUMENTATION_SPRING_WEBMVC_ENABLED
        value: "true"

  # Python auto-instrumentation
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:latest
    env:
      - name: OTEL_PYTHON_LOG_CORRELATION
        value: "true"
      - name: OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED
        value: "true"

  # Node.js auto-instrumentation
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
    env:
      - name: OTEL_NODE_ENABLED_INSTRUMENTATIONS
        value: "http,grpc,express,nestjs-core,pg,redis"

  # .NET auto-instrumentation
  dotnet:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:latest
    env:
      - name: OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES
        value: "MyCompany.*"

  # Go auto-instrumentation (requires eBPF, Linux only)
  go:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-go:latest
    env:
      - name: OTEL_GO_AUTO_TARGET_EXE
        value: /app/server
```

---

## Pod Annotations to Enable Auto-Instrumentation

Add the appropriate annotation to the Pod template (`spec.template.metadata.annotations`) or to the Pod directly. The
Operator's webhook injects the agent on the next pod (re)start.

| Language | Annotation key | Value |
|----------|---------------|-------|
| Java | `instrumentation.opentelemetry.io/inject-java` | `"true"` or `"<namespace>/<instrumentation-name>"` |
| Python | `instrumentation.opentelemetry.io/inject-python` | `"true"` or `"<namespace>/<instrumentation-name>"` |
| Node.js | `instrumentation.opentelemetry.io/inject-nodejs` | `"true"` or `"<namespace>/<instrumentation-name>"` |
| .NET | `instrumentation.opentelemetry.io/inject-dotnet` | `"true"` or `"<namespace>/<instrumentation-name>"` |
| Go | `instrumentation.opentelemetry.io/inject-go` | `"true"` or `"<namespace>/<instrumentation-name>"` |

Use `"true"` when the `Instrumentation` resource is in the same namespace as the pod. Use `"<namespace>/<name>"` for
cross-namespace references.

### Example: Java Application Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: payments
spec:
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
      annotations:
        # Inject Java auto-instrumentation from the observability namespace
        instrumentation.opentelemetry.io/inject-java: "observability/otel-instrumentation"
    spec:
      containers:
        - name: payment-service
          image: myregistry/payment-service:1.2.3
          env:
            - name: OTEL_SERVICE_NAME
              value: payment-service
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "deployment.environment=production,service.version=1.2.3"
```

### Example: Node.js Application

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-nodejs: "observability/otel-instrumentation"
```

### Example: Python Application

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-python: "observability/otel-instrumentation"
```

### Example: .NET Application

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-dotnet: "observability/otel-instrumentation"
```

### Example: Go Application

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-go: "observability/otel-instrumentation"
```

---

## Sampler Configuration

The `sampler` field in the `Instrumentation` CRD configures the SDK's sampler via the `OTEL_TRACES_SAMPLER` and
`OTEL_TRACES_SAMPLER_ARG` environment variables.

| Sampler type | Description |
|-------------|-------------|
| `always_on` | Sample every trace (use only in low-volume development environments) |
| `always_off` | Drop all traces |
| `traceidratio` | Sample a fixed percentage of new traces; ignores parent decision |
| `parentbased_always_on` | Respect parent; always sample if no parent |
| `parentbased_always_off` | Respect parent; always drop if no parent |
| `parentbased_traceidratio` | Respect parent; sample new roots at the configured ratio |

Prefer `parentbased_traceidratio` in production. It honours the sampling decision made by upstream services and samples
only a fraction of root spans, preventing inconsistent partial traces.

```yaml
spec:
  sampler:
    type: parentbased_traceidratio
    argument: "0.1"   # 10% of new root spans
```

The `argument` field accepts a float between `0.0` (drop all) and `1.0` (keep all).

---

## RBAC Requirements for k8sattributes

The `k8sattributes` processor calls the Kubernetes API to look up pod and namespace metadata. The Collector's
ServiceAccount requires the following permissions.

### ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-agent
  namespace: observability
```

### ClusterRole

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-agent-k8sattributes
rules:
  - apiGroups: [""]
    resources:
      - pods
      - namespaces
      - nodes
    verbs: [get, list, watch]
  - apiGroups: ["apps"]
    resources:
      - replicasets
      - deployments
      - daemonsets
      - statefulsets
    verbs: [get, list, watch]
  - apiGroups: ["extensions"]
    resources:
      - replicasets
    verbs: [get, list, watch]
```

### ClusterRoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otel-agent-k8sattributes
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: otel-agent-k8sattributes
subjects:
  - kind: ServiceAccount
    name: otel-agent
    namespace: observability
```

---

## References

- [OpenTelemetry Operator documentation](https://opentelemetry.io/docs/kubernetes/operator/)
- [OpenTelemetry Operator GitHub](https://github.com/open-telemetry/opentelemetry-operator)
- [OpenTelemetryCollector CRD spec](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#opentelemetrycollector)
- [Instrumentation CRD spec](https://github.com/open-telemetry/opentelemetry-operator/blob/main/docs/api.md#instrumentation)
- [cert-manager installation](https://cert-manager.io/docs/installation/)
- [Auto-instrumentation overview](https://opentelemetry.io/docs/kubernetes/operator/automatic/)
