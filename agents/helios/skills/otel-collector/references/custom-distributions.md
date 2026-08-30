# Custom Collector Distributions

The OpenTelemetry Collector Contrib image includes over 100 receivers, processors, exporters, and extensions. In
production you typically use fewer than 10 of these components. Building a custom distribution with OCB (OpenTelemetry
Collector Builder) removes unused components, producing a smaller, faster, and more secure binary.

## Why Build a Custom Distribution?

| Benefit | Detail |
|---------|--------|
| **Reduced attack surface** | Unused components cannot be exploited or misconfigured. Each component is a Go dependency — removing it eliminates its CVE exposure. |
| **Smaller binary and image** | The contrib binary is ~450 MB. A minimal Kubernetes agent can be under 50 MB, reducing pull time and storage costs. |
| **Faster startup** | Fewer components means less initialisation work. Critical for DaemonSet pods that must start quickly during a node rollout. |
| **Enforced component policy** | The build manifest is the authoritative list of permitted components. Any attempt to use an unlisted component fails at configuration validation, not at runtime. |
| **Easier auditing** | A short builder manifest is easier to audit than the full contrib source tree. |

---

## Installing OCB

OCB is a standalone binary. Install the version that matches the Collector version you want to build.

```bash
# Replace X.Y.Z with the desired Collector version (e.g., 0.100.0)
OTELCOL_VERSION=0.100.0

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')

# Download the OCB binary
curl -LO "https://github.com/open-telemetry/opentelemetry-collector/releases/download/cmd%2Fbuilder%2Fv${OTELCOL_VERSION}/ocb_${OTELCOL_VERSION}_${OS}_${ARCH}"

# Make it executable and move to PATH
chmod +x "ocb_${OTELCOL_VERSION}_${OS}_${ARCH}"
sudo mv "ocb_${OTELCOL_VERSION}_${OS}_${ARCH}" /usr/local/bin/ocb

# Verify
ocb version
```

Alternatively, install with Go:

```bash
go install go.opentelemetry.io/collector/cmd/builder@v0.100.0
# The binary is installed as 'builder' in $GOPATH/bin
# Rename or alias it as 'ocb' if preferred
```

---

## Builder Manifest

The builder manifest (`builder.yaml`) declares every component included in the distribution. OCB uses this file to
generate Go source code, fetch dependencies, and compile the binary.

### Manifest structure

```yaml
# builder.yaml

# dist — output configuration
dist:
  name: otelcol-custom         # Binary name
  description: "Custom OTel Collector for Kubernetes agent"
  version: "0.100.0"
  output_path: ./dist           # Directory where the binary is written
  otelcol_version: "0.100.0"   # Must match the component module versions below

# extensions — lifecycle and health components
extensions:
  - gomod: go.opentelemetry.io/collector/extension/ballastextension v0.100.0
  - gomod: go.opentelemetry.io/collector/extension/zpagesextension v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/extension/healthcheckextension v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/extension/pprofextension v0.100.0

# receivers — data ingestion
receivers:
  - gomod: go.opentelemetry.io/collector/receiver/otlpreceiver v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/filelogreceiver v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/kubeletstatsreceiver v0.100.0

# processors — data transformation and enrichment
processors:
  - gomod: go.opentelemetry.io/collector/processor/batchprocessor v0.100.0
  - gomod: go.opentelemetry.io/collector/processor/memorylimiterprocessor v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/k8sattributesprocessor v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/resourcedetectionprocessor v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/resourceprocessor v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/filterprocessor v0.100.0

# exporters — data egress
exporters:
  - gomod: go.opentelemetry.io/collector/exporter/otlpexporter v0.100.0
  - gomod: go.opentelemetry.io/collector/exporter/otlphttpexporter v0.100.0
  - gomod: go.opentelemetry.io/collector/exporter/debugexporter v0.100.0

# connectors — pipeline bridges (optional)
connectors:
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/connector/spanmetricsconnector v0.100.0
```

### Key manifest fields

| Field | Description |
|-------|-------------|
| `dist.name` | Name of the generated binary |
| `dist.version` | Version embedded in the binary (shown by `--version`) |
| `dist.output_path` | Directory where OCB writes the compiled binary |
| `dist.otelcol_version` | Core Collector version; must match the `vX.Y.Z` in all `gomod` entries |
| `extensions` | Lifecycle and operational components |
| `receivers` | Components that ingest telemetry data |
| `processors` | Components that transform or enrich data |
| `exporters` | Components that send data to backends |
| `connectors` | Components that bridge pipelines (act as both receiver and exporter) |

---

## Build Command

```bash
# Build using the manifest
ocb --config builder.yaml

# The binary is written to ./dist/<name>
./dist/otelcol-custom --version
./dist/otelcol-custom --config collector-config.yaml
```

OCB performs the following steps:

1. Generates a Go module (`go.mod`) and main package in a temporary directory.
2. Runs `go mod tidy` to resolve all dependencies.
3. Compiles the binary with `go build`.
4. Copies the binary to `dist.output_path`.

The build requires Go 1.21 or later. Set `GOFLAGS=-trimpath` for reproducible builds.

---

## Example Minimal Manifest — Kubernetes Agent

This manifest produces a binary suitable for a Kubernetes DaemonSet agent. It includes only the components required to
collect node logs, host metrics, kubelet metrics, and OTLP spans/metrics/logs, enrich them with Kubernetes metadata, and
forward to a gateway.

```yaml
# kubernetes-agent-builder.yaml
dist:
  name: otelcol-k8s-agent
  description: "Minimal OTel Collector for Kubernetes DaemonSet agent"
  version: "0.100.0"
  output_path: ./dist/k8s-agent
  otelcol_version: "0.100.0"

extensions:
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/extension/healthcheckextension v0.100.0

receivers:
  - gomod: go.opentelemetry.io/collector/receiver/otlpreceiver v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/filelogreceiver v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/hostmetricsreceiver v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/kubeletstatsreceiver v0.100.0

processors:
  - gomod: go.opentelemetry.io/collector/processor/batchprocessor v0.100.0
  - gomod: go.opentelemetry.io/collector/processor/memorylimiterprocessor v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/k8sattributesprocessor v0.100.0
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/processor/resourcedetectionprocessor v0.100.0

exporters:
  - gomod: go.opentelemetry.io/collector/exporter/otlpexporter v0.100.0
  - gomod: go.opentelemetry.io/collector/exporter/debugexporter v0.100.0
```

Build it:

```bash
ocb --config kubernetes-agent-builder.yaml
ls -lh dist/k8s-agent/otelcol-k8s-agent
```

### Containerise the custom binary

```dockerfile
# Dockerfile
FROM golang:1.22-bookworm AS builder

WORKDIR /build
COPY kubernetes-agent-builder.yaml .

# Install OCB
RUN OTELCOL_VERSION=0.100.0 && \
    curl -LO "https://github.com/open-telemetry/opentelemetry-collector/releases/download/cmd%2Fbuilder%2Fv${OTELCOL_VERSION}/ocb_${OTELCOL_VERSION}_linux_amd64" && \
    chmod +x ocb_${OTELCOL_VERSION}_linux_amd64 && \
    mv ocb_${OTELCOL_VERSION}_linux_amd64 /usr/local/bin/ocb

RUN ocb --config kubernetes-agent-builder.yaml

# Minimal runtime image
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=builder /build/dist/k8s-agent/otelcol-k8s-agent /otelcol

EXPOSE 4317 4318 13133

ENTRYPOINT ["/otelcol"]
CMD ["--config=/etc/otelcol/config.yaml"]
```

---

## References

- [OCB documentation](https://opentelemetry.io/docs/collector/custom-collector/)
- [OCB GitHub repository](https://github.com/open-telemetry/opentelemetry-collector/tree/main/cmd/builder)
- [OCB releases](https://github.com/open-telemetry/opentelemetry-collector/releases?q=builder&expanded=true)
- [Collector contrib component list](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main)
- [OpenTelemetry Collector core components](https://github.com/open-telemetry/opentelemetry-collector/tree/main)
