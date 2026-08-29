---
name: o11y-traces
description: This skill should be used when the user asks about "distributed tracing", "opentelemetry setup", "trace sampling", "tempo configuration", "jaeger", "trace context propagation", "spans", "service dependency mapping", or needs guidance on implementing distributed tracing.
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - tempo
  - jaeger
  - opentelemetry
  task: [configure, debug]
  persona: [sre, devops]
  workload: [observability]
---

# Observability Traces Expert

Expert guidance on distributed tracing using OpenTelemetry, Tempo, and Jaeger.

## Core Concepts

### When to Use Traces

- Debug request flows across microservices
- Identify latency bottlenecks
- Understand service dependencies
- Root cause analysis for errors

### Traces vs Metrics vs Logs

**Traces**: Show request path through distributed system
**Metrics**: Aggregate statistics (rate, errors, latency)
**Logs**: Discrete events

**Use together**: Link traces to metrics and logs via trace_id

## OpenTelemetry Architecture

```text
Application (OTel SDK)
    ↓
OTel Collector (optional)
    ↓
Tempo/Jaeger (backend)
    ↓
Grafana (visualization)
```

## Instrumentation

### Python Example

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# Setup
trace.set_tracer_provider(TracerProvider())
otlp_exporter = OTLPSpanExporter(endpoint="tempo:4317", insecure=True)
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(otlp_exporter)
)

# Use
tracer = trace.get_tracer(__name__)
with tracer.start_as_current_span("process_request") as span:
    span.set_attribute("user.id", user_id)
    span.set_attribute("http.method", "GET")
    # Your code here
    if error:
        span.set_status(trace.Status(trace.StatusCode.ERROR))
```

### Go Example

```go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

func initTracer() {
    exporter, _ := otlptracegrpc.New(context.Background(),
        otlptracegrpc.WithEndpoint("tempo:4317"),
        otlptracegrpc.WithInsecure(),
    )
    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
    )
    otel.SetTracerProvider(tp)
}

func handler(ctx context.Context) {
    tracer := otel.Tracer("my-service")
    ctx, span := tracer.Start(ctx, "handler")
    defer span.End()

    span.SetAttributes(
        attribute.String("user.id", userID),
    )
}
```

## Sampling Strategies

### Head Sampling

Decision made at trace start (in application):

```yaml
# OTel SDK config
sampler:
  type: parent_based_traceidratio
  config:
    sampling_probability: 0.05 # 5% of traces
```

**Pros**: Low overhead, predictable volume
**Cons**: May miss important traces

### Tail Sampling

Decision made after trace completes (in collector):

```yaml
# OTel Collector config
processors:
  tail_sampling:
    policies:
      - name: errors
        type: status_code
        status_code: { status_codes: [ERROR] }
      - name: slow
        type: latency
        latency: { threshold_ms: 1000 }
      - name: sample
        type: probabilistic
        probabilistic: { sampling_percentage: 1 }
```

**Pros**: Keep all errors and slow traces
**Cons**: Higher resource usage

### Recommendations

- Start with 1-5% head sampling
- Add tail sampling for errors/slow requests
- Increase sampling for low-traffic services

## Tempo Configuration

```yaml
# tempo.yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

storage:
  trace:
    backend: s3
    s3:
      bucket: tempo-traces
      endpoint: s3.amazonaws.com
      region: us-east-1

compactor:
  compaction:
    block_retention: 168h # 7 days

metrics_generator:
  registry:
    external_labels:
      cluster: production
  storage:
    path: /var/tempo/wal
```

## OpenTelemetry Collector

```yaml
# otel-collector.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  memory_limiter:
    check_interval: 1s
    limit_mib: 512

exporters:
  otlp:
    endpoint: tempo:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

## Context Propagation

### W3C Trace Context Headers

```text
traceparent: 00-trace_id-span_id-01
tracestate: vendor1=value1,vendor2=value2
```

### HTTP Context Propagation

```python
# Extract context from incoming request
from opentelemetry.propagate import extract

ctx = extract(request.headers)
with tracer.start_as_current_span("handler", context=ctx):
    # Process request

# Inject context into outgoing request
from opentelemetry.propagate import inject
headers = {}
inject(headers)
requests.get("http://service", headers=headers)
```

## Service Dependency Mapping

Query Tempo for service graph:

```promql
# Service calls per second
sum by (client, server) (
  rate(traces_service_graph_request_total[5m])
)

# Error rate between services
sum by (client, server) (
  rate(traces_service_graph_request_failed_total[5m])
)
/
sum by (client, server) (
  rate(traces_service_graph_request_total[5m])
)
```

## Linking Traces to Logs/Metrics

### Add trace_id to Logs

```python
import logging
from opentelemetry import trace

# Add trace_id to log record
span = trace.get_current_span()
logging.info("Processing request", extra={
    "trace_id": format(span.get_span_context().trace_id, '032x')
})
```

### Link Grafana Dashboards

```json
{
  "datasource": "Tempo",
  "exemplars": {
    "enabled": true,
    "datasource": "Prometheus"
  }
}
```

## Performance Optimization

### Reduce Overhead

- Use head sampling (1-5%)
- Batch span exports
- Use efficient exporters (OTLP gRPC)
- Limit span attributes (< 20 per span)

### Storage Optimization

- Configure retention (7-30 days typical)
- Use object storage (S3/GCS)
- Enable compression
- Tune block sizes

## Troubleshooting

### Traces Not Appearing

1. Check application instrumentation
2. Verify OTel Collector receiving spans
3. Check Tempo ingestion
4. Verify sampling isn't too aggressive

### High Latency

- Use tail sampling (process traces in collector)
- Increase batch sizes
- Scale collectors horizontally

---

**Summary**: Use OpenTelemetry for vendor-neutral distributed tracing. Start with 1-5% sampling, scale as needed. Link
traces to logs/metrics via trace_id.
