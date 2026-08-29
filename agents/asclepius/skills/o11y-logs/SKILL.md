---
name: o11y-logs
description: This skill should be used when the user asks about "log aggregation", "loki configuration", "promtail setup", "log retention", "logql queries", "log parsing", "structured logging", "fluentd", or needs guidance on log collection, storage, and querying.
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - loki
  - grafana
  task: [configure, debug, audit]
  persona: [sre, devops]
  workload: [observability]
---

# Observability Logs Expert

Expert guidance on log aggregation, storage, and querying using Loki, Promtail, Fluentd, and Elasticsearch.

## Core Principles

### Log vs Metrics vs Traces

**Use logs for**:

- Discrete events (user login, error occurred)
- Debugging and troubleshooting
- Audit trails
- Unstructured or semi-structured data

**Don't use logs for**:

- High-frequency metrics (use Prometheus)
- Distributed request tracing (use Tempo)

### Structured Logging

Always use structured formats (JSON preferred):

```json
{
  "timestamp": "2024-01-14T10:30:00Z",
  "level": "error",
  "message": "Database connection failed",
  "error": "connection timeout",
  "database": "users-db",
  "retry_attempt": 3
}
```

**Benefits**:

- Easy to parse and query
- Consistent fields across services
- Machine-readable
- Efficient storage in Loki

## Loki Architecture

Loki uses labels (like Prometheus) instead of full-text indexing:

```text
Applications → Promtail → Loki → Grafana
                  ↓
              Log Files
```

### Key Concepts

**Labels**: Low-cardinality metadata (service, environment, pod)
**Log lines**: Actual log content (not indexed)
**Chunks**: Compressed log blocks stored in object storage

### Loki Configuration

```yaml
# loki-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 15m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2024-01-01
      store: boltdb-shipper
      object_store: s3
      schema: v11
      index:
        prefix: loki_index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: s3
  aws:
    s3: s3://loki-logs
    region: us-east-1

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h # 7 days
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

table_manager:
  retention_deletes_enabled: true
  retention_period: 168h # 7 days
```

## Promtail Configuration

Promtail collects logs and sends to Loki:

```yaml
# promtail-config.yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Kubernetes pods
  - job_name: kubernetes-pods
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Add namespace label
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      # Add pod name label
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
      # Add app label
      - source_labels: [__meta_kubernetes_pod_label_app]
        target_label: app
      # Add container name
      - source_labels: [__meta_kubernetes_pod_container_name]
        target_label: container
      # Log path
      - source_labels:
          [__meta_kubernetes_pod_uid, __meta_kubernetes_pod_container_name]
        target_label: __path__
        separator: /
        replacement: /var/log/pods/*$1/*.log

  # System logs
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log

  # Application logs (JSON)
  - job_name: app-json
    static_configs:
      - targets:
          - localhost
        labels:
          job: app
          __path__: /var/log/app/*.log
    pipeline_stages:
      - json:
          expressions:
            level: level
            message: message
            trace_id: trace_id
      - labels:
          level:
      - timestamp:
          source: timestamp
          format: RFC3339
```

## LogQL Query Language

### Basic Queries

```logql
# All logs from job
{job="app"}

# Filter by log content
{job="app"} |= "error"

# Exclude content
{job="app"} != "debug"

# Regex match
{job="app"} |~ "error|exception"

# Multiple labels
{job="app", environment="production", level="error"}
```

### Log Parsing

```logql
# Parse JSON
{job="app"} | json

# Parse specific fields
{job="app"} | json level="level", message="msg"

# Parse logfmt
{job="app"} | logfmt

# Regex parsing
{job="app"} | regexp "(?P<method>\\w+) (?P<path>/\\S+) (?P<status>\\d+)"
```

### Filtering After Parsing

```logql
# Filter on parsed field
{job="app"} | json | level="error"

# Numeric comparison
{job="nginx"} | json | status_code >= 500

# Duration filter
{job="app"} | json | duration > 1s
```

### Aggregations

```logql
# Count logs over time
count_over_time({job="app"}[5m])

# Rate of logs
rate({job="app"}[5m])

# Sum by label
sum by (level) (count_over_time({job="app"}[5m]))

# Top K
topk(10, sum by (endpoint) (rate({job="api"}[5m])))

# Error rate percentage
(
  sum(rate({job="app"} |= "ERROR" [5m]))
  /
  sum(rate({job="app"}[5m]))
) * 100
```

## Log Retention Strategies

### Retention Configuration

```yaml
# Short retention for high-volume
table_manager:
  retention_deletes_enabled: true
  retention_period: 72h # 3 days for debug logs

# Longer retention for errors
limits_config:
  per_tenant_override_config: /etc/loki/overrides.yaml
```

### Sample by Log Level

```yaml
# In Promtail, sample info logs, keep all errors
pipeline_stages:
  - match:
      selector: '{job="app"} |= "INFO"'
      stages:
        - sampling:
            rate: 0.1 # Keep only 10% of INFO logs
  - match:
      selector: '{job="app"} |= "ERROR"'
      stages:
        - sampling:
            rate: 1.0 # Keep 100% of ERROR logs
```

## Log Parsing Patterns

### JSON Logs

```yaml
pipeline_stages:
  - json:
      expressions:
        timestamp: timestamp
        level: level
        message: message
        trace_id: trace_id
        user_id: user_id
  - labels:
      level:
  - timestamp:
      source: timestamp
      format: RFC3339
  - output:
      source: message
```

### Apache/Nginx Access Logs

```yaml
pipeline_stages:
  - regex:
      expression: '^(?P<ip>\S+) \S+ \S+ \[(?P<time>[^\]]+)\] "(?P<method>\w+) (?P<path>\S+) \S+" (?P<status>\d+) (?P<size>\d+)'
  - labels:
      method:
      status:
  - timestamp:
      source: time
      format: "02/Jan/2006:15:04:05 -0700"
```

### Go/Python Application Logs

```yaml
pipeline_stages:
  - regex:
      expression: '(?P<timestamp>\S+) (?P<level>\w+) (?P<message>.*)'
  - labels:
      level:
  - timestamp:
      source: timestamp
      format: RFC3339Nano
```

## Performance Optimization

### Label Cardinality

**Good labels** (low cardinality, <100 values):

- `job`, `namespace`, `pod`, `container`
- `environment`, `region`, `cluster`
- `level` (info, warn, error)

**Bad labels** (high cardinality):

- ❌ `user_id`, `request_id`, `session_id`
- ❌ `trace_id` (put in log line, not label)
- ❌ Dynamic paths

### Query Optimization

**Slow**:

```logql
# Searches all logs
{job="app"} |~ "user_id.*12345"
```

**Fast**:

```logql
# Uses label filtering first
{job="app", level="error"} |~ "user_id.*12345"
```

### Chunk Size

Tune chunk size for your log volume:

```yaml
ingester:
  chunk_target_size: 1536000 # 1.5MB (default)
  chunk_idle_period: 15m
```

## Loki Alternatives

### When to Use Elasticsearch

- Need full-text search
- Complex queries with aggregations
- Log analysis workflows
- Already have ELK expertise

### When to Use Splunk

- Enterprise support required
- Advanced analysis features needed
- Budget allows ($150-2000/GB/year)

### When to Use Loki

- Prometheus users (similar label-based approach)
- Cost-sensitive (10x cheaper than Elasticsearch)
- Kubernetes-native
- Simple log queries sufficient

## Common Queries

### Error Investigation

```logql
# All errors in last hour
{job="app"} |= "ERROR" | level="error"

# Error rate per service
sum by (service) (rate({level="error"}[5m]))

# Specific error pattern
{job="api"} |~ "(?i)timeout|connection refused"
```

### Performance Analysis

```logql
# Slow requests (duration > 1s)
{job="api"} | json | duration > 1s

# P99 latency
quantile_over_time(0.99,
  {job="api"} | json | unwrap duration [5m]
)

# Request volume
sum(rate({job="api"}[5m]))
```

### Security Auditing

```logql
# Failed login attempts
{job="auth"} |= "login failed"

# Admin actions
{job="api"} | json | user_role="admin"

# Suspicious activity
{job="api"} |~ "(?i)injection|script|xss"
```

## Troubleshooting

### Logs Not Appearing

1. Check Promtail status:

```bash
curl http://promtail:9080/metrics | grep promtail_sent
```

2. Check Loki ingestion:

```bash
curl http://loki:3100/metrics | grep loki_ingester_received
```

3. Verify log files exist:

```bash
ls -la /var/log/pods/
```

### High Memory Usage

**Causes**:

- Too many active streams (high label cardinality)
- Large chunk sizes
- High ingestion rate

**Solutions**:

- Reduce label cardinality
- Increase chunk size
- Scale out ingesters

### Query Timeouts

**Solutions**:

- Add more specific label selectors
- Reduce time range
- Use smaller query parallelism
- Add query frontend cache

## Additional Resources

- **`references/loki-setup.md`**: Complete Loki deployment guide
- **`references/logql-cheatsheet.md`**: LogQL query patterns
- **`examples/promtail-configs.yml`**: Common Promtail configurations

---

**Summary**: Use Loki for cost-effective log aggregation with Prometheus-style labels. Focus on structured logging,
low-cardinality labels, and efficient querying. Consult `o11y-expert` for architecture decisions.
