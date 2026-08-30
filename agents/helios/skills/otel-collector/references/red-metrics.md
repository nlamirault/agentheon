# RED Metrics from Traces

RED metrics — **Rate**, **Errors**, **Duration** — are the three signals that characterise the health of a service from
the perspective of its callers. Rather than instrumenting metrics separately, you can derive them from trace spans
inside the Collector using the `spanmetrics` connector. This gives you consistent metrics that are structurally
identical to the underlying traces, simplifying root-cause analysis.

## What Are RED Metrics?

| Signal | Meaning | Derived from spans |
|--------|---------|-------------------|
| **Rate** | Requests per second | Count of spans per time window |
| **Errors** | Fraction of requests that failed | Count of spans with `status.code = ERROR` |
| **Duration** | Latency distribution | Span duration histogram |

### Why span-derived metrics are useful

- **Single source of truth.** The metric values are computed from the same data as your traces. A spike in error rate in
  the metric corresponds exactly to spans with `status.code = ERROR` that you can click through to in your tracing
  backend.
- **Zero application changes.** If your services already emit traces, you get RED metrics for free — no additional
  instrumentation or metric SDK setup required.
- **Exemplars.** The `spanmetrics` connector can attach trace IDs to histogram buckets, enabling one-click navigation
  from a slow P99 bucket in a metrics dashboard directly to a representative trace.
- **Consistent cardinality control.** Dimensions are defined in the Collector configuration, not in application code,
  making cardinality management centrally governable.

---

## spanmetrics Connector Configuration

The `spanmetrics` connector sits between a traces pipeline and a metrics pipeline. It consumes spans and emits metrics.

```yaml
connectors:
  spanmetrics:
    # Namespace prefix for generated metric names.
    # Produces: calls_total, duration_milliseconds_bucket, etc.
    namespace: traces

    # Dimensions are span attributes extracted as metric label dimensions.
    # Keep this list short — each unique combination creates a new time series.
    dimensions:
      - name: service.name
      - name: http.method
        default: GET
      - name: http.status_code
        default: "200"
      - name: http.route
        default: ""
      - name: rpc.method
        default: ""
      - name: rpc.service
        default: ""
      - name: db.system
        default: ""

    # Histogram configuration for duration metrics.
    histogram:
      explicit:
        buckets:
          - 5ms
          - 10ms
          - 25ms
          - 50ms
          - 75ms
          - 100ms
          - 250ms
          - 500ms
          - 750ms
          - 1s
          - 2.5s
          - 5s
          - 10s

    # Attach a trace ID as an exemplar to each histogram observation.
    # Requires the metrics exporter to support exemplars (e.g., prometheusremotewrite).
    exemplars:
      enabled: true

    # How long to keep a metric series alive after the last span for it was seen.
    metrics_flush_interval: 15s

    # Only generate metrics for SERVER and CONSUMER spans to avoid double-counting.
    # CLIENT spans represent the caller-side view of the same operation.
    dimensions_cache_size: 1000
    aggregation_temporality: AGGREGATION_TEMPORALITY_CUMULATIVE
```

---

## Full Pipeline Example

This pipeline receives OTLP traces, fans them out to both a trace exporter and the `spanmetrics` connector, and then
exports the generated metrics via Prometheus remote write.

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

connectors:
  spanmetrics:
    namespace: traces
    dimensions:
      - name: service.name
      - name: http.method
        default: GET
      - name: http.status_code
        default: "200"
      - name: http.route
        default: ""
    histogram:
      explicit:
        buckets: [5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2.5s, 5s, 10s]
    exemplars:
      enabled: true
    metrics_flush_interval: 15s
    aggregation_temporality: AGGREGATION_TEMPORALITY_CUMULATIVE

processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 75
    spike_limit_percentage: 20

  batch:
    send_batch_size: 512
    timeout: 10s

exporters:
  # Trace exporter — forward spans to the backend
  otlp:
    endpoint: "${env:OTLP_BACKEND_ENDPOINT}"
    headers:
      authorization: "${env:OTLP_BACKEND_TOKEN}"

  # Metrics exporter — send span-derived metrics via Prometheus remote write
  prometheusremotewrite:
    endpoint: "${env:PROMETHEUS_REMOTE_WRITE_URL}"
    headers:
      authorization: "${env:PROMETHEUS_TOKEN}"
    tls:
      insecure: false
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
    resource_to_telemetry_conversion:
      enabled: true   # Convert resource attributes to metric labels

service:
  pipelines:
    # Traces pipeline: receive spans, process, export to backend AND connector
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp, spanmetrics]   # spanmetrics is a connector, acts as exporter here

    # Metrics pipeline: receive from spanmetrics connector, export to Prometheus
    metrics:
      receivers: [spanmetrics]          # spanmetrics is a connector, acts as receiver here
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite]
```

The `spanmetrics` connector is declared in `connectors:` and then referenced as both an **exporter** in the traces
pipeline and a **receiver** in the metrics pipeline.

---

## Generated Metric Names

With `namespace: traces`, the connector generates the following metrics:

| Metric name | Type | Description |
|-------------|------|-------------|
| `traces_calls_total` | Counter | Total number of spans (requests) |
| `traces_duration_milliseconds_bucket` | Histogram | Span duration distribution |
| `traces_duration_milliseconds_sum` | Gauge | Sum of all span durations |
| `traces_duration_milliseconds_count` | Counter | Total count of measured spans |

---

## Prometheus Queries for RED Metrics

The following PromQL queries assume `namespace: traces` and that `service.name` is a label on the generated metrics.
Adjust the metric name prefix and label names to match your configuration.

### Rate — Requests per second

```promql
# Per-service request rate (5-minute window)
sum(rate(traces_calls_total[5m])) by (service_name)

# Per-route request rate
sum(rate(traces_calls_total[5m])) by (service_name, http_route)
```

### Errors — Error rate

```promql
# Error rate as a fraction (0–1) per service
sum(rate(traces_calls_total{status_code="STATUS_CODE_ERROR"}[5m])) by (service_name)
/
sum(rate(traces_calls_total[5m])) by (service_name)

# Absolute error count per service per second
sum(rate(traces_calls_total{status_code="STATUS_CODE_ERROR"}[5m])) by (service_name)

# HTTP 5xx error rate
sum(rate(traces_calls_total{http_status_code=~"5.."}[5m])) by (service_name, http_route)
/
sum(rate(traces_calls_total[5m])) by (service_name, http_route)
```

### Duration — Latency percentiles

```promql
# P50 latency per service
histogram_quantile(
  0.50,
  sum(rate(traces_duration_milliseconds_bucket[5m])) by (service_name, le)
)

# P95 latency per service
histogram_quantile(
  0.95,
  sum(rate(traces_duration_milliseconds_bucket[5m])) by (service_name, le)
)

# P99 latency per service
histogram_quantile(
  0.99,
  sum(rate(traces_duration_milliseconds_bucket[5m])) by (service_name, le)
)

# P99 latency per route
histogram_quantile(
  0.99,
  sum(rate(traces_duration_milliseconds_bucket[5m])) by (service_name, http_route, le)
)
```

---

## Recommended Dimensions

Choose dimensions carefully. Each unique combination of dimension values creates a separate time series. Dimensions with
high cardinality (e.g., user IDs, request IDs) cause cardinality explosions.

| Dimension | Cardinality | Notes |
|-----------|------------|-------|
| `service.name` | Low | Always include |
| `http.method` | Very low | GET, POST, PUT, DELETE, etc. |
| `http.status_code` | Low | 200, 404, 500, etc. |
| `http.route` | Medium | Use route patterns, not URLs with IDs |
| `rpc.method` | Low | gRPC method name |
| `rpc.service` | Low | gRPC service name |
| `db.system` | Very low | postgresql, mysql, redis, etc. |
| `messaging.system` | Very low | kafka, rabbitmq, etc. |

Do not include high-cardinality attributes such as `http.url`, `http.target`, `db.statement`, user IDs, or session IDs
as spanmetrics dimensions.

---

## References

- [spanmetrics connector documentation](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector)
- [OpenTelemetry Collector connectors](https://opentelemetry.io/docs/collector/configuration/#connectors)
- [Prometheus remote write exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusremotewriteexporter)
- [Exemplars in Prometheus](https://prometheus.io/docs/prometheus/latest/feature_flags/#exemplars-storage)
- [RED method — Tom Wilkie](https://grafana.com/blog/2018/08/02/the-red-method-how-to-instrument-your-services/)
