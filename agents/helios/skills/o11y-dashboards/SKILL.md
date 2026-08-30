---
name: o11y-dashboards
description: This skill should be used when the user asks about "grafana dashboard", "dashboard design", "visualization best practices", "promql queries", "logql", "dashboard panels", "grafana variables", "dashboard templates", or needs guidance on creating effective observability dashboards.
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - grafana
  - prometheus
  task: [configure, build, review]
  persona: [sre, devops]
  workload: [observability]
---

# Observability Dashboards Expert

Expert guidance on designing effective Grafana dashboards for observability.

## Dashboard Design Principles

### RED Method (for Services)

- **Rate**: Requests per second
- **Errors**: Error rate percentage
- **Duration**: Latency percentiles (p50, p95, p99)

### USE Method (for Resources)

- **Utilization**: % time resource busy
- **Saturation**: Queue depth/backlog
- **Errors**: Error count

### Four Golden Signals (Google SRE)

- Latency, Traffic, Errors, Saturation

## Dashboard Structure

### Layout Best Practices

```text
┌─────────────────────────────────────┐
│  Title + Description                │ ← Context
├─────────────────────────────────────┤
│  [KPIs] [KPIs] [KPIs] [KPIs]       │ ← Key metrics
├────────────┬────────────────────────┤
│  Rate      │  Errors                │ ← Primary signals
│  (Graph)   │  (Graph)               │
├────────────┼────────────────────────┤
│  Latency   │  Resource Usage        │ ← Secondary
│  (Heatmap) │  (Graph)               │
├─────────────────────────────────────┤
│  Detailed Tables/Logs               │ ← Details
└─────────────────────────────────────┘
```

### Panel Organization

1. **Top**: High-level KPIs (single stats)
2. **Middle**: Time series graphs (trends)
3. **Bottom**: Tables, logs, traces (drill-down)

## Essential Dashboards

### 1. Service Overview (RED)

```json
{
  "title": "API Service Overview",
  "panels": [
    {
      "title": "Request Rate",
      "description": "Total HTTP requests per second across all services. Uses 5-minute rate for smoothing.",
      "datasource": "$prometheus_datasource",
      "targets": [
        {
          "expr": "sum(rate(http_requests_total[5m])) by (service)"
        }
      ]
    },
    {
      "title": "Error Rate %",
      "description": "Percentage of 5xx errors. Alert threshold: > 5%.",
      "datasource": "$prometheus_datasource",
      "targets": [
        {
          "expr": "(sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))) * 100"
        }
      ]
    },
    {
      "title": "Latency (p99)",
      "description": "99th percentile response time. SLO: < 500ms.",
      "datasource": "$prometheus_datasource",
      "targets": [
        {
          "expr": "histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))"
        }
      ]
    }
  ]
}
```

### 2. Infrastructure (USE)

```json
{
  "title": "Node Resources",
  "panels": [
    {
      "title": "CPU Utilization %",
      "description": "Average CPU usage across all cores. Alert threshold: > 80%.",
      "datasource": "$prometheus_datasource",
      "targets": [
        {
          "expr": "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
        }
      ]
    },
    {
      "title": "Memory Usage %",
      "description": "Percentage of total memory in use. Alert threshold: > 90%.",
      "datasource": "$prometheus_datasource",
      "targets": [
        {
          "expr": "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
        }
      ]
    },
    {
      "title": "Disk I/O",
      "description": "Disk I/O time rate indicating disk saturation.",
      "datasource": "$prometheus_datasource",
      "targets": [
        {
          "expr": "rate(node_disk_io_time_seconds_total[5m])"
        }
      ]
    }
  ]
}
```

## Dashboard Variables

⚠️ **MANDATORY DATASOURCE NAMING CONVENTION** ⚠️

**All datasource variables MUST follow this naming pattern:**

| Datasource Type | Variable Name           |
| --------------- | ----------------------- |
| Prometheus      | `prometheus_datasource` |
| Loki            | `loki_datasource`       |
| Tempo           | `tempo_datasource`      |
| Generic         | `<type>_datasource`     |

### Template Variables

```json
{
  "templating": {
    "list": [
      {
        "name": "prometheus_datasource",
        "label": "Prometheus Data Source",
        "type": "datasource",
        "query": "prometheus"
      },
      {
        "name": "environment",
        "type": "query",
        "datasource": "$prometheus_datasource",
        "query": "label_values(up, environment)",
        "multi": true
      },
      {
        "name": "service",
        "type": "query",
        "datasource": "$prometheus_datasource",
        "query": "label_values(http_requests_total{environment=~\"$environment\"}, service)"
      }
    ]
  }
}
```

**For Loki dashboards:**

```json
{
  "name": "loki_datasource",
  "label": "Loki Data Source",
  "type": "datasource",
  "query": "loki"
}
```

Use in queries:

```promql
rate(http_requests_total{environment=~"$environment", service="$service"}[5m])
```

## Query Patterns

### PromQL for Dashboards

```promql
# Rate per service
sum(rate(metric[5m])) by (service)

# Percentage
(errors / total) * 100

# Top N
topk(10, sum(rate(metric[5m])) by (label))

# Heatmap
sum(rate(metric_bucket[5m])) by (le)
```

### LogQL for Dashboards

```logql
# Log volume
sum(rate({job="app"}[5m])) by (level)

# Error rate
sum(rate({level="error"}[5m])) / sum(rate({job="app"}[5m]))

# Pattern extraction
{job="app"} | json | status_code >= 500
```

## Mandatory Panel Requirements

⚠️ **CRITICAL RULE** ⚠️

**ALL panels MUST have:**

1. **A clear, descriptive title** (< 50 characters)
2. **A detailed description** explaining:
   - What the panel shows
   - Why it matters
   - Alert thresholds (if applicable)
   - Links to runbooks or documentation

**Example**:

```json
{
  "title": "API Error Rate",
  "description": "Percentage of 5xx responses over total requests. Alert threshold: > 5%. Runbook: https://runbooks.example.com/api-errors"
}
```

This is a **non-negotiable requirement** for all production Grafana dashboards.

---

## Mandatory Datasource Naming Convention

⚠️ **CRITICAL RULE** ⚠️

**ALL datasource variables MUST follow this naming pattern:**

```text
<type>_datasource
```

**Specific naming requirements:**

| Datasource Type | Required Variable Name  | Example Label            |
| --------------- | ----------------------- | ------------------------ |
| Prometheus      | `prometheus_datasource` | "Prometheus Data Source" |
| Loki            | `loki_datasource`       | "Loki Data Source"       |
| Tempo           | `tempo_datasource`      | "Tempo Data Source"      |
| Other types     | `<type>_datasource`     | "<Type> Data Source"     |

**Example**:

```json
{
  "name": "prometheus_datasource",
  "label": "Prometheus Data Source",
  "type": "datasource",
  "query": "prometheus"
}
```

**Why This Matters:**

- Ensures consistency across all dashboards
- Prevents naming conflicts in multi-datasource dashboards
- Makes dashboard maintenance easier
- Enables clear identification of datasource types

**Reference in panels:**

```json
{
  "datasource": "$prometheus_datasource",
  "targets": [...]
}
```

❌ **Don't use**: `datasource`, `ds`, `prom`, `prometheus`

✅ **Use**: `prometheus_datasource`, `loki_datasource`, `tempo_datasource`

This is a **non-negotiable requirement** for all production Grafana dashboards.

---

## Panel Types

### Stat Panel (KPIs)

Use for single values:

- Current request rate
- Error percentage
- Available memory

### Time Series (Graphs)

Use for trends over time:

- Request rate history
- Latency percentiles
- Resource usage

### Heatmap

Use for distribution:

- Latency distribution
- Request size distribution

### Table

Use for detailed data:

- Top endpoints by latency
- Error logs
- Service list

## Color Schemes

### Traffic Light Colors

- 🟢 Green: Healthy (< threshold)
- 🟡 Yellow: Warning (threshold to 80%)
- 🔴 Red: Critical (> 80%)

```json
{
  "thresholds": {
    "mode": "absolute",
    "steps": [
      { "value": null, "color": "green" },
      { "value": 80, "color": "yellow" },
      { "value": 90, "color": "red" }
    ]
  }
}
```

## Dashboard as Code

Store dashboards in Git:

```bash
# Export dashboard
curl -H "Authorization: Bearer $API_KEY" \
  http://grafana:3000/api/dashboards/uid/abc123 > dashboard.json

# Import dashboard
curl -X POST -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d @dashboard.json \
  http://grafana:3000/api/dashboards/db
```

## Additional Resources

For comprehensive guidance on dashboard best practices, linting rules, and common mistakes to avoid, consult:

- **`references/best-practices.md`** - Complete Grafana Dashboard Linter rules, common mistakes, and anti-patterns
- **`references/advanced-patterns.md`** - Advanced dashboard patterns, provisioning, and complex configurations

---

**Summary**: Design focused dashboards using RED/USE methods. Limit panels to 10-15, use appropriate visualizations, and
enable drill-down with variables. **MANDATORY: All panels must have both a title AND a description. All datasource
variables must follow the naming pattern: `<type>_datasource` (e.g., `prometheus_datasource`, `loki_datasource`,
`tempo_datasource`).** Follow linter rules for production-ready dashboards.
