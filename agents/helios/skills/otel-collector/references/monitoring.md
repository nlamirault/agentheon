# OpenTelemetry Collector Meta-Monitoring

## Overview

"Who watches the watchers?" Meta-monitoring is the practice of observing the observability pipeline itself. A failing collector can silently drop data, creating blind spots in production systems. This reference provides comprehensive guidance on collector self-monitoring, health checks, and alerting patterns.

## Table of Contents

1. [Why Meta-Monitoring?](#why-meta-monitoring)
2. [Collector Telemetry](#collector-telemetry)
3. [OTLP Self-Telemetry](#otlp-self-telemetry)
4. [Critical Metrics](#critical-metrics)
5. [Health Checks](#health-checks)
6. [Dashboards](#dashboards)
7. [Alert Rules](#alert-rules)

---

## Why Meta-Monitoring?

### The Silent Failure Problem

**Scenario**: Your collector is silently dropping 50% of traces due to memory pressure.

**Impact**:
- ❌ Missing spans in distributed traces
- ❌ Incorrect latency percentiles (p95, p99)
- ❌ Undetected errors
- ❌ False confidence in system health

**Solution**: Monitor the collector's internal metrics to detect issues **before** data loss becomes critical.

### What to Monitor

| Category | Metrics | Purpose |
|----------|---------|---------|
| **Throughput** | Accepted vs sent spans/metrics/logs | Data flow verification |
| **Data Loss** | Refused, dropped, failed exports | Detect backpressure and failures |
| **Resources** | CPU, memory, disk usage | Prevent OOM kills |
| **Queue Health** | Queue size vs capacity | Predict saturation |
| **Export Performance** | Export latency, retry count | Backend health |

---

## Collector Telemetry

The collector exposes internal metrics on port **8888** (default).

### Enabling Telemetry

```yaml
service:
  telemetry:
    logs:
      level: info  # Options: debug, info, warn, error

    metrics:
      level: detailed  # Options: none, basic, normal, detailed
      address: "0.0.0.0:8888"  # Prometheus scrape endpoint
```

### Scraping Collector Metrics

**Prometheus scrape config**:

```yaml
scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8888']

    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
```

**Kubernetes ServiceMonitor (with Prometheus Operator)**:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: otel-collector
  namespace: observability
spec:
  selector:
    matchLabels:
      app: otel-collector
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

---

## OTLP Self-Telemetry

The [OpenTelemetry Collector Internal Telemetry documentation](https://opentelemetry.io/docs/collector/internal-telemetry/) recommends using **OTLP periodic readers** for self-observability instead of (or in addition to) the Prometheus scrape pattern.

### Why OTLP for Self-Telemetry?

| Pattern | Pros | Cons |
|---------|------|------|
| **Prometheus scrape (pull)** | Simple, compatible with existing Prometheus stacks | Requires external scraper; pull model means delayed detection |
| **OTLP push (recommended)** | No external scraper; metrics arrive as fast as flush interval; unified with app telemetry | Requires OTLP-capable metrics backend |

### Configuration: OTLP Periodic Reader

```yaml
service:
  telemetry:
    logs:
      level: info
    metrics:
      level: detailed          # none | basic | normal | detailed
      readers:
        - pull:
            exporter:
              prometheus:
                host: "0.0.0.0"
                port: 8888     # keep Prometheus endpoint for existing dashboards

        - periodic:
            interval: 60000    # push interval in milliseconds (60s)
            timeout: 30000     # export timeout in milliseconds
            exporter:
              otlp:
                protocol: grpc
                endpoint: "http://otlp-backend:4317"
                headers:
                  authorization: "Bearer ${env:SELF_TELEMETRY_TOKEN:-}"
```

### Self-Telemetry Pipeline Pattern

```yaml
service:
  telemetry:
    metrics:
      level: detailed
      readers:
        - periodic:
            interval: 30000
            exporter:
              otlp:
                protocol: grpc
                endpoint: "localhost:4317"   # loopback to own OTLP receiver

  pipelines:
    metrics:
      receivers: [otlp]                      # receives both app and self metrics
      processors: [memory_limiter, batch]
      exporters: [otlp/backend]
```

### Resource Attributes for Self-Telemetry

```yaml
service:
  telemetry:
    resource:
      service.name: "otel-gateway"
      service.instance.id: "${env:POD_NAME}"
      k8s.namespace.name: "${env:NAMESPACE}"
      k8s.node.name: "${env:NODE_NAME}"
    metrics:
      level: detailed
      readers:
        - periodic:
            interval: 60000
            exporter:
              otlp:
                protocol: grpc
                endpoint: "http://central-backend:4317"
```

---

## Critical Metrics

### Metric Naming Convention

All collector metrics follow the pattern:
```
otelcol_{component}_{signal}_{metric}
```

**Examples**:
- `otelcol_receiver_accepted_spans`
- `otelcol_processor_dropped_metric_points`
- `otelcol_exporter_send_failed_log_records`

### Golden Signals for Collectors

#### 1. Throughput (Data Flow)

```promql
# Traces
rate(otelcol_receiver_accepted_spans[1m])
rate(otelcol_exporter_sent_spans[1m])

# Metrics
rate(otelcol_receiver_accepted_metric_points[1m])
rate(otelcol_exporter_sent_metric_points[1m])

# Logs
rate(otelcol_receiver_accepted_log_records[1m])
rate(otelcol_exporter_sent_log_records[1m])
```

**What to look for**:
- ✅ Accepted ≈ Sent → Healthy pipeline
- ⚠️ Accepted > Sent → Backpressure, queue filling
- ❌ Accepted >> Sent → Data loss

#### 2. Data Loss (Errors)

```promql
# Dropped percentage
100 * (
  rate(otelcol_processor_dropped_spans[1m]) +
  rate(otelcol_exporter_send_failed_spans[1m])
) / rate(otelcol_receiver_accepted_spans[1m])
```

**Alert threshold**: > 1% data loss

#### 3. Resource Usage

```promql
# Memory (RSS)
otelcol_process_memory_rss

# CPU
rate(otelcol_process_cpu_seconds_total[1m])

# Memory usage percentage
100 * otelcol_process_memory_rss / node_memory_MemTotal_bytes
```

**Alert threshold**: > 80% of container limit

#### 4. Queue Health

```promql
# Queue saturation percentage
100 * otelcol_exporter_queue_size / otelcol_exporter_queue_capacity
```

**Alert threshold**: > 80% full

#### 5. Export Performance

```promql
rate(otelcol_exporter_send_failed_spans[1m])
```

**Alert threshold**: > 0 (any failures)

---

## Health Checks

### Health Check Extension

```yaml
extensions:
  health_check:
    endpoint: "0.0.0.0:13133"
    check_collector_pipeline:
      enabled: true
      interval: "5m"
      exporter_failure_threshold: 5

service:
  extensions: [health_check]
```

### Kubernetes Probes

```yaml
containers:
- name: otel-collector
  ports:
  - containerPort: 13133
    name: health

  livenessProbe:
    httpGet:
      path: /
      port: 13133
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3

  readinessProbe:
    httpGet:
      path: /
      port: 13133
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3
```

---

## Dashboards

### Community Dashboards

**Grafana Dashboard ID**: 15983 (monitoringartist/opentelemetry-collector-monitoring)

```bash
# Import via Grafana UI
Dashboard → Import → ID: 15983
```

### Key Dashboard Panels

```promql
# Throughput
sum(rate(otelcol_receiver_accepted_spans[1m])) by (receiver)
sum(rate(otelcol_exporter_sent_spans[1m])) by (exporter)

# Data loss
sum(rate(otelcol_processor_dropped_spans[1m])) by (processor)
sum(rate(otelcol_exporter_send_failed_spans[1m])) by (exporter)

# Memory usage (MB)
otelcol_process_memory_rss / 1024 / 1024

# Queue saturation
100 * otelcol_exporter_queue_size / otelcol_exporter_queue_capacity

# Export latency p99
histogram_quantile(0.99, rate(otelcol_exporter_send_latency_bucket[1m]))
```

---

## Alert Rules

```yaml
groups:
  - name: otel-collector
    interval: 30s
    rules:
      - alert: OTelCollectorDataLoss
        expr: rate(otelcol_exporter_send_failed_spans[1m]) > 0
        for: 5m
        labels:
          severity: critical
          component: otel-collector
        annotations:
          summary: "OpenTelemetry Collector is dropping data"
          description: "Collector {{ $labels.instance }} has failed to export {{ $value }} spans/second for 5 minutes."

      - alert: OTelCollectorHighMemory
        expr: |
          100 * otelcol_process_memory_rss /
          (container_spec_memory_limit_bytes{pod=~"otel-collector.*"} > 0) > 80
        for: 10m
        labels:
          severity: warning
          component: otel-collector
        annotations:
          summary: "OpenTelemetry Collector memory usage high"
          description: "Collector {{ $labels.instance }} is using {{ $value }}% of its memory limit."

      - alert: OTelCollectorQueueFull
        expr: 100 * otelcol_exporter_queue_size / otelcol_exporter_queue_capacity > 80
        for: 5m
        labels:
          severity: warning
          component: otel-collector
        annotations:
          summary: "OpenTelemetry Collector queue is filling up"
          description: "Collector {{ $labels.instance }} queue is {{ $value }}% full. Risk of data loss."

      - alert: OTelCollectorDown
        expr: up{job="otel-collector"} == 0
        for: 2m
        labels:
          severity: critical
          component: otel-collector
        annotations:
          summary: "OpenTelemetry Collector is down"
          description: "Collector {{ $labels.instance }} has been down for 2 minutes."

      - alert: OTelCollectorBackpressure
        expr: rate(otelcol_receiver_refused_spans[1m]) > 0
        for: 5m
        labels:
          severity: warning
          component: otel-collector
        annotations:
          summary: "OpenTelemetry Collector is applying backpressure"
          description: "Collector {{ $labels.instance }} is refusing {{ $value }} spans/second due to memory limits."
```

---

## Troubleshooting Checklist

### Collector Not Accepting Data

Check: `rate(otelcol_receiver_refused_spans[1m])`

Causes: memory limiter triggered, receiver port not exposed, network policy blocking traffic.

### Data Not Reaching Backend

Check: `rate(otelcol_exporter_sent_spans[1m])` vs `rate(otelcol_exporter_send_failed_spans[1m])`

Causes: exporter misconfigured, backend down, queue full.

### High Memory Usage / OOMKilled

Check: `otelcol_process_memory_rss`, `otelcol_exporter_queue_size`

Causes: no `memory_limiter` processor, queue too large, high throughput without batching.

### Incomplete Traces (Tail Sampling)

- Verify loadbalancing exporter uses `routing_key: traceID`
- Check Headless Service returns pod IPs, not VIP
- Verify `decision_wait` is long enough for trace completion

---

## Summary

✅ Expose metrics on port 8888 for Prometheus scraping
✅ Or use OTLP push via `service.telemetry.metrics.readers` for unified self-telemetry
✅ Monitor throughput: Accepted vs sent spans/metrics/logs
✅ Alert on data loss: `otelcol_exporter_send_failed_spans > 0`
✅ Track memory usage: Set alerts at 80% of limit
✅ Watch queue saturation: Alert when > 80% full
✅ Use health checks: Configure Kubernetes liveness/readiness probes
✅ Deploy dashboards: Use monitoringartist/opentelemetry-collector-monitoring (ID: 15983)

## Reference Links

- [Collector Internal Telemetry](https://opentelemetry.io/docs/collector/internal-telemetry/)
- [Health Check Extension](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/healthcheckextension)
- [MonitoringArtist Dashboards](https://github.com/monitoringartist/opentelemetry-collector-monitoring)
