# Semantic Convention Selection

Pick the closest released semantic convention group before inventing custom keys. Start with one primary group, then
add related groups only when they provide needed context.

## Selection rules

1. Match the **boundary type** (what operation is being described)
2. Pick **one primary group** first
3. Add related groups only when they contribute attributes the primary group does not cover
4. Prefer **required** and **recommended** attributes before optional ones
5. If no released key exists, use a stable custom namespace (`com.company.`) and keep values bounded

## Common starting groups

| Group | Use when |
|-------|----------|
| `http` | HTTP client or server operations |
| `db` | Database queries, transactions, connections |
| `messaging` | Queues, streams, topics, pub-sub producers and consumers |
| `rpc` | gRPC, Thrift, WCF, Java RMI calls |
| `network` | Raw TCP/UDP transport, socket-level details |
| `url` | URL components not covered by `http` |
| `server` | Server host and port (used alongside other groups) |
| `error` | Error type classification |
| `user-agent` | Client user-agent string |
| `gen-ai` | LLM inference, embeddings, image generation |
| `mcp` | Model Context Protocol tool calls and responses |

## Typical group pairings

### HTTP server span

Primary: `http`  
Add: `url`, `server`, `network`, `user-agent`, `error`

```bash
./scripts/query-otel-semantic-conventions.sh http
./scripts/query-otel-semantic-conventions.sh url
./scripts/query-otel-semantic-conventions.sh server
```

### HTTP client span

Primary: `http`  
Add: `url`, `server`, `network`, `error`

### Database span

Primary: `db`  
Add: `server`, `error`

```bash
./scripts/query-otel-semantic-conventions.sh db
./scripts/query-otel-semantic-conventions.sh server
```

### Messaging producer / consumer span

Primary: `messaging`  
Add: `network`, `server`, `error`

```bash
./scripts/query-otel-semantic-conventions.sh messaging
```

### RPC span

Primary: `rpc`  
Add: `server`, `network`, `error`

```bash
./scripts/query-otel-semantic-conventions.sh rpc
```

### GenAI span

Primary: `gen-ai`  
Add: `error`

```bash
./scripts/query-otel-semantic-conventions.sh gen-ai
```

### MCP tool call span

Primary: `mcp`  
Add: `error`

```bash
./scripts/query-otel-semantic-conventions.sh mcp
```

## Lookup workflow

Always query the script before using static tables — tables go stale, the script uses the latest release:

```bash
# Step 1: discover group name
./scripts/query-otel-semantic-conventions.sh --groups

# Step 2: inspect primary group
./scripts/query-otel-semantic-conventions.sh <group>

# Step 3: inspect exact attribute when needed
./scripts/query-otel-semantic-conventions.sh <group> <attribute-id>
```

## Custom attributes

When no released key covers the need:

- Prefix with `com.company.product.` to avoid future semconv collisions
- Lowercase with dot separators — no camelCase, no hyphens
- Keep values low-cardinality (bounded set)
- Document in a team registry

See [attributes.md](./attributes.md) for full custom attribute rules.
