# OpenTelemetry Production Playbooks

## Overview

A **routing-friendly playbook index** for OpenTelemetry blog content. Use this reference when a user asks for a real-world deployment pattern, production rollout model, or blog-derived example.

For each playbook, load deeper reference material from local references as needed after routing.

---

## Relevant 2025-2026 Blogs

| Blog | Primary routing signals | Why it matters | Load next |
| :--- | :--- | :--- | :--- |
| [Kubernetes annotation-based discovery for the OpenTelemetry Collector](https://opentelemetry.io/blog/2025/otel-collector-k8s-discovery/) | `receiver_creator`, annotation-based discovery, Kubernetes self-service scraping | Self-service Collector onboarding with platform safety rails | [processors](./processors.md), [platforms](./platforms.md) |
| [Observing Lambdas using the OpenTelemetry Collector Extension Layer](https://opentelemetry.io/blog/2025/observing-lambdas/) | Lambda, serverless, extension layer, delayed export | Ephemeral runtime constraints and decoupled export patterns | [platforms](./platforms.md), [monitoring](./monitoring.md) |
| [Exposing OTel Collector in Kubernetes with Gateway API & mTLS](https://opentelemetry.io/blog/2025/expose-otel-collector-gateway-api/) | Gateway API, mTLS, external OTLP ingress, multi-cluster | Security and ingress pattern for centralized collector deployments | [security](./security.md), [architecture](./architecture.md) |
| [How Mastodon Runs OpenTelemetry Collectors in Production](https://opentelemetry.io/blog/2026/devex-mastodon/) | small team, OTel Operator, Argo CD, tail sampling, vendor-neutral | Operating model for simple, declarative, reliable collector deployments | [architecture](./architecture.md), [monitoring](./monitoring.md) |
| [OpenTelemetry Profiles Enters Public Alpha](https://opentelemetry.io/blog/2026/profiles-alpha/) | profiles, continuous profiling, eBPF profiler, `pprof` receiver | How continuous profiling fits into OpenTelemetry | [platforms](./platforms.md), [monitoring](./monitoring.md) |
| [Demystifying Automatic Instrumentation](https://opentelemetry.io/blog/2025/demystifying-auto-instrumentation/) | auto-instrumentation, zero-code, bytecode instrumentation, eBPF | Which automatic instrumentation mechanism fits a runtime | [deployment](./deployment.md) |
| [OpenTelemetry Logging and You](https://opentelemetry.io/blog/2025/opentelemetry-logging-and-you/) | logs, events, Logs API, log bridges, signal correlation | How logs relate to traces and metrics in OTel's model | [pipelines](./pipelines.md) |
| [How to Name Your Spans](https://opentelemetry.io/blog/2025/how-to-name-your-spans/) | span naming, low cardinality, semantic conventions | Custom instrumentation and naming guidance | — |
| [How to Name Your Metrics](https://opentelemetry.io/blog/2025/how-to-name-your-metrics/) | metric naming, units, cardinality, `service.name` | Metric schema hygiene and cross-service aggregation | [monitoring](./monitoring.md) |
| [OpenTelemetry Sampling update](https://opentelemetry.io/blog/2025/sampling-milestones/) | consistent sampling, TraceState, probability sampling | Advanced sampling beyond basic head vs tail framing | [sampling](./sampling.md) |
| [OTTL contexts just got easier with context inference](https://opentelemetry.io/blog/2025/ottl-contexts-just-got-easier/) | OTTL, transform processor, context inference | Simpler transform-processor guidance, avoid manual context selection | [processors](./processors.md), [connectors](./connectors.md) |
| [Contributing the Unroll Processor to OTel Collector Contrib](https://opentelemetry.io/blog/2025/contrib-unroll-processor/) | unroll processor, bundled logs, record expansion | Log-pipeline questions where bundled payload expansion should not use OTTL | [processors](./processors.md) |
| [Announcing the Beta Release of Go Auto-Instrumentation using eBPF](https://opentelemetry.io/blog/2025/go-auto-instrumentation-beta/) | Go auto-instrumentation, eBPF, zero-code Go | Go runtime-specific route beyond generic auto-instrumentation | [deployment](./deployment.md) |

---

## Generic Playbook Patterns

### Route by problem, not by company

Match on the user's technical goal — Lambda export, secure ingress, naming guidance — not on a company name.

### Prefer self-service with safety rails

Good playbooks let application teams opt in through narrow, well-defined interfaces while the platform retains the right guardrails.

### Treat external collector ingress as a security boundary

If telemetry crosses clusters, networks, or trust domains, route to patterns that include explicit authentication and encryption.

### Adapt the topology to the runtime

Ephemeral runtimes like Lambda need different collector and export patterns than long-running Kubernetes workloads.

### Always connect a playbook to deeper docs

A blog route should be the front door. Implementation details should come from the local references.

---

## Common Failure Modes

❌ Routing on company names instead of technical intent
❌ Treating all auto-instrumentation as the same thing
❌ Putting dynamic context into span or metric names (breaks aggregation, increases cardinality)
❌ Exposing collectors without a clear trust model
❌ Blocking ephemeral runtimes on exporter completion
❌ Answering advanced sampling questions with only basic head-vs-tail advice

---

## Reference Links

- [OTel blog](https://opentelemetry.io/blog/)
- [Developer Experience survey](https://opentelemetry.io/blog/2025/devex-survey/)
