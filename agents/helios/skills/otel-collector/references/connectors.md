# OpenTelemetry Collector: Connectors

## Overview

**Connectors** are a first-class OpenTelemetry Collector component type that act as **both an exporter and a receiver**. A connector bridges two pipelines: it receives data as an exporter on one pipeline and emits data as a receiver on another. This enables cross-pipeline signal routing, aggregation, and transformation patterns that are impossible with standard pipeline stages.

## Table of Contents

1. [What Are Connectors?](#what-are-connectors)
2. [Production-Relevant Connectors](#production-relevant-connectors)
3. [spanmetricsconnector: R.E.D. Metrics from Traces](#spanmetricsconnector-red-metrics-from-traces)
4. [servicegraphconnector: Dependency Graphs](#servicegraphconnector-dependency-graphs)
5. [routingconnector: Attribute-Based Pipeline Routing](#routingconnector-attribute-based-pipeline-routing)
6. [failoverconnector: Automatic Pipeline Failover](#failoverconnector-automatic-pipeline-failover)
7. [countconnector: Signal Counting](#countconnector-signal-counting)
8. [signaltometricsconnector: Any Signal to Metrics](#signaltometricsconnector-any-signal-to-metrics)
9. [Connector Pipeline Patterns](#connector-pipeline-patterns)
10. [Stability Levels](#stability-levels)

---

## What Are Connectors?

A connector simultaneously acts as:

- **Exporter** (consuming data from a source pipeline)
- **Receiver** (emitting data into a destination pipeline)

```
Pipeline A (Traces) → [connector as exporter] → [connector as receiver] → Pipeline B (Metrics)
```

### Service Pipeline Definition

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [spanmetrics]          # connector as exporter

    metrics:
      receivers: [spanmetrics]          # same connector as receiver
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

---

## Production-Relevant Connectors

| Connector | Purpose | Source Signal | Output Signal | Stability |
|-----------|---------|---------------|---------------|-----------|
| `spanmetricsconnector` | R.E.D. metrics from traces | Traces | Metrics | Beta |
| `servicegraphconnector` | Service dependency graph | Traces | Metrics | Beta |
| `routingconnector` | Attribute-based pipeline routing | Any | Same signal | Alpha |
| `failoverconnector` | Automatic pipeline failover | Any | Same signal | Alpha |
| `countconnector` | Count signals as metrics | Any | Metrics | Alpha |
| `signaltometricsconnector` | Convert any signal to metrics | Any | Metrics | Alpha |

---

## spanmetricsconnector: R.E.D. Metrics from Traces

Generates **R.E.D. metrics** (Rate, Errors, Duration) from trace spans without requiring a separate agent or post-processing step.

### Generated Metrics

- `traces.span.metrics.calls` (counter): Request rate and error rate
- `traces.span.metrics.duration` (histogram): Latency distribution

### Configuration

```yaml
connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000]  # milliseconds
    dimensions:
      - name: http.request.method
        default: GET
      - name: http.response.status_code
      - name: service.name
    exemplars:
      enabled: true              # Link metrics to traces via exemplars
    metrics_flush_interval: 60s

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp, spanmetrics]

    metrics:
      receivers: [otlp, spanmetrics]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

### ⚠️ Stickiness Requirement

`spanmetricsconnector` is **stateful** — it aggregates metrics in-memory across spans. In a multi-replica gateway deployment, all spans for the same service or trace must route to the **same collector instance**.

```yaml
exporters:
  loadbalancing:
    routing_key: traceID
    protocol:
      otlp:
        tls:
          insecure: true
    resolver:
      k8s:
        service: otel-gateway-headless  # ⚠️ must be Headless Service
```

### Cardinality Warning

⚠️ Apply the **Rule of 100**: only include dimensions with fewer than 100 unique values. Never use `user.id`, `request.id`, or raw `url.path` as dimensions.

---

## servicegraphconnector: Dependency Graphs

Generates **service dependency graph metrics** showing request rates and error rates between pairs of services.

### Generated Metrics

- `traces.service.graph.request.total` (counter)
- `traces.service.graph.request.failed.total` (counter)
- `traces.service.graph.request.duration` (histogram)
- `traces.service.graph.unpaired_spans_total` (counter)

### Configuration

```yaml
connectors:
  servicegraph:
    latency_histogram_buckets: [1, 2, 6, 10, 100, 250]  # milliseconds
    dimensions:
      - http.request.method
    store:
      ttl: 2s
      max_items: 10000

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp, servicegraph]

    metrics:
      receivers: [otlp, servicegraph]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

⚠️ Like `spanmetricsconnector`, requires sticky routing — use `loadbalancing` exporter with `routing_key: traceID`.

---

## routingconnector: Attribute-Based Pipeline Routing

Routes signals to different pipelines based on attribute values.

```yaml
connectors:
  routing:
    default_pipelines: [traces/default]
    error_mode: ignore
    table:
      - statement: route() where attributes["tenant.id"] == "us-east"
        pipelines: [traces/us_east]
      - statement: route() where attributes["env"] == "prod"
        pipelines: [traces/prod]

service:
  pipelines:
    traces/in:
      receivers: [otlp]
      processors: [memory_limiter]
      exporters: [routing]

    traces/us_east:
      receivers: [routing]
      processors: [batch]
      exporters: [otlp/us_east]

    traces/default:
      receivers: [routing]
      processors: [batch]
      exporters: [otlp/default]
```

✅ Use low-cardinality, deterministic attributes (`tenant.id`, `env`, `cluster`)
❌ Do not route on high-cardinality attributes (`user.id`, `request.id`)

---

## failoverconnector: Automatic Pipeline Failover

Provides automatic failover between pipelines based on health/error conditions.

```yaml
connectors:
  failover:
    priority_levels:
      - [traces/primary]
      - [traces/secondary]
    retry_interval: 10m
    retry_gap: 10s
    max_retries: 3

service:
  pipelines:
    traces/in:
      receivers: [otlp]
      processors: [memory_limiter]
      exporters: [failover]

    traces/primary:
      receivers: [failover]
      processors: [batch]
      exporters: [otlp/primary]

    traces/secondary:
      receivers: [failover]
      processors: [batch]
      exporters: [otlp/secondary]
```

---

## countconnector: Signal Counting

Counts telemetry signals and emits the counts as metrics. Useful for SLI instrumentation.

```yaml
connectors:
  count:
    spans:
      - name: trace.span.count
        description: Total spans processed
        conditions:
          - 'attributes["http.route"] != nil'
        attributes:
          - key: http.request.method
          - key: http.response.status_code
          - key: service.name

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp, count]

    metrics:
      receivers: [otlp, count]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

---

## signaltometricsconnector: Any Signal to Metrics

Converts any signal type to metrics using OTTL expressions. More flexible than `spanmetricsconnector`.

```yaml
connectors:
  signaltometrics:
    spans:
      - name: http.server.request.duration
        description: HTTP server request duration from spans
        unit: ms
        histogram:
          value: Milliseconds(end_time - start_time)
          bucket_boundaries: [0, 5, 10, 25, 50, 100, 250, 500, 1000]
          attributes:
            - key: http.request.method
            - key: http.route
            - key: http.response.status_code
```

---

## Connector Pipeline Patterns

### Full Observability Stack (Traces + Metrics + Graphs)

```yaml
connectors:
  spanmetrics: {}
  servicegraph: {}

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, k8sattributes, batch]
      exporters: [otlp, spanmetrics, servicegraph]

    metrics:
      receivers: [otlp, spanmetrics, servicegraph]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

### Multi-Tenant Routing with Fallback

```yaml
connectors:
  routing:
    default_pipelines: [traces/default]
    table:
      - statement: route() where resource.attributes["tenant.id"] == "acme"
        pipelines: [traces/acme]

service:
  pipelines:
    traces/in:
      receivers: [otlp]
      processors: [memory_limiter]
      exporters: [routing]
    traces/acme:
      receivers: [routing]
      processors: [batch]
      exporters: [otlp/acme_backend]
    traces/default:
      receivers: [routing]
      processors: [batch]
      exporters: [otlp/shared_backend]
```

---

## Stability Levels

⚠️ **Check stability before production use**:

| Connector | Stability | Notes |
|-----------|-----------|-------|
| `spanmetricsconnector` | **Beta** | Feature-complete, minor breaking changes possible |
| `servicegraphconnector` | **Beta** | Feature-complete, minor breaking changes possible |
| `routingconnector` | **Alpha** | Experimental — test thoroughly before production |
| `failoverconnector` | **Alpha** | Experimental — test thoroughly before production |
| `countconnector` | **Alpha** | Experimental — test thoroughly before production |
| `signaltometricsconnector` | **Alpha** | Experimental — test thoroughly before production |

## Summary

✅ Use **spanmetricsconnector** to generate R.E.D. metrics from traces
✅ Use **servicegraphconnector** to build service dependency maps
✅ Use **routingconnector** for attribute-based multi-tenant routing
✅ Use **failoverconnector** for cross-region failover
✅ Always pair **stateful connectors** (spanmetrics, servicegraph) with `loadbalancing` exporter and `routing_key: traceID`
✅ Check **stability levels** — only spanmetrics and servicegraph are Beta
⚠️ Avoid **high-cardinality dimensions** in spanmetrics/servicegraph

## Reference Links

- [Connectors Documentation](https://opentelemetry.io/docs/collector/configuration/#connectors)
- [Connector Components (Contrib)](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector)
- [spanmetricsconnector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector)
- [servicegraphconnector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/servicegraphconnector)
