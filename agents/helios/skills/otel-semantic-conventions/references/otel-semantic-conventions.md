---
title: OpenTelemetry Semantic Conventions Script Reference
read_when: Choosing released semantic convention attributes for instrumentation
---

# OTel Semantic Conventions Query Reference

Do not load the full semantic convention spec into context. Query only the needed released group using the bundled
script. The script fetches the **latest released tag** from GitHub and reads `model/<group>/registry.yaml` directly —
no stale tables.

## Dependencies

```bash
curl --version   # HTTP fetching
jq --version     # JSON parsing
awk --version    # YAML text extraction (POSIX awk)
```

## Commands

```bash
# List all available groups in the latest release
./scripts/query-otel-semantic-conventions.sh --groups

# Inspect one group — shows attributes + available kinds
./scripts/query-otel-semantic-conventions.sh <group>

# Inspect one kind within a group (spans, metrics, logs, events, entities, common, registry)
./scripts/query-otel-semantic-conventions.sh <group> <kind>

# Get the exact released definition block for one attribute
./scripts/query-otel-semantic-conventions.sh <group> <attribute-id>
```

## Usage rules

- Use `--groups` first if you do not already know the right group name
- Use the one-argument form (`<group>`) first to discover current released attribute IDs and available kinds
- Use the two-argument form only when you need the exact upstream definition for one attribute or kind
- Start with one group; add related groups only when they provide needed context
- The script output includes `version:` and `source:` — always include these in your response

## Examples

```bash
# What groups exist in the latest release?
./scripts/query-otel-semantic-conventions.sh --groups

# What HTTP attributes are available?
./scripts/query-otel-semantic-conventions.sh http

# What HTTP span conventions exist?
./scripts/query-otel-semantic-conventions.sh http spans

# Get the exact definition of http.request.method
./scripts/query-otel-semantic-conventions.sh http http.request.method

# GenAI conventions
./scripts/query-otel-semantic-conventions.sh gen-ai

# Database conventions
./scripts/query-otel-semantic-conventions.sh db

# Messaging conventions
./scripts/query-otel-semantic-conventions.sh messaging

# MCP (Model Context Protocol) conventions
./scripts/query-otel-semantic-conventions.sh mcp
```

## Common groups

| Group | Domain |
|-------|--------|
| `http` | HTTP client and server operations |
| `db` | Database operations |
| `messaging` | Queues, streams, pub-sub |
| `rpc` | Remote procedure calls |
| `network` | Transport-level details |
| `url` | URL components |
| `server` | Server endpoint metadata |
| `error` | Error classification |
| `user-agent` | Client user-agent details |
| `gen-ai` | AI model and generation operations |
| `mcp` | Model Context Protocol operations |
| `k8s` | Kubernetes resource attributes |
| `cloud` | Cloud provider attributes |
| `host` | Host machine attributes |
| `process` | Process attributes |
| `service` | Service identity attributes |
| `deployment` | Deployment environment attributes |

## Script output format

The script prints structured output with source citations:

```text
group: http
version: 1.28.0
source: https://github.com/open-telemetry/semantic-conventions/tree/v1.28.0/model/http
kinds:
- metrics (http-metrics.yaml)
- registry (registry.yaml)
- spans (http-spans.yaml)

http.request.body.size    experimental  Size of the HTTP request body in bytes.
http.request.method       stable        HTTP request method.
http.response.body.size   experimental  Size of the HTTP response body in bytes.
http.response.status_code stable        HTTP response status code.
http.route                stable        The matched route.
```

Always include `version:` and `source:` in your response when referencing script output.
