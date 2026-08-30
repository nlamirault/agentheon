# OpenTelemetry Collector Pipelines

Pipelines are defined in the `service` section of the Collector configuration. They wire together receivers, processors,
and exporters, and they are the unit of signal-type routing.

---

## Service Section Structure

```yaml
service:
  extensions: [health_check, pprof, zpages, file_storage/queue]
  pipelines:
    <signal>[/<name>]:
      receivers:  [<receiver_id>, ...]
      processors: [<processor_id>, ...]   # Optional; ordered
      exporters:  [<exporter_id>, ...]
  telemetry:
    logs:
      level: info
    metrics:
      level: detailed
      address: 0.0.0.0:8888
```

- All components referenced in `pipelines` must be declared in their respective top-level sections (`receivers:`,
  `processors:`, `exporters:`).
- Components declared at the top level but not referenced in any pipeline are ignored (and emit a warning).
- The `processors` list order **is significant** — processors execute left to right.

---

## One Pipeline Per Signal Rule

Each pipeline handles exactly one signal type: `traces`, `metrics`, or `logs`. A component can appear in multiple
pipelines, but cannot process mixed signal types within a single pipeline.

| Signal | Pipeline Key Prefix | Receiver Examples | Exporter Examples |
|---|---|---|---|
| Traces | `traces` | `otlp`, `zipkin`, `jaeger` | `otlp`, `otlphttp`, `debug` |
| Metrics | `metrics` | `otlp`, `prometheus`, `hostmetrics` | `otlp`, `otlphttp`, `prometheus`, `debug` |
| Logs | `logs` | `otlp`, `filelog`, `syslog` | `otlp`, `otlphttp`, `debug` |

---

## Complete Working Configuration

This example shows all three signal pipelines with production-recommended processors and a persistent export queue.

```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
  file_storage/queue:
    directory: /var/lib/otelcol/queue
    timeout: 10s

receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  prometheus:
    config:
      scrape_configs:
        - job_name: otelcol-self
          scrape_interval: 30s
          static_configs:
            - targets: [localhost:8888]
  filelog:
    include: [/var/log/pods/*/*/*.log]
    exclude: [/var/log/pods/*/otelcol/*.log]
    start_at: end
    include_file_path: true
  hostmetrics:
    root_path: /hostfs
    collection_interval: 30s
    scrapers:
      cpu: {}
      memory: {}
      filesystem: {}
      network: {}

processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 80
    spike_limit_percentage: 25
  resourcedetection:
    detectors: [env, k8snode, system]
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
        - k8s.node.name
        - k8s.deployment.name
        - container.image.name
        - container.image.tag
    pod_association:
      - sources:
          - from: resource_attribute
            name: k8s.pod.uid
      - sources:
          - from: connection
  resource/cluster:
    attributes:
      - key: k8s.cluster.name
        value: ${env:K8S_CLUSTER_NAME}
        action: insert
      - key: deployment.environment
        value: ${env:DEPLOYMENT_ENVIRONMENT}
        action: insert
  batch:
    timeout: 5s
    send_batch_size: 512

exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:OTLP_AUTH_TOKEN}"
    compression: gzip
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 10000
      storage: file_storage/queue
  debug:
    verbosity: basic

service:
  extensions: [health_check, file_storage/queue]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, k8sattributes, resource/cluster, batch]
      exporters: [otlp]
    metrics:
      receivers: [otlp, prometheus, hostmetrics]
      processors: [memory_limiter, resourcedetection, k8sattributes, resource/cluster, batch]
      exporters: [otlp]
    logs:
      receivers: [otlp, filelog]
      processors: [memory_limiter, resourcedetection, k8sattributes, resource/cluster, batch]
      exporters: [otlp]
  telemetry:
    logs:
      level: info
    metrics:
      level: detailed
      address: 0.0.0.0:8888
```

---

## Fan-Out (Multiple Exporters)

List multiple exporters in a pipeline to send the same telemetry to multiple destinations simultaneously. The Collector
copies the data to each exporter independently; failure in one does not affect others.

```yaml
exporters:
  otlp/primary:
    endpoint: <PRIMARY_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:PRIMARY_TOKEN}"
    compression: gzip

  otlp/archive:
    endpoint: <ARCHIVE_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:ARCHIVE_TOKEN}"
    compression: gzip

  debug:
    verbosity: basic

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/primary, otlp/archive, debug]
```

---

## Connectors: Routing Between Pipelines

Connectors act as both an exporter (in one pipeline) and a receiver (in another). They are the mechanism for splitting,
merging, or routing telemetry across pipeline boundaries.

### Routing Connector

The `routing` connector forwards data to different exporters (or pipelines) based on attribute values. This is useful
for splitting telemetry by team, namespace, or environment.

```yaml
connectors:
  routing/by_namespace:
    default_pipelines: [metrics/default]
    error_mode: ignore
    table:
      - statement: route() where resource.attributes["k8s.namespace.name"] == "team-alpha"
        pipelines: [metrics/team-alpha]
      - statement: route() where resource.attributes["k8s.namespace.name"] == "team-beta"
        pipelines: [metrics/team-beta]

exporters:
  otlp/team-alpha:
    endpoint: <TEAM_ALPHA_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:TEAM_ALPHA_TOKEN}"
  otlp/team-beta:
    endpoint: <TEAM_BETA_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:TEAM_BETA_TOKEN}"
  otlp/default:
    endpoint: <DEFAULT_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:DEFAULT_TOKEN}"

service:
  pipelines:
    # Ingestion pipeline: receives all metrics, routes to sub-pipelines
    metrics/ingest:
      receivers: [otlp]
      processors: [memory_limiter, k8sattributes]
      exporters: [routing/by_namespace]      # Connector as exporter

    # Per-team pipelines: connector as receiver
    metrics/team-alpha:
      receivers: [routing/by_namespace]
      processors: [batch]
      exporters: [otlp/team-alpha]
    metrics/team-beta:
      receivers: [routing/by_namespace]
      processors: [batch]
      exporters: [otlp/team-beta]
    metrics/default:
      receivers: [routing/by_namespace]
      processors: [batch]
      exporters: [otlp/default]
```

### Spanmetrics Connector

Generates metrics (request rate, error rate, duration histograms) from trace spans:

```yaml
connectors:
  spanmetrics:
    histogram:
      explicit:
        buckets: [2ms, 4ms, 6ms, 8ms, 10ms, 50ms, 100ms, 200ms, 400ms, 800ms, 1s, 1400ms, 2s, 5s, 10s, 15s]
    dimensions:
      - name: http.method
      - name: http.status_code
      - name: service.name
    exemplars:
      enabled: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp, spanmetrics]     # Connector as trace exporter

    metrics:
      receivers: [otlp, spanmetrics]     # Connector as metrics receiver
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

---

## Named Component Instances

Any component can have multiple instances by appending `/<name>` to its type. This allows different configurations for
the same component type in different pipelines.

```yaml
processors:
  batch/traces:
    timeout: 2s          # Traces: lower latency
    send_batch_size: 256
  batch/metrics:
    timeout: 10s         # Metrics: higher throughput
    send_batch_size: 2048
  batch/logs:
    timeout: 5s
    send_batch_size: 512

exporters:
  otlp/traces:
    endpoint: <TRACES_ENDPOINT>:4317
  otlp/metrics:
    endpoint: <METRICS_ENDPOINT>:4317
  otlp/logs:
    endpoint: <LOGS_ENDPOINT>:4317

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch/traces]
      exporters: [otlp/traces]
    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch/metrics]
      exporters: [otlp/metrics]
    logs:
      receivers: [otlp, filelog]
      processors: [memory_limiter, batch/logs]
      exporters: [otlp/logs]
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Referencing an undeclared component in a pipeline | Collector fails to start with a validation error | Ensure every component in a pipeline is declared in its top-level section |
| Mixed signal types in one pipeline | Not supported; Collector rejects the config | Use separate pipelines for traces, metrics, and logs |
| Declaring components but not using them in any pipeline | Silent waste; components are initialized but do nothing | Remove unused declarations or add them to a pipeline |
| Same receiver in multiple pipelines of the same signal type | Receiver runs multiple times → duplicated data | A receiver can only appear in one pipeline per signal; use a connector to fan-out after ingestion |
| `processors` list in wrong order | Incorrect behavior (e.g., filtering before enrichment means filters can't use enriched attributes) | Follow the ordering guidelines in `processors.md` |
| Using `batch` processor after exporters' `sending_queue` | Batching happens at wrong stage; adds latency without benefit | `batch` belongs in `processors`, before the exporter; `sending_queue` is on the exporter itself |
| No `memory_limiter` in any pipeline | Collector OOMs under load | Add `memory_limiter` as the first processor in every pipeline |

---

## References

- [Collector Configuration — Service Section](https://opentelemetry.io/docs/collector/configuration/#service)
- [Connectors](https://opentelemetry.io/docs/collector/configuration/#connectors)
- [Routing Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/routingconnector)
- [Spanmetrics Connector](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/connector/spanmetricsconnector)
- [Building a Pipeline](https://opentelemetry.io/docs/collector/building/)
- [Collector Architecture](https://opentelemetry.io/docs/collector/architecture/)
