# OpenTelemetry Sampling Strategies

Sampling reduces the volume of trace data ingested and stored without eliminating observability into system behavior.
This document covers head sampling (SDK-side), tail sampling (Collector-side), and the infrastructure needed to support
each.

---

## Head Sampling (SDK-Side)

In head sampling, the sampling decision is made at the **start** of a request, before any work is done. The decision
propagates through the entire call chain via the W3C `tracestate` header.

### Configuration via Environment Variables

```bash
# Sample 10% of all new traces (ratio = 0.1)
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1
```

### `parentbased_traceidratio` Sampler

This is the recommended sampler for most applications:

- If a **parent span** exists and is **sampled** → this span is sampled.
- If a **parent span** exists and is **not sampled** → this span is not sampled.
- If there is **no parent** (root span) → sample with the given ratio.

This ensures consistent sampling across service boundaries: if a trace is sampled in service A, all downstream services
B and C will also sample their spans for that trace.

```bash
# Sample 5% of root spans; respect parent's decision for child spans
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.05
```

### Other SDK Samplers

| Sampler | Behavior |
|---|---|
| `always_on` | Sample 100% (default if unset) |
| `always_off` | Sample 0% (discard all) |
| `traceidratio` | Sample N% regardless of parent decision |
| `parentbased_always_on` | Respect parent; 100% for roots |
| `parentbased_always_off` | Respect parent; 0% for roots |
| `parentbased_traceidratio` | Respect parent; N% for roots (recommended) |

---

## Why to Avoid SDK-Side Sampling in Production

Head sampling makes a decision before the request completes. This creates several problems:

1. **Errors are sampled by chance.** A 1% sampling rate means 99% of errors are dropped.
2. **Slow requests are sampled by chance.** P99 latency events are statistically under-represented.
3. **You can't sample by outcome.** You only know the outcome (error, slow, interesting) after the request finishes.
4. **Distributed inconsistency.** Different services may run different sampler configurations, causing broken traces.

**Prefer Collector-side tail sampling** for production. Use SDK head sampling only as a last-resort volume reducer
before the Collector, or in development environments.

---

## Tail Sampling (Collector-Side)

The `tailsampling` processor holds trace spans in memory until the full trace is assembled (or a timeout is reached),
then evaluates policies against the complete trace.

### Prerequisites

Tail sampling requires that **all spans of a single trace arrive at the same Collector instance**. In a multi-Collector
gateway setup, use a load balancing exporter (see below) to route by `traceId`.

### Configuration

```yaml
processors:
  tail_sampling:
    # How long to wait for a complete trace before making a decision
    decision_wait: 10s
    # Number of trace batches to buffer (each batch = 100 traces by default)
    num_traces: 50000
    # Evaluation interval
    decision_cache:
      sampled_cache_size: 100000
    policies:
      # Policy 1: Always sample traces with errors
      - name: sample-errors
        type: status_code
        status_code:
          status_codes: [ERROR]

      # Policy 2: Always sample slow requests (>1 second)
      - name: sample-slow-traces
        type: latency
        latency:
          threshold_ms: 1000

      # Policy 3: Always sample traces from critical services by attribute
      - name: sample-critical-services
        type: string_attribute
        string_attribute:
          key: service.name
          values:
            - payment-service
            - auth-service
            - checkout-service
          enabled_regex_matching: false

      # Policy 4: Probabilistic fallback for everything else (1%)
      - name: probabilistic-fallback
        type: probabilistic
        probabilistic:
          sampling_percentage: 1

      # Policy 5: Composite — sample 10% of traces that are neither errors nor slow
      # (Alternative to a pure probabilistic fallback)
      - name: composite-normal-traffic
        type: composite
        composite:
          max_total_spans_per_second: 1000
          policy_order:
            - sample-errors
            - sample-slow-traces
            - sample-critical-services
          composite_sub_policy:
            - name: probabilistic-base
              type: probabilistic
              probabilistic:
                sampling_percentage: 10
          rate_allocation:
            - policy: sample-errors
              percent: 30
            - policy: sample-slow-traces
              percent: 30
            - policy: sample-critical-services
              percent: 30
            - policy: probabilistic-base
              percent: 10
```

### Policy Types Reference

| Policy Type | `type` Value | Key Setting | Use Case |
|---|---|---|---|
| Error traces | `status_code` | `status_codes: [ERROR]` | Capture all failures |
| Slow traces | `latency` | `threshold_ms: <N>` | Capture performance issues |
| By attribute value | `string_attribute` | `key`, `values` | Critical services, tenants |
| By numeric attribute | `numeric_attribute` | `key`, `min_value`, `max_value` | Error counts, span counts |
| Rate-limited | `rate_limiting` | `spans_per_second` | Cap volume for noisy services |
| Probabilistic | `probabilistic` | `sampling_percentage` | Statistical baseline |
| Span count | `span_count` | `min_spans`, `max_spans` | Filter trivially short traces |
| Always sample | `always_sample` | (none) | Debug pipelines |
| Composite | `composite` | `max_total_spans_per_second` | Combine multiple policies with rate limits |

---

## Load Balancing Exporter

Tail sampling requires all spans of a trace to arrive at the same Collector instance. The `loadbalancing` exporter
solves this by consistently routing traces to the same downstream Collector based on `traceId`.

### Architecture

```text
Application Pods
      │  OTLP
      ▼
┌─────────────────┐
│  Agent Collector │  (DaemonSet — no tail sampling)
│  passthrough     │
└────────┬────────┘
         │ OTLP (load balanced by traceId)
         ▼
┌────────────────────────────────────────────────────┐
│          Gateway Collector (Deployment, 3 replicas) │
│  tail_sampling processor                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐         │
│  │ replica 0│  │ replica 1│  │ replica 2│         │
└──┴──────────┴──┴──────────┴──┴──────────┴─────────┘
         │ OTLP
         ▼
    OTLP Backend
```

### Agent Configuration (with load balancing exporter)

```yaml
exporters:
  loadbalancing:
    protocol:
      otlp:
        timeout: 10s
        tls:
          insecure: false
        sending_queue:
          enabled: true
          queue_size: 1000
        retry_on_failure:
          enabled: true
    resolver:
      # DNS-based discovery: resolves to all pod IPs of the gateway headless service
      dns:
        hostname: otelcol-gateway-headless.monitoring.svc.cluster.local
        port: 4317
        interval: 5s
        timeout: 1s
      # Alternative: static list of gateway addresses
      # static:
      #   hostnames:
      #     - otelcol-gateway-0.monitoring.svc.cluster.local:4317
      #     - otelcol-gateway-1.monitoring.svc.cluster.local:4317
      #     - otelcol-gateway-2.monitoring.svc.cluster.local:4317

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter]   # Minimal processing on the agent
      exporters: [loadbalancing]
```

Create a Kubernetes headless service for DNS-based discovery:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: otelcol-gateway-headless
  namespace: monitoring
spec:
  clusterIP: None     # Headless — returns all pod IPs
  selector:
    app: otelcol-gateway
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
```

### Gateway Configuration (with tail sampling)

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 80
    spike_limit_percentage: 25
  tail_sampling:
    decision_wait: 10s
    num_traces: 50000
    policies:
      - name: sample-errors
        type: status_code
        status_code:
          status_codes: [ERROR]
      - name: sample-slow
        type: latency
        latency:
          threshold_ms: 500
      - name: probabilistic-fallback
        type: probabilistic
        probabilistic:
          sampling_percentage: 5
  batch:
    timeout: 5s

exporters:
  otlp:
    endpoint: <OTLP_BACKEND_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:OTLP_AUTH_TOKEN}"
    compression: gzip

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, tail_sampling, batch]
      exporters: [otlp]
```

---

## Probability-Based Sampling with Span Metrics

When using probabilistic sampling, span metrics (RED metrics derived from traces) will undercount unless the sampling
rate is accounted for. Use the `spanmetrics` connector combined with consistent sampling ratio metadata.

```yaml
connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2s, 5s]
    dimensions:
      - name: service.name
      - name: http.method
      - name: http.status_code
      # Include sampling ratio for downstream rate correction
      - name: sampling.ratio

service:
  pipelines:
    # Generate span metrics BEFORE sampling (from all traces)
    traces/pre-sample:
      receivers: [otlp]
      processors: [memory_limiter, k8sattributes]
      exporters: [spanmetrics, tail_sampling_connector]

    # After sampling: export sampled spans to backend
    traces/sampled:
      receivers: [tail_sampling_connector]
      processors: [batch]
      exporters: [otlp]

    # Span metrics go to the metrics pipeline
    metrics:
      receivers: [spanmetrics]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| SDK `parentbased_traceidratio` in production without Collector tail sampling | Errors and slow requests are sampled by chance; broken traces across services | Use tail sampling at the Collector; set SDK sampler to `always_on` or 100% |
| Tail sampling with multiple Collector replicas but no load balancing | Different replicas receive different spans of the same trace; incomplete traces → wrong decisions | Use the `loadbalancing` exporter before gateway Collectors |
| `decision_wait` too short (e.g., 1s) | Slow spans arrive after the decision window; traces appear incomplete | Set `decision_wait` to at least 2× your P99 request latency (minimum 5s) |
| `num_traces` too small | Old traces evicted before all spans arrive; incomplete trace decisions | Size for (requests/s × `decision_wait`) × 2 headroom |
| Generating span metrics after tail sampling | Metrics reflect only sampled traces, not actual traffic | Generate span metrics from unsampled data before the tail sampling stage |
| Using `traceidratio` (non-parentbased) SDK sampler | Inconsistent decisions: parent says sample, child says drop → broken traces | Use `parentbased_traceidratio` or disable SDK sampling entirely |
| Running tail sampling on the same Collector as the `loadbalancing` exporter | Load balancer and tail sampler fight each other | Separate agents (with `loadbalancing` exporter) from gateways (with `tail_sampling`) |

---

## References

- [Tail Sampling Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/tailsamplingprocessor)
- [Load Balancing Exporter](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/loadbalancingexporter)
- [Spanmetrics Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector)
- [OpenTelemetry SDK Sampling](https://opentelemetry.io/docs/concepts/sampling/)
- [SDK Environment Variables — Sampler](https://opentelemetry.io/docs/languages/sdk-configuration/general/#otel_traces_sampler)
- [Sampling Guidance (OTel Docs)](https://opentelemetry.io/docs/collector/scaling/#sampling)
