---
name: o11y-expert
description: This skill should be used when the user asks to "design observability strategy", "implement observability", "monitoring architecture", "set up monitoring", "o11y best practices", "telemetry setup", "observability stack", or needs strategic guidance on observability implementation for DevOps/SRE workflows.
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - grafana
  - prometheus
  - loki
  - opentelemetry
  task: [configure, debug, review]
  persona: [sre, devops]
  workload: [observability]
---

# Observability Expert

Provide strategic guidance and architecture recommendations for implementing comprehensive observability across modern
infrastructure and applications.

## Purpose

Serve as the master orchestrator for observability strategy, helping DevOps and SRE teams design, implement, and
optimize monitoring systems. Guide users through selecting the right tools, architecting observability stacks, and
establishing best practices for metrics, logs, traces, dashboards, and SLO/SLI monitoring.

## Core Responsibilities

### Strategic Architecture

Help users design observability strategies by:

1. **Assessing current state**: Understand existing infrastructure, applications, and monitoring gaps
2. **Defining requirements**: Identify what needs to be monitored and why (services, infrastructure, user experience)
3. **Selecting tools**: Recommend the appropriate observability stack based on constraints (budget, scale, expertise,
   cloud provider)
4. **Planning implementation**: Create phased rollout plans prioritizing highest-value signals first

### Technology Selection Decision Tree

Guide users through choosing the right observability stack:

#### Recommended Platform Stacks

**Option 1: LGTM Stack (Recommended for most)**

A comprehensive observability platform consisting of:

- **Metrics**: Prometheus (+ Mimir/Thanos for long-term storage)
- **Logs**: Loki
- **Traces**: Tempo
- **Collection**: OpenTelemetry Collector (one per signal: logs, metrics, traces + one gateway)
- **Visualization**: Grafana

**Choose LGTM when:**

- Open source preferred
- Kubernetes/cloud-native infrastructure
- Need flexibility and vendor independence
- Team has technical expertise
- Want community ecosystem and control

**OpenTelemetry Collector Architecture for LGTM:**

- Deploy **4 collectors**:
  - One dedicated collector for logs
  - One dedicated collector for metrics
  - One dedicated collector for traces
  - One gateway collector for routing and preprocessing

**Option 2: Signoz (All-in-One)**

A unified observability platform built on:

- **Backend**: Clickhouse
- **Collection**: OpenTelemetry Collector
- **Signals**: Metrics, logs, and traces in one platform

**Choose Signoz when:**

- Want simpler deployment and management
- Prefer unified query interface across all signals
- Need faster setup with less operational complexity
- Clickhouse performance benefits are attractive

**Option 3: Clickhouse with Clickstack**

**Choose when:**

- Already using Clickhouse
- Want Clickhouse's performance characteristics
- Need custom observability solution

**What we DON'T use:**

❌ Promtail (replaced by OpenTelemetry Collector)
❌ Fluentbit (replaced by OpenTelemetry Collector)
❌ Elasticsearch (replaced by Loki or Clickhouse)

#### For Commercial Solutions

**Datadog - Choose when:**

- Want turnkey solution with minimal setup
- Budget allows ($15-23/host/month + custom metrics)
- Need comprehensive features immediately
- Prefer support over DIY
- APM and RUM are priorities

**Grafana Cloud - Choose when:**

- Want Prometheus/Loki/Tempo but don't want to operate them
- Need managed Grafana with enterprise features
- Hybrid approach: managed backend, control over collection

### Three Pillars Implementation Order

Recommend implementing observability signals in this priority order:

#### 1. Metrics First (Weeks 1-2)

**Why first**: Provide system-wide visibility quickly, lowest overhead, easiest to implement

**Implementation:**

- Deploy Prometheus for metrics storage
- Deploy dedicated OpenTelemetry Collector for metrics collection
- Instrument infrastructure: node exporters, cAdvisor, cloud provider metrics
- Create basic dashboards: CPU, memory, disk, network
- Set up fundamental alerts: host down, disk full, high CPU

**Reference**: Consult `o11y-metrics` skill for detailed Prometheus setup

#### 2. Logs Second (Weeks 2-3)

**Why second**: Essential for debugging, builds on metrics foundation

**Implementation:**

- Deploy log aggregation: Loki with dedicated OpenTelemetry Collector for logs
- Collect application logs with structured format (JSON)
- Configure retention policies
- Create log-based metrics for key events
- Link logs to metrics (via labels/tags)
- Configure the OTEL Collector to receive logs and forward to Loki

**Reference**: Consult `o11y-logs` skill for log aggregation patterns

#### 3. Traces Last (Weeks 3-4)

**Why last**: Higher complexity, requires application changes, benefits from metrics/logs foundation

**Implementation:**

- Deploy dedicated OpenTelemetry Collector for traces
- Deploy OpenTelemetry Collector gateway for routing and preprocessing
- Instrument applications with OTel SDKs
- Configure sampling (start with head sampling: 1-5%)
- Deploy trace backend: Tempo (recommended for LGTM) or Signoz
- Create service dependency maps
- Link traces to metrics and logs

**Reference**: Consult `o11y-traces` skill for distributed tracing setup

### OpenTelemetry Collector Architecture

For the LGTM stack and other platforms, deploy OpenTelemetry Collectors with this architecture:

#### Collector Deployment Pattern

1. **Dedicated Collectors (One per Signal)**:
   - **Metrics Collector**: Receives metrics from instrumented applications, exporters, and Prometheus remote write
   - **Logs Collector**: Receives logs from applications and forwards to Loki
   - **Traces Collector**: Receives traces from instrumented applications and forwards to Tempo

2. **Gateway Collector**:
   - Central routing and preprocessing layer
   - Handles filtering, sampling, and enrichment
   - Load balancing across backend services
   - Reduces load on individual signal collectors

#### Benefits of This Architecture

- **Isolation**: Each signal has dedicated resources, preventing cross-signal interference
- **Scalability**: Scale each signal independently based on volume
- **Reliability**: Failure in one signal doesn't affect others
- **Flexibility**: Configure each collector for its specific signal requirements
- **Performance**: Optimize each collector for its workload (batch sizes, memory, processors)

#### Deployment Topology

```text
Applications/Exporters
    ↓
Gateway Collector (optional, for preprocessing)
    ↓
    ├─→ Metrics Collector → Prometheus
    ├─→ Logs Collector → Loki
    └─→ Traces Collector → Tempo
```

**Reference**: Consult `o11y-traces` skill for OpenTelemetry Collector configuration details

### Recommended Dashboards

Guide users to create these dashboards in order:

1. **Infrastructure Overview**: CPU, memory, disk, network across all hosts
2. **Application Health**: Request rate, error rate, latency (RED method)
3. **Resource Utilization**: Utilization, saturation, errors (USE method)
4. **SLO Dashboard**: Error budget consumption, burn rate alerts
5. **Business Metrics**: User signups, transactions, revenue (if applicable)

**Reference**: Consult `o11y-dashboards` skill for Grafana dashboard design

### Alert Strategy

Recommend this alert hierarchy:

#### Critical Alerts (Page immediately)

- Service completely down
- SLO error budget exhausted
- Data loss imminent (disk >95%)
- Security breach detected

**Goal**: <5 critical alerts, each must be immediately actionable

#### Warning Alerts (Notify, don't wake up)

- Service degraded
- SLO burn rate elevated
- Resource trending toward exhaustion
- Backup failures

**Goal**: <20 warning alerts, triaged during business hours

#### Info Alerts (Log only, for analysis)

- Routine events
- Non-critical threshold breaches
- Planned maintenance activities

**Goal**: No alert fatigue, use for postmortem analysis

**Reference**: Consult `o11y-slo-sli` skill for SLO-based alerting

### Tool Coordination

Orchestrate the use of specialized skills based on user needs:

| User Need                                              | Skill to Consult  |
| ------------------------------------------------------ | ----------------- |
| Prometheus configuration, recording rules, cardinality | `o11y-metrics`    |
| Log aggregation, Loki setup, log parsing               | `o11y-logs`       |
| Distributed tracing, OpenTelemetry, sampling           | `o11y-traces`     |
| Grafana dashboards, visualization, queries             | `o11y-dashboards` |
| SLOs, error budgets, burn rate alerts                  | `o11y-slo-sli`    |

**Usage pattern**: Provide high-level strategy here, reference specialized skills for implementation details.

## Common Scenarios

### Scenario 1: Starting from Zero

**User asks**: "We have no monitoring. Where do we start?"

**Response approach**:

1. Understand infrastructure: Kubernetes? VMs? Cloud provider?
2. Recommend stack based on requirements:
   - **LGTM Stack**: Best for most use cases, component flexibility
   - **Signoz**: Simpler setup, unified platform, good for smaller teams
   - **Clickhouse + Clickstack**: If already using Clickhouse
3. Provide phased plan: metrics → logs → traces
4. Explain OpenTelemetry Collector architecture: dedicated collectors per signal + gateway
5. Suggest commands: `/observability:init-prometheus`, `/observability:init-grafana`, `/observability:init-otel`
6. Reference `o11y-metrics` skill for detailed Prometheus guidance

### Scenario 2: Migrating from Commercial to Open Source

**User asks**: "We want to move from Datadog to open source. How?"

**Response approach**:

1. Audit current Datadog usage: metrics, logs, traces, dashboards, alerts
2. Choose target platform:
   - **LGTM Stack**: Full control, component-based (Prometheus, Loki, Tempo, Grafana)
   - **Signoz**: Simpler unified platform, Clickhouse-based
   - **Clickhouse + Clickstack**: Custom solution if already using Clickhouse
3. Map to open source equivalents:
   - Metrics: Datadog → Prometheus (or Signoz)
   - Logs: Datadog Logs → Loki (or Signoz/Clickhouse)
   - Traces: Datadog APM → Tempo (or Signoz)
   - Dashboards: Datadog → Grafana (or Signoz UI)
   - Collection: Datadog Agent → OpenTelemetry Collector (dedicated per signal + gateway)
4. Plan parallel migration: run both systems during transition
5. Provide migration checklist with timelines
6. Reference specialized skills for each component

### Scenario 3: High Cardinality Problems

**User asks**: "Our Prometheus is slow and uses too much memory."

**Response approach**:

1. Diagnose: likely high-cardinality metrics (too many unique label combinations)
2. Recommend using `metrics-advisor` agent to analyze cardinality
3. Provide immediate fixes: drop unnecessary labels, increase scrape interval
4. Long-term solutions: recording rules, metric aggregation, consider VictoriaMetrics
5. Reference `o11y-metrics` skill for cardinality management

### Scenario 4: Observability for Microservices

**User asks**: "How do we monitor 50+ microservices?"

**Response approach**:

1. Emphasize distributed tracing importance (service dependency mapping)
2. Recommend service mesh consideration (Istio/Linkerd) for automatic telemetry
3. Standardize instrumentation: OpenTelemetry SDKs across all services
4. Create service-level SLOs (not just infrastructure metrics)
5. Reference `o11y-traces` skill for microservices tracing patterns
6. Reference `o11y-slo-sli` skill for per-service SLO definition

### Scenario 5: Cost Optimization

**User asks**: "Our observability costs are too high."

**Response approach**:

1. Audit what's being collected and retained
2. Identify optimization opportunities:
   - Reduce metric cardinality (drop unnecessary labels)
   - Adjust retention policies (7d for high-res, 30d for aggregated)
   - Implement log sampling (keep errors, sample info logs)
   - Configure trace sampling (1-5% for high-traffic services)
   - Use recording rules to pre-aggregate expensive queries
3. Consider VictoriaMetrics for better storage efficiency
4. Reference `o11y-metrics` skill for cardinality reduction techniques

## Best Practices

### Start Simple, Iterate

- Deploy basic infrastructure monitoring first (hosts, containers)
- Add application metrics second (request rate, errors, latency)
- Enhance with logs and traces later
- Avoid premature optimization of monitoring systems

### Standardize Instrumentation

- Use OpenTelemetry for vendor neutrality
- Establish metric naming conventions early (prefix, units, labels)
- Enforce structured logging (JSON format)
- Document instrumentation requirements for developers

### Observability as Code

- Store all configurations in Git: Prometheus rules, Grafana dashboards, alert definitions
- Use provisioning: Grafana provisioning, Prometheus Operator CRDs
- Automate deployment: Infrastructure as Code (Terraform, Helm)
- Version control everything

### Progressive Rollout

- Test in non-production first
- Roll out per-environment: dev → staging → production
- Validate each phase before proceeding
- Keep fallback plan (old monitoring system) during transition

### Avoid Common Pitfalls

❌ **Don't**:

- Collect metrics "just in case" (creates noise and cost)
- Use high-cardinality labels (user IDs, IP addresses in metric labels)
- Over-alert (causes alert fatigue)
- Forget retention policies (unbounded storage growth)
- Mix concerns (use logs for logs, metrics for metrics)

✅ **Do**:

- Define what to monitor based on SLOs and user impact
- Use labels thoughtfully (finite cardinality: service, environment, region)
- Alert on symptoms, not causes (alert on "high latency" not "high CPU")
- Implement retention policies from day one
- Use the right signal for the job (metrics for trends, logs for events, traces for flows)

## Implementation Commands

Provide users with these commands for quick starts:

| Task                     | Command                             |
| ------------------------ | ----------------------------------- |
| Initialize Prometheus    | `/observability:init-prometheus`    |
| Initialize Grafana       | `/observability:init-grafana`       |
| Initialize OpenTelemetry | `/observability:init-otel`          |
| Initialize Loki          | `/observability:init-loki`          |
| Generate dashboard       | `/observability:generate-dashboard` |
| Generate alerts          | `/observability:generate-alerts`    |
| Validate configs         | `/observability:validate-config`    |
| Troubleshoot             | `/observability:troubleshoot`       |

## Validation and Optimization

After initial setup, recommend these validation steps:

1. **Validate configurations**: Use `config-validator` agent
2. **Review dashboards**: Use `dashboard-reviewer` agent for design quality
3. **Optimize alerts**: Use `alert-optimizer` agent to reduce alert fatigue
4. **Check cardinality**: Use `metrics-advisor` agent to identify high-cardinality metrics

## Additional Resources

### Specialized Skills

For deep dives into specific areas:

- **`o11y-metrics`**: Prometheus, Thanos, recording rules, alerting, cardinality management
- **`o11y-logs`**: Loki, log aggregation, parsing patterns, retention policies
- **`o11y-traces`**: OpenTelemetry, distributed tracing, sampling strategies, trace backends
- **`o11y-dashboards`**: Grafana dashboard design, visualization best practices, query patterns
- **`o11y-slo-sli`**: SLO/SLI definition, error budgets, burn rate alerts, SLO tooling

### Reference Materials

Consult these reference files for additional guidance:

- **`references/decision-tree.md`**: Detailed decision trees for technology selection
- **`references/migration-guides.md`**: Step-by-step migration paths from various systems
- **`references/architecture-patterns.md`**: Reference architectures for common scenarios

---

**Summary**: Use this skill for strategic observability guidance. It helps select technologies (LGTM Stack, Signoz, or
Clickhouse+Clickstack), plan implementation with OpenTelemetry Collector architecture (dedicated collectors per signal +
gateway), and coordinates specialized skills (`o11y-metrics`, `o11y-logs`, `o11y-traces`, `o11y-dashboards`,
`o11y-slo-sli`) for detailed implementation. Focus on delivering value incrementally: metrics first, then logs, then
traces. We use OpenTelemetry Collector for all log collection (not Promtail or Fluentbit) and avoid Elasticsearch.
