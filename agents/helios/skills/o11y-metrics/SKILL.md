---
name: o11y-metrics
description: This skill should be used when the user asks about "prometheus setup", "metric cardinality", "recording rules", "alerting rules", "prometheus optimization", "metric naming", "time series database", or needs guidance on metrics collection and storage using Prometheus.
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - prometheus
  - grafana
  task: [configure, review, optimize]
  persona: [sre, devops]
  workload: [observability]
---

# Observability Metrics Expert

Provide expert guidance on metrics collection, storage, and querying using Prometheus.

## Purpose

Guide DevOps and SRE teams in implementing production-grade metrics infrastructure. Focus on Prometheus as the primary
metrics solution with expertise in high cardinality challenges, recording rules, alerting rules, and performance
optimization.

## Core Concepts

### Metrics Types

**Counter**: Monotonically increasing value (requests, errors)

```promql
http_requests_total{service="api", status="200"}
```

**Gauge**: Point-in-time value that can go up or down (memory, CPU, queue size)

```promql
node_memory_available_bytes
```

**Histogram**: Distribution of values in buckets (latency, request size)

```promql
http_request_duration_seconds_bucket{le="0.5"}
```

**Summary**: Similar to histogram, pre-calculated percentiles

```promql
http_request_duration_seconds{quantile="0.99"}
```

### Metric Naming Conventions

Follow this pattern: `<namespace>_<subsystem>_<name>_<unit>`

**Good examples**:

- `http_requests_total` (counter of HTTP requests)
- `http_request_duration_seconds` (histogram of request duration)
- `node_memory_available_bytes` (gauge of available memory)
- `database_queries_total` (counter of database queries)

**Bad examples**:

- ❌ `RequestCount` (not snake_case, no unit)
- ❌ `api_latency` (ambiguous unit)
- ❌ `errors` (too generic, no namespace)

### Labels and Cardinality

**Labels** add dimensions to metrics:

```promql
http_requests_total{method="GET", path="/api/users", status="200"}
```

**Cardinality** = unique combinations of label values

**Safe labels** (low cardinality):

- `service`, `environment`, `region`, `cluster`
- `method`, `status_code`, `instance`
- Typically: 10-100 unique values

**Dangerous labels** (high cardinality):

- ❌ `user_id`, `email`, `session_id`
- ❌ `ip_address`, `request_id`
- ❌ Dynamic paths like `/api/users/12345`
- Can create millions of unique series

**Cardinality limit**: Aim for <100K active series per Prometheus instance

## Prometheus Configuration

### Basic prometheus.yml

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "production"
    region: "us-east-1"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - "alertmanager:9093"

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  # Node exporter
  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]

  # Kubernetes pods with prometheus.io/scrape annotation
  - job_name: "kubernetes-pods"
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels:
          [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: kubernetes_pod_name
```

### Storage Retention

Configure retention based on needs:

```yaml
# In Prometheus StatefulSet args:
--storage.tsdb.retention.time=15d  # Keep data for 15 days
--storage.tsdb.retention.size=50GB  # Or until 50GB used
```

**Recommendations**:

- Local retention: 7-15 days for short-term metrics
- Configure retention based on storage capacity and query needs

## Recording Rules

Pre-aggregate expensive queries to reduce query load.

### When to Use Recording Rules

- Query runs frequently (dashboards refreshing every 30s)
- Query is expensive (scans millions of samples)
- Need consistent results across multiple dashboards
- Creating SLI/SLO metrics

### Recording Rule Examples

```yaml
groups:
  - name: api_recording_rules
    interval: 30s
    rules:
      # Pre-aggregate request rate
      - record: job:api_requests:rate5m
        expr: sum(rate(http_requests_total[5m])) by (job)

      # Pre-aggregate error ratio
      - record: job:api_error_ratio:rate5m
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
          /
          sum(rate(http_requests_total[5m])) by (job)

      # Pre-aggregate latency percentiles
      - record: job:api_request_duration:p99
        expr: |
          histogram_quantile(0.99,
            sum(rate(http_request_duration_seconds_bucket[5m])) by (job, le)
          )

      # Multi-level aggregation
      - record: instance:node_cpu:usage:rate5m
        expr: 1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)

      - record: cluster:node_cpu:usage:rate5m
        expr: avg(instance:node_cpu:usage:rate5m)
```

**Naming convention**: `<level>:<metric>:<aggregation>:<rollup>`

## Alerting Rules

Create actionable alerts based on symptoms, not causes.

### Alert Structure

```yaml
groups:
  - name: application_alerts
    rules:
      - alert: AlertName
        expr: <promql expression>
        for: <duration>
        labels:
          severity: <critical|warning|info>
        annotations:
          summary: "<Brief description>"
          description: "<Detailed description with value: {{ $value }}>"
          runbook_url: "https://runbooks.example.com/alert-name"
```

### Critical Alert Examples

```yaml
groups:
  - name: critical_alerts
    rules:
      # Service completely down
      - alert: ServiceDown
        expr: up{job="api"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.instance }} has been down for 5+ minutes"
          runbook_url: "https://runbooks.example.com/service-down"

      # High error rate (>5%)
      - alert: HighErrorRate
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
            /
            sum(rate(http_requests_total[5m])) by (job)
          ) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate in {{ $labels.job }}"
          description: "Error rate is {{ $value | humanizePercentage }}"

      # Disk almost full
      - alert: DiskSpaceLow
        expr: |
          (
            node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"}
            /
            node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs"}
          ) < 0.10
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Disk space critically low on {{ $labels.instance }}"
          description: "Only {{ $value | humanizePercentage }} space remaining on {{ $labels.mountpoint }}"
```

### Warning Alert Examples

```yaml
groups:
  - name: warning_alerts
    rules:
      # Elevated error rate
      - alert: ElevatedErrorRate
        expr: |
          (
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total[5m]))
          ) > 0.01
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Elevated error rate"
          description: "Error rate {{ $value | humanizePercentage }} for 15+ minutes"

      # High CPU usage
      - alert: HighCPUUsage
        expr: |
          100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is {{ $value }}% for 15+ minutes"

      # Memory pressure
      - alert: HighMemoryUsage
        expr: |
          (
            1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
          ) * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is {{ $value }}%"
```

## Cardinality Management

### Detecting High Cardinality

Query Prometheus to find high-cardinality metrics:

```promql
# Top 10 metrics by series count
topk(10, count by (__name__) ({__name__=~".+"}))

# Series count per job
count by (job) ({__name__=~".+"})

# Find metrics with many label combinations
count({__name__="http_requests_total"}) by (__name__)
```

### Reducing Cardinality

**Method 1: Drop unnecessary labels**

```yaml
# In prometheus.yml scrape config
metric_relabel_configs:
  - source_labels: [__name__]
    regex: 'http_requests_total'
    action: labeldrop
    regex: 'user_id|session_id'
```

**Method 2: Aggregate with recording rules**

```yaml
# Instead of keeping per-user metrics
- record: service:requests:rate5m
  expr: sum(rate(http_requests_total[5m])) by (service, method, status)
  # Drop user_id label
```

**Method 3: Use recording rules to downsample**

```yaml
- record: job:requests:rate1h
  expr: sum(rate(http_requests_total[1h])) by (job)
  # Lower resolution, fewer samples
```

### Metric Relabeling

Drop metrics you don't need:

```yaml
scrape_configs:
  - job_name: "app"
    metric_relabel_configs:
      # Drop debug metrics
      - source_labels: [__name__]
        regex: "debug_.*"
        action: drop

      # Drop high-cardinality metrics
      - source_labels: [__name__]
        regex: ".*_by_user"
        action: drop

      # Keep only specific metrics
      - source_labels: [__name__]
        regex: "(http_requests_total|http_request_duration_seconds|up)"
        action: keep
```

## Common PromQL Queries

### Rate and Increase

```promql
# Requests per second (5m window)
rate(http_requests_total[5m])

# Total requests in last hour
increase(http_requests_total[1h])

# Requests per second per service
sum(rate(http_requests_total[5m])) by (service)
```

### Percentiles

```promql
# 99th percentile latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Multiple percentiles
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.90, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

### Ratios and Percentages

```promql
# Error rate percentage
(
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
) * 100

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# CPU usage percentage
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Aggregations

```promql
# Sum across all instances
sum(rate(http_requests_total[5m]))

# Average per instance
avg(rate(http_requests_total[5m])) by (instance)

# Top 5 services by request rate
topk(5, sum(rate(http_requests_total[5m])) by (service))

# Bottom 3 instances by available memory
bottomk(3, node_memory_MemAvailable_bytes)
```

## Performance Optimization

### Query Optimization

**Avoid**:

- Large time ranges without aggregation
- High cardinality group by
- Complex regex in queries

**Prefer**:

- Use recording rules for expensive queries
- Limit time ranges (prefer 5m, 15m, 1h)
- Use specific label matchers

### Storage Optimization

**Techniques**:

1. Reduce scrape frequency (30s → 60s for non-critical)
2. Implement metric relabeling (drop unused metrics)
3. Use recording rules to downsample
4. Configure appropriate retention
5. Enable compression in Thanos/Mimir

## Troubleshooting

### High Memory Usage

```promql
# Check series count
count({__name__=~".+"})

# If >1M, investigate cardinality:
topk(20, count by (__name__, job) ({__name__=~".+"}))
```

**Solutions**:

- Drop high-cardinality metrics
- Reduce label cardinality
- Increase Prometheus memory limits

### Slow Queries

Use Prometheus query analysis:

```text
http://prometheus:9090/graph
# Enable "Explain" to see query execution stats
```

**Solutions**:

- Create recording rules
- Reduce time range
- Optimize label matchers

### Missing Metrics

Check Prometheus targets:

```text
http://prometheus:9090/targets
```

**Common causes**:

- Service not exposing /metrics
- Network firewall blocking scrape
- Incorrect scrape config
- Service discovery not finding pods

## Additional Resources

### Example Files

- **`examples/recording-rules.yml`**: Production recording rules examples

### Scripts

- **`scripts/cardinality-check.sh`**: Analyze Prometheus cardinality

---

**Summary**: Use this skill for Prometheus guidance. Focuses on metric naming, cardinality management, recording rules,
alerting rules, and performance optimization. Consult `o11y-expert` for strategic architecture decisions.
