---
name: o11y-slo-sli
description: This skill should be used when the user asks about "service level objectives", "service level indicators", "error budgets", "burn rate alerts", "SLO definition", "SLA", "reliability metrics", "sloth", or needs guidance on implementing SLO-based monitoring and alerting.
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - prometheus
  - grafana
  task: [configure, audit, optimize]
  persona: [sre, devops]
  workload: [observability]
---

# Observability SLO/SLI Expert

Expert guidance on defining and monitoring Service Level Objectives (SLOs) and Service Level Indicators (SLIs).

## Core Concepts

### SLI (Service Level Indicator)

Quantitative measure of service behavior:

- Availability: % of successful requests
- Latency: % of requests under threshold
- Throughput: Requests per second

### SLO (Service Level Objective)

Target value for an SLI:

- "99.9% of requests succeed"
- "95% of requests complete in < 500ms"

### SLA (Service Level Agreement)

Business contract with consequences:

- "99.9% uptime or refund"
- External commitment to customers

### Error Budget

Allowed failure rate = (1 - SLO):

- SLO: 99.9% → Error budget: 0.1%
- 30-day month: 43 minutes downtime allowed

## Defining SLOs

### Step 1: Choose SLIs

**Availability SLI** (most common):

```promql
# Good events / Total events
sum(rate(http_requests_total{status!~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

**Latency SLI**:

```promql
# Fast requests / Total requests
sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))
```

### Step 2: Set Targets

**Guidelines**:

- Start conservative (99% not 99.99%)
- Match user expectations
- Consider dependencies
- Leave error budget for innovation

**Example SLOs**:

- User-facing service: 99.9%
- Internal API: 99.5%
- Batch jobs: 99%

### Step 3: Define Measurement Windows

**Windows**:

- 30-day rolling window (standard)
- 7-day (faster feedback)
- 1-day (very sensitive)

## Implementing SLOs with Sloth

### Install Sloth

```bash
kubectl apply -f https://raw.githubusercontent.com/slok/sloth/main/deploy/kubernetes/raw/sloth.yaml
```

### Define SLO Spec

```yaml
# slo-api.yaml
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: api-availability
  namespace: monitoring
spec:
  service: "api"
  labels:
    team: "backend"
  slos:
    - name: "availability"
      objective: 99.9
      description: "99.9% of API requests succeed"
      sli:
        events:
          error_query: sum(rate(http_requests_total{job="api",status=~"5.."}[{{.window}}]))
          total_query: sum(rate(http_requests_total{job="api"}[{{.window}}]))
      alerting:
        name: ApiHighErrorRate
        labels:
          severity: critical
        annotations:
          summary: API error budget is burning fast
        page_alert:
          labels:
            severity: critical
        ticket_alert:
          labels:
            severity: warning
```

### Multi-Window Multi-Burn-Rate Alerts

Sloth automatically creates alerts for different burn rates:

**Fast burn** (1h window, 14.4x burn rate):

- Consumes 2% error budget in 1h
- Pages immediately

**Slow burn** (6h window, 6x burn rate):

- Consumes 5% error budget in 6h
- Creates ticket

## Error Budget Policy

### Example Policy

```yaml
error_budget_policy:
  - window: 30d
    slo_target: 99.9
    error_budget: 0.1%
    actions:
      - remaining: 100%
        action: "Development unrestricted"
      - remaining: 50%
        action: "Review releases, prioritize reliability"
      - remaining: 25%
        action: "Feature freeze, focus on reliability"
      - remaining: 0%
        action: "Full freeze until error budget restored"
```

### Burn Rate Calculation

```text
Burn rate = Error rate / Error budget

Example:
- SLO: 99.9%
- Current error rate: 0.5%
- Error budget: 0.1%
- Burn rate: 0.5% / 0.1% = 5x

At 5x burn rate:
- Will exhaust budget in: 30 days / 5 = 6 days
```

## Common SLO Patterns

### API Service

```yaml
slos:
  - name: availability
    objective: 99.9
    sli:
      events:
        error_query: sum(rate(http_requests_total{status=~"5.."}[{{.window}}]))
        total_query: sum(rate(http_requests_total[{{.window}}]))

  - name: latency
    objective: 99
    sli:
      events:
        error_query: sum(rate(http_request_duration_seconds_bucket{le="0.5"}[{{.window}}]))
        total_query: sum(rate(http_request_duration_seconds_count[{{.window}}]))
```

### Database

```yaml
slos:
  - name: query_success
    objective: 99.95
    sli:
      events:
        error_query: sum(rate(database_queries_total{status="error"}[{{.window}}]))
        total_query: sum(rate(database_queries_total[{{.window}}]))

  - name: query_latency
    objective: 99.5
    sli:
      events:
        error_query: sum(rate(database_query_duration_seconds_bucket{le="0.1"}[{{.window}}]))
        total_query: sum(rate(database_query_duration_seconds_count[{{.window}}]))
```

### Message Queue

```yaml
slos:
  - name: processing_success
    objective: 99.9
    sli:
      events:
        error_query: sum(rate(queue_messages_failed_total[{{.window}}]))
        total_query: sum(rate(queue_messages_processed_total[{{.window}}]))
```

## SLO Dashboard

### Grafana Dashboard

```json
{
  "panels": [
    {
      "title": "Error Budget Remaining",
      "targets": [
        {
          "expr": "100 * (1 - ((1 - slo:service_errors:ratio30d) / (1 - 0.999)))"
        }
      ],
      "thresholds": [
        { "value": 0, "color": "red" },
        { "value": 25, "color": "yellow" },
        { "value": 100, "color": "green" }
      ]
    },
    {
      "title": "Burn Rate (5m)",
      "targets": [
        {
          "expr": "(1 - slo:service_errors:ratio5m) / (1 - 0.999)"
        }
      ]
    },
    {
      "title": "SLI Compliance",
      "targets": [
        {
          "expr": "slo:service_errors:ratio30d"
        }
      ],
      "thresholds": [
        { "value": 0.999, "color": "green" },
        { "value": 0.995, "color": "yellow" },
        { "value": 0, "color": "red" }
      ]
    }
  ]
}
```

## Alert Examples

### Fast Burn Rate Alert

```yaml
- alert: SLOErrorBudgetFastBurn
  expr: |
    (
      slo:service_errors:ratio1h > (14.4 * 0.001)
      and
      slo:service_errors:ratio5m > (14.4 * 0.001)
    )
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: Fast burn rate on error budget
    description: "Burning {{ $value }}x error budget"
```

### Slow Burn Rate Alert

```yaml
- alert: SLOErrorBudgetSlowBurn
  expr: |
    (
      slo:service_errors:ratio6h > (6 * 0.001)
      and
      slo:service_errors:ratio30m > (6 * 0.001)
    )
  for: 15m
  labels:
    severity: warning
  annotations:
    summary: Slow burn rate on error budget
```

## Best Practices

### Start Simple

1. Begin with availability SLO
2. Add latency SLO later
3. Measure before committing to SLA

### Align with Users

- SLOs should reflect user experience
- Don't set SLOs users don't care about
- Survey users for expectations

### Use Error Budgets

- Error budget is for innovation
- Spend on releases, experiments
- Don't hoard error budget

### Review Regularly

- Quarterly SLO reviews
- Adjust based on:
  - User feedback
  - Business needs
  - Technical constraints

---

**Summary**: Define SLOs using availability and latency SLIs. Use Sloth for multi-window burn rate alerts. Track error
budgets to balance reliability and innovation.
