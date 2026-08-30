---
name: otel-semantic-conventions
description: OpenTelemetry Semantic Conventions expert. Use when selecting, applying, or reviewing telemetry attributes, span names, span kinds, or span status codes. Triggers on tasks involving attribute selection, naming telemetry, semantic convention compliance, attribute migration, or custom attribute decisions. Covers the attribute registry, naming patterns, status mapping, attribute placement, and versioning.
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - opentelemetry
  task: [configure, review]
  persona: [developer, sre]
  workload: [observability]
---

# OpenTelemetry Semantic Conventions

Semantic conventions define standardized names, types, and semantics for telemetry attributes, span names, metric
instruments, and log fields. They ensure that telemetry from different libraries, frameworks, and services describes the
same concepts in the same way — enabling correlation, querying, and tooling across the entire stack.

The [Attribute Registry](https://opentelemetry.io/docs/specs/semconv/registry/attributes/) is the single source of truth
for all defined attributes.

## Workflow

Use this workflow instead of relying on static tables — the script always queries the **current released version**.

1. **Start with released conventions, not memory**
   - Do not load the full spec into context
   - Use the bundled script to query only the needed group or attribute

2. **Choose the closest released group** — see [`references/semconv-selection.md`](./references/semconv-selection.md)
   - Identify the boundary type: `http`, `db`, `messaging`, `rpc`, `network`, `gen-ai`, `mcp`, etc.
   - Pick one primary group first, then add related groups only when they add needed context

3. **Query only the released guidance you need**
   ```bash
   # List all available groups
   ./scripts/query-otel-semantic-conventions.sh --groups

   # Inspect one group (attributes + available kinds)
   ./scripts/query-otel-semantic-conventions.sh http

   # Inspect one kind
   ./scripts/query-otel-semantic-conventions.sh http spans

   # Inspect one exact attribute
   ./scripts/query-otel-semantic-conventions.sh http http.request.method
   ```
   See [`references/otel-semantic-conventions.md`](./references/otel-semantic-conventions.md) for full query reference.

4. **Apply the released naming and attribute rules directly**
   - Use required and recommended attributes before optional ones
   - Derive semconv-governed span names from the released naming rule
   - Do not prepend protocol labels, hostnames, or business hints to semconv-governed span names
   - If no released key exists, use a stable custom namespace and keep values bounded

5. **Return results with source context**
   - Include the group name, released version, and source URL from the script output
   - Call out any compatibility limitation if the implementation cannot fully match the released guidance

## References

| Reference | Description |
|-----------|-------------|
| [semconv-selection](./references/semconv-selection.md) | Group selection guide and typical group pairings |
| [otel-semantic-conventions](./references/otel-semantic-conventions.md) | Script query reference |
| [attributes](./references/attributes.md) | Attribute placement, domain tables, cardinality, custom attribute rules |
| [versioning](./references/versioning.md) | Semconv versioning, stability, migration |

## Official documentation

- [Attribute Registry](https://opentelemetry.io/docs/specs/semconv/registry/attributes/)
- [Semantic Conventions Specification](https://opentelemetry.io/docs/specs/semconv/)
- [Semantic Conventions Repository](https://github.com/open-telemetry/semantic-conventions)

## Key principles

- **Script first** — Use the lookup script before falling back to static tables
- **Registry first** — Search the registry before creating any custom attribute
- **No custom attributes unless necessary** — Custom names fragment querying and break tooling
- **Low cardinality in names** — Span names and metric attribute values must be bounded; variable data goes in
  attributes
- **Right level, every time** — Place attributes at the correct telemetry level (resource, scope, span, log, metric)
- **Consistent placement** — Once an attribute is at a level, keep it there across all services

## Quick reference

| Use Case | Reference |
|----------|-----------|
| Which group to use | [semconv-selection](./references/semconv-selection.md) |
| Live attribute lookup | [otel-semantic-conventions](./references/otel-semantic-conventions.md) |
| Choosing or reviewing attributes | [attributes](./references/attributes.md) |
| HTTP/DB/messaging/RPC/GenAI attributes | [attributes](./references/attributes.md) |
| Attribute placement (resource vs span) | [attributes](./references/attributes.md) |
| Naming a span or choosing span kind | [spans](../otel-instrumentation/references/spans.md) |
| Span status code mapping | [spans](../otel-instrumentation/references/spans.md) |
| Semconv version migration | [versioning](./references/versioning.md) |
