# OpenTelemetry Platforms & Serverless

## Overview

Platform-specific guidance for deploying OpenTelemetry in serverless (FaaS) and client-side environments.

For Kubernetes deployment patterns (DaemonSet, Gateway, Sidecar, Hybrid), see [architecture.md](./architecture.md).

## Table of Contents

1. [Functions as a Service (FaaS)](#functions-as-a-service-faas)
2. [AWS Lambda Best Practices](#aws-lambda-best-practices)
3. [Azure Functions](#azure-functions)
4. [Google Cloud Functions](#google-cloud-functions)
5. [Client-Side Applications](#client-side-applications)

---

## Functions as a Service (FaaS)

### The FaaS Challenge

| Challenge | Impact | Solution |
|-----------|--------|----------|
| **Short Execution Time** | Function may terminate before telemetry export completes | Use Collector Extension Layer (async export) |
| **Cold Starts** | Initialization overhead increases latency | Minimize instrumentation scope |
| **Timeouts** | Function must complete within time limit | Never block on telemetry export |
| **Cost Per Millisecond** | Every ms of execution is billed | Async export to avoid blocking handler |

### Deployment Patterns

**Pattern 1: Lambda Layer** — pre-built auto-instrumentation layer, zero code changes.

**Pattern 2: Collector Extension Layer** — collector runs as Lambda extension (sidecar process). Non-blocking export happens after handler returns. **Recommended for production**.

**Pattern 3: Manual SDK** — full control, best combined with Collector Extension Layer.

---

## AWS Lambda Best Practices

### Critical Rule: Never Block on Telemetry Export

**Solution**: Use the OpenTelemetry Collector Extension Layer to decouple export from execution.

### Setup: Lambda Layers

```bash
# Node.js (example, verify current ARN on aws-otel.github.io)
arn:aws:lambda:<region>:901920570463:layer:aws-otel-nodejs-amd64-ver-1-18-1:4

# Python
arn:aws:lambda:<region>:901920570463:layer:aws-otel-python-amd64-ver-1-25-0:3

# Collector Extension Layer (required for async export)
arn:aws:lambda:<region>:901920570463:layer:aws-otel-collector-amd64-ver-0-102-1:1
```

### Environment Variables

```bash
OTEL_SERVICE_NAME=my-lambda-function
OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf     # HTTP recommended for Lambda
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318  # Collector extension endpoint
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production
AWS_LAMBDA_EXEC_WRAPPER=/opt/otel-handler     # For Node.js/Python

# Performance: disable unused instrumentations
OTEL_INSTRUMENTATION_COMMON_DEFAULT_ENABLED=false
OTEL_INSTRUMENTATION_AWS_SDK_ENABLED=true
OTEL_INSTRUMENTATION_HTTP_ENABLED=true
```

> ⚠️ **Go SDK**: `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf` is not enough to switch the Go SDK from gRPC to HTTP. For Go Lambda, instantiate `otlptracehttp`/`otlpmetrichttp` in code or use `go.opentelemetry.io/contrib/exporters/autoexport`.

### Collector Extension Config

```yaml
# /var/task/collector.yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: localhost:4318

processors:
  batch:
    timeout: 1s        # Short timeout for Lambda lifecycle
    send_batch_size: 512
  memory_limiter:
    limit_mib: 50      # Conservative for Lambda extension
    spike_limit_mib: 10

exporters:
  otlp:
    endpoint: your-backend.example.com:4317
    tls:
      insecure: false
    timeout: 5s

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

```bash
OPENTELEMETRY_COLLECTOR_CONFIG_FILE=/var/task/collector.yaml
```

### Lambda Anti-Patterns

❌ Blocking on export in the handler (`tracer.force_flush()`)
❌ Using gRPC protocol (high cold start overhead) — use HTTP/protobuf instead
❌ Over-instrumenting all libraries (increases cold start)

---

## Azure Functions

### Configuration

```bash
APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=...
OTEL_SERVICE_NAME=my-azure-function
OTEL_EXPORTER_OTLP_ENDPOINT=https://your-backend:4318
```

✅ Use Application Insights native integration for simplicity
✅ Configure sampling to control cost (default: 5 requests/second)

---

## Google Cloud Functions

### Configuration

```bash
OTEL_SERVICE_NAME=my-gcp-function
OTEL_TRACES_EXPORTER=google_cloud_trace
GOOGLE_CLOUD_PROJECT=my-project-id
```

### ⚠️ GCP FaaS ID Resource Detection: Feature Gate Removed

The `processor.resourcedetection.removeGCPFaasID` feature gate has been **permanently removed** (collector-contrib [#45808](https://github.com/open-telemetry/opentelemetry-collector-contrib/issues/45808)):

- `faas.id` is **no longer populated** by the `resourcedetectionprocessor` GCP detector.
- Use `faas.instance` as the canonical FaaS instance identifier.
- Remove any `processor.resourcedetection.removeGCPFaasID=false` flags from your collector deployment.

**Migration** — rename `faas.id` to `faas.instance` in dashboards and OTTL:

```yaml
processors:
  transform:
    resource_statements:
      - set(attributes["faas.instance"], attributes["faas.id"]) where attributes["faas.id"] != nil
      - delete_key(attributes, "faas.id") where attributes["faas.id"] != nil
```

---

## Client-Side Applications

### The Client-Side Challenge

| Challenge | Solution |
|-----------|----------|
| **Battery Drain** | 1-5% sampling, batch exports every 5-10s |
| **Data Usage** | Compress payloads, aggressive sampling |
| **Privacy (GDPR/CCPA)** | Never collect PII, use anonymous IDs |
| **Network Reliability** | Buffer locally, retry with backoff |
| **Bundle Size** | Tree-shaking, selective imports |

### Mobile: Critical Best Practices

**iOS**:
```swift
// 1% sampling for production
let sampler = ParentBasedSampler(root: TraceIdRatioBasedSampler(ratio: 0.01))
```

**Android**:
```kotlin
val sampler = Sampler.parentBased(Sampler.traceIdRatioBased(0.01))
```

### Browser: Setup

```javascript
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { BatchSpanProcessor, ParentBasedSampler, TraceIdRatioBasedSampler } from '@opentelemetry/sdk-trace-base';

const exporter = new OTLPTraceExporter({
  url: 'https://your-backend.example.com/v1/traces',  // HTTP not gRPC
  headers: { 'X-API-Key': 'your-api-key' }
});

const provider = new WebTracerProvider({
  sampler: new ParentBasedSampler({ root: new TraceIdRatioBasedSampler(0.05) })
});

// Batch every 5 seconds
provider.addSpanProcessor(new BatchSpanProcessor(exporter, {
  maxQueueSize: 100,
  scheduledDelayMillis: 5000
}));
```

**CORS**: Backend must support `Access-Control-Allow-Origin`, `Access-Control-Allow-Methods: POST, OPTIONS`.

### Client-Side Anti-Patterns

❌ Sampling at 100% (excessive battery drain and data usage)
❌ Collecting PII (`user.email`, `credit_card`) — use anonymous IDs
❌ Synchronous exports (blocks main thread) — always use `BatchSpanProcessor`
❌ Importing entire SDK — use tree-shaking and selective imports

---

## Prometheus Interoperability Notes

### Resource Attributes in OTLP → Prometheus

The mapping of OTLP `Resource` attributes into Prometheus `target_info` remains under active upstream work. Do **not** assume every resource attribute will appear as a stable Prometheus label. If a dimension is operationally required in Prometheus, copy it onto the metric stream explicitly with a Collector `transform` processor.

## Reference Links

- [OpenTelemetry Platforms](https://opentelemetry.io/docs/platforms/)
- [Lambda Repository](https://github.com/open-telemetry/opentelemetry-lambda)
- [AWS Lambda Layers](https://aws-otel.github.io/docs/getting-started/lambda)
- [Azure Functions](https://learn.microsoft.com/azure/azure-functions/opentelemetry)
