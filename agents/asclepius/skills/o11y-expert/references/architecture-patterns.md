# Observability Architecture Patterns

This document provides detailed reference architectures for the recommended observability platforms.

## Platform Options Overview

We support three primary observability platform architectures:

1. **LGTM Stack**: Component-based, maximum flexibility
2. **Signoz**: Unified platform, simplified operations
3. **Clickhouse + Clickstack**: Custom solution for Clickhouse users

**What we DON'T use:**

- ❌ Promtail (replaced by OpenTelemetry Collector)
- ❌ Fluentbit (replaced by OpenTelemetry Collector)
- ❌ Elasticsearch (replaced by Loki or Clickhouse)

---

## Option 1: LGTM Stack Architecture

**LGTM** = **L**oki + **G**rafana + **T**empo + **M**imir (or Prometheus)

### Components

- **Prometheus**: Metrics storage and querying
- **Loki**: Log aggregation and querying
- **Tempo**: Distributed trace storage and querying
- **Grafana**: Unified visualization and dashboarding
- **OpenTelemetry Collector**: Telemetry collection (4 instances per cluster)

### Architecture Diagram

```text
┌───────────────────────────────────────────────────────────--──────┐
│                        Applications                               │
│  ┌────────-──┐  ┌─────────-─┐  ┌──────-────┐  ┌─────-─────┐       │
│  │  App 1    │  │  App 2    │  │  App 3    │  │  App N    │       │
│  │ (OTel SDK)│  │ (OTel SDK)│  │ (OTel SDK)│  │ (OTel SDK)│       │
│  └────┬────-─┘  └────┬───-──┘  └────┬───-──┘  └────┬──────┘       │
└───────┼──────────────┼──────────────┼──────────────┼──────────────┘
        │              │              │              │
        └──────────────┴──────────────┴──────────────┘
                      │
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│ OTEL Metrics  │ │  OTEL Logs    │ │ OTEL Traces   │
│  Collector    │ │  Collector    │ │  Collector    │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        |                 |                 |
        └─────────────────┴─────────────────┘
                      |
             ┌─────────────▼─────────────┐
             │  OTEL Collector Gateway   │  ← Central routing & preprocessing
             │  (Filtering, Sampling)    │
             └─────────────┬─────────────┘
              │            │           │
              ▼            ▼           ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│  Prometheus   │ │     Loki      │ │     Tempo     │
│  (+ Mimir)    │ │               │ │               │
└───────┬───────┘ └───────┬───────┘ └───────┬───────┘
        │                 │                 │
        └─────────────────┴─────────────────┘
                          │
                          ▼
                  ┌───────────────┐
                  │    Grafana    │
                  │  (Dashboards) │
                  └───────────────┘
```

### OpenTelemetry Collector Architecture

Deploy **4 OpenTelemetry Collectors** per cluster:

#### 1. Gateway Collector (Optional but Recommended)

**Purpose**: Central entry point for all telemetry

**Responsibilities**:

- Initial filtering and sampling
- Label enrichment
- Load balancing
- Rate limiting

**Configuration**:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024

  attributes:
    actions:
      - key: cluster
        value: production
        action: insert

exporters:
  otlp/metrics:
    endpoint: otel-metrics-collector:4317
  otlp/logs:
    endpoint: otel-logs-collector:4317
  otlp/traces:
    endpoint: otel-traces-collector:4317

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [otlp/metrics]

    logs:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [otlp/logs]

    traces:
      receivers: [otlp]
      processors: [batch, attributes]
      exporters: [otlp/traces]
```

#### 2. Metrics Collector

**Purpose**: Dedicated metrics processing and forwarding to Prometheus

**Responsibilities**:

- Receive metrics from gateway or directly from applications
- Metrics-specific processing (aggregation, filtering)
- Forward to Prometheus via remote write

**Configuration**:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

  prometheus:
    config:
      scrape_configs:
        - job_name: "otel-collector"
          scrape_interval: 10s

processors:
  batch:
    timeout: 10s
    send_batch_size: 10000

  metricstransform:
    transforms:
      - include: .*
        match_type: regexp

exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write

service:
  pipelines:
    metrics:
      receivers: [otlp, prometheus]
      processors: [batch, metricstransform]
      exporters: [prometheusremotewrite]
```

#### 3. Logs Collector

**Purpose**: Dedicated log processing and forwarding to Loki

**Responsibilities**:

- Receive logs from gateway or directly from applications
- Log parsing and attribute extraction
- Forward to Loki

**Configuration**:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    timeout: 5s
    send_batch_size: 8192

  resource:
    attributes:
      - key: loki.resource.labels
        value: service.name, service.namespace, cluster
        action: insert

exporters:
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    labels:
      resource:
        service.name: "service_name"
        service.namespace: "service_namespace"

service:
  pipelines:
    logs:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [loki]
```

#### 4. Traces Collector

**Purpose**: Dedicated trace processing and forwarding to Tempo

**Responsibilities**:

- Receive traces from gateway or directly from applications
- Trace sampling (tail sampling)
- Forward to Tempo

**Configuration**:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    timeout: 1s
    send_batch_size: 1000

  tail_sampling:
    decision_wait: 10s
    policies:
      - name: error-policy
        type: status_code
        status_code:
          status_codes: [ERROR]

      - name: slow-traces
        type: latency
        latency:
          threshold_ms: 1000

exporters:
  otlp:
    endpoint: http://tempo:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, tail_sampling]
      exporters: [otlp]
```

### Deployment Considerations

#### Kubernetes Deployment

Deploy each collector as a separate Deployment/StatefulSet:

```yaml
# Gateway Collector (DaemonSet or Deployment)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-gateway-collector
spec:
  replicas: 3 # For high availability

---
# Metrics Collector (Deployment)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-metrics-collector
spec:
  replicas: 2

---
# Logs Collector (StatefulSet for buffering)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: otel-logs-collector
spec:
  replicas: 2

---
# Traces Collector (Deployment)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-traces-collector
spec:
  replicas: 2
```

#### Resource Allocation

**Gateway Collector**:

- CPU: 1-2 cores
- Memory: 2-4 GB
- Network: High bandwidth

**Metrics Collector**:

- CPU: 2-4 cores
- Memory: 4-8 GB (depends on cardinality)
- Disk: Local SSD for WAL

**Logs Collector**:

- CPU: 1-2 cores
- Memory: 2-4 GB
- Disk: Persistent volume for buffering

**Traces Collector**:

- CPU: 2-4 cores
- Memory: 4-8 GB (for tail sampling)
- Disk: Local SSD for temporary storage

### Scalability

- **Horizontal Scaling**: Each collector type scales independently
- **Metrics Collector**: Scale based on metrics volume (time series)
- **Logs Collector**: Scale based on log volume (GB/day)
- **Traces Collector**: Scale based on trace volume (spans/second)
- **Gateway Collector**: Scale based on total throughput

### Benefits of LGTM Stack

✅ **Pros**:

- Maximum flexibility and control
- Component-level scaling
- Vendor independence
- Active open-source community
- Rich ecosystem of exporters
- Cost-effective for large scale

❌ **Cons**:

- Higher operational complexity
- Requires expertise to operate
- More components to maintain
- Need to manage separate storage backends

### Use Cases

**Best for**:

- Large organizations with dedicated SRE teams
- Multi-cloud or hybrid environments
- Teams requiring maximum customization
- Cost-sensitive deployments at scale
- Organizations with Kubernetes expertise

---

## Option 2: Signoz Architecture

**Signoz** = Unified observability platform built on OpenTelemetry and Clickhouse

### Components

- **Signoz Query Service**: API and query engine
- **Signoz Frontend**: Web UI
- **OpenTelemetry Collector**: Telemetry collection
- **Clickhouse**: Unified storage backend for all signals
- **Alert Manager**: Alerting engine

### Architecture Diagram

```text
┌────────────────────────────────────────────────────────────────┐
│                        Applications                            │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │  App 1    │  │  App 2    │  │  App 3    │  │  App N    │    │
│  │ (OTel SDK)│  │ (OTel SDK)│  │ (OTel SDK)│  │ (OTel SDK)│    │
│  └────┬──────┘  └────┬──────┘  └────┬──────┘  └────┬──────┘    │
└───────┼──────────────┼──────────────┼──────────────┼───────────┘
        │              │              │              │
        └──────────────┴──────────────┴──────────────┘
                      │
        ┌─────────────▼─────────────┐
        │  OpenTelemetry Collector  │
        │   (Signoz Distribution)   │
        └─────────────┬─────────────┘
                      │
                      ▼
              ┌───────────────┐
              │  Clickhouse   │  ← Unified storage for metrics, logs, traces
              │   (Cluster)   │
              └───────┬───────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│ Query Service │ │   Frontend    │ │ Alert Manager │
└───────────────┘ └───────────────┘ └───────────────┘
```

### Deployment Configuration

#### Docker Compose Example

```yaml
version: "3.8"

services:
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    volumes:
      - ./clickhouse-data:/var/lib/clickhouse
    environment:
      - CLICKHOUSE_DB=signoz

  otel-collector:
    image: signoz/signoz-otel-collector:latest
    command: ["--config=/etc/otel-collector-config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml
    ports:
      - "4317:4317" # OTLP gRPC
      - "4318:4318" # OTLP HTTP

  query-service:
    image: signoz/query-service:latest
    environment:
      - STORAGE=clickhouse
      - CLICKHOUSE_HOST=clickhouse:9000

  frontend:
    image: signoz/frontend:latest
    ports:
      - "3301:3301"
    environment:
      - QUERY_SERVICE_URL=http://query-service:8080
```

#### Kubernetes Deployment

Use Signoz Helm chart:

```bash
helm repo add signoz https://charts.signoz.io
helm install signoz signoz/signoz -n signoz --create-namespace
```

### Benefits of Signoz

✅ **Pros**:

- Unified platform (one UI for all signals)
- Simpler deployment and operations
- Single storage backend (Clickhouse)
- Excellent query performance
- Built-in alerting
- Lower operational overhead
- Cost-effective unified solution

❌ **Cons**:

- Less flexibility than component-based approach
- Smaller ecosystem than Prometheus/Grafana
- Clickhouse operational complexity
- Vendor lock-in (to Signoz)

### Use Cases

**Best for**:

- Small to medium teams
- Teams wanting simplicity over flexibility
- Organizations new to observability
- Cost-conscious deployments
- Teams with limited SRE resources
- Startups and fast-moving teams

---

## Option 3: Clickhouse + Clickstack Architecture

**Clickhouse + Clickstack** = Custom observability solution leveraging existing Clickhouse infrastructure

### Components

- **Clickhouse**: Storage backend (already deployed)
- **Clickstack**: Observability layer on top of Clickhouse
- **OpenTelemetry Collector**: Telemetry collection
- **Custom Dashboards**: Grafana or custom UI

### Architecture Diagram

```text
┌────────────────────────────────────────────────────────────────┐
│                        Applications                            │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │  App 1    │  │  App 2    │  │  App 3    │  │  App N    │    │
│  │ (OTel SDK)│  │ (OTel SDK)│  │ (OTel SDK)│  │ (OTel SDK)│    │
│  └────┬──────┘  └────┬──────┘  └────┬──────┘  └────┬──────┘    │
└───────┼──────────────┼──────────────┼──────────────┼───────────┘
        │              │              │              │
        └──────────────┴──────────────┴──────────────┘
                       │
         ┌─────────────▼─────────────┐
         │  OpenTelemetry Collector  │
         └─────────────┬─────────────┘
                       │
                       ▼
               ┌───────────────┐
               │  Clickhouse   │  ← Existing Clickhouse infrastructure
               │   (Cluster)   │
               └───────┬───────┘
                       │
                       ▼
              ┌───────────────┐
              │  Clickstack   │  ← Observability layer
              └───────┬───────┘
                      │
                      ▼
              ┌───────────────┐
              │    Grafana    │  ← Visualization
              │  (or Custom)  │
              └───────────────┘
```

### Implementation Considerations

1. **Schema Design**: Design Clickhouse tables for metrics, logs, and traces
2. **Retention Policies**: Configure TTL for different signal types
3. **Partitioning**: Use date-based partitioning for performance
4. **Materialized Views**: Create for common queries and aggregations
5. **Compression**: Enable appropriate compression codecs

### Benefits of Clickhouse + Clickstack

✅ **Pros**:

- Leverage existing Clickhouse infrastructure
- Excellent query performance (Clickhouse strength)
- Flexible schema design
- Cost-effective if already using Clickhouse
- Column-oriented storage efficiency

❌ **Cons**:

- Requires custom integration work
- Less mature than LGTM or Signoz
- Need Clickhouse expertise
- More operational overhead
- Limited out-of-box features

### Use Cases

**Best for**:

- Organizations already using Clickhouse
- Teams with Clickhouse expertise
- Custom observability requirements
- High-volume, high-performance needs
- Data warehouse integration

---

## Comparison Matrix

| Feature                  | LGTM Stack   | Signoz    | Clickhouse + Clickstack |
| ------------------------ | ------------ | --------- | ----------------------- |
| **Complexity**           | High         | Low       | Medium-High             |
| **Flexibility**          | Very High    | Medium    | High                    |
| **Operational Overhead** | High         | Low       | Medium                  |
| **Community Support**    | Excellent    | Good      | Limited                 |
| **Query Performance**    | Good         | Excellent | Excellent               |
| **Cost (at scale)**      | Low-Medium   | Low       | Low                     |
| **Time to Production**   | Weeks        | Days      | Weeks                   |
| **Unified UI**           | No (Grafana) | Yes       | Custom                  |
| **Vendor Lock-in**       | None         | Medium    | Low                     |
| **Kubernetes Native**    | Yes          | Yes       | Yes                     |

---

## Migration Paths

### From Prometheus/Grafana to LGTM

1. Add Loki alongside Prometheus
2. Deploy OpenTelemetry Collectors (4 instances)
3. Add Tempo for traces
4. Migrate collectors from Promtail → OTEL Collector
5. Consolidate dashboards in Grafana

### From Commercial APM to Signoz

1. Deploy Signoz in parallel
2. Instrument applications with OpenTelemetry
3. Run both systems during transition
4. Migrate dashboards and alerts
5. Decommission commercial APM

### From ELK Stack to Any Option

1. **To LGTM**: Deploy Loki → OTEL Collector → migrate dashboards
2. **To Signoz**: Deploy Signoz → OTEL Collector → migrate visualizations
3. **To Clickhouse**: Deploy Clickhouse schema → OTEL Collector → custom UI

---

## Recommendations by Organization Size

### Small Teams (< 10 engineers)

**Recommended**: **Signoz**

- Least operational overhead
- Fastest time to value
- Unified platform
- Cost-effective

### Medium Teams (10-50 engineers)

**Recommended**: **LGTM Stack** or **Signoz**

- LGTM if you have dedicated SRE team
- Signoz if you want to move fast with less overhead

### Large Teams (> 50 engineers)

**Recommended**: **LGTM Stack**

- Maximum flexibility
- Component-level scaling
- Multi-team support
- Enterprise features via Grafana Cloud (optional)

### Already Using Clickhouse

**Recommended**: **Clickhouse + Clickstack**

- Leverage existing infrastructure
- Reduce costs
- Unified data platform

---

## Architecture Decision Framework

### Ask These Questions

1. **Do you have dedicated SRE team?**
   - Yes → LGTM Stack
   - No → Signoz

2. **Already using Clickhouse?**
   - Yes → Clickhouse + Clickstack
   - No → Continue...

3. **Maximum flexibility needed?**
   - Yes → LGTM Stack
   - No → Signoz

4. **Need to move fast?**
   - Yes → Signoz
   - No → LGTM Stack

5. **Budget constraints?**
   - All options are cost-effective at scale
   - Signoz slightly lower operational cost

6. **Team expertise?**
   - Kubernetes + Prometheus expertise → LGTM Stack
   - Limited observability experience → Signoz
   - Clickhouse expertise → Clickhouse + Clickstack

---

## Summary

All three architectures use **OpenTelemetry Collector** for telemetry collection, with dedicated collectors per signal
(logs, metrics, traces) plus a gateway for preprocessing.

**Choose**:

- **LGTM Stack**: Maximum flexibility, component control, large scale
- **Signoz**: Simplicity, unified platform, faster deployment
- **Clickhouse + Clickstack**: Custom solution, leverage existing Clickhouse

**Avoid**:

- ❌ Promtail, Fluentbit (use OTEL Collector)
- ❌ Elasticsearch (use Loki or Clickhouse)
- ❌ Proprietary log shippers
