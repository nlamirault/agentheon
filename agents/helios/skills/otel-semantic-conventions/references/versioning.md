# Semantic Convention Versioning Reference

OpenTelemetry semantic conventions evolve over time. Attributes and metrics graduate from experimental to stable and are
occasionally renamed or deprecated. This reference explains the stability model, how to track what version you're using,
and how to handle migrations.

## Stability levels

Every attribute, metric, and span convention has a stability level:

| Level | Meaning | Can change? | Use in production? |
|-------|---------|-------------|-------------------|
| **stable** | Specification locked — no breaking changes | No breaking changes | Yes — required |
| **experimental** (incubating) | Under active development — may be renamed or removed | Yes | With caution |
| **deprecated** | Will be removed in a future version | No new features | Migrate away |

**Rules**:

- Only use `stable` attributes in production metrics — Prometheus time series must not be renamed by semconv upgrades
- `experimental` attributes are safe in spans where a rename only affects future queries, not alert rules
- Replace `deprecated` attributes as soon as the stable replacement is available
- Never use deprecated names for new instrumentation

## How to check the semconv version your library uses

### Python

```bash
pip show opentelemetry-semantic-conventions
# Name: opentelemetry-semantic-conventions
# Version: 0.49b0
# Requires: deprecated, opentelemetry-api

# Check stable vs incubating split:
python -c "import opentelemetry.semconv; print(opentelemetry.semconv.__version__)"

# List what's in stable metrics:
python -c "from opentelemetry.semconv.metrics import http_metrics; print(dir(http_metrics))"
# List what's in incubating metrics:
python -c "from opentelemetry.semconv._incubating.metrics import http_metrics; print(dir(http_metrics))"
```

The Python package version maps to semconv spec version. Check the
[opentelemetry-python changelog](https://github.com/open-telemetry/opentelemetry-python/blob/main/CHANGELOG.md) for
semconv dependency bumps.

### Go

```bash
# Check semconv version in go.mod
grep "go.opentelemetry.io/otel/semconv" go.mod
# go.opentelemetry.io/otel/semconv/v1.26.0 v1.26.0

# Check available versions:
go list -m -versions go.opentelemetry.io/otel/semconv/v1.26.0
```

Go semconv is versioned in the import path itself (`semconv/v1.26.0`). To upgrade, change the import path and run
`go get`:

```bash
go get go.opentelemetry.io/otel/semconv/v1.27.0
# Update imports in source files from v1.26.0 to v1.27.0
```

### Node.js

```bash
npm list @opentelemetry/semantic-conventions
# └── @opentelemetry/semantic-conventions@1.25.0

# Check stable vs incubating:
node -e "const s = require('@opentelemetry/semantic-conventions'); console.log(Object.keys(s).slice(0,10))"
node -e "const s = require('@opentelemetry/semantic-conventions/incubating'); console.log(Object.keys(s).slice(0,10))"
```

### Java

```bash
# In pom.xml
grep "opentelemetry-semconv" pom.xml

# In Gradle
grep "opentelemetry-semconv" build.gradle
```

```xml
<dependency>
    <groupId>io.opentelemetry.semconv</groupId>
    <artifactId>opentelemetry-semconv</artifactId>
    <version>1.25.0-alpha</version>
</dependency>
```

The `-alpha` suffix indicates incubating. Stable attributes are in the main artifact.

## Migration guide: old → new attribute names

OpenTelemetry migrated HTTP attributes in semconv v1.21 / v1.23. Many auto-instrumentation libraries are still in a
dual-emit period.

### HTTP attribute migrations

| Old name (deprecated) | New name (stable) | Notes |
|----------------------|-------------------|-------|
| `http.method` | `http.request.method` | String value unchanged |
| `http.status_code` | `http.response.status_code` | Int, unchanged |
| `http.url` | `url.full` | Moved to url namespace |
| `http.target` | `url.path` + `url.query` | Split into two attributes |
| `http.host` | `server.address` + `server.port` | Split |
| `http.scheme` | `url.scheme` | Moved to url namespace |
| `http.route` | `http.route` | No change |
| `http.flavor` | `network.protocol.version` | Renamed |
| `http.server_name` | `server.address` | Merged |
| `http.user_agent` | `user_agent.original` | Moved to user_agent namespace |

### Database attribute migrations

| Old name (deprecated) | New name (stable) |
|----------------------|-------------------|
| `db.statement` | `db.query.text` |
| `db.operation` | `db.operation.name` |
| `db.sql.table` | `db.collection.name` |

### Metric name migrations (HTTP)

| Old metric name | New metric name | Change |
|----------------|-----------------|--------|
| `http.server.duration` | `http.server.request.duration` | Renamed |
| `http.server.request_count` | (use rate on `http.server.request.duration`) | Removed |
| `http.client.duration` | `http.client.request.duration` | Renamed |

## How auto-instrumentation libraries lag behind semconv

Auto-instrumentation libraries (Instrumentation for Flask, Django, requests, JDBC, etc.) implement a specific semconv
version at release time. They do not update automatically when you upgrade the semconv constants package.

**Example timeline**:

- Semconv v1.21 introduces `http.request.method` (stable), deprecates `http.method`
- `opentelemetry-instrumentation-flask` v0.41b0 still emits `http.method`
- `opentelemetry-instrumentation-flask` v0.44b0 emits `http.request.method`

**Consequence**: During the upgrade window, some services emit old names and some emit new names. Dashboard queries
using either name will show incomplete data.

**Check which version an instrumentation library implements**:

```bash
# Python
pip show opentelemetry-instrumentation-flask
# Read the changelog for the HTTP semconv migration note

# Node.js
npm view @opentelemetry/instrumentation-http version
# Check CHANGELOG.md for semconv migration status
```

## Using the filter processor to handle dual-emit periods

During the period when both old and new metric names exist, use a Collector transform to normalize them:

```yaml
processors:
  # Rename old HTTP metric names to new semconv names
  transform/normalize-http-metrics:
    metric_statements:
      - context: metric
        statements:
          # Old name → new name
          - set(name, "http.server.request.duration") where name == "http.server.duration"
          - set(name, "http.client.request.duration") where name == "http.client.duration"

  # Rename old HTTP span attributes to new names
  transform/normalize-http-attrs:
    trace_statements:
      - context: span
        statements:
          # Copy old attribute to new name if old exists and new does not
          - set(attributes["http.request.method"], attributes["http.method"])
            where attributes["http.method"] != nil and attributes["http.request.method"] == nil
          - set(attributes["http.response.status_code"], attributes["http.status_code"])
            where attributes["http.status_code"] != nil and attributes["http.response.status_code"] == nil
          - set(attributes["url.full"], attributes["http.url"])
            where attributes["http.url"] != nil and attributes["url.full"] == nil
          # Clean up old attributes after copying
          - delete_key(attributes, "http.method")
            where attributes["http.request.method"] != nil
          - delete_key(attributes, "http.status_code")
            where attributes["http.response.status_code"] != nil
          - delete_key(attributes, "http.url")
            where attributes["url.full"] != nil

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [transform/normalize-http-attrs, batch]
      exporters: [otlp]
    metrics:
      receivers: [otlp]
      processors: [transform/normalize-http-metrics, batch]
      exporters: [prometheusremotewrite]
```

**When to use this approach**:

- Multiple services, some upgraded to new semconv and some not yet
- Dashboard alert rules use the new name but instrumentation still emits the old name
- Gradual rollout of instrumentation library upgrades

**When to remove it**:

- Once all services emit the new name, remove the transform to avoid double processing

## Prometheus dual recording for zero-downtime metric migration

When renaming a metric that backs a critical alert, record both the old and new name simultaneously for a migration
window:

```yaml
processors:
  metricstransform/dual-emit:
    transforms:
      - include: http.server.duration
        action: insert  # insert = keep original + add copy
        new_name: http.server.request.duration
```

This produces both `http.server.duration` and `http.server.request.duration` until you remove the old one from your
dashboards and alerts.

## Semconv changelog references

Track attribute and metric changes across versions:

- [Semantic Conventions CHANGELOG](https://github.com/open-telemetry/semantic-conventions/blob/main/CHANGELOG.md)
- [Semconv v1.21 migration guide (HTTP)](https://opentelemetry.io/docs/specs/semconv/http/migration-guide/)
- [Semconv stability across all areas](https://opentelemetry.io/docs/specs/semconv/#status)
- [Python semconv package CHANGELOG](https://github.com/open-telemetry/opentelemetry-python/blob/main/opentelemetry-semantic-conventions/CHANGELOG.md)
- [Go semconv module tags](https://github.com/open-telemetry/opentelemetry-go/tags)
- [Node.js @opentelemetry/semantic-conventions CHANGELOG](https://github.com/open-telemetry/opentelemetry-js/blob/main/packages/opentelemetry-semantic-conventions/CHANGELOG.md)
- [Java opentelemetry-semconv releases](https://github.com/open-telemetry/semantic-conventions-java/releases)

## Checklist for a semconv upgrade

- [ ] Identify which attributes and metrics changed between the current and target version (check CHANGELOG)
- [ ] Check whether auto-instrumentation libraries support the new version
- [ ] If not: add Collector transform to normalize old → new names
- [ ] Update SDK resource configuration to use new attribute names
- [ ] Update manual instrumentation code to use new constants
- [ ] Update dashboard queries and alert rules to use new names
- [ ] Enable dual-emit in Collector for critical alerts during migration window
- [ ] After all services are updated: remove the Collector normalization transforms
