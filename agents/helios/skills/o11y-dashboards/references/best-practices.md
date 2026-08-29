# Grafana Dashboard Best Practices

This reference provides comprehensive best practices for creating production-ready Grafana dashboards based on the
[Grafana Dashboard Linter](https://github.com/grafana/dashboard-linter) rules and industry standards.

## Overview

The Grafana Dashboard Linter enforces 17 rules across four categories:

1. **Template Configuration Rules** (5 rules)
2. **Panel Rules** (4 rules)
3. **Query Validation Rules** (7 rules)
4. **Dashboard Configuration Rules** (1 rule)

Following these rules ensures dashboards are:

- **Consistent**: Standardized structure and naming
- **Maintainable**: Easy to update and extend
- **Portable**: Work across different Grafana instances
- **Documented**: Clear purpose and context
- **Performant**: Optimized queries and configurations

---

## Template Configuration Rules

### 1. Template Datasource Rule (`template-datasource-rule`)

⚠️ **MANDATORY NAMING CONVENTION** ⚠️

**Purpose**: Ensures dashboards contain exactly one templated datasource variable with standardized naming.

**Mandatory Naming Convention**:

| Datasource Type | Variable Name           | Query Type   |
| --------------- | ----------------------- | ------------ |
| Prometheus      | `prometheus_datasource` | `prometheus` |
| Loki            | `loki_datasource`       | `loki`       |
| Tempo           | `tempo_datasource`      | `tempo`      |
| Generic Pattern | `<type>_datasource`     | varies       |

**Best Practice**:

```json
{
  "templating": {
    "list": [
      {
        "name": "prometheus_datasource",
        "label": "Prometheus Data Source",
        "type": "datasource",
        "query": "prometheus",
        "current": {
          "text": "Prometheus",
          "value": "prometheus"
        }
      }
    ]
  }
}
```

**For Loki Dashboards**:

```json
{
  "templating": {
    "list": [
      {
        "name": "loki_datasource",
        "label": "Loki Data Source",
        "type": "datasource",
        "query": "loki",
        "current": {
          "text": "Loki",
          "value": "loki"
        }
      }
    ]
  }
}
```

**For Tempo Dashboards**:

```json
{
  "templating": {
    "list": [
      {
        "name": "tempo_datasource",
        "label": "Tempo Data Source",
        "type": "datasource",
        "query": "tempo",
        "current": {
          "text": "Tempo",
          "value": "tempo"
        }
      }
    ]
  }
}
```

**Why This Matters**:

- Ensures consistent naming across all dashboards
- Allows dashboards to work with different datasource instances
- Enables environment-specific datasource selection
- Simplifies dashboard portability across clusters
- Prevents naming conflicts in multi-datasource dashboards

**Variable Naming**:

- ✅ Prometheus: `prometheus_datasource`
- ✅ Loki: `loki_datasource`
- ✅ Tempo: `tempo_datasource`
- ✅ Label: `"<Type> Data Source"` (e.g., "Prometheus Data Source")
- ❌ Generic `datasource` (deprecated - too ambiguous)

**Common Naming Mistakes**:

❌ **Wrong naming patterns**:

- `datasource` (too generic, causes conflicts)
- `ds` (cryptic abbreviation)
- `prom` (not following the pattern)
- `prometheus` (missing `_datasource` suffix)
- `loki-datasource` (using hyphen instead of underscore)

✅ **Correct naming patterns**:

- `prometheus_datasource`
- `loki_datasource`
- `tempo_datasource`
- `elasticsearch_datasource`

**Known Limitations**:

- Currently supports single datasource per dashboard
- Limited to Prometheus and Loki types
- Multi-datasource dashboards require exclusions

**Exclusion Example**:

```yaml
# .lint
exclusions:
  template-datasource-rule:
    reason: "Dashboard uses multiple datasource types (Prometheus + Elasticsearch)"
```

---

### 2. Template Job Rule (`template-job-rule`)

**Purpose**: Requires dashboards to have a templated job variable for filtering by job labels.

**Best Practice**:

```json
{
  "templating": {
    "list": [
      {
        "name": "job",
        "label": "Job",
        "type": "query",
        "datasource": "$datasource",
        "query": "label_values(up, job)",
        "refresh": 2,
        "multi": true,
        "includeAll": true,
        "allValue": ".*"
      }
    ]
  }
}
```

**Why This Matters**:

- Enables filtering metrics by Prometheus job label
- Reduces cardinality in queries
- Improves dashboard performance
- Allows focusing on specific services

**Query Usage**:

```promql
# Use job variable in queries
sum(rate(http_requests_total{job=~"$job"}[5m])) by (instance)
```

**Exclusion Example**:

```yaml
exclusions:
  template-job-rule:
    reason: "Job matcher is hardcoded into recording rules"
```

---

### 3. Template Instance Rule (`template-instance-rule`)

**Purpose**: Verifies dashboards contain a templated instance variable for instance-level filtering.

**Best Practice**:

```json
{
  "templating": {
    "list": [
      {
        "name": "instance",
        "label": "Instance",
        "type": "query",
        "datasource": "$datasource",
        "query": "label_values(up{job=~\"$job\"}, instance)",
        "refresh": 2,
        "multi": true,
        "includeAll": true,
        "allValue": ".*"
      }
    ]
  }
}
```

**Why This Matters**:

- Enables drilling down to specific instances
- Essential for debugging individual servers
- Reduces noise when investigating issues
- Improves query performance by limiting scope

**Query Usage**:

```promql
# Use instance variable in queries
rate(http_requests_total{job=~"$job", instance=~"$instance"}[5m])
```

**Granular Exclusion Example**:

```yaml
exclusions:
  template-instance-rule:
    reason: "Totals span all instances"
    entries:
      - panel: "Total Requests Per Second"
        targetIdx: 0
```

---

### 4. Template Label PromQL Rule (`template-label-promql-rule`)

**Purpose**: Validates that templated labels use proper PromQL expressions.

**Best Practice**:

```json
{
  "name": "namespace",
  "type": "query",
  "datasource": "$datasource",
  "query": "label_values(kube_pod_info, namespace)",
  "refresh": 1,
  "multi": true
}
```

**Common Mistakes**:

❌ **Bad**: Invalid PromQL syntax

```json
{
  "query": "label_values(namespace)"  // Missing metric name
}
```

✅ **Good**: Valid PromQL

```json
{
  "query": "label_values(kube_pod_info, namespace)"
}
```

**Why This Matters**:

- Prevents runtime query errors
- Ensures variables populate correctly
- Validates label extraction logic

---

### 5. Template On Time Change Reload Rule (`template-on-time-change-reload-rule`)

**Purpose**: Confirms template variables refresh appropriately when time ranges change.

**Best Practice**:

```json
{
  "templating": {
    "list": [
      {
        "name": "service",
        "type": "query",
        "query": "label_values(up, service)",
        "refresh": 2  // 2 = On time range change
      }
    ]
  }
}
```

**Refresh Options**:

- `0` = Never
- `1` = On dashboard load
- `2` = On time range change (recommended)

**Why This Matters**:

- Ensures variables stay current with visible data
- Prevents showing stale service/instance lists
- Improves user experience when zooming time ranges

---

## Panel Rules

### 6. Panel Datasource Rule (`panel-datasource-rule`)

**Purpose**: Validates that every panel references the templated datasource rather than hardcoded values.

**Best Practice**:

❌ **Bad**: Hardcoded datasource

```json
{
  "datasource": "Prometheus",
  "targets": [...]
}
```

✅ **Good**: Templated datasource with correct naming

```json
{
  "datasource": "$prometheus_datasource",
  "targets": [...]
}
```

**For Loki Panels**:

```json
{
  "datasource": "$loki_datasource",
  "targets": [...]
}
```

**For Tempo Panels**:

```json
{
  "datasource": "$tempo_datasource",
  "targets": [...]
}
```

**Why This Matters**:

- Enables dashboard portability across environments
- Allows switching datasources without editing panels
- Reduces maintenance burden
- Follows standardized naming convention

---

### 7. Panel Title Description Rule (`panel-title-description-rule`)

⚠️ **MANDATORY REQUIREMENT** ⚠️

**Purpose**: **ALL panels MUST include both a title AND a description. This is a non-negotiable requirement for
production dashboards.**

**Best Practice**:

```json
{
  "title": "Request Rate",
  "description": "Total HTTP requests per second across all instances. Uses 5-minute rate calculation for smoothing. Alert threshold: > 1000 rps.",
  "type": "graph",
  "targets": [...]
}
```

**Panel Types Covered**:

- stat
- singlestat
- graph
- table
- timeseries
- gauge

**Title Guidelines**:

- Clear and concise (< 50 characters)
- Describes what the panel shows
- Uses consistent capitalization

**Description Guidelines**:

- Explains the metric's purpose
- Documents thresholds or alert conditions
- Provides troubleshooting context
- Links to runbooks or documentation

**Example Descriptions**:

```markdown
## API Error Rate

Percentage of 5xx responses over total requests in the last 5 minutes.

**Alert Threshold**: > 5%
**Runbook**: <https://runbooks.example.com/api-errors>
**Data Source**: Prometheus http_requests_total metric
```

**Acceptable Exclusion**:

```yaml
exclusions:
  panel-title-description-rule:
    reason: "Title and visualization are self-explanatory"
    entries:
      - panel: "Status"
```

---

### 8. Panel Units Rule (`panel-units-rule`)

**Purpose**: Ensures panels have valid units properly defined.

**Best Practice**:

```json
{
  "fieldConfig": {
    "defaults": {
      "unit": "reqps",  // Requests per second
      "decimals": 2,
      "min": 0
    }
  }
}
```

**Common Units**:

| Unit          | Use Case            | Format        |
| ------------- | ------------------- | ------------- |
| `short`       | Generic numbers     | 1.23K, 4.56M  |
| `percent`     | Percentages         | 95.5%         |
| `percentunit` | Ratios (0-1)        | 0.955 → 95.5% |
| `bytes`       | Data size           | 1.5 GB        |
| `decbytes`    | Data size (decimal) | 1.5 GB        |
| `reqps`       | Requests/sec        | 1.2K rps      |
| `ops`         | Operations/sec      | 500 ops       |
| `s`           | Seconds             | 1.5s          |
| `ms`          | Milliseconds        | 250ms         |
| `µs`          | Microseconds        | 1500µs        |
| `ns`          | Nanoseconds         | 1000ns        |

**Unit Examples by Panel Type**:

```json
// CPU usage
{
  "unit": "percent",
  "min": 0,
  "max": 100
}

// Memory size
{
  "unit": "bytes",
  "decimals": 2
}

// Request rate
{
  "unit": "reqps",
  "decimals": 1
}

// Latency
{
  "unit": "ms",
  "decimals": 2
}

// Error rate
{
  "unit": "percentunit",
  "decimals": 2,
  "min": 0,
  "max": 1
}
```

**Automatic Exclusions**:

- Panels with value mappings enabled
- Stat panels displaying non-numeric values

**Manual Exclusion Example**:

```yaml
exclusions:
  panel-units-rule:
    reason: "Displays categorical status values"
    entries:
      - panel: "Service Health Status"
```

---

### 9. Panel No Targets Rule (`panel-no-targets-rule`)

**Purpose**: Verifies each panel contains at least one query target.

**Best Practice**:

```json
{
  "title": "Request Rate",
  "targets": [
    {
      "expr": "sum(rate(http_requests_total[5m]))",
      "legendFormat": "Total Requests"
    }
  ]
}
```

**Why This Matters**:

- Prevents empty/broken panels
- Catches configuration errors early
- Ensures all panels serve a purpose

**Common Mistake**:

```json
{
  "title": "Request Rate",
  "targets": []  // ❌ Empty targets array
}
```

---

## Query Validation Rules

### 10. Target LogQL Rule (`target-logql-rule`)

**Purpose**: Validates Loki query targets use syntactically correct LogQL expressions.

**Best Practice**:

✅ **Valid LogQL**:

```logql
# Basic label matching
{job="api"}

# With log filtering
{job="api"} |= "error"

# With parsing
{job="api"} | json | level="error"

# With aggregations
sum(rate({job="api"}[5m])) by (level)
```

❌ **Invalid LogQL**:

```logql
# Missing braces
job="api"

# Invalid operator
{job="api"} >= "error"

# Malformed aggregation
rate({job="api"}[5m]) by level
```

**Why This Matters**:

- Prevents runtime query errors
- Ensures logs display correctly
- Validates syntax before deployment

---

### 11. Target LogQL Auto Rule (`target-logql-auto-rule`)

**Purpose**: Ensures Loki targets employ `$__auto` for appropriate range vectors.

**Best Practice**:

✅ **Good**: Using $__auto

```logql
rate({job="api"}[$__auto])
```

❌ **Bad**: Fixed interval

```logql
rate({job="api"}[5m])
```

**Why This Matters**:

- Automatically adjusts range based on time window
- Prevents insufficient data points
- Improves query performance

**When to Use Fixed Intervals**:

```yaml
exclusions:
  target-logql-auto-rule:
    reason: "Fixed 24-hour rate for SLO calculation"
    entries:
      - panel: "Daily Error Budget"
        targetIdx: 0
```

---

### 12. Target PromQL Rule (`target-promql-rule`)

**Purpose**: Validates Prometheus targets use correct PromQL syntax.

**Best Practice**:

✅ **Valid PromQL**:

```promql
# Basic metric
http_requests_total

# With labels
http_requests_total{job="api", status="200"}

# With functions
rate(http_requests_total[5m])

# With aggregation
sum(rate(http_requests_total[5m])) by (job)

# Complex query
sum(rate(http_requests_total{status=~"5.."}[5m])) by (job)
/
sum(rate(http_requests_total[5m])) by (job)
* 100
```

❌ **Invalid PromQL**:

```promql
# Missing brackets
rate(http_requests_total 5m)

# Invalid operator
http_requests_total > = 100

# Malformed aggregation
sum rate(http_requests_total[5m])

# Missing closing bracket
rate(http_requests_total[5m]
```

**Why This Matters**:

- Catches syntax errors before deployment
- Prevents broken panels
- Validates query logic

---

### 13. Target Rate Interval Rule (`target-rate-interval-rule`)

**Purpose**: Requires queries using `rate`, `irate`, or `increase` to use `$__rate_interval`.

**Best Practice**:

✅ **Good**: Using $__rate_interval

```promql
rate(http_requests_total[5m])
# Should be:
rate(http_requests_total[$__rate_interval])
```

✅ **Good**: Using $__rate_interval with aggregation

```promql
sum(rate(http_requests_total[$__rate_interval])) by (job)
```

**Why This Matters**:

- Ensures adequate data points for rate calculations
- Adapts to scrape intervals dynamically
- Prevents "no data" errors with sparse metrics
- Maintains accuracy across different time ranges

**How $__rate_interval Works**:

```text
$__rate_interval = max(
  scrape_interval * 4,
  time_range / pixel_width * 1s
)
```

**Grafana Recommendation**:

> "Using `$__rate_interval` prevents insufficient sampling that could skew rate calculations."

**When Fixed Intervals Are Acceptable**:

```yaml
exclusions:
  target-rate-interval-rule:
    reason: "Fixed 1-hour window for specific SLO calculation"
    entries:
      - panel: "Hourly Error Rate"
        targetIdx: 0
```

**Common Functions Affected**:

- `rate(metric[$__rate_interval])`
- `irate(metric[$__rate_interval])`
- `increase(metric[$__rate_interval])`

---

### 14. Target Job Rule (`target-job-rule`)

**Purpose**: Enforces job label matchers in every PromQL query.

**Best Practice**:

✅ **Good**: Includes job matcher

```promql
rate(http_requests_total{job=~"$job"}[5m])

sum(rate(http_requests_total{job="api"}[$__rate_interval])) by (instance)

http_requests_total{job=~"api|frontend"}
```

❌ **Bad**: Missing job matcher

```promql
rate(http_requests_total[5m])

sum(rate(http_requests_total[$__rate_interval])) by (instance)
```

**Why This Matters**:

- Reduces query cardinality
- Improves query performance
- Enables filtering by service
- Prevents accidental cross-service queries

**Query Patterns**:

```promql
# Single job
{job="api"}

# Job variable
{job=~"$job"}

# Multiple jobs
{job=~"api|worker|scheduler"}

# Regex pattern
{job=~"prod-.*"}
```

**Exclusion Example**:

```yaml
exclusions:
  target-job-rule:
    reason: "Aggregates across all jobs for cluster-wide metrics"
    entries:
      - panel: "Cluster Total CPU"
        targetIdx: 0
```

---

### 15. Target Instance Rule (`target-instance-rule`)

**Purpose**: Mandates instance label matchers in all PromQL queries.

**Best Practice**:

✅ **Good**: Includes instance matcher

```promql
rate(http_requests_total{job=~"$job", instance=~"$instance"}[5m])

sum(rate(http_requests_total{job="api", instance=~".*:8080"}[$__rate_interval]))

node_cpu_seconds_total{instance="server1:9100"}
```

❌ **Bad**: Missing instance matcher

```promql
rate(http_requests_total{job=~"$job"}[5m])

sum(rate(http_requests_total{job="api"}[$__rate_interval]))
```

**Why This Matters**:

- Enables instance-level debugging
- Reduces query cardinality
- Improves dashboard performance
- Allows drilling down to specific servers

**When to Exclude**:

- Cluster-wide aggregations
- Total metrics across all instances
- Recording rules that pre-aggregate

**Exclusion Example**:

```yaml
exclusions:
  target-instance-rule:
    reason: "Shows total across all instances"
    entries:
      - panel: "Total Request Rate"
        targetIdx: 0
      - panel: "Cluster CPU Usage"
        targetIdx: 0
```

---

### 16. Target Counter Aggregation Rule (`target-counter-agg-rule`)

**Purpose**: Requires counter metrics (ending in `_total`) use rate, irate, or increase aggregations.

**Best Practice**:

✅ **Good**: Counter with rate function

```promql
# Raw counter metric: http_requests_total
rate(http_requests_total[$__rate_interval])

# With aggregation
sum(rate(http_requests_total[$__rate_interval])) by (job)

# Using irate for high-resolution
irate(http_requests_total[$__rate_interval])

# Using increase
increase(http_requests_total[1h])
```

❌ **Bad**: Counter without rate function

```promql
# Raw counter (always increasing)
http_requests_total

# Counter in aggregation without rate
sum(http_requests_total) by (job)
```

**Why This Matters**:

- Counter metrics continuously increase (monotonic)
- Raw counters are not useful for visualization
- Rate functions calculate per-second change
- Prevents misleading graphs

**Counter Metrics Pattern**:

```text
Metric Name Pattern: *_total
Examples:
  - http_requests_total
  - http_request_duration_seconds_total
  - errors_total
  - bytes_sent_total
```

**Function Comparison**:

| Function     | Use Case            | Calculation                   |
| ------------ | ------------------- | ----------------------------- |
| `rate()`     | Smooth average rate | Per-second average over range |
| `irate()`    | Instant rate        | Rate between last two samples |
| `increase()` | Total increase      | Sum of increases over range   |

**Examples by Use Case**:

```promql
# Request rate (smoothed)
rate(http_requests_total[$__rate_interval])

# Instant request rate (high resolution)
irate(http_requests_total[$__rate_interval])

# Total requests in last hour
increase(http_requests_total[1h])

# Error rate percentage
sum(rate(http_requests_total{status=~"5.."}[$__rate_interval]))
/
sum(rate(http_requests_total[$__rate_interval]))
* 100
```

**Non-Counter Metrics** (don't need rate):

```promql
# Gauges (can go up and down)
node_memory_available_bytes

# Histograms
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[$__rate_interval]))
```

---

## Dashboard Configuration Rules

### 17. Uneditable Dashboard Rule (`uneditable-dashboard`)

**Purpose**: Confirms dashboards are protected against accidental modifications.

**Best Practice**:

```json
{
  "dashboard": {
    "title": "Production API Monitoring",
    "editable": false,
    "version": 1
  }
}
```

**Why This Matters**:

- Prevents accidental changes in production
- Enforces dashboard-as-code workflow
- Protects standardized dashboards
- Encourages version control

**When to Allow Editing**:

```json
{
  "editable": true  // Development/staging environments
}
```

**Dashboard Protection Strategy**:

1. **Production**: `editable: false`
2. **Staging**: `editable: false` (test changes)
3. **Development**: `editable: true` (rapid iteration)

**Provisioning Configuration**:

```yaml
apiVersion: 1
providers:
  - name: 'production'
    folder: 'Production'
    type: file
    disableDeletion: true    # Prevent deletion
    allowUiUpdates: false     # Prevent UI edits
    options:
      path: /etc/grafana/dashboards/production
```

---

## Lint Configuration

### Configuration File Format

Create a `.lint` file in your dashboard directory:

```yaml
# .lint
# Exclude specific rules
exclusions:
  template-job-rule:
    reason: "Job matcher hardcoded in recording rules"

  template-datasource-rule:
    reason: "Multi-datasource dashboard (Prometheus + Loki + Elasticsearch)"

# Downgrade rules to warnings
warnings:
  template-instance-rule:

# Granular exclusions for specific panels
exclusions:
  target-instance-rule:
    reason: "Cluster-wide totals span all instances"
    entries:
      - panel: "Total Requests Per Second"
        targetIdx: 0
      - panel: "Cluster CPU Usage"
        targetIdx: 1

  panel-units-rule:
    reason: "Status panel uses value mappings"
    entries:
      - panel: "Service Health"
```

### Command-Line Usage

```bash
# Lint a single dashboard
dashboard-linter lint dashboard.json

# Lint with auto-fix
dashboard-linter lint --fix dashboard.json

# Strict mode (warnings become errors)
dashboard-linter lint --strict dashboard.json

# Verbose output
dashboard-linter lint --verbose dashboard.json

# Custom config file
dashboard-linter lint --config custom.lint dashboard.json

# Lint multiple dashboards
dashboard-linter lint dashboards/*.json

# Show rule documentation
dashboard-linter rules

# Show specific rule
dashboard-linter rules template-datasource-rule
```

### CI/CD Integration

```yaml
# .github/workflows/lint-dashboards.yml
name: Lint Grafana Dashboards

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install dashboard-linter
        run: |
          go install github.com/grafana/dashboard-linter@latest

      - name: Lint dashboards
        run: |
          dashboard-linter lint --strict dashboards/*.json
```

---

## Complete Dashboard Example

Here's a production-ready dashboard following all best practices:

```json
{
  "dashboard": {
    "title": "API Production Monitoring",
    "tags": ["api", "production"],
    "timezone": "browser",
    "refresh": "30s",
    "editable": false,
    "version": 1,

    "templating": {
      "list": [
        {
          "name": "prometheus_datasource",
          "label": "Prometheus Data Source",
          "type": "datasource",
          "query": "prometheus",
          "current": {
            "text": "Prometheus",
            "value": "prometheus"
          }
        },
        {
          "name": "job",
          "label": "Job",
          "type": "query",
          "datasource": "$prometheus_datasource",
          "query": "label_values(up, job)",
          "refresh": 2,
          "multi": true,
          "includeAll": true
        },
        {
          "name": "instance",
          "label": "Instance",
          "type": "query",
          "datasource": "$prometheus_datasource",
          "query": "label_values(up{job=~\"$job\"}, instance)",
          "refresh": 2,
          "multi": true,
          "includeAll": true
        }
      ]
    },

    "panels": [
      {
        "title": "Request Rate",
        "description": "Total HTTP requests per second using 5-minute rolling average. Alert threshold: > 1000 rps.",
        "type": "graph",
        "datasource": "$prometheus_datasource",
        "gridPos": {"x": 0, "y": 0, "w": 12, "h": 8},
        "fieldConfig": {
          "defaults": {
            "unit": "reqps",
            "decimals": 2
          }
        },
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=~\"$job\", instance=~\"$instance\"}[$__rate_interval])) by (job)",
            "legendFormat": "{{job}}"
          }
        ]
      },
      {
        "title": "Error Rate",
        "description": "Percentage of 5xx responses over total requests. SLO: < 1%. Alert at > 5%.",
        "type": "graph",
        "datasource": "$prometheus_datasource",
        "gridPos": {"x": 12, "y": 0, "w": 12, "h": 8},
        "fieldConfig": {
          "defaults": {
            "unit": "percentunit",
            "decimals": 2,
            "min": 0,
            "max": 1
          }
        },
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=~\"$job\", instance=~\"$instance\", status=~\"5..\"}[$__rate_interval])) / sum(rate(http_requests_total{job=~\"$job\", instance=~\"$instance\"}[$__rate_interval]))",
            "legendFormat": "Error Rate"
          }
        ]
      }
    ]
  }
}
```

---

## Summary Checklist

Use this checklist when creating or reviewing dashboards:

### Template Variables

- [ ] **MANDATORY: Has templated datasource variable with correct naming** (`prometheus_datasource`, `loki_datasource`,
      or `tempo_datasource`)
- [ ] Has job template variable using `label_values()`
- [ ] Has instance template variable using `label_values()`
- [ ] All template queries use valid PromQL syntax
- [ ] Variables refresh on time range change (`refresh: 2`)

### Panels

- [ ] All panels use correct datasource variable (e.g., `$prometheus_datasource`, not hardcoded)
- [ ] **MANDATORY: All panels have clear, descriptive titles**
- [ ] **MANDATORY: All panels have detailed descriptions**
- [ ] All panels have appropriate units configured
- [ ] All panels have at least one query target

### Queries

- [ ] LogQL queries are syntactically valid
- [ ] Loki queries use `$__auto` for range vectors
- [ ] PromQL queries are syntactically valid
- [ ] Rate/irate/increase use `$__rate_interval`
- [ ] All queries include `{job=~"$job"}` matcher
- [ ] All queries include `{instance=~"$instance"}` matcher
- [ ] Counter metrics use rate/irate/increase functions

### Dashboard

- [ ] Dashboard is marked as non-editable (`editable: false`)
- [ ] Dashboard has appropriate tags
- [ ] Dashboard has reasonable refresh interval
- [ ] Dashboard includes `.lint` file with documented exclusions

---

## Common Mistakes to Avoid

### Dashboard Organization Mistakes

#### Too Many Panels

❌ **Bad Practice**:

- 50+ panels on one dashboard
- Cluttered layout with no clear hierarchy
- Multiple unrelated metrics on the same dashboard

✅ **Good Practice**:

- 10-15 focused panels per dashboard
- Clear visual hierarchy (KPIs → Trends → Details)
- Create separate dashboards for different concerns
- Use rows to organize related panels

**Rationale**: Overloaded dashboards are hard to navigate, slow to load, and difficult to maintain. Focus on specific
use cases or user personas.

**Example Structure**:

```text
Dashboard 1: API Service Overview (10 panels)
Dashboard 2: API Performance Deep Dive (12 panels)
Dashboard 3: API Error Analysis (8 panels)
```

---

#### Wrong Time Ranges

❌ **Bad Practice**:

- Using 24h range for real-time monitoring dashboards
- Not configuring appropriate refresh intervals
- Same time range for all dashboard types

✅ **Good Practice**:

- **Real-time monitoring**: 1h or 6h with 30s-1m refresh
- **Trend analysis**: 24h or 7d with 5m+ refresh
- **Historical analysis**: 30d+ with no auto-refresh
- Enable time picker for user flexibility

**Configuration Examples**:

```json
// Real-time operations dashboard
{
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "refresh": "30s"
}

// Daily trend analysis
{
  "time": {
    "from": "now-24h",
    "to": "now"
  },
  "refresh": "5m"
}

// Historical performance review
{
  "time": {
    "from": "now-30d",
    "to": "now"
  },
  "refresh": false
}
```

---

### Panel Configuration Mistakes

#### No Context

⚠️ **CRITICAL VIOLATION** ⚠️

❌ **Bad Practice**:

- **Panel without title (FORBIDDEN)**
- **Panel without description (FORBIDDEN)**
- Missing units on axis
- No tooltip or context
- Cryptic metric names in legends

✅ **Good Practice** ✅:

- **MANDATORY: Clear, descriptive panel titles**
- **MANDATORY: Detailed panel descriptions with alert thresholds and runbook links**
- Proper unit configuration (%, bytes, seconds, etc.)
- Meaningful legend formats using label variables

**Example**:

```json
{
  "title": "API Response Time (P95)",
  "description": "95th percentile response time for API endpoints. Alert threshold: > 500ms. Includes all HTTP methods.",
  "fieldConfig": {
    "defaults": {
      "unit": "ms",
      "decimals": 2
    }
  },
  "targets": [{
    "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, endpoint))",
    "legendFormat": "{{endpoint}}"
  }]
}
```

---

### Query Mistakes

#### High Cardinality

❌ **Bad Practice**:

```promql
# Grouping by high-cardinality labels
sum(rate(http_requests_total[5m])) by (user_id)

# Grouping by dynamic paths
sum(rate(http_requests_total[5m])) by (path)

# Grouping by IP addresses
sum(rate(http_requests_total[5m])) by (client_ip)
```

✅ **Good Practice**:

```promql
# Group by low-cardinality labels
sum(rate(http_requests_total[5m])) by (service, region)

# Use topk/bottomk for high cardinality when needed
topk(10, sum(rate(http_requests_total[5m])) by (endpoint))

# Pre-aggregate with recording rules
sum(rate(http_requests_total[5m])) by (service)
```

**Why This Matters**:

- High cardinality queries are slow and resource-intensive
- Can cause Prometheus/Grafana performance issues
- May hit cardinality limits
- Makes graphs unreadable with too many series

**Cardinality Guidelines**:

| Label Type | Cardinality     | Usage                           |
| ---------- | --------------- | ------------------------------- |
| Low        | < 100 values    | ✅ Safe for grouping            |
| Medium     | 100-1000 values | ⚠️ Use with topk/bottomk         |
| High       | > 1000 values   | ❌ Avoid or use recording rules |

**Examples by Cardinality**:

**Low Cardinality** (safe):

- `service`, `environment`, `region`, `zone`
- `job`, `instance`, `cluster`
- `method`, `status_code`, `handler`

**Medium Cardinality** (use carefully):

- `endpoint`, `route`, `pod`
- `container`, `node`

**High Cardinality** (avoid):

- `user_id`, `session_id`, `request_id`
- `ip_address`, `email`
- Dynamic path segments (`/users/12345`)

---

#### Missing Rate Functions

❌ **Bad Practice**:

```promql
# Using counter metrics without rate
http_requests_total

# Aggregating counters directly
sum(http_requests_total) by (job)
```

✅ **Good Practice**:

```promql
# Always use rate/irate/increase with counters
rate(http_requests_total[$__rate_interval])

# Aggregate after rate calculation
sum(rate(http_requests_total[$__rate_interval])) by (job)
```

**Related Rule**: See `target-counter-agg-rule` in the linter rules section.

---

#### Hardcoded Values

❌ **Bad Practice**:

```promql
# Hardcoded time ranges
rate(http_requests_total[5m])

# Hardcoded datasource
{
  "datasource": "Prometheus Production"
}

# Wrong datasource variable naming
{
  "datasource": "$datasource"  // Too generic
}
{
  "datasource": "$prom"  // Not following pattern
}

# Hardcoded label values
{job="api", environment="production"}
```

✅ **Good Practice**:

```promql
# Use variables
rate(http_requests_total[$__rate_interval])

# Use templated datasource with correct naming
{
  "datasource": "$prometheus_datasource"
}

# For Loki panels
{
  "datasource": "$loki_datasource"
}

# Use template variables
{job=~"$job", environment=~"$environment"}
```

---

### Color and Threshold Mistakes

#### Inconsistent Color Schemes

❌ **Bad Practice**:

- Random colors per panel
- Red for success, green for errors
- Different threshold levels across similar panels

✅ **Good Practice**:

- **Consistent color mapping**:
  - 🟢 Green: Healthy, success, within SLO
  - 🟡 Yellow: Warning, degraded, approaching threshold
  - 🔴 Red: Critical, error, SLO violation
  - 🔵 Blue: Informational, neutral

- **Consistent thresholds** across dashboard:
  - Error rate: < 1% green, 1-5% yellow, > 5% red
  - Latency: < 100ms green, 100-500ms yellow, > 500ms red
  - CPU: < 70% green, 70-90% yellow, > 90% red

**Example Threshold Configuration**:

```json
{
  "fieldConfig": {
    "defaults": {
      "thresholds": {
        "mode": "absolute",
        "steps": [
          { "value": null, "color": "green" },
          { "value": 1, "color": "yellow" },
          { "value": 5, "color": "red" }
        ]
      },
      "unit": "percentunit"
    }
  }
}
```

---

### Variable Configuration Mistakes

#### Overly Complex Variables

❌ **Bad Practice**:

```json
{
  "name": "instance",
  "query": "label_values(up{job=~\"$job\",environment=~\"$environment\",region=~\"$region\",cluster=~\"$cluster\"}, instance)"
}
```

✅ **Good Practice**:

```json
// Start simple
{
  "name": "instance",
  "query": "label_values(up{job=~\"$job\"}, instance)"
}

// Add complexity only when needed
{
  "name": "instance",
  "query": "label_values(up{job=~\"$job\", environment=~\"$environment\"}, instance)"
}
```

---

#### Missing All/Multi Options

❌ **Bad Practice**:

```json
{
  "name": "service",
  "multi": false,
  "includeAll": false
}
```

✅ **Good Practice**:

```json
{
  "name": "service",
  "multi": true,
  "includeAll": true,
  "allValue": ".*"
}
```

**Why This Matters**:

- Users often want to see all services at once
- Multi-select enables comparing specific services
- Improves dashboard flexibility

---

## Quick Reference: Anti-Patterns

| Anti-Pattern                     | Impact                     | Solution                                       |
| -------------------------------- | -------------------------- | ---------------------------------------------- |
| 50+ panels per dashboard         | Slow load, confusing       | Split into 3-4 focused dashboards              |
| 24h range for real-time          | Delayed insights           | Use 1h-6h range                                |
| **Missing panel titles** ⚠️       | **FORBIDDEN - No context** | **MANDATORY: Add descriptive titles**          |
| **Missing panel descriptions** ⚠️ | **FORBIDDEN - No context** | **MANDATORY: Add detailed descriptions**       |
| No units configured              | Ambiguous values           | Set appropriate units                          |
| High cardinality grouping        | Slow queries               | Use topk() or recording rules                  |
| Hardcoded datasource             | Not portable               | Use `$prometheus_datasource` variable          |
| **Wrong datasource naming** ⚠️    | **Inconsistent**           | **MANDATORY: Use `<type>_datasource` pattern** |
| Counter without rate()           | Misleading graphs          | Always use rate/irate/increase                 |
| Inconsistent colors              | Confusing                  | Use standard color scheme                      |
| No variables                     | Not reusable               | Add datasource, job, instance                  |
| Random refresh rates             | Poor UX                    | Match use case (30s-5m)                        |

---

## Quick Validation

Use the provided validation script to check your dashboards:

```bash
# Validate dashboards in a directory
./scripts/validate-dashboards.sh ./dashboards

# Strict mode (warnings become errors)
./scripts/validate-dashboards.sh --strict ./dashboards

# Verbose output
./scripts/validate-dashboards.sh --verbose ./dashboards

# Auto-fix issues
./scripts/validate-dashboards.sh --fix ./dashboards
```

See `scripts/README.md` for complete usage documentation.

---

## Additional Resources

### Documentation

- [Grafana Dashboard Linter Repository](https://github.com/grafana/dashboard-linter)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Provisioning](https://grafana.com/docs/grafana/latest/administration/provisioning/)

### Tools

- **Validation Script**: `scripts/validate-dashboards.sh` - Quick dashboard validation
- **Dashboard Linter**: `dashboard-linter` - Automated rule checking

### Related Files

- `o11y-dashboards/SKILL.md` - Core dashboard design concepts
- `o11y-dashboards/references/advanced-patterns.md` - Advanced implementation patterns
- `o11y-dashboards/scripts/README.md` - Validation script documentation
