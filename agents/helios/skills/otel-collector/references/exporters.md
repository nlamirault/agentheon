# OpenTelemetry Collector Exporters

Exporters send telemetry data from the Collector to a backend or another Collector. The OTLP exporter is the standard
choice for forwarding to any OTLP-compatible backend.

---

## Protocol Selection: gRPC vs HTTP

| Dimension | OTLP/gRPC (`otlp`) | OTLP/HTTP (`otlphttp`) |
|---|---|---|
| Default port | 4317 | 4318 |
| Transport | HTTP/2 + binary Protobuf | HTTP/1.1 or HTTP/2 + JSON or Protobuf |
| Multiplexing | Yes (HTTP/2 streams) | Limited (HTTP/1.1 one request at a time) |
| Firewall friendliness | Some proxies block HTTP/2 | Works through any HTTP proxy |
| TLS required for auth | Recommended | Recommended |
| Overhead per request | Lower (long-lived connections) | Slightly higher |
| **Recommendation** | Default choice for Collector-to-Collector | Use when gRPC is blocked or for serverless |

---

## OTLP/gRPC Exporter

### Minimal Configuration

```yaml
exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:OTLP_AUTH_TOKEN}"
```

- `<OTLP_ENDPOINT>` — replace with your backend's hostname (no scheme; gRPC uses h2 directly).
- `${env:OTLP_AUTH_TOKEN}` — read the token from an environment variable (see Authentication section).
- TLS is enabled by default when connecting to port 4317 unless `tls.insecure: true` is set.

### Production Configuration

```yaml
exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:OTLP_AUTH_TOKEN}"
    compression: gzip
    timeout: 30s
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
    tls:
      insecure: false
      # Optional: override CA for self-signed certs
      # ca_file: /etc/otelcol/certs/ca.crt
```

### gRPC Keepalive

Configure keepalive to detect dead connections proactively rather than waiting for a request to time out:

```yaml
exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    keepalive:
      time: 30s           # Send keepalive pings every 30s
      timeout: 5s         # Consider connection dead if no response within 5s
      permit_without_stream: true  # Send pings even without active streams
```

### DNS-Based Load Balancing

When the endpoint resolves to multiple IPs (e.g., a Kubernetes headless service), the gRPC client uses `round_robin`
load balancing by default. This distributes load across all resolved addresses automatically.

---

## Compression

Compression reduces egress bandwidth. `gzip` is the standard choice; `zstd` offers better ratios at slightly higher CPU
cost.

```yaml
exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    compression: gzip   # Options: none, gzip, snappy, zstd, zlib, deflate, lz4
```

Typical savings: **60-80%** for trace data, **40-60%** for metrics, depending on cardinality and label verbosity.

---

## Retry on Failure

The `retry_on_failure` block controls exponential back-off when the backend returns retryable errors (HTTP 429, 503).

| Setting | Default | Recommendation | Notes |
|---|---|---|---|
| `enabled` | `true` | `true` | Always enable in production |
| `initial_interval` | `5s` | `5s` | First retry delay |
| `max_interval` | `30s` | `30s` | Maximum delay between retries |
| `max_elapsed_time` | `300s` | `300s` (5 min) | Set to `0` for infinite retries |

```yaml
retry_on_failure:
  enabled: true
  initial_interval: 5s
  max_interval: 30s
  max_elapsed_time: 300s
```

---

## Sending Queue with File Storage

The in-memory sending queue is lost on Collector restart. Use the `file_storage` extension to persist the queue to disk,
preventing data loss during rolling restarts or brief backend outages.

### Extension Configuration

```yaml
extensions:
  file_storage/queue:
    directory: /var/lib/otelcol/queue
    timeout: 10s
    compaction:
      on_start: true
      on_rebound: true
      rebound_needed_threshold_mib: 100
      rebound_trigger_threshold_mib: 10
      max_transaction_size: 65_536
```

### Exporter with Persistent Queue

```yaml
exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:OTLP_AUTH_TOKEN}"
    compression: gzip
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 10000
      storage: file_storage/queue  # Reference the extension
```

Ensure the storage directory is writable and backed by a persistent volume in Kubernetes:

```yaml
# PersistentVolumeClaim
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: otelcol-queue
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
```

---

## Authentication

### Use Environment Variables, Never Hardcoded Tokens

**BAD** — token visible in ConfigMap, leaks into version control:

```yaml
# DO NOT DO THIS
exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer supersecrettoken123"
```

**GOOD** — token injected at runtime from a Kubernetes Secret:

```yaml
exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:OTLP_AUTH_TOKEN}"
```

Inject the environment variable from a Kubernetes Secret:

```yaml
# In the Collector Deployment/DaemonSet spec
env:
  - name: OTLP_AUTH_TOKEN
    valueFrom:
      secretKeyRef:
        name: otelcol-auth
        key: token
```

Create the secret:

```bash
kubectl create secret generic otelcol-auth \
  --from-literal=token=<your-token> \
  --namespace monitoring
```

### Using the `basicauth` Extension

For username/password auth, use the `basicauth` extension rather than base64-encoding manually:

```yaml
extensions:
  basicauth/backend:
    client_auth:
      username: ${env:OTLP_USERNAME}
      password: ${env:OTLP_PASSWORD}

exporters:
  otlphttp:
    endpoint: https://<OTLP_ENDPOINT>:4318
    auth:
      authenticator: basicauth/backend
```

---

## OTLP/HTTP Exporter

```yaml
exporters:
  otlphttp:
    endpoint: https://<OTLP_ENDPOINT>:4318
    headers:
      Authorization: "Bearer ${env:OTLP_AUTH_TOKEN}"
    compression: gzip
    encoding: proto   # Options: proto (binary, default), json (text, larger payloads)
    timeout: 30s
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
    # Override individual signal endpoints (optional — must be full paths)
    traces_endpoint: https://<OTLP_ENDPOINT>:4318/v1/traces
    metrics_endpoint: https://<OTLP_ENDPOINT>:4318/v1/metrics
    logs_endpoint: https://<OTLP_ENDPOINT>:4318/v1/logs
```

Notes:

- For `otlphttp`, the `endpoint` includes the scheme (`https://`). For `otlp` (gRPC), it does not.
- When using `endpoint` (without signal-specific overrides), the Collector automatically appends `/v1/traces`,
  `/v1/metrics`, `/v1/logs`. When using `traces_endpoint` / `metrics_endpoint` / `logs_endpoint`, provide the full path
  including the signal suffix.
- `encoding: json` produces significantly larger payloads and higher CPU usage. Use `proto` (default) in production.

---

## Monitoring Exporter Health

Key metrics exposed on the Collector's telemetry endpoint (`0.0.0.0:8888`):

| Metric | Description |
|---|---|
| `otelcol_exporter_sent_spans` | Spans successfully exported |
| `otelcol_exporter_send_failed_spans` | Spans that failed export after retries |
| `otelcol_exporter_queue_size` | Current depth of the sending queue |
| `otelcol_exporter_queue_capacity` | Maximum queue capacity |
| `otelcol_exporter_enqueue_failed_spans` | Spans dropped because the queue was full |

Alert on `otelcol_exporter_send_failed_spans > 0` (data loss) and
`otelcol_exporter_queue_size / otelcol_exporter_queue_capacity > 0.8` (queue saturation).

---

## Debug Exporter

Use the `debug` exporter during development to print telemetry to stdout.
**Never use `verbosity: detailed` in production** — it logs every attribute of every span/metric/log record. Output goes
to **stderr** (check via `kubectl logs`, `docker logs`, or `journalctl`).

```yaml
exporters:
  debug:
    verbosity: basic  # Options: basic, normal, detailed
    sampling_initial: 5      # Records to log per second on startup
    sampling_thereafter: 200 # Log 1 per N records for sustained traffic
```

| Verbosity Level | Output | Use Case |
|---|---|---|
| `basic` | Signal counts only (e.g., "5 spans") | Verify data is flowing |
| `normal` | Resource and scope attributes, basic span info | Debugging attribute propagation |
| `detailed` | All attributes of all records with explicit types | Deep debugging — high volume output |

`sampling_initial` and `sampling_thereafter` control log output rate to avoid flooding stderr.

### Chained Debug Exporters (Before/After Comparison)

To compare telemetry before and after a processor, chain pipelines using an internal OTLP receiver/exporter pair:

```yaml
exporters:
  debug/raw:
    verbosity: detailed
  debug/processed:
    verbosity: detailed
  otlp/internal:
    endpoint: localhost:4317
    tls:
      insecure: true

receivers:
  otlp/internal:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  transform/my_transform:
    # ... your transform under test

service:
  pipelines:
    traces/before:
      receivers: [otlp]
      processors: []
      exporters: [debug/raw, otlp/internal]   # Print raw, forward to next pipeline

    traces/after:
      receivers: [otlp/internal]
      processors: [transform/my_transform]
      exporters: [debug/processed]             # Print after transform
```

This lets you see the exact diff caused by a processor without modifying the main pipeline.

---

## Multiple Exporters

Send the same telemetry to multiple backends by listing both exporters in the pipeline:

```yaml
exporters:
  otlp/primary:
    endpoint: <PRIMARY_OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:PRIMARY_AUTH_TOKEN}"
    compression: gzip

  otlp/secondary:
    endpoint: <SECONDARY_OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:SECONDARY_AUTH_TOKEN}"
    compression: gzip

  debug:
    verbosity: basic

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/primary, otlp/secondary, debug]
```

The Collector fans out to all listed exporters. If one exporter fails, others are unaffected.

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Hardcoded auth tokens in ConfigMap | Credentials leak into version control and etcd | Use `${env:VAR}` with Kubernetes `secretKeyRef` |
| No `retry_on_failure` | Data lost on transient backend errors | Enable retry with appropriate `max_elapsed_time` |
| No `sending_queue` | Data lost on Collector restart | Enable queue, use `file_storage` for persistence |
| `verbosity: detailed` in production | Floods logs; can cause memory pressure | Use `basic` in production, `detailed` only for short debug sessions |
| Single exporter for all signals without named instances | Can't tune settings per signal type | Use named instances: `otlp/traces`, `otlp/metrics`, `otlp/logs` |
| Missing `compression` | Unnecessary egress cost | Always set `compression: gzip` |
| `tls.insecure: true` in production | Exposes auth tokens and telemetry to interception | Use TLS everywhere; only disable in local development |

---

## References

- [OTLP Exporter](https://github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/otlpexporter)
- [OTLP HTTP Exporter](https://github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/otlphttpexporter)
- [Debug Exporter](https://github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/debugexporter)
- [File Storage Extension](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/storage/filestorage)
- [Basic Auth Extension](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/basicauthextension)
- [Sending Queue and Retry](https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/exporterhelper/README.md)
