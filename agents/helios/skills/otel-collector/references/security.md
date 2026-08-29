# OpenTelemetry Security & Compliance

## Overview

Security in observability systems is critical: telemetry data often contains sensitive information (PII, credentials, business logic), and the collector itself is a privileged component with broad network access. This reference provides guidance on PII redaction, TLS configuration, authentication, and extension security.

## Table of Contents

1. [Data Redaction & Sanitization](#data-redaction--sanitization)
2. [TLS & Encryption](#tls--encryption)
3. [Authentication & Authorization](#authentication--authorization)
4. [Extension Security](#extension-security)
5. [Least Privilege & RBAC](#least-privilege--rbac)
6. [Compliance Patterns](#compliance-patterns)

---

## Data Redaction & Sanitization

### The PII Problem

Telemetry data frequently captures sensitive information:
- **HTTP headers**: `Authorization`, `Cookie`, `X-Api-Key`
- **URLs**: Query parameters with tokens, passwords
- **Database statements**: `INSERT INTO users (email, password) VALUES (...)`
- **Custom attributes**: Credit card numbers, SSNs, phone numbers

**Regulation**: GDPR, CCPA, PCI-DSS, HIPAA mandate PII protection.

### Redaction Strategies

| Strategy | Pros | Cons | Use Case |
|----------|------|------|----------|
| **Drop** | Complete removal | No context | Highly sensitive (passwords, SSNs) |
| **Hash** | Deterministic, correlation-friendly | Reversible with rainbow tables | User IDs, emails (for tracking) |
| **Mask** | Partial visibility | Fixed pattern | Credit cards (show last 4 digits) |
| **Truncate** | Preserves structure | Partial exposure | URLs (remove query params) |

### Configuration: Attributes Processor

```yaml
processors:
  attributes:
    actions:
      - key: http.request.header.authorization
        action: delete
      - key: http.request.header.cookie
        action: delete
      - key: http.request.header.x-api-key
        action: delete
      - key: user.email
        action: hash
      - key: payment.card_number
        action: update
        value: "****-****-****-1234"
```

### Configuration: Redaction Processor (Contrib)

```yaml
processors:
  redaction:
    allowed_keys:
      - http.request.method
      - http.response.status_code
      - http.route

    blocked_values:
      - "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b"            # Credit card
      - "\\b\\d{3}-\\d{2}-\\d{4}\\b"                 # SSN
      - "\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}\\b"  # Email
      - "AKIA[0-9A-Z]{16}"                            # AWS keys
      - "eyJ[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_.+/=]+"  # JWT

    summary: replace

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, redaction, batch]
      exporters: [otlp]
```

### Common PII Patterns

| Data Type | Regex Pattern | Example |
|-----------|---------------|---------|
| **Credit Card** | `\b(?:\d{4}[- ]?){3}\d{4}\b` | 4111-1111-1111-1111 |
| **SSN** | `\b\d{3}-\d{2}-\d{4}\b` | 123-45-6789 |
| **Email** | `\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z\|a-z]{2,}\b` | user@example.com |
| **Phone (US)** | `\b\d{3}[-.]?\d{3}[-.]?\d{4}\b` | 555-123-4567 |
| **AWS Key** | `AKIA[0-9A-Z]{16}` | AKIAIOSFODNN7EXAMPLE |
| **JWT** | `eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.` | eyJhbGciOiJIUzI1NiIsIn... |

---

## TLS & Encryption

### Receiver TLS Configuration

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
        tls:
          cert_file: /etc/otel/certs/server.crt
          key_file: /etc/otel/certs/server.key
          client_ca_file: /etc/otel/certs/ca.crt  # For mTLS
          min_version: "1.3"
```

### Exporter TLS Configuration

```yaml
exporters:
  otlp:
    endpoint: backend.example.com:4317
    tls:
      insecure: false
      ca_file: /etc/otel/certs/ca.crt
      cert_file: /etc/otel/certs/client.crt  # For mTLS
      key_file: /etc/otel/certs/client.key
      insecure_skip_verify: false  # NEVER set to true in production
```

### Mutual TLS (mTLS)

Use mTLS in multi-tenant or zero-trust environments:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        tls:
          cert_file: /etc/otel/certs/server.crt
          key_file: /etc/otel/certs/server.key
          client_ca_file: /etc/otel/certs/ca.crt
          client_auth_type: require_and_verify_client_cert
```

### Kubernetes TLS with cert-manager

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: otel-collector-tls
spec:
  secretName: otel-collector-tls
  issuerRef:
    name: ca-issuer
    kind: ClusterIssuer
  dnsNames:
    - otel-collector.observability.svc.cluster.local
```

---

## Authentication & Authorization

### Bearer Token Authentication

```yaml
extensions:
  bearertokenauth:
    scheme: "Bearer"
    token: ${OTEL_BEARER_TOKEN}

receivers:
  otlp:
    protocols:
      grpc:
        auth:
          authenticator: bearertokenauth

service:
  extensions: [bearertokenauth]
```

### OIDC Authentication

```yaml
extensions:
  oidc:
    issuer_url: https://auth.example.com
    client_id: otel-collector
    client_secret: ${OIDC_CLIENT_SECRET}
    audience: otel-api

receivers:
  otlp:
    protocols:
      grpc:
        auth:
          authenticator: oidc
```

---

## Extension Security

### Dangerous Extensions

| Extension | Port | Risk | Mitigation |
|-----------|------|------|------------|
| `pprof` | 1777 | **Critical** — heap dumps, CPU profiling → DoS, memory disclosure | Bind to `localhost` only |
| `zpages` | 55679 | **High** — live trace data → PII exposure | Bind to `localhost` only |
| `health_check` | 13133 | Low | Safe to expose within cluster |

```yaml
# ❌ NEVER
extensions:
  pprof:
    endpoint: "0.0.0.0:1777"

# ✅ ALWAYS
extensions:
  pprof:
    endpoint: "localhost:1777"
```

### Kubernetes NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: otel-collector-netpol
spec:
  podSelector:
    matchLabels:
      app: otel-collector
  policyTypes:
  - Ingress
  ingress:
  - from: []
    ports:
    - protocol: TCP
      port: 4317
    - protocol: TCP
      port: 4318
  - from:
    - podSelector:
        matchLabels:
          role: debug
    ports:
    - protocol: TCP
      port: 1777
    - protocol: TCP
      port: 55679
```

---

## Least Privilege & RBAC

### Kubernetes ServiceAccount

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-collector
rules:
- apiGroups: [""]
  resources: ["pods", "namespaces", "nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["replicasets"]
  verbs: ["get", "list", "watch"]
```

### Pod Security Standards

```yaml
spec:
  serviceAccountName: otel-collector
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: otel-collector
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
```

---

## Compliance Patterns

### GDPR

```yaml
processors:
  attributes:
    actions:
      - key: user.email
        action: hash
      - key: user.phone
        action: delete
  filter:
    traces:
      span:
        - 'attributes["user.id"] == "deleted_user_123"'
```

### PCI-DSS

```yaml
processors:
  redaction:
    blocked_values:
      - "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b"   # Credit card
      - "\\bcvv:\\s*\\d{3,4}\\b"            # CVV
```

### HIPAA

Enable TLS 1.3 + encrypted storage + RBAC + audit logging:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        tls:
          min_version: "1.3"

extensions:
  file_storage:
    directory: /mnt/encrypted-volume/otel   # Encrypted EBS/disk
```

---

## Summary

✅ Redact PII at SDK or collector using `attributes`/`redaction` processors
✅ Enable TLS for all receivers and exporters (min version: 1.3)
✅ Use mTLS in zero-trust or multi-tenant environments
✅ Never expose `pprof`/`zpages` on `0.0.0.0` — bind to `localhost` only
✅ Use RBAC with least privilege for Kubernetes collectors
✅ Implement NetworkPolicy to restrict access to debug endpoints

## Reference Links

- [Security Documentation](https://opentelemetry.io/docs/specs/otel/protocol/exporter/#security)
- [Attributes Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/attributesprocessor)
- [Redaction Processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/redactionprocessor)
