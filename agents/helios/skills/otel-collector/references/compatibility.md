# Compatibility Reference

Use this document for version-sensitive guidance that changes more frequently than the core routing logic in `SKILL.md`.

## Baseline version floors

- **OpenTelemetry Collector**: v0.151.0+
- **Semantic Conventions**: v1.40.0+
- **Kubernetes**: v1.24+ for native sidecar support
- **Go SDK**: v1.24.0+
- **Python SDK**: v1.41.0+

## AI agent telemetry compatibility

| Agent | Signals | Notes |
|-------|---------|-------|
| **Claude Code** | Metrics + Logs/Events only (no traces) | `OTEL_METRICS_INCLUDE_ENTRYPOINT=true` adds bounded `app.entrypoint` dimension |
| **Gemini CLI** | Traces + Metrics + Logs | v0.34.0+ with GenAI semantic conventions (`gen_ai.*`) |
| **GitHub Copilot** | Traces + Metrics + Events | Latest stable/Insiders builds with GenAI semantic conventions |
| **Codex CLI** | Partial — interactive mode only | v0.105.0+; `exec` and `mcp-server` have known gaps |
| **Qwen Code** | Partial | v0.16.1+; partial `gen_ai.*` dual-emit on top of `qwen-code.*` fields |

## Claude Code temporality note

Claude Code emits **cumulative** metrics. Always set:
```bash
OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE=cumulative
```
VictoriaMetrics and some Prometheus backends will silently drop delta-converted metrics from cumulative sources.

## Maintenance guidance

- Treat these version floors as fast-moving compatibility notes rather than hard-coded architectural rules.
- Pin collector components to released versions and verify stability levels before using non-stable features in production.
- Re-check upstream release notes whenever updating examples that depend on AI agent telemetry support or evolving semantic conventions.
- For the full AI agent support matrix and per-agent configs, see [ai-agents.md](../../../otel-instrumentation/references/ai-agents.md).
