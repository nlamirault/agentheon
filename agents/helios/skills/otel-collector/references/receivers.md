# OpenTelemetry Collector Receivers

Receivers are the entry points for telemetry data into the Collector. They listen for incoming data (push-based) or
scrape targets (pull-based) and convert it into the internal pdata representation.

---

## Receiver Selection Decision Table

| Receiver | Signal | Protocol | Use Case |
|---|---|---|---|
| `otlp` | Traces, Metrics, Logs | gRPC / HTTP | Instrumented applications sending OTLP |
| `prometheus` | Metrics | HTTP (pull) | Scraping Prometheus `/metrics` endpoints |
| `filelog` | Logs | File system | Container/pod log files, syslog, application logs |
| `hostmetrics` | Metrics | OS APIs | CPU, memory, disk, network on the host node |

---

## OTLP Receiver

The OTLP receiver is the primary ingestion point for instrumented applications.

### Minimal Configuration

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
```

### Bind Address: `0.0.0.0` vs `localhost`

| Address | Behavior | When to Use |
|---|---|---|
| `0.0.0.0` | Listens on all interfaces | DaemonSet agents, Gateway deployments, Docker |
| `localhost` / `127.0.0.1` | Loopback only | Sidecar containers on the same pod network |

> In Kubernetes, a sidecar Collector and the application container share the same pod network namespace. Use `localhost`
> to restrict access to only that pod.

### gRPC Tuning

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        # Maximum number of concurrent streams per connection
        max_concurrent_streams: 64
        # Maximum size of a received message (default: 4 MiB)
        max_recv_msg_size_mib: 16
        # Keepalive settings
        keepalive:
          server_parameters:
            max_connection_idle: 11s
            max_connection_age: 12s
            max_connection_age_grace: 5s
            time: 30s
            timeout: 5s
          enforcement_policy:
            min_time: 10s
            permit_without_stream: false
```

### TLS Configuration

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        tls:
          cert_file: /etc/otelcol/certs/tls.crt
          key_file: /etc/otelcol/certs/tls.key
          # Optional: require client certificates (mTLS)
          client_ca_file: /etc/otelcol/certs/ca.crt
      http:
        endpoint: 0.0.0.0:4318
        tls:
          cert_file: /etc/otelcol/certs/tls.crt
          key_file: /etc/otelcol/certs/tls.key
```

Mount the TLS certificates via Kubernetes secrets:

```yaml
# In your Collector Deployment/DaemonSet spec
volumes:
  - name: tls-certs
    secret:
      secretName: otelcol-tls
volumeMounts:
  - name: tls-certs
    mountPath: /etc/otelcol/certs
    readOnly: true
```

### CORS Configuration (HTTP only)

Required when the Collector receives telemetry directly from browser-based SDKs (RUM / frontend instrumentation):

```yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
        cors:
          allowed_origins:
            - https://app.example.com
            - https://staging.example.com
          allowed_headers:
            - traceparent
            - tracestate
            - baggage
            - Content-Type
          max_age: 7200
```

> Use the least-privilege origin list. Avoid `allowed_origins: ["*"]` in production — it allows any website to submit
> telemetry to your Collector.

---

## Prometheus Receiver

The Prometheus receiver embeds a Prometheus scrape engine and converts scraped metrics to OTLP.

### Static Targets

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: my-service
          scrape_interval: 30s
          scrape_timeout: 10s
          static_configs:
            - targets:
                - localhost:8080
              labels:
                environment: production
```

### Kubernetes Service Discovery

Scrape all pods that have the `prometheus.io/scrape: "true"` annotation:

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: kubernetes-pods
          scrape_interval: 30s
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            # Only scrape annotated pods
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: "true"
            # Use custom path annotation if present
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            # Use custom port annotation if present
            - source_labels:
                [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
              action: replace
              regex: ([^:]+)(?::\d+)?;(\d+)
              replacement: $1:$2
              target_label: __address__
            # Preserve pod metadata as labels
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
            - source_labels: [__meta_kubernetes_namespace]
              action: replace
              target_label: namespace
            - source_labels: [__meta_kubernetes_pod_name]
              action: replace
              target_label: pod
```

### Metric Relabeling

Drop high-cardinality or unwanted metrics before they enter the pipeline:

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
        - job_name: my-service
          static_configs:
            - targets: [localhost:8080]
          metric_relabel_configs:
            # Drop go runtime internal metrics
            - source_labels: [__name__]
              regex: go_gc_.*
              action: drop
            # Drop label with unbounded cardinality
            - regex: request_id
              action: labeldrop
```

### Target Allocator (Multi-Collector Scaling)

When running multiple Collector replicas, each will scrape the same targets independently, causing duplicate data. The
**Target Allocator** solves this by distributing scrape targets across Collector instances using consistent hashing.

```yaml
receivers:
  prometheus:
    config:
      scrape_configs: []  # Targets come from the Target Allocator
    target_allocator:
      endpoint: http://otel-targetallocator:80
      interval: 30s
      collector_id: ${env:POD_NAME}
```

The Target Allocator is deployed separately (via the OpenTelemetry Operator) and:

- Automatically rebalances targets when Collector instances scale up/down
- Supports Prometheus Operator CRDs (`ServiceMonitor`, `PodMonitor`) for target discovery
- Prevents duplicate scraping without requiring external coordination

> Without the Target Allocator, run a single Collector replica per Prometheus scrape pipeline, or use federation to
> aggregate from multiple single-instance scrapers.

---

## Filelog Receiver

The filelog receiver tails log files and parses them into log records.

### Basic Collection

```yaml
receivers:
  filelog:
    include:
      - /var/log/myapp/*.log
    exclude:
      - /var/log/myapp/*.log.gz
    start_at: end
```

### Multiline Parsing

Parse stack traces and multi-line log entries:

```yaml
receivers:
  filelog:
    include:
      - /var/log/myapp/*.log
    multiline:
      line_start_pattern: '^\d{4}-\d{2}-\d{2}'  # Lines starting with a date
    operators:
      - type: regex_parser
        regex: '^(?P<time>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s+(?P<severity>\w+)\s+(?P<message>.*)$'
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%fZ'
        severity:
          parse_from: attributes.severity
```

### Severity Parsing

Map string severity levels to OpenTelemetry severity numbers:

```yaml
receivers:
  filelog:
    include:
      - /var/log/myapp/*.log
    operators:
      - type: regex_parser
        regex: '^\S+\s+(?P<sev>DEBUG|INFO|WARN|ERROR|FATAL)\s+(?P<msg>.*)$'
        severity:
          parse_from: attributes.sev
          mapping:
            fatal: FATAL
            error: ERROR
            warn: WARN
            info: INFO
            debug: DEBUG
```

### Kubernetes Pod Logs

Container runtimes write logs to `/var/log/pods/` in a structured format. Mount this path in a DaemonSet agent.

**Minimal configuration:**

```yaml
receivers:
  filelog:
    include:
      - /var/log/pods/*/*/*.log
    exclude:
      # Exclude the Collector's own logs to avoid feedback loops
      - /var/log/pods/*/otelcol/*.log
    start_at: end
    include_file_path: true
    include_file_name: false
```

**Production configuration with resource extraction:**

```yaml
receivers:
  filelog:
    include:
      - /var/log/pods/*/*/*.log
    exclude:
      - /var/log/pods/*/otelcol/*.log
    start_at: end
    include_file_path: true
    include_file_name: false
    operators:
      # Parse the containerd/CRI-O log format: timestamp stream flags message
      - type: regex_parser
        id: parse_cri
        regex: '^(?P<time>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z) (?P<stream>stdout|stderr) (?P<flags>[FP]) (?P<log>.*)$'
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%fZ'
      # Move the log field to body
      - type: move
        from: attributes.log
        to: body
      # Extract Kubernetes metadata from the file path
      # Path format: /var/log/pods/<namespace>_<pod-name>_<pod-uid>/<container-name>/<rotation>.log
      - type: regex_parser
        id: parse_k8s_from_path
        parse_from: attributes["log.file.path"]
        regex: '^/var/log/pods/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<pod_uid>[^/]+)/(?P<container_name>[^/]+)/\d+\.log$'
      - type: move
        from: attributes.namespace
        to: resource["k8s.namespace.name"]
      - type: move
        from: attributes.pod_name
        to: resource["k8s.pod.name"]
      - type: move
        from: attributes.pod_uid
        to: resource["k8s.pod.uid"]
      - type: move
        from: attributes.container_name
        to: resource["k8s.container.name"]
      # Remove the raw file path attribute from log record attributes
      - type: remove
        field: attributes["log.file.path"]
```

**Structured JSON logs from pods:**

When application containers emit JSON-formatted logs, parse the JSON body:

```yaml
receivers:
  filelog:
    include:
      - /var/log/pods/*/*/*.log
    exclude:
      - /var/log/pods/*/otelcol/*.log
    start_at: end
    include_file_path: true
    include_file_name: false
    operators:
      - type: regex_parser
        id: parse_cri
        regex: '^(?P<time>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z) (?P<stream>stdout|stderr) (?P<flags>[FP]) (?P<log>.*)$'
        timestamp:
          parse_from: attributes.time
          layout: '%Y-%m-%dT%H:%M:%S.%fZ'
      - type: move
        from: attributes.log
        to: body
      # Attempt JSON parsing; if it fails, leave body as-is
      - type: json_parser
        id: parse_json_body
        if: 'body matches "^\\{"'
        severity:
          parse_from: attributes.level
          preset: default
      - type: regex_parser
        id: parse_k8s_from_path
        parse_from: attributes["log.file.path"]
        regex: '^/var/log/pods/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<pod_uid>[^/]+)/(?P<container_name>[^/]+)/\d+\.log$'
      - type: move
        from: attributes.namespace
        to: resource["k8s.namespace.name"]
      - type: move
        from: attributes.pod_name
        to: resource["k8s.pod.name"]
      - type: move
        from: attributes.pod_uid
        to: resource["k8s.pod.uid"]
      - type: move
        from: attributes.container_name
        to: resource["k8s.container.name"]
```

### Performance Tuning

```yaml
receivers:
  filelog:
    include:
      - /var/log/pods/*/*/*.log
    # Limit concurrent file handles (default: unlimited)
    max_concurrent_files: 1024
    # Polling interval for new data (default: 200ms)
    poll_interval: 200ms
    # Maximum size of a single log entry (default: 1 MiB)
    max_log_size: 1MiB
    # Persist read position across Collector restarts
    storage: file_storage/filepos
```

The `storage` option requires the `file_storage` extension (see exporters.md). Without it, the Collector re-reads files
from the beginning (or `end`) on restart.

### Excluding Collector Logs

Always exclude the Collector's own log files to prevent feedback loops that can cause memory exhaustion:

```yaml
receivers:
  filelog:
    include:
      - /var/log/pods/*/*/*.log
    exclude:
      # Match the namespace and container name of your Collector deployment
      - /var/log/pods/monitoring_otelcol*/*.log
      - /var/log/pods/*/otelcol/*.log
```

---

## Hostmetrics Receiver

The hostmetrics receiver collects OS-level metrics. It must run on the host (DaemonSet with `hostPID: true` or
node-level access).

### Configuration

```yaml
receivers:
  hostmetrics:
    # Root path for filesystem-based collectors when running in a container
    root_path: /hostfs
    collection_interval: 30s
    scrapers:
      cpu:
        metrics:
          system.cpu.utilization:
            enabled: true
      load: {}
      memory:
        metrics:
          system.memory.utilization:
            enabled: true
      disk: {}
      filesystem:
        exclude_mount_points:
          mount_points:
            - /dev/*
            - /proc/*
            - /sys/*
            - /run/k3s/containerd/*
            - /var/lib/docker/*
            - /var/lib/kubelet/*
          match_type: regexp
        exclude_fs_types:
          fs_types:
            - autofs
            - binfmt_misc
            - cgroup
            - cgroup2
            - configfs
            - debugfs
            - devpts
            - devtmpfs
            - fusectl
            - hugetlbfs
            - mqueue
            - nsfs
            - overlay
            - proc
            - procfs
            - pstore
            - rpc_pipefs
            - securityfs
            - selinuxfs
            - squashfs
            - sysfs
            - tracefs
            - tmpfs
          match_type: strict
      network:
        exclude:
          interfaces:
            - lo
          match_type: strict
      paging: {}
      processes: {}
      process:
        # Requires elevated privileges
        mute_process_name_error: true
        mute_process_exe_error: true
        mute_process_io_error: true
```

### Kubernetes DaemonSet Mounts

To correctly resolve host paths inside a container:

```yaml
# DaemonSet spec
env:
  - name: HOST_PROC
    value: /hostfs/proc
  - name: HOST_SYS
    value: /hostfs/sys
  - name: HOST_ETC
    value: /hostfs/etc
  - name: HOST_VAR
    value: /hostfs/var
  - name: HOST_RUN
    value: /hostfs/run
  - name: HOST_DEV
    value: /hostfs/dev
volumeMounts:
  - name: hostfs
    mountPath: /hostfs
    readOnly: true
    mountPropagation: HostToContainer
volumes:
  - name: hostfs
    hostPath:
      path: /
```

### Filesystem Filtering

Always filter virtual and container-overlay filesystems; they produce meaningless metrics and inflate cardinality:

```yaml
scrapers:
  filesystem:
    exclude_fs_types:
      fs_types: [tmpfs, overlay, cgroup, cgroup2, sysfs, proc, devtmpfs]
      match_type: strict
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `endpoint: localhost:4317` in a DaemonSet | Only accessible within the pod, not from other pods on the node | Use `0.0.0.0:4317` |
| Including all `/var/log/pods` without excluding the Collector | Feedback loop causing memory exhaustion | Add `exclude` for the Collector's own container log path |
| No `root_path` for hostmetrics in containers | Reads container's own `/proc` instead of the host's | Set `root_path: /hostfs` and mount the host filesystem |
| Static Prometheus targets in a dynamic cluster | Missed targets as pods scale and reschedule | Use Kubernetes service discovery with pod annotations |
| Scraping every metric from every pod | High cardinality, high cost | Use `metric_relabel_configs` to drop unused metrics early |
| Binding OTLP receiver to `0.0.0.0` in a sidecar | Exposes the receiver to other pods unnecessarily | Use `127.0.0.1` in sidecar deployments |

---

## References

- [OTLP Receiver](https://github.com/open-telemetry/opentelemetry-collector/tree/main/receiver/otlpreceiver)
- [Prometheus Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/prometheusreceiver)
- [Filelog Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver)
- [Hostmetrics Receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/hostmetricsreceiver)
- [Operators Reference](https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/stanza/docs/operators/README.md)
- [OpenTelemetry Collector Configuration](https://opentelemetry.io/docs/collector/configuration/)
