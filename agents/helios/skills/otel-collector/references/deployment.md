# OpenTelemetry Collector Deployment Patterns

Choosing the right Collector deployment pattern depends on where the telemetry originates, what processing is required,
and the scale and topology of the environment.

---

## Deployment Pattern Decision Table

| Pattern | Kubernetes Kind | Scope | When to Use |
|---|---|---|---|
| **Agent** | DaemonSet | Per node | Host metrics, pod log collection, node-level data, local OTLP ingestion |
| **Gateway** | Deployment (scaled) | Cluster-wide | Tail sampling, heavy transformation, aggregation, multi-tenant routing, scaling independently of nodes |
| **Sidecar** | Pod container | Per pod | Direct process instrumentation, strict network isolation, service mesh bypass |
| **Standalone** | Deployment (1 replica) | Single instance | Development, testing, small clusters with low volume |

---

## Agent Mode (DaemonSet)

An agent Collector runs one replica per Kubernetes node. It is positioned close to the workloads and has direct access
to host-level resources.

### Use Cases

- **Host metrics**: CPU, memory, disk I/O, network statistics via the `hostmetrics` receiver (requires host filesystem
  mount).
- **Pod log collection**: Tail `/var/log/pods/` via the `filelog` receiver; the DaemonSet has node-local access without
  network hops.
- **Node-level telemetry**: Kubelet metrics, cAdvisor metrics, node-exporter scraping.
- **Local OTLP ingestion**: Receive spans/metrics/logs from pods on the same node, reducing cross-node traffic.
- **Passthrough enrichment**: Add Kubernetes metadata and forward to a gateway for further processing.

### Key Characteristics

| Characteristic | Value |
|---|---|
| Kubernetes resource | `DaemonSet` |
| Scaling | Automatic — one pod per node |
| Processing | Lightweight; avoid heavy CPU/memory operations |
| Tail sampling | Not recommended — spans from a single trace can arrive on different nodes |
| Host filesystem access | Yes (via `hostPath` volume mounts) |
| RBAC | Needs `get/list/watch` on pods and nodes for `k8sattributes` |

### Minimal DaemonSet Configuration Sketch

```yaml
# Agent does minimal processing; sends to gateway
processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 75
    spike_limit_percentage: 20
  resourcedetection:
    detectors: [env, k8snode]
  k8sattributes:
    passthrough: true   # Let the gateway do full enrichment

exporters:
  loadbalancing:        # Route traces by traceId for tail sampling on gateway
    protocol:
      otlp:
        tls:
          insecure: false
    resolver:
      dns:
        hostname: otelcol-gateway-headless.monitoring.svc.cluster.local
        port: 4317

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, k8sattributes]
      exporters: [loadbalancing]
    metrics:
      receivers: [otlp, hostmetrics, prometheus]
      processors: [memory_limiter, resourcedetection, k8sattributes]
      exporters: [otlp/gateway]
    logs:
      receivers: [otlp, filelog]
      processors: [memory_limiter, resourcedetection, k8sattributes]
      exporters: [otlp/gateway]
```

---

## Gateway Mode (Deployment)

A gateway Collector is a centralized, horizontally scalable service. It receives telemetry forwarded from agents or
directly from applications and performs heavier processing.

### Use Cases

- **Tail sampling**: Requires all spans of a trace to reach the same instance; use the load balancing exporter from
  agents to route by `traceId`.
- **Heavy processing**: OTTL transforms, redaction, complex filtering — offload from per-node agents.
- **Aggregation**: Merge telemetry from multiple agents; add cluster-level metadata.
- **Multi-tenant routing**: Route telemetry to different backends based on namespace, team label, or attribute value.
- **Backend fan-out**: Send to multiple OTLP endpoints from one place.
- **Independent scaling**: Scale based on throughput rather than node count.

### Key Characteristics

| Characteristic | Value |
|---|---|
| Kubernetes resource | `Deployment` (HPA recommended) |
| Scaling | Manual or HPA (based on CPU, memory, or custom metrics queue depth) |
| Processing | CPU and memory intensive operations are appropriate here |
| Tail sampling | Supported — use `loadbalancing` exporter from agents |
| Host filesystem access | Not applicable |
| RBAC | Needs `get/list/watch` on pods, nodes, namespaces for full `k8sattributes` enrichment |
| Persistent volume | Recommended for `file_storage` queue |

### Headless Service for Agent Discovery

```yaml
apiVersion: v1
kind: Service
metadata:
  name: otelcol-gateway-headless
  namespace: monitoring
spec:
  clusterIP: None
  selector:
    app.kubernetes.io/name: otelcol-gateway
  ports:
    - name: otlp-grpc
      port: 4317
---
apiVersion: v1
kind: Service
metadata:
  name: otelcol-gateway
  namespace: monitoring
spec:
  selector:
    app.kubernetes.io/name: otelcol-gateway
  ports:
    - name: otlp-grpc
      port: 4317
    - name: otlp-http
      port: 4318
```

### HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: otelcol-gateway
  namespace: monitoring
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otelcol-gateway
  minReplicas: 2
  maxReplicas: 10
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
          averageUtilization: 75
```

---

## Sidecar Mode

A sidecar Collector runs as an additional container in the same pod as the instrumented application.

### Use Cases

- **Strict isolation**: The application must only communicate with its own Collector, not a shared agent.
- **Per-pod configuration**: Different sampling rates or export destinations per application.
- **Service mesh bypass**: Avoid mTLS or mesh policy issues by keeping telemetry on loopback.
- **Legacy applications**: Applications that cannot be reconfigured to send to a remote endpoint; point them to
  `localhost:4317`.

### Key Characteristics

| Characteristic | Value |
|---|---|
| Kubernetes resource | Sidecar container in `Pod` / `Deployment` spec |
| Scaling | Scales with the application pod |
| Processing | Minimal — overhead per pod is multiplied by replica count |
| Bind address | `127.0.0.1` (loopback only) |
| Host filesystem access | Not available |
| Resource overhead | Adds CPU/memory request per pod; budget carefully |

### Sidecar Container Spec

```yaml
# In the Pod spec
containers:
  - name: myapp
    image: myapp:latest
    env:
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: http://localhost:4317
      - name: OTEL_EXPORTER_OTLP_PROTOCOL
        value: grpc

  - name: otelcol-sidecar
    image: otel/opentelemetry-collector-contrib:latest
    args: ["--config=/etc/otelcol/config.yaml"]
    resources:
      requests:
        cpu: 50m
        memory: 64Mi
      limits:
        cpu: 200m
        memory: 256Mi
    volumeMounts:
      - name: otelcol-config
        mountPath: /etc/otelcol

volumes:
  - name: otelcol-config
    configMap:
      name: otelcol-sidecar-config
```

---

## Hybrid Pattern: DaemonSet Agents + Gateway Deployment

The most common production pattern combines both:

```text
┌──────────────────────────────────────────────────────────────┐
│  Kubernetes Node                                             │
│                                                              │
│  ┌──────────────┐    OTLP     ┌──────────────────────────┐  │
│  │  Application  │ ─────────► │  Agent Collector         │  │
│  │  Pod          │            │  (DaemonSet)             │  │
│  └──────────────┘            │  - Receive OTLP           │  │
│                               │  - Collect host metrics   │  │
│  ┌──────────────┐    OTLP     │  - Collect pod logs       │  │
│  │  Application  │ ─────────► │  - passthrough k8sattrs  │  │
│  │  Pod          │            └───────────┬──────────────┘  │
└──────────────────────────────────────────┼──────────────────┘
                                           │ OTLP (loadbalancing by traceId)
                                           ▼
                              ┌────────────────────────────┐
                              │  Gateway Collector         │
                              │  (Deployment, N replicas)  │
                              │  - Full k8sattributes      │
                              │  - Tail sampling           │
                              │  - OTTL transforms         │
                              │  - Routing to backends     │
                              └────────────┬───────────────┘
                                           │ OTLP
                                           ▼
                                     OTLP Backend
```

### Division of Responsibilities

| Responsibility | Agent (DaemonSet) | Gateway (Deployment) |
|---|---|---|
| Receive OTLP from pods | Yes | No (agents do this) |
| Collect host metrics | Yes | No |
| Collect pod logs | Yes | No |
| `k8sattributes` passthrough | Yes (passthrough: true) | Full enrichment |
| Tail sampling | No | Yes |
| Heavy OTTL transforms | No | Yes |
| Redaction / PII scrubbing | No | Yes |
| Fan-out to multiple backends | No | Yes |
| Persistent queue | Optional | Yes (file_storage) |

---

## When to Use Each Mode

| Scenario | Recommended Pattern |
|---|---|
| Collecting host and node metrics | Agent (DaemonSet) |
| Collecting logs from all pods | Agent (DaemonSet) with `filelog` receiver |
| Simple OTLP forwarding at small scale | Agent or Standalone |
| Tail sampling across all services | Agent (loadbalancing) + Gateway (tail_sampling) |
| Multi-tenant routing by namespace | Gateway |
| Strict per-pod network isolation | Sidecar |
| Development environment | Standalone or Sidecar |
| Large cluster, high throughput | Hybrid (DaemonSet + Gateway with HPA) |
| Data must not leave the node | Agent only, no gateway |

---

## Links to Detailed Deployment References

- [Deployment directory](./deployment/) — Kubernetes manifests and Helm values for each pattern
- [Processors reference](./processors.md) — `k8sattributes` passthrough mode, RBAC, processor ordering
- [Sampling reference](./sampling.md) — load balancing exporter configuration, tail sampling gateway setup
- [Exporters reference](./exporters.md) — `sending_queue` with `file_storage`, authentication
- [Receivers reference](./receivers.md) — `hostmetrics` host mounts, `filelog` pod log collection

### External References

- [Collector Deployment Patterns (OTel Docs)](https://opentelemetry.io/docs/collector/deployment/)
- [Agent Pattern](https://opentelemetry.io/docs/collector/deployment/agent/)
- [Gateway Pattern](https://opentelemetry.io/docs/collector/deployment/gateway/)
- [No-Collector Pattern](https://opentelemetry.io/docs/collector/deployment/no-collector/)
- [Scaling the Collector](https://opentelemetry.io/docs/collector/scaling/)
- [OpenTelemetry Operator for Kubernetes](https://github.com/open-telemetry/opentelemetry-operator) — automates sidecar
  injection and Collector lifecycle management
