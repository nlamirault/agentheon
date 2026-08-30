# OpenTelemetry Collector Processors

Processors transform, filter, enrich, and control the flow of telemetry data between receivers and exporters. Correct
processor ordering is critical for correctness and stability.

---

## Required: `memory_limiter`

The `memory_limiter` processor **must be the first processor in every pipeline**. It prevents the Collector from running
out of memory by applying back-pressure or dropping data when memory usage exceeds configured limits.

The processor uses two thresholds:

- **Soft limit** (`limit - spike_limit`): sends a non-permanent error to receivers to slow ingestion and allow recovery.
- **Hard limit** (`limit`): forces a garbage collection cycle; if memory is still above the limit, data is dropped.

### Configuration

```yaml
processors:
  memory_limiter:
    # How often to check memory usage
    check_interval: 1s
    # Refuse new data when heap exceeds this percentage of container limit
    limit_percentage: 80
    # Recovery: stop refusing when heap drops below this percentage
    spike_limit_percentage: 25
```

Alternatively, use absolute MiB values (useful when container memory limit is not set):

```yaml
processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 1500
    spike_limit_mib: 350
```

| Setting | Recommendation | Notes |
|---|---|---|
| `check_interval` | `1s` | Lower values add CPU overhead; higher values react slowly |
| `limit_percentage` | `75-80%` | Leave headroom for spike and GC overhead |
| `spike_limit_percentage` | `20-25%` | Must be less than `limit_percentage` |
| `limit_mib` | Container limit × 0.75 | Use when percentage is unavailable |

### Complementary: `GOMEMLIMIT`

Set `GOMEMLIMIT` to 80–90% of the container memory limit as a complementary defense. The Go runtime uses it to trigger
GC more aggressively before the OS-level OOM killer fires, reducing the chance that the `memory_limiter` check interval
fires too late.

```yaml
# In the Collector Deployment/DaemonSet spec
env:
  - name: GOMEMLIMIT
    valueFrom:
      resourceFieldRef:
        resource: limits.memory
        divisor: "1"  # bytes — the Go runtime parses this directly
```

Or set it as a fixed value: `GOMEMLIMIT=1GiB`.

### Monitoring

Key metrics to alert on:

- `otelcol_process_memory_rss` — resident set size; alert if it approaches `limit_mib`
- `otelcol_processor_refused_spans` / `otelcol_processor_refused_log_records` /
  `otelcol_processor_refused_metric_points` — non-zero values mean the limiter is actively dropping data

### Processor Ordering: `memory_limiter` Must Be First

**BAD** — `memory_limiter` placed after enrichment processors:

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors:
        - resourcedetection     # These run before the limiter
        - k8sattributes         # Memory spike can happen here
        - memory_limiter        # Too late — OOM already occurred
        - batch
      exporters: [otlp]
```

**GOOD** — `memory_limiter` is first, limiting admission before any processing:

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors:
        - memory_limiter        # First: gate admission
        - resourcedetection     # Enrich
        - k8sattributes         # Enrich
        - batch                 # Batch for export
      exporters: [otlp]
```

---

## Batching: `batch` Processor + `sending_queue`

### `batch` Processor

The `batch` processor accumulates records in memory and flushes them when either the `timeout` expires OR
`send_batch_size` is reached — whichever comes first. Use `send_batch_max_size` as a hard upper bound to prevent
oversized requests to the backend.

```yaml
processors:
  batch:
    timeout: 5s              # Max wait before flushing regardless of size
    send_batch_size: 512     # Flush when this many records accumulate
    send_batch_max_size: 1024  # Hard limit per request (splits if needed)
```

| Setting | Default | Notes |
|---|---|---|
| `timeout` | `200ms` | Low latency → use lower values; high throughput → use higher values |
| `send_batch_size` | `8192` | Triggers flush when reached; tune to backend limits |
| `send_batch_max_size` | `0` (disabled) | Set to avoid oversized requests; must be ≥ `send_batch_size` |

The `batch` processor is **mandatory for production** pipelines with network exporters. Without it, each record
generates a separate export request.

**Always place `batch` last in the processor chain**, after filtering and transformation — this avoids batching data
that will be dropped.

### Why `batch` Processor Alone Is Insufficient for Durability

The `batch` processor accumulates records in memory. If the Collector restarts before the batch is flushed, all
in-memory data is lost. The `batch` processor has no persistence mechanism.

**BAD** — relying only on the `batch` processor for durability:

```yaml
processors:
  batch:
    timeout: 10s
    send_batch_size: 1000

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

**GOOD** — use `sending_queue` on the exporter (with optional `file_storage`) for persistence; `batch` reduces request
count:

```yaml
processors:
  batch:
    timeout: 5s
    send_batch_size: 512
    send_batch_max_size: 1024

exporters:
  otlp:
    endpoint: <OTLP_ENDPOINT>:4317
    headers:
      Authorization: "Bearer ${env:OTLP_AUTH_TOKEN}"
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 10000
      storage: file_storage/queue  # Survives restarts
    retry_on_failure:
      enabled: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, k8sattributes, batch]
      exporters: [otlp]
```

The `batch` processor reduces the number of export requests (lower overhead per call); the `sending_queue` on the
exporter provides the durability guarantee.

---

## Recommended: `resourcedetection`

The `resourcedetection` processor auto-detects the environment (cloud provider, Kubernetes node, container) and adds
resource attributes to all telemetry.

### Detectors by Environment

| Environment | Detectors | Key Attributes Added |
|---|---|---|
| Kubernetes (any cloud) | `env`, `k8snode` | `k8s.node.name` from `K8S_NODE_NAME` env var |
| AWS EKS | `env`, `eks`, `ec2` | `cloud.provider`, `cloud.region`, `host.id` |
| GCP GKE | `env`, `gcp` | `cloud.provider`, `cloud.region`, `k8s.cluster.name` |
| Azure AKS | `env`, `aks`, `azure` | `cloud.provider`, `cloud.region` |
| Bare metal / VMs | `env`, `system` | `host.name`, `os.type` |
| Docker | `env`, `docker` | `host.name`, `os.type` |

### Configuration

```yaml
processors:
  resourcedetection:
    detectors:
      - env          # Read OTEL_RESOURCE_ATTRIBUTES env var
      - k8snode      # Kubernetes node attributes (requires K8S_NODE_NAME)
      - system       # hostname, OS
    timeout: 5s
    override: false  # Don't overwrite attributes already set by the SDK
```

For `k8snode` detector, inject the node name:

```yaml
# DaemonSet env
env:
  - name: K8S_NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
```

---

## Recommended: `k8sattributes`

The `k8sattributes` processor enriches telemetry with Kubernetes metadata by querying the Kubernetes API. It correlates
telemetry to the pod that sent it using the source IP address or explicit pod UID/name attributes.

### Full Configuration

```yaml
processors:
  k8sattributes:
    auth_type: serviceAccount   # Use the pod's service account (default)
    passthrough: false          # Set to true in agent mode; false in gateway mode
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.pod.name
        - k8s.pod.uid
        - k8s.pod.start_time
        - k8s.node.name
        - k8s.replicaset.name
        - k8s.replicaset.uid
        - k8s.deployment.name
        - k8s.statefulset.name
        - k8s.statefulset.uid
        - k8s.daemonset.name
        - k8s.daemonset.uid
        - k8s.job.name
        - k8s.job.uid
        - k8s.cronjob.name
        - k8s.cluster.uid
        - container.image.name
        - container.image.tag
        - container.id
      labels:
        - tag_name: app.kubernetes.io/name
          key: app.kubernetes.io/name
          from: pod
        - tag_name: app.kubernetes.io/version
          key: app.kubernetes.io/version
          from: pod
      annotations:
        - tag_name: prometheus.io/scrape
          key: prometheus.io/scrape
          from: pod
    pod_association:
      # Try these strategies in order to identify the source pod
      - sources:
          - from: resource_attribute
            name: k8s.pod.ip
      - sources:
          - from: resource_attribute
            name: k8s.pod.uid
      - sources:
          - from: resource_attribute
            name: k8s.pod.name
          - from: resource_attribute
            name: k8s.namespace.name
      - sources:
          - from: connection
            # Use the sender's IP as last resort (requires network access)
    filter:
      node_from_env_var: K8S_NODE_NAME  # Only cache pods on this node (DaemonSet)
```

### Pod Association Strategies

| Strategy | `from` | `name` | When to Use |
|---|---|---|---|
| Pod IP | `resource_attribute` | `k8s.pod.ip` | Most common; set by SDK via `OTEL_RESOURCE_ATTRIBUTES` |
| Pod UID | `resource_attribute` | `k8s.pod.uid` | More reliable than IP; set by SDK or downward API |
| Pod name + namespace | `resource_attribute` | `k8s.pod.name` / `k8s.namespace.name` | When UID is unavailable |
| Connection IP | `connection` | (none) | Fallback for DaemonSet agents receiving from node-local pods |

### Passthrough Mode

Use `passthrough: true` on **agent** Collectors (DaemonSet) when a **gateway** Collector will do the actual enrichment.
In passthrough mode, the agent only adds the pod IP to the resource, and the gateway performs the full Kubernetes API
lookup.

```yaml
# Agent DaemonSet: mark data with pod IP for the gateway to enrich
processors:
  k8sattributes:
    passthrough: true

# Gateway Deployment: perform full enrichment
processors:
  k8sattributes:
    passthrough: false
    # ... full config above
```

### RBAC Requirements

The Collector's service account needs read access to pods and namespaces:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otelcol-k8sattributes
rules:
  - apiGroups: [""]
    resources:
      - nodes
      - namespaces
      - pods
    verbs: [get, watch, list]
  - apiGroups: ["apps"]
    resources:
      - replicasets
      - deployments
      - statefulsets
      - daemonsets
    verbs: [get, watch, list]
  - apiGroups: ["batch"]
    resources:
      - jobs
      - cronjobs
    verbs: [get, watch, list]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otelcol-k8sattributes
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: otelcol-k8sattributes
subjects:
  - kind: ServiceAccount
    name: otelcol
    namespace: monitoring
```

---

## Recommended: `resource` Processor

The `resource` processor adds, updates, or deletes resource attributes using static values. Use it to add cluster-level
metadata that cannot be auto-detected.

### Adding Static Cluster Attributes

```yaml
processors:
  resource/cluster:
    attributes:
      - key: k8s.cluster.name
        value: production-eu-west-1
        action: insert   # insert = only add if not already present
      - key: deployment.environment
        value: production
        action: insert
```

### Getting the kube-system Namespace UID as Cluster ID

A common pattern for a stable cluster identifier (before `k8s.cluster.uid` is widely populated):

```bash
kubectl get namespace kube-system -o jsonpath='{.metadata.uid}'
```

Inject via env var and reference in the processor:

```yaml
# env in Deployment/DaemonSet
env:
  - name: K8S_CLUSTER_UID
    valueFrom:
      configMapKeyRef:
        name: cluster-info
        key: cluster-uid

# processor config
processors:
  resource/cluster:
    attributes:
      - key: k8s.cluster.uid
        value: ${env:K8S_CLUSTER_UID}
        action: insert
```

---

## Filter Processor

The `filter` processor drops metrics, spans, or log records that match a condition. Use it to remove outdated, internal,
or high-cardinality signals before they reach the exporter.

### Dropping Metrics Scoped to an Instrumentation Library

When a dependency emits metrics you don't want, filter by `instrumentation_scope`:

```yaml
processors:
  filter/drop_internal_metrics:
    error_mode: ignore
    metrics:
      metric:
        # Drop all metrics from internal Go runtime scope
        - instrumentation_scope.name == "go.opentelemetry.io/contrib/instrumentation/runtime"
        # Drop a specific metric by name
        - name == "http.server.duration" and instrumentation_scope.name == "old-library/v1"
```

### Dropping Spans

```yaml
processors:
  filter/drop_health_checks:
    error_mode: ignore
    traces:
      span:
        # Drop health check spans by URL path attribute
        - attributes["http.target"] == "/health"
        - attributes["http.target"] == "/ready"
        - attributes["http.target"] == "/metrics"
```

### Dropping Log Records

```yaml
processors:
  filter/drop_debug_logs:
    error_mode: ignore
    logs:
      log_record:
        - severity_number < SEVERITY_NUMBER_INFO
```

---

## `attributes` Processor

The `attributes` processor adds, updates, deletes, hashes, or extracts span, log, and metric attributes. Unlike the
`resource` processor (which operates on resource attributes), the `attributes` processor targets record-level attributes
(span attributes, log record attributes, metric datapoint attributes).

### Actions

| Action | Description |
|---|---|
| `insert` | Add attribute only if key is absent |
| `update` | Modify attribute only if key is present |
| `upsert` | Add or update regardless |
| `delete` | Remove the attribute by key |
| `hash` | Replace value with SHA-256 hash (anonymisation) |
| `extract` | Parse value with regex named capture groups into new attributes |
| `convert` | Change attribute value type (`int`, `double`, `string`) |

### Filtering

Both `include` and `exclude` filters support `strict` (exact match) and `regexp` (pattern match) strategies, on span
name, attribute key/value, log severity, or metric name. This allows the same processor to apply to a subset of records.

### Configuration

```yaml
processors:
  attributes/enrich:
    actions:
      # Add a static attribute if not already present
      - key: deployment.environment.name
        value: production
        action: insert
      # Copy from another attribute
      - key: service.name
        from_attribute: app.name
        action: insert
      # Hash a sensitive field
      - key: user.email
        action: hash
      # Delete a sensitive field
      - key: http.request.header.authorization
        action: delete
      # Extract named groups from a URL into separate attributes
      - key: url.path
        pattern: '^/api/(?P<api_version>v\d+)/(?P<resource>[^/]+)'
        action: extract

  attributes/drop-internal:
    include:
      match_type: regexp
      services: ["internal-.*"]
    actions:
      - key: internal.request.id
        action: delete
```

> **Gotcha**: Avoid using `upsert` to change attributes that form metric identity (e.g., `http.route`). Changing those
> attributes creates new metric streams in the backend, which can inflate cardinality and break dashboards.

---

## `groupbyattrs` Processor

The `groupbyattrs` processor solves the problem of attributes trapped at the wrong OTLP hierarchy level. It promotes
span/log/metric attributes up to the **Resource level**, grouping records by the promoted attribute values.

### Why it matters

OTLP has a three-level hierarchy: Resource → Scope → Record. Attributes at the record level (span attributes, log
attributes) consume storage on every record. Attributes that are constant for the lifetime of a process belong at the
Resource level. The `groupbyattrs` processor re-organises data to match this structure.

### Common use cases

- **Flat log formats**: Log shippers (syslog, filelog without resource extraction) attach all fields as record
  attributes. Promote `service.name`, `host.name`, etc. to Resource level so downstream processors (e.g.,
  `k8sattributes`) can match correctly.
- **Eliminate resource fragmentation**: When the same Resource appears as many separate ResourceSpans/ResourceLogs
  objects (due to batching quirks), `groupbyattrs` compacts them into a single object.

### Configuration

```yaml
processors:
  groupbyattrs/promote-service:
    keys:
      - service.name
      - k8s.namespace.name
      - host.name
```

After processing, records that share the same values for the listed keys are grouped under a single Resource that
carries those attributes. The attributes are removed from the individual records.

> `groupbyattrs` is stateless and synchronous — it processes each batch independently with no buffering or cardinality
> controls. Place it early in the pipeline, after `memory_limiter` and before processors that operate on Resource
> attributes (e.g., `k8sattributes`).

---

## Sensitive Data Redaction

For redacting PII, secrets, and other sensitive values from telemetry, use OTTL-based transformations.

- See `../otel-ottl/SKILL.md` for OTTL transform expressions and the `transform` processor.
- See `../../otel-instrumentation/references/sensitive-data.md` for instrumentation-level strategies to prevent
  sensitive data from entering telemetry in the first place.

The `redaction` processor (contrib) provides allowlist-based attribute redaction with pattern matching:

```yaml
processors:
  redaction:
    # Allowlist mode (fail-closed): only these keys survive; everything else is removed
    allow_all_keys: false
    allowed_keys:
      - http.request.method
      - http.response.status_code
      - http.route
      - service.name
      - deployment.environment.name

    # Keys to bypass all rules (take precedence over allowed_keys and blocked_values)
    ignored_keys:
      - already_safe_attribute

    # Pattern-based value masking: replace matching substrings with ****
    blocked_values:
      # Redact credit card numbers
      - '\b(?:\d[ -]?){13,16}\b'
      # Redact email addresses
      - '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'

    # Key pattern masking: mask values when the attribute key matches a pattern
    blocked_key_patterns:
      - 'password'
      - 'secret'
      - 'token'
      - 'api[_-]?key'

    # Values matching these patterns are exempt from blocked_values checks
    allowed_values:
      - 'Bearer public-token'

    summary: info  # Options: silent, info, debug
```

> **Allowlist vs. blocklist strategy**: `allow_all_keys: false` with `allowed_keys` is **fail-closed** — new unexpected
> attributes are automatically removed. This is the safer default for compliance requirements. `allow_all_keys: true`
> with `blocked_values` is fail-open — only explicitly matched values are removed, but new PII-carrying attributes are
> not blocked.
>
> **Hashing** (`blocked_values` does not hash; use `attributes` processor with `action: hash` or OTTL `SHA256()` to
> anonymise while preserving cardinality for metrics).

---

## Processor Ordering

Follow this numbered decision process when assembling a pipeline:

1. **`memory_limiter`** — always first; gates admission before any processing occurs.
2. **`groupbyattrs`** — if needed, promote record-level attributes to Resource level before any Resource-level
   processors run.
3. **`resourcedetection`** — auto-detect cloud/node metadata; run early so subsequent processors can use these
   attributes.
4. **`k8sattributes`** — enrich with Kubernetes metadata (pod, namespace, deployment); depends on network/API access
   established at startup.
5. **`resource`** — add static attributes (cluster name, environment); after detection so it can fill gaps.
6. **`attributes`** — insert, update, or delete record-level attributes; after Resource enrichment so attribute
   conditions can reference Resource attributes.
7. **`filter`** — drop unwanted data after enrichment (so filters can reference enriched attributes) but before
   transform (save CPU on dropped records).
8. **`transform` / `redaction`** — mutate, rename, or redact attributes; after filtering to avoid processing dropped
   records.
9. **`batch`** — always last before export; accumulates records to reduce request overhead.

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors:
        - memory_limiter      # 1. Admission control
        - groupbyattrs        # 2. Promote flat attrs to Resource (if needed)
        - resourcedetection   # 3. Cloud/node detection
        - k8sattributes       # 4. Kubernetes enrichment
        - resource/cluster    # 5. Static attributes
        - attributes/enrich   # 6. Record-level attribute manipulation
        - filter/drop_health  # 7. Drop unwanted spans
        - transform/redact    # 8. Redact sensitive data
        - batch               # 9. Batch for export
      exporters: [otlp]
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| `memory_limiter` not first | OOM before back-pressure kicks in | Always place `memory_limiter` as the first processor |
| `batch` without `sending_queue` | In-memory batches lost on restart | Enable `sending_queue` with `file_storage` on the exporter |
| `k8sattributes` without RBAC | Collector crashes or returns empty enrichment | Apply the ClusterRole and ClusterRoleBinding |
| `passthrough: false` on DaemonSet when gateway does enrichment | Both Collector instances query the API → doubled load | Set `passthrough: true` on agents; `false` on gateways |
| No `filter` for internal/debug signals | High cardinality from framework internals | Add `filter` processor to drop known-noisy scopes |
| `filter` before `k8sattributes` using Kubernetes attributes | Kubernetes attributes not yet set when filter runs | Place `filter` after `k8sattributes` |
| `resource` processor using `upsert` to overwrite SDK attributes | Overwrites accurate SDK-provided values with static defaults | Use `insert` to only fill gaps |
| `attributes` processor `upsert` on metric-identity attributes | Creates new metric streams in the backend, inflating cardinality | Avoid changing attributes like `http.route` or `service.name` that form metric identity |
| `redaction` with `allow_all_keys: true` and only `blocked_values` | New unexpected PII-carrying attributes bypass the blocklist | Use `allow_all_keys: false` + `allowed_keys` for fail-closed behaviour in compliance contexts |

---

## References

- [Memory Limiter Processor](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/memorylimiterprocessor)
- [Batch Processor](https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor)
- [Resource Detection Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/resourcedetectionprocessor)
- [Kubernetes Attributes Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor)
- [Resource Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/resourceprocessor)
- [Attributes Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/attributesprocessor)
- [GroupByAttrs Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/groupbyattrsprocessor)
- [Filter Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/filterprocessor)
- [Redaction Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/redactionprocessor)
- [Transform Processor (OTTL)](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor)
