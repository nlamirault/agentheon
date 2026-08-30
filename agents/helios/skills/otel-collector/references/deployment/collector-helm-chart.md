# OpenTelemetry Collector Helm Chart

The `opentelemetry-collector` Helm chart is the recommended way to deploy the Collector on Kubernetes. It supports all
deployment modes through a single chart and provides presets that activate common configurations without requiring
manual component setup.

---

## Add the Helm Repository

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

Verify the chart is available:

```bash
helm search repo open-telemetry/opentelemetry-collector --versions | head -5
```

---

## Mode Selection

Set `mode` to control the Kubernetes workload type:

| Mode | Workload | Typical use case |
|------|----------|------------------|
| `daemonset` | DaemonSet | Node-level log/metric collection, agent |
| `deployment` | Deployment | Gateway aggregation, processing |
| `statefulset` | StatefulSet | Tail sampling (requires sticky routing) |

### Install as DaemonSet (agent)

```bash
helm install otel-agent open-telemetry/opentelemetry-collector \
  --namespace observability \
  --create-namespace \
  --values agent-values.yaml
```

### Install as Deployment (gateway)

```bash
helm install otel-gateway open-telemetry/opentelemetry-collector \
  --namespace observability \
  --create-namespace \
  --values gateway-values.yaml
```

---

## Presets

Presets activate commonly needed receivers, processors, and volumes without manual configuration. Enable only the
presets required for your deployment mode.

| Preset | Available modes | What it activates |
|--------|----------------|-------------------|
| `logsCollection` | `daemonset` | `filelog` receiver, host path volumes for `/var/log` |
| `hostMetrics` | `daemonset` | `hostmetrics` receiver with standard scrapers |
| `kubeletMetrics` | `daemonset` | `kubeletstats` receiver |
| `kubernetesAttributes` | all | `k8sattributes` processor + RBAC (ClusterRole, ClusterRoleBinding, ServiceAccount) |
| `kubernetesEvents` | `deployment` | `k8sobjects` receiver for cluster events |
| `clusterMetrics` | `deployment` | `k8s_cluster` receiver |

### Agent values.yaml with presets

```yaml
# agent-values.yaml
mode: daemonset

presets:
  logsCollection:
    enabled: true
    includeCollectorLogs: false
  hostMetrics:
    enabled: true
  kubeletMetrics:
    enabled: true
  kubernetesAttributes:
    enabled: true
    extractAllPodLabels: false
    extractAllPodAnnotations: false

image:
  repository: otel/opentelemetry-collector-contrib
  tag: "0.100.0"

resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Gateway values.yaml with presets

```yaml
# gateway-values.yaml
mode: deployment

replicaCount: 2

presets:
  kubernetesAttributes:
    enabled: false   # gateway does not need k8sattributes; agents handle enrichment

image:
  repository: otel/opentelemetry-collector-contrib
  tag: "0.100.0"

resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

---

## Custom Configuration via values.yaml

Override or extend the Collector configuration using `config`. The chart merges your `config` with the preset-generated
configuration.

```yaml
# values.yaml — complete agent example with custom pipeline
mode: daemonset

presets:
  logsCollection:
    enabled: true
  hostMetrics:
    enabled: true
  kubernetesAttributes:
    enabled: true

image:
  repository: otel/opentelemetry-collector-contrib
  tag: "0.100.0"

config:
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

    resourcedetection:
      detectors: [env, k8snode]
      timeout: 5s
      override: false

    batch:
      send_batch_size: 512
      timeout: 10s

  exporters:
    otlp:
      endpoint: otel-gateway.observability.svc.cluster.local:4317
      tls:
        insecure: false
      retry_on_failure:
        enabled: true

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

# Expose OTLP ports as a ClusterIP service
service:
  enabled: true
  type: ClusterIP

ports:
  otlp:
    enabled: true
    containerPort: 4317
    servicePort: 4317
    protocol: TCP
  otlp-http:
    enabled: true
    containerPort: 4318
    servicePort: 4318
    protocol: TCP
```

### Passing secrets via environment variables

Store backend credentials in a Kubernetes Secret and reference them from the chart values:

```yaml
extraEnvs:
  - name: OTLP_BACKEND_ENDPOINT
    valueFrom:
      secretKeyRef:
        name: otlp-backend-credentials
        key: endpoint
  - name: OTLP_BACKEND_TOKEN
    valueFrom:
      secretKeyRef:
        name: otlp-backend-credentials
        key: token
```

Reference the variables in the Collector config using `${env:VAR_NAME}`:

```yaml
config:
  exporters:
    otlp:
      endpoint: "${env:OTLP_BACKEND_ENDPOINT}"
      headers:
        authorization: "${env:OTLP_BACKEND_TOKEN}"
```

---

## Image Selection

The chart supports two official Collector images:

| Image | Repository | When to use |
|-------|-----------|-------------|
| Core | `otel/opentelemetry-collector` | Minimal build; includes only core components |
| Contrib | `otel/opentelemetry-collector-contrib` | All community components; use when you need `k8sattributes`, `filelog`, `spanmetrics`, etc. |

```yaml
# Core image — smaller attack surface
image:
  repository: otel/opentelemetry-collector
  tag: "0.100.0"
  pullPolicy: IfNotPresent

# Contrib image — required for most Kubernetes deployments
image:
  repository: otel/opentelemetry-collector-contrib
  tag: "0.100.0"
  pullPolicy: IfNotPresent
```

For production, pin the image tag to an exact version. Do not use `latest`.

---

## Resources and Scaling

### Resource requests and limits

Size the Collector based on the expected throughput. These are starting-point values — adjust based on observed usage.

```yaml
# Agent (DaemonSet) — sized per node
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Gateway (Deployment) — sized for aggregate load
resources:
  requests:
    cpu: 500m
    memory: 1Gi
  limits:
    cpu: 2000m
    memory: 2Gi
```

Always configure `memory_limiter` in the Collector pipeline to avoid OOM crashes. Set `limit_percentage` to 75% of the
container memory limit.

### Horizontal autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 75
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
```

### PodDisruptionBudget

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

---

## Upgrade

```bash
helm upgrade otel-agent open-telemetry/opentelemetry-collector \
  --namespace observability \
  --values agent-values.yaml \
  --atomic \
  --timeout 5m
```

Use `--atomic` to automatically roll back on failure.

---

## Validate the Deployment

```bash
# Check rollout status
kubectl rollout status daemonset/otel-agent -n observability
kubectl rollout status deployment/otel-gateway -n observability

# Tail Collector logs
kubectl logs -n observability -l app.kubernetes.io/name=otel-agent -f --tail=100

# Check health endpoint
kubectl port-forward -n observability svc/otel-agent 13133:13133
curl http://localhost:13133/
```

---

## References

- [opentelemetry-collector Helm chart](https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector)
- [Chart values reference](https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-collector/values.yaml)
- [Collector presets documentation](https://opentelemetry.io/docs/kubernetes/helm/collector/)
- [otel/opentelemetry-collector-contrib Docker Hub](https://hub.docker.com/r/otel/opentelemetry-collector-contrib)
- [OpenTelemetry Collector releases](https://github.com/open-telemetry/opentelemetry-collector-releases/releases)
