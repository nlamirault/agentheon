# OpenTelemetry Collector Architecture & Deployment Patterns

## Overview

This reference provides guidance on deploying the OpenTelemetry Collector in production environments, with a focus on Kubernetes architectures, scaling patterns, and the critical concept of **load balancing stickiness** for stateful operations like tail sampling.

## Table of Contents

1. [Deployment Decision Matrix](#deployment-decision-matrix)
2. [Agent Pattern (DaemonSet)](#agent-pattern-daemonset)
3. [Gateway Pattern (Deployment)](#gateway-pattern-deployment)
4. [Sidecar Pattern](#sidecar-pattern)
5. [Hybrid Architecture](#hybrid-architecture)
6. [Scaling Stateful Collectors](#scaling-stateful-collectors)
7. [Load Balancing & Sticky Sessions](#load-balancing--sticky-sessions)
8. [Target Allocator for Prometheus](#target-allocator-for-prometheus)
9. [Resource Sizing Guidelines](#resource-sizing-guidelines)
10. [When NOT to Scale](#when-not-to-scale)

---

## Deployment Decision Matrix

| Pattern | Use Case | Pros | Cons | When to Use |
|---------|----------|------|------|-------------|
| **Agent (DaemonSet)** | Host metrics, logs | 1 per node efficiency | No central aggregation | Logs, host metrics, K8s events |
| **Gateway (Deployment)** | Tail sampling, aggregation | Central processing, scales independently | Additional network hop | Tail sampling, metric aggregation, fan-out |
| **Sidecar** | Per-pod isolation | Strict isolation, no RBAC | High resource overhead | Serverless (Fargate), security isolation |
| **Hybrid** | Production systems | Best of both | Increased complexity | Most production deployments |

### Decision Tree

```
Do you need to collect logs or host metrics?
├─ YES → Deploy Agent (DaemonSet)
└─ NO  → Continue

Do you need tail sampling or span-to-metrics?
├─ YES → Deploy Gateway (Deployment) with sticky sessions
└─ NO  → Continue

Are you on serverless (Fargate/Lambda)?
├─ YES → Deploy Sidecar or use Lambda Extension Layer (see platforms.md)
└─ NO  → Deploy Gateway for centralized export
```

---

## Agent Pattern (DaemonSet)

Runs **one collector pod per Kubernetes node**. Collects: host metrics, logs from `/var/log/pods`, Kubernetes events, application metrics.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-agent
  namespace: observability
spec:
  selector:
    matchLabels:
      app: otel-agent
  template:
    spec:
      serviceAccountName: otel-agent
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:0.151.0
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```

**Best Practices**:
✅ Always use DaemonSet for logs — the only way to access node-local log files
✅ Use tolerations to ensure the agent runs on all nodes including control plane
✅ Set conservative resource limits (512Mi memory) to prevent node exhaustion

---

## Gateway Pattern (Deployment)

A stateless or stateful collector deployment that aggregates data, performs tail sampling, reduces egress connections.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-gateway
  namespace: observability
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: otel-collector
        image: otel/opentelemetry-collector-contrib:0.151.0
        ports:
        - containerPort: 4317   # OTLP gRPC
        - containerPort: 4318   # OTLP HTTP
        - containerPort: 8888   # Metrics
        - containerPort: 13133  # Health check
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        livenessProbe:
          httpGet:
            path: /
            port: 13133
        readinessProbe:
          httpGet:
            path: /
            port: 13133
```

### Horizontal Pod Autoscaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: otel-gateway-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otel-gateway
  minReplicas: 3
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
        averageUtilization: 80
```

**Best Practices**:
✅ 3 replicas minimum for HA during rolling updates
✅ Prefer Services over `hostPort` for gateways
✅ Validate rollout settings together: `replicas`, HPA `minReplicas`, PodDisruptionBudget

### Deployment Sanity Checks

1. **Replica math**: PodDisruptionBudget must not require more available pods than the Deployment guarantees during maintenance.
2. **Tail sampling stickiness**: If HPA can scale above one replica, upstream routing must already be sticky.
3. **Port exposure**: A gateway exposed via ClusterIP/LoadBalancer/Ingress should not use `hostPort`.

---

## Sidecar Pattern

Each application pod gets its own collector container. Use **only** for:
- Serverless environments (AWS Fargate, Google Cloud Run)
- Strict security isolation requirements

**Trade-offs**:
❌ High resource overhead — every pod pays the cost
❌ No k8sattributes processor (no cluster access)
✅ Strong isolation — tenant A's collector never sees tenant B's data

---

## Hybrid Architecture

**Recommended production architecture**: Agent (DaemonSet) → Gateway (Deployment) → Backend

```yaml
# Agent config snippet — forward traces to gateway
exporters:
  otlp:
    endpoint: otel-gateway.observability.svc.cluster.local:4317

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
    logs:
      receivers: [filelog]
      processors: [memory_limiter, k8sattributes, batch]
      exporters: [otlp]
```

```yaml
# Gateway config snippet — tail sampling + export
processors:
  tail_sampling:
    policies:
      - name: errors
        type: status_code
        status_code: {status_codes: [ERROR]}
      - name: slow
        type: latency
        latency: {threshold_ms: 500}
      - name: default
        type: probabilistic
        probabilistic: {sampling_percentage: 1}
```

---

## Scaling Stateful Collectors

**The stickiness problem**: Tail sampling requires all spans of a trace to arrive at the **same collector instance**. Standard Kubernetes Service round-robin breaks this.

```
WITHOUT stickiness:
Span A (trace_id: 123) → Gateway Pod 1
Span B (trace_id: 123) → Gateway Pod 2  ❌ Different pod = broken sampling

WITH stickiness:
Span A (trace_id: 123) → Gateway Pod 1
Span B (trace_id: 123) → Gateway Pod 1  ✅ Correct
```

---

## Load Balancing & Sticky Sessions

### Solution: Load Balancing Exporter + Headless Service

```yaml
# Pre-gateway tier (agents)
exporters:
  loadbalancing:
    routing_key: "traceID"         # CRITICAL — ensures stickiness
    protocol:
      otlp:
        tls:
          insecure: true
    resolver:
      k8s:
        service: otel-gateway-headless  # Must be Headless Service
        ports:
          - 4317
```

```yaml
# Headless Service — resolver gets individual pod IPs, not VIP
apiVersion: v1
kind: Service
metadata:
  name: otel-gateway-headless
spec:
  clusterIP: None    # Headless
  selector:
    app: otel-gateway
  ports:
  - name: otlp-grpc
    port: 4317
```

**Use stable, low-cardinality routing keys**: `traceID`, `tenant_id`, or `cluster`. Avoid timestamps, session IDs, or high-cardinality volatile attributes.

---

## Target Allocator for Prometheus

When scaling the Prometheus receiver, every collector replica scrapes every target → **duplicate data**.

The **Target Allocator** (OpenTelemetry Operator) shards Prometheus targets across collector replicas:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: otel-prometheus
spec:
  mode: statefulset
  replicas: 3
  targetAllocator:
    enabled: true
    serviceAccount: otel-prometheus-ta
    prometheusCR:
      enabled: true  # Discover ServiceMonitors and PodMonitors
  config: |
    receivers:
      prometheus:
        config:
          scrape_configs: []  # Populated by Target Allocator
        target_allocator:
          endpoint: http://otel-prometheus-targetallocator:80
          interval: 30s
          collector_id: "${POD_NAME}"
```

---

## Resource Sizing Guidelines

### Agent (DaemonSet)

| Workload | CPU Request | Memory Request | Memory Limit |
|----------|-------------|----------------|--------------|
| Low (dev) | 100m | 128Mi | 256Mi |
| Medium | 200m | 256Mi | 512Mi |
| High (prod) | 500m | 512Mi | 1Gi |

### Gateway (Deployment)

| Throughput | Memory Request | Memory Limit | Replicas |
|------------|----------------|--------------|----------|
| <1k RPS | 1Gi | 2Gi | 2 |
| 1-10k RPS | 2Gi | 4Gi | 3 |
| 10-50k RPS | 4Gi | 8Gi | 5 |
| >50k RPS | 8Gi | 16Gi | 10+ |

### Persistent Storage (file_storage)

| Use Case | Volume Size | Storage Class |
|----------|-------------|---------------|
| Short buffer (<1h) | 5-10 GB | gp3 (standard) |
| Medium buffer (1-6h) | 20-50 GB | gp3 (3000 IOPS) |
| Long buffer (>6h) | 100+ GB | gp3 (5000+ IOPS) |

---

## When NOT to Scale

Scaling the collector does **not** fix downstream bottlenecks.

### Key Signal: Queue Saturation

```promql
otelcol_exporter_queue_size / otelcol_exporter_queue_capacity
```

| Queue Ratio | Interpretation | Action |
|-------------|----------------|--------|
| < 0.5 | Healthy | No action |
| 0.5–0.8 | Warning — backend slowing | Investigate backend latency |
| > 0.8 persistently | ⚠️ Downstream bottleneck | **Scaling collector won't help** |

### Scaling Anti-Patterns

❌ Scaling collectors when the backend is the bottleneck
❌ Scaling without sampling at >50k RPS
❌ Scaling stateful collectors without sticky routing
❌ Scaling to compensate for cardinality explosion

### When Scaling DOES Help

✅ Collector CPU is the bottleneck (transform/filter heavy)
✅ Receiver throughput is limited (accept queue full)
✅ Tail sampling replicas need more memory for in-flight traces
✅ Prometheus scraping needs more targets per collector

---

## Summary

✅ Use **DaemonSet** for logs and host metrics
✅ Use **Gateway** for tail sampling with loadbalancing exporter (sticky sessions)
✅ Use **Sidecar** only for serverless or strict isolation
✅ Use **Hybrid** (Agent → Gateway → Backend) for production
✅ Use **Target Allocator** for Prometheus scraping at scale
✅ Use **Headless Service** with loadbalancing exporter
✅ Before scaling, check if the problem is **downstream** (backend saturation)

## Reference Links

- [Deployment Patterns](https://opentelemetry.io/docs/collector/deployment/)
- [Kubernetes Operator](https://github.com/open-telemetry/opentelemetry-operator)
- [Scaling Guide](https://opentelemetry.io/docs/collector/scaling/)
