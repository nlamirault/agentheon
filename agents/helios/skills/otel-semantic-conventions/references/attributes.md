# Attributes Reference

Attributes are key-value pairs that annotate telemetry. Choosing the right attribute, placing it at the right level, and
keeping cardinality bounded are the three most important decisions in attribute design.

## Attribute placement levels

Every attribute belongs at exactly one level. Placing an attribute at the wrong level wastes storage and produces
confusing queries.

| Level | What it describes | Changes per | Example |
|-------|------------------|-------------|---------|
| **Resource** | The entity producing telemetry | Process restart | `service.name`, `k8s.pod.name` |
| **Scope** | The instrumentation library | Library version | `otel.scope.name`, `otel.scope.version` |
| **Span** | A single operation | Span | `http.route`, `db.operation.name` |
| **Metric data point** | A single measurement | Measurement | `http.request.method`, `http.response.status_code` |
| **Log record** | A single log event | Log entry | `error.type`, `order.id` |

**Rules**:

- If the attribute has the same value for the lifetime of the process → **resource attribute**
- If the attribute varies per request/operation → **span attribute** or **metric dimension**
- If the attribute varies per measurement but is not bounded → do not put it on metrics (spans only)
- Never duplicate a resource attribute on every span — it is already part of the ResourceSpans envelope

## Resource attributes

Resource attributes describe the service and its deployment context. Set them once when initializing the SDK.

### service.* (required)

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `service.name` | string | Logical service name. Must be consistent (same case, same spelling) across all instances and deployments. | `order-service` |
| `service.version` | string | Release version. Valuable during rollouts — enables side-by-side comparison between versions. | `1.4.2` |
| `service.namespace` | string | Logical group of services. Prevents naming collisions when multiple teams share backends. | `ecommerce` |
| `service.instance.id` | string | Unique ID per process instance. Use pod UID on Kubernetes, AWS ECS task ARN on ECS, or a generated UUID. Never reuse across restarts. | `a7c3f...` |

**`service.instance.id` sources by platform**:

- **Kubernetes**: pod UID from Downward API (`metadata.uid`)
- **AWS ECS**: task ARN (`ECS_TASK_ARN` env var injected by the agent)
- **VMs / bare metal**: machine-id (`/etc/machine-id`), or generate a UUID at process start
- **Fallback**: `socket.gethostname()` (not globally unique across clusters)

**Python**:

```python
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.attributes import service_attributes
from opentelemetry.semconv._incubating.attributes import service_attributes as inc_svc

resource = Resource.create({
    service_attributes.SERVICE_NAME: "order-service",
    service_attributes.SERVICE_VERSION: "1.4.2",
    inc_svc.SERVICE_NAMESPACE: "ecommerce",
    inc_svc.SERVICE_INSTANCE_ID: os.getenv("K8S_POD_UID", socket.gethostname()),
})
```

**Go**:

```go
import semconv "go.opentelemetry.io/otel/semconv/v1.26.0"

res, _ := resource.New(ctx,
    resource.WithAttributes(
        semconv.ServiceName("order-service"),
        semconv.ServiceVersion("1.4.2"),
        semconv.ServiceNamespace("ecommerce"),
        semconv.ServiceInstanceID(os.Getenv("K8S_POD_UID")),
    ),
    resource.WithFromEnv(),  // picks up OTEL_RESOURCE_ATTRIBUTES
)
```

### deployment.* (required)

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `deployment.environment.name` | string | Deployment environment | `production`, `staging`, `development` |

```python
from opentelemetry.semconv._incubating.attributes import deployment_attributes

resource = Resource.create({
    deployment_attributes.DEPLOYMENT_ENVIRONMENT_NAME: "production",
})
```

### k8s.* (required in Kubernetes)

| Attribute | Type | Source |
|-----------|------|--------|
| `k8s.cluster.name` | string | Cluster config or env var |
| `k8s.namespace.name` | string | Downward API: `metadata.namespace` |
| `k8s.pod.name` | string | Downward API: `metadata.name` |
| `k8s.pod.uid` | string | Downward API: `metadata.uid` |
| `k8s.node.name` | string | Downward API: `spec.nodeName` |
| `k8s.deployment.name` | string | k8sattributes processor |
| `k8s.container.name` | string | k8sattributes processor |

Set via `OTEL_RESOURCE_ATTRIBUTES` in the pod spec (see [k8s platform guide](../platforms/k8s.md)).

### host.* (for non-containerized services)

| Attribute | Type | Description |
|-----------|------|-------------|
| `host.name` | string | Hostname or FQDN |
| `host.id` | string | Unique host identifier |
| `host.arch` | string | CPU architecture: `amd64`, `arm64` |
| `host.type` | string | Instance type (cloud VMs) |

### cloud.* (for cloud-hosted services)

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `cloud.provider` | string | Cloud vendor | `aws`, `gcp`, `azure` |
| `cloud.account.id` | string | Account / project ID | `123456789012` |
| `cloud.region` | string | Region | `us-east-1` |
| `cloud.availability_zone` | string | AZ | `us-east-1a` |

Use `resource.WithDetectors(ec2.NewResourceDetector())` (Go) or `OTELResourceDetector` (Python) to auto-detect cloud
attributes.

## HTTP attributes (stable)

Use stable semconv constants. These attributes appear on both spans and metrics.

| Attribute | Type | Description | Span | Metric |
|-----------|------|-------------|------|--------|
| `http.request.method` | string | HTTP method | Yes | Yes |
| `http.response.status_code` | int | Response status | Yes | Yes |
| `http.route` | string | Parameterized route | Yes | Yes |
| `server.address` | string | Server hostname | Yes | Yes |
| `server.port` | int | Server port | Yes | Conditionally |
| `url.scheme` | string | `http` or `https` | Yes | No |
| `url.path` | string | URL path (concrete) | Yes (client) | No |
| `url.full` | string | Full URL | Yes (client) | No |
| `user_agent.original` | string | User-Agent header | Yes | No |
| `client.address` | string | Client IP | Yes | No |
| `network.protocol.version` | string | `1.1`, `2`, `3` | Yes | No |

**Python**:

```python
from opentelemetry.semconv.attributes import (
    http_attributes,
    server_attributes,
    url_attributes,
    client_attributes,
    network_attributes,
)

span.set_attributes({
    http_attributes.HTTP_REQUEST_METHOD: "POST",
    http_attributes.HTTP_ROUTE: "/api/orders",
    http_attributes.HTTP_RESPONSE_STATUS_CODE: 201,
    server_attributes.SERVER_ADDRESS: "orders.internal",
    server_attributes.SERVER_PORT: 8080,
    url_attributes.URL_SCHEME: "https",
    url_attributes.URL_PATH: "/api/orders",
    client_attributes.CLIENT_ADDRESS: "203.0.113.5",
})
```

**Go**:

```go
import semconv "go.opentelemetry.io/otel/semconv/v1.26.0"

span.SetAttributes(
    semconv.HTTPRequestMethodPost,
    semconv.HTTPRoute("/api/orders"),
    semconv.HTTPResponseStatusCode(201),
    semconv.ServerAddress("orders.internal"),
    semconv.ServerPort(8080),
    semconv.URLScheme("https"),
    semconv.URLPath("/api/orders"),
)
```

> `url.full` and `url.path` are suitable for CLIENT spans (they describe the target). On SERVER spans, use `http.route`
> (parameterized) — never the concrete path with IDs.

## Database attributes (stable)

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `db.system` | string | Database type | `postgresql`, `mysql`, `mongodb`, `redis`, `elasticsearch` |
| `db.name` | string | Database name | `orders` |
| `db.operation.name` | string | Operation verb | `SELECT`, `INSERT`, `FINDONE` |
| `db.query.text` | string | Parameterized query | `SELECT * FROM orders WHERE id = $1` |
| `db.collection.name` | string | Table / collection | `orders` |
| `server.address` | string | DB host | `postgres.internal` |
| `server.port` | int | DB port | `5432` |

**Python**:

```python
from opentelemetry.semconv.attributes import db_attributes, server_attributes

span.set_attributes({
    db_attributes.DB_SYSTEM: "postgresql",
    db_attributes.DB_NAME: "orders",
    db_attributes.DB_OPERATION_NAME: "SELECT",
    db_attributes.DB_QUERY_TEXT: "SELECT * FROM orders WHERE id = $1",
    db_attributes.DB_COLLECTION_NAME: "orders",
    server_attributes.SERVER_ADDRESS: "postgres.internal",
    server_attributes.SERVER_PORT: 5432,
})
```

**Go**:

```go
span.SetAttributes(
    semconv.DBSystemPostgreSQL,
    semconv.DBName("orders"),
    semconv.DBOperationName("SELECT"),
    semconv.DBQueryText("SELECT * FROM orders WHERE id = $1"),
    semconv.DBCollectionName("orders"),
    semconv.ServerAddress("postgres.internal"),
    semconv.ServerPort(5432),
)
```

> `db.query.text` is opt-in (it may contain query structure that reveals schema). Always use parameterized form — never
> interpolate values. See [sensitive-data](../sensitive-data.md).

## Messaging attributes

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `messaging.system` | string | Messaging platform | `kafka`, `rabbitmq`, `aws_sqs`, `gcp_pubsub` |
| `messaging.destination.name` | string | Topic / queue | `orders.created` |
| `messaging.operation.name` | string | Operation | `publish`, `receive`, `settle` |
| `messaging.message.id` | string | Message ID | `msg-abc-123` |
| `messaging.message.body.size` | int | Message body size in bytes | `1024` |
| `messaging.message.envelope.size` | int | Total message size | `1280` |
| `messaging.consumer.group.name` | string | Consumer group | `order-processor` |
| `server.address` | string | Broker address | `kafka.internal` |
| `server.port` | int | Broker port | `9092` |

**Python**:

```python
from opentelemetry.semconv._incubating.attributes import messaging_attributes

span.set_attributes({
    messaging_attributes.MESSAGING_SYSTEM: "kafka",
    messaging_attributes.MESSAGING_DESTINATION_NAME: "orders.created",
    messaging_attributes.MESSAGING_OPERATION_NAME: "publish",
    messaging_attributes.MESSAGING_MESSAGE_ID: "msg-abc-123",
    messaging_attributes.MESSAGING_MESSAGE_BODY_SIZE: 1024,
})
```

**Go**:

```go
span.SetAttributes(
    semconv.MessagingSystemKafka,
    semconv.MessagingDestinationName("orders.created"),
    semconv.MessagingOperationName("publish"),
    semconv.MessagingMessageID("msg-abc-123"),
    semconv.MessagingMessageBodySize(1024),
)
```

## RPC attributes

| Attribute | Type | Description | Example |
|-----------|------|-------------|---------|
| `rpc.system` | string | RPC framework | `grpc`, `dotnet_wcf`, `java_rmi` |
| `rpc.service` | string | Service name | `com.example.OrderService` |
| `rpc.method` | string | Method name | `CreateOrder` |
| `rpc.grpc.status_code` | int | gRPC status code | `0` (OK), `5` (NOT_FOUND) |
| `server.address` | string | Server host | `grpc-server.internal` |
| `server.port` | int | Server port | `50051` |

```python
from opentelemetry.semconv.attributes import rpc_attributes, server_attributes

span.set_attributes({
    rpc_attributes.RPC_SYSTEM: "grpc",
    rpc_attributes.RPC_SERVICE: "com.example.OrderService",
    rpc_attributes.RPC_METHOD: "CreateOrder",
    server_attributes.SERVER_ADDRESS: "grpc-server.internal",
    server_attributes.SERVER_PORT: 50051,
})
```

## GenAI attributes (stable/experimental)

Use for LLM inference, embeddings, image generation, and AI pipeline operations. Query the latest state with the script
(`./scripts/query-otel-semantic-conventions.sh gen-ai`) as this group is actively evolving.

| Attribute | Stability | Type | Description | Example |
|-----------|-----------|------|-------------|---------|
| `gen_ai.system` | experimental | string | AI provider identifier | `openai`, `anthropic`, `vertex_ai`, `aws_bedrock` |
| `gen_ai.operation.name` | experimental | string | Operation type | `chat`, `text_completion`, `embeddings`, `image_generation` |
| `gen_ai.request.model` | experimental | string | Model ID requested | `gpt-4o`, `claude-3-5-sonnet` |
| `gen_ai.response.model` | experimental | string | Model actually used in response | `gpt-4o-2024-08-06` |
| `gen_ai.usage.input_tokens` | experimental | int | Input / prompt token count | `512` |
| `gen_ai.usage.output_tokens` | experimental | int | Output / completion token count | `128` |
| `gen_ai.request.max_tokens` | experimental | int | Max tokens requested | `1024` |
| `gen_ai.request.temperature` | experimental | float | Sampling temperature | `0.7` |
| `gen_ai.request.top_p` | experimental | float | Top-p nucleus sampling parameter | `0.9` |
| `gen_ai.response.finish_reasons` | experimental | string[] | Finish reasons from model | `["stop"]`, `["length", "stop"]` |

**Python**:

```python
from opentelemetry.semconv._incubating.attributes import gen_ai_attributes

span.set_attributes({
    gen_ai_attributes.GEN_AI_SYSTEM: "openai",
    gen_ai_attributes.GEN_AI_OPERATION_NAME: "chat",
    gen_ai_attributes.GEN_AI_REQUEST_MODEL: "gpt-4o",
    gen_ai_attributes.GEN_AI_RESPONSE_MODEL: "gpt-4o-2024-08-06",
    gen_ai_attributes.GEN_AI_USAGE_INPUT_TOKENS: 512,
    gen_ai_attributes.GEN_AI_USAGE_OUTPUT_TOKENS: 128,
})
```

**Go**:

```go
import semconv "go.opentelemetry.io/otel/semconv/v1.26.0"

span.SetAttributes(
    semconv.GenAISystem("openai"),
    semconv.GenAIOperationName("chat"),
    semconv.GenAIRequestModel("gpt-4o"),
    semconv.GenAIResponseModel("gpt-4o-2024-08-06"),
    semconv.GenAIUsageInputTokens(512),
    semconv.GenAIUsageOutputTokens(128),
)
```

> All `gen_ai.*` attributes are `experimental` — safe on spans, but do not use as Prometheus metric dimensions until
> stable. Token counts (`gen_ai.usage.*`) are the primary candidates for metrics cardinality is bounded.

## Custom attribute guidelines

When no standard attribute exists in the
[OTel Attribute Registry](https://opentelemetry.io/docs/specs/semconv/registry/attributes/), create a custom attribute
using a reverse-domain namespace:

**Pattern**: `com.company.product.attribute_name`

```python
# Custom business attributes — use string literals, no constant exists
span.set_attributes({
    "com.example.order.type": "subscription",      # bounded: ~5 values
    "com.example.customer.tier": "premium",        # bounded: ~4 values
    "com.example.payment.processor": "stripe",     # bounded: ~3 values
    "com.example.feature.flag": "new-checkout-v2", # bounded: number of flags
})
```

**Rules for custom attributes**:

1. Search the [Attribute Registry](https://opentelemetry.io/docs/specs/semconv/registry/attributes/) first — an
   equivalent may already exist
2. Use the `com.company.` prefix to avoid future collisions with OTel semconv
3. Lowercase with dots as separators — no camelCase, no hyphens
4. The attribute name must be self-explanatory without documentation
5. Do not create custom attributes that duplicate standard ones with different names

## Cardinality rules

Cardinality is the number of unique values an attribute takes. It determines storage cost and query performance.

**Hard limit**: < 100 unique values per attribute **on metrics**. Spans have no hard limit, but billions of unique span
attribute values slow backend indexing.

| Use | Safe attributes (low cardinality) | Dangerous (high cardinality) |
|-----|----------------------------------|------------------------------|
| Metrics | `http.request.method`, `http.response.status_code`, `http.route`, `deployment.environment` | `user.id`, `order.id`, `url.full`, `request.id` |
| Spans | All the above + `order.id` (opaque ID, not PII) | `user.email`, raw query text, JWT tokens |

**When cardinality cannot be reduced**, keep the attribute on spans only and use trace sampling to control volume.

## What NOT to put in attributes

Regardless of level (resource, span, metric, log), never set:

- Passwords, API keys, OAuth tokens, JWTs — see [sensitive-data](../sensitive-data.md)
- User email, full name, phone number, national ID
- Credit card numbers, bank account numbers
- Full SQL queries with interpolated values
- Raw HTTP request/response bodies
- Raw `Authorization` or `Cookie` header values
- Stack traces as attribute values (use span events with `exception.*` attributes instead)
- High-frequency timestamps as metric dimensions

## References

- [OTel Attribute Registry](https://opentelemetry.io/docs/specs/semconv/registry/attributes/)
- [OTel General Attribute Naming](https://opentelemetry.io/docs/specs/semconv/general/attribute-naming/)
- [OTel HTTP Attributes](https://opentelemetry.io/docs/specs/semconv/http/http-spans/)
- [OTel Database Attributes](https://opentelemetry.io/docs/specs/semconv/database/database-spans/)
- [OTel Messaging Attributes](https://opentelemetry.io/docs/specs/semconv/messaging/messaging-spans/)
- [OTel RPC Attributes](https://opentelemetry.io/docs/specs/semconv/rpc/rpc-spans/)
- [Attribute Requirement Levels](https://opentelemetry.io/docs/specs/semconv/general/attribute-requirement-level/)
