# Advanced Grafana Dashboard Patterns

This reference provides advanced patterns and examples for creating production-ready Grafana dashboards.

## Dashboard Design Principles

### Hierarchy of Information

```text
┌─────────────────────────────────────┐
│  Critical Metrics (Big Numbers)     │
├─────────────────────────────────────┤
│  Key Trends (Time Series)           │
├─────────────────────────────────────┤
│  Detailed Metrics (Tables/Heatmaps) │
└─────────────────────────────────────┘
```

**Implementation Strategy:**

1. Top row: High-level KPIs (stat panels with thresholds)
2. Middle rows: Time series graphs showing trends
3. Bottom rows: Detailed breakdowns (tables, heatmaps)

### RED Method Implementation (Services)

Complete dashboard structure for monitoring services:

- **Rate** - Requests per second
- **Errors** - Error rate percentage
- **Duration** - Latency percentiles (P50, P95, P99)

### USE Method Implementation (Resources)

Complete dashboard structure for monitoring resources:

- **Utilization** - % time resource is busy
- **Saturation** - Queue length/wait time
- **Errors** - Error count

## Complete Dashboard Examples

### API Monitoring Dashboard

```json
{
  "dashboard": {
    "title": "API Monitoring",
    "tags": ["api", "production"],
    "timezone": "browser",
    "refresh": "30s",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m])) by (service)",
            "legendFormat": "{{service}}"
          }
        ],
        "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8}
      },
      {
        "title": "Error Rate %",
        "type": "graph",
        "targets": [
          {
            "expr": "(sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))) * 100",
            "legendFormat": "Error Rate"
          }
        ],
        "alert": {
          "conditions": [
            {
              "evaluator": {"params": [5], "type": "gt"},
              "operator": {"type": "and"},
              "query": {"params": ["A", "5m", "now"]},
              "type": "query"
            }
          ]
        },
        "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8}
      },
      {
        "title": "P95 Latency",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))",
            "legendFormat": "{{service}}"
          }
        ],
        "gridPos": {"x": 0, "y": 8, "w": 24, "h": 8}
      }
    ]
  }
}
```

## Advanced Panel Types

### 1. Stat Panel with Thresholds

```json
{
  "type": "stat",
  "title": "Total Requests",
  "targets": [{
    "expr": "sum(http_requests_total)"
  }],
  "options": {
    "reduceOptions": {
      "values": false,
      "calcs": ["lastNotNull"]
    },
    "orientation": "auto",
    "textMode": "auto",
    "colorMode": "value"
  },
  "fieldConfig": {
    "defaults": {
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {"value": 0, "color": "green"},
          {"value": 80, "color": "yellow"},
          {"value": 90, "color": "red"}
        ]
      }
    }
  }
}
```

**Usage:**

- Display single values with color-coded health
- Show critical metrics at a glance
- Use for SLO compliance indicators

### 2. Time Series with Units

```json
{
  "type": "graph",
  "title": "CPU Usage",
  "targets": [{
    "expr": "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
  }],
  "yaxes": [
    {"format": "percent", "max": 100, "min": 0},
    {"format": "short"}
  ]
}
```

**Common Units:**

- `percent` - Percentages (0-100)
- `bytes` - Bytes (auto-scaling to KB, MB, GB)
- `s` - Seconds (auto-scaling to ms, μs)
- `reqps` - Requests per second
- `ops` - Operations per second

### 3. Table Panel with Transformations

```json
{
  "type": "table",
  "title": "Service Status",
  "targets": [{
    "expr": "up",
    "format": "table",
    "instant": true
  }],
  "transformations": [
    {
      "id": "organize",
      "options": {
        "excludeByName": {"Time": true},
        "indexByName": {},
        "renameByName": {
          "instance": "Instance",
          "job": "Service",
          "Value": "Status"
        }
      }
    }
  ]
}
```

**Transformation Types:**

- **Organize**: Rename, reorder, or hide columns
- **Filter by name**: Show/hide specific series
- **Filter by value**: Show only values matching conditions
- **Join by field**: Combine data from multiple queries
- **Group by**: Aggregate rows by field values

### 4. Heatmap for Distribution

```json
{
  "type": "heatmap",
  "title": "Latency Heatmap",
  "targets": [{
    "expr": "sum(rate(http_request_duration_seconds_bucket[5m])) by (le)",
    "format": "heatmap"
  }],
  "dataFormat": "tsbuckets",
  "yAxis": {
    "format": "s"
  }
}
```

**Best For:**

- Request latency distribution
- Response time patterns
- Identifying latency spikes

## Variables and Templating

### Query Variables

```json
{
  "templating": {
    "list": [
      {
        "name": "namespace",
        "type": "query",
        "datasource": "Prometheus",
        "query": "label_values(kube_pod_info, namespace)",
        "refresh": 1,
        "multi": false
      },
      {
        "name": "service",
        "type": "query",
        "datasource": "Prometheus",
        "query": "label_values(kube_service_info{namespace=\"$namespace\"}, service)",
        "refresh": 1,
        "multi": true
      }
    ]
  }
}
```

### Using Variables in Queries

```promql
# Single selection variable
sum(rate(http_requests_total{namespace="$namespace"}[5m]))

# Multi-selection variable
sum(rate(http_requests_total{namespace="$namespace", service=~"$service"}[5m]))

# All option (regex)
sum(rate(http_requests_total{namespace="$namespace", service=~"$service|"}[5m]))
```

### Variable Types

**Query Variable**: Dynamic list from datasource

```json
{
  "name": "env",
  "type": "query",
  "query": "label_values(up, environment)",
  "refresh": 2,  // On dashboard load
  "multi": false
}
```

**Custom Variable**: Static list

```json
{
  "name": "percentile",
  "type": "custom",
  "query": "0.50,0.90,0.95,0.99",
  "multi": false
}
```

**Interval Variable**: Time interval selector

```json
{
  "name": "interval",
  "type": "interval",
  "query": "1m,5m,10m,30m,1h",
  "auto": true,
  "auto_min": "10s"
}
```

## Dashboard Alerting

### Alert Configuration

```json
{
  "alert": {
    "name": "High Error Rate",
    "conditions": [
      {
        "evaluator": {
          "params": [5],
          "type": "gt"
        },
        "operator": {"type": "and"},
        "query": {
          "params": ["A", "5m", "now"]
        },
        "reducer": {"type": "avg"},
        "type": "query"
      }
    ],
    "executionErrorState": "alerting",
    "for": "5m",
    "frequency": "1m",
    "message": "Error rate is above 5%",
    "noDataState": "no_data",
    "notifications": [
      {"uid": "slack-channel"}
    ]
  }
}
```

**Alert States:**

- `alerting` - Condition is true
- `pending` - Waiting for "for" duration
- `no_data` - No data received
- `execution_error` - Query failed

**Notification Channels:**

- Slack
- PagerDuty
- Email
- Webhook
- OpsGenie

## Common Dashboard Patterns

### Infrastructure Dashboard

**Key Panels:**

1. **Resource Overview**
   - CPU utilization per node
   - Memory usage per node
   - Disk I/O per node
   - Network traffic

2. **Cluster Health**
   - Pod count by namespace
   - Node status (up/down)
   - Container restarts
   - Resource requests vs limits

3. **Performance Metrics**
   - Disk latency
   - Network latency
   - Context switches
   - Load average

**Example Queries:**

```promql
# CPU utilization
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk I/O
rate(node_disk_io_time_seconds_total[5m])

# Network traffic
rate(node_network_receive_bytes_total[5m])
```

### Database Dashboard

**Key Panels:**

1. **Query Performance**
   - Queries per second
   - Query latency (P50, P95, P99)
   - Slow queries count
   - Query errors

2. **Connection Health**
   - Connection pool usage
   - Active connections
   - Waiting connections
   - Connection errors

3. **Storage Metrics**
   - Database size
   - Table sizes
   - Index sizes
   - Replication lag

**Example Queries:**

```promql
# Queries per second
rate(mysql_global_status_queries[5m])

# Query latency P95
histogram_quantile(0.95, rate(mysql_perf_schema_events_statements_histogram_bucket[5m]))

# Connection pool usage
mysql_global_status_threads_connected / mysql_global_variables_max_connections * 100

# Replication lag
mysql_slave_status_seconds_behind_master
```

### Application Dashboard

**Key Panels:**

1. **Request Metrics**
   - Request rate by endpoint
   - Error rate by endpoint
   - Response time percentiles
   - Request size distribution

2. **Application Health**
   - Active users/sessions
   - Cache hit rate
   - Queue length
   - Background job status

3. **Business Metrics**
   - Transactions per minute
   - Successful operations
   - Failed operations
   - Revenue impact

**Example Queries:**

```promql
# Request rate by endpoint
sum(rate(http_requests_total[5m])) by (endpoint)

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100

# Cache hit rate
sum(rate(cache_hits_total[5m])) / (sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m]))) * 100

# Active sessions
sum(active_sessions)
```

## Dashboard Provisioning

### Grafana Provisioning Configuration

**dashboards.yml:**

```yaml
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: 'General'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards

  - name: 'production'
    orgId: 1
    folder: 'Production'
    type: file
    disableDeletion: true
    editable: false
    options:
      path: /etc/grafana/dashboards/production
```

**Key Configuration Options:**

- `disableDeletion`: Prevent dashboard deletion
- `updateIntervalSeconds`: How often to scan for changes
- `allowUiUpdates`: Allow editing in UI
- `editable`: Allow editing in viewer

### Terraform Provisioning

```hcl
resource "grafana_folder" "monitoring" {
  title = "Production Monitoring"
}

resource "grafana_dashboard" "api_monitoring" {
  config_json = file("${path.module}/dashboards/api-monitoring.json")
  folder      = grafana_folder.monitoring.id

  depends_on = [
    grafana_folder.monitoring
  ]
}

resource "grafana_dashboard" "infrastructure" {
  config_json = file("${path.module}/dashboards/infrastructure.json")
  folder      = grafana_folder.monitoring.id
}

resource "grafana_dashboard" "database" {
  config_json = file("${path.module}/dashboards/database.json")
  folder      = grafana_folder.monitoring.id
}
```

### Ansible Provisioning

```yaml
- name: Create Grafana dashboard directory
  file:
    path: /etc/grafana/dashboards
    state: directory
    owner: grafana
    group: grafana
    mode: '0755'

- name: Deploy Grafana dashboards
  copy:
    src: "{{ item }}"
    dest: /etc/grafana/dashboards/
    owner: grafana
    group: grafana
    mode: '0644'
  with_fileglob:
    - "dashboards/*.json"
  notify: reload grafana

- name: Deploy dashboard provisioning config
  template:
    src: dashboards.yml.j2
    dest: /etc/grafana/provisioning/dashboards/dashboards.yml
    owner: grafana
    group: grafana
    mode: '0644'
  notify: restart grafana
```

## Best Practices

### Design Principles

1. **Start with templates**
   - Browse [Grafana dashboard marketplace](https://grafana.com/grafana/dashboards/)
   - Fork and customize existing dashboards
   - Learn from community best practices

2. **Use consistent naming**
   - Panel titles: Descriptive and concise
   - Variables: Lowercase with underscores
   - Tags: Lowercase, hyphen-separated

3. **Group related metrics**
   - Use rows to organize related panels
   - Collapse rows by default for large dashboards
   - Add row descriptions for context

4. **Set appropriate time ranges**
   - Default: Last 6 hours for operations
   - Default: Last 24 hours for trends
   - Enable time picker for flexibility

5. **Use variables for flexibility**
   - Environment selector
   - Service selector
   - Time interval selector
   - Percentile selector

6. **Add panel descriptions**
   - Explain what the metric means
   - Document thresholds
   - Link to runbooks

7. **Configure units correctly**
   - Use appropriate unit formats
   - Set min/max values where applicable
   - Use consistent units across panels

8. **Set meaningful thresholds**
   - Base on SLOs/SLIs
   - Use traffic light colors (green/yellow/red)
   - Avoid too many threshold levels

9. **Use consistent colors**
   - Red for errors/critical
   - Yellow for warnings
   - Green for healthy
   - Blue for informational

10. **Test with different time ranges**
    - Verify queries work at different scales
    - Check for query timeouts
    - Optimize slow queries

### Performance Optimization

**Query Optimization:**

- Use recording rules for expensive queries
- Limit time series cardinality
- Use `topk()` or `bottomk()` for large result sets
- Avoid regex when possible

**Dashboard Optimization:**

- Limit number of panels (< 20 per dashboard)
- Use appropriate refresh intervals (30s-1m)
- Disable auto-refresh for historical views
- Use shared queries across panels

**Data Source Optimization:**

- Configure query timeout limits
- Enable query caching
- Use appropriate scrape intervals
- Consider using Trickster for query acceleration

## Advanced Features

### Annotations

```json
{
  "annotations": {
    "list": [
      {
        "datasource": "Prometheus",
        "enable": true,
        "expr": "changes(kube_deployment_spec_replicas[5m]) > 0",
        "iconColor": "blue",
        "name": "Deployments",
        "step": "60s",
        "tagKeys": "deployment",
        "textFormat": "Deployment: {{deployment}}",
        "titleFormat": "Deployment Change"
      }
    ]
  }
}
```

**Use Cases:**

- Mark deployment events
- Show incident times
- Display configuration changes
- Highlight alert triggers

### Links

```json
{
  "links": [
    {
      "title": "Related Dashboard",
      "type": "dashboard",
      "dashboardId": 123,
      "keepTime": true
    },
    {
      "title": "Runbook",
      "type": "link",
      "url": "https://runbooks.example.com/api-errors",
      "targetBlank": true
    }
  ]
}
```

**Link Types:**

- Dashboard links (with variable passing)
- External URLs
- Panel-specific links
- Data links (per series)

### Repeated Panels

```json
{
  "repeat": "service",
  "repeatDirection": "h",
  "maxPerRow": 3
}
```

**Benefits:**

- Automatically create panels per variable value
- Reduce dashboard maintenance
- Ensure consistency across similar panels

---

**Related Resources:**

- Main o11y-dashboards SKILL.md for core concepts
- Prometheus documentation for query examples
- Grafana documentation for panel configuration
