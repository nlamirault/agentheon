# Helm / Best Practices

This reference provides comprehensive guidance for Helm chart development, covering chart structure, templating best
practices, values management, and packaging for Helm 3+.

## Chart Structure

### Standard Directory Layout

```text
chart-name/
├── Chart.yaml          # Chart metadata (required)
├── values.yaml         # Default configuration values (required)
├── charts/             # Chart dependencies
├── templates/          # Kubernetes manifest templates
│   ├── NOTES.txt      # Post-install instructions
│   ├── _helpers.tpl   # Template helpers and partials
│   ├── deployment.yaml
│   ├── service.yaml
│   └── tests/         # Chart tests
├── crds/              # CustomResourceDefinitions
└── .helmignore        # Files to ignore
```

## Chart.yaml Configuration

### Helm 3 Chart Metadata

```yaml
apiVersion: v2
name: my-app
description: Production-ready Helm chart
type: application
version: 1.2.3
appVersion: "2.1.0"

keywords:
  - web
  - api

maintainers:
  - name: Team Name
    email: team@example.com

dependencies:
  - name: postgresql
    version: 12.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
```

**Required Fields:**

- `apiVersion: v2` (Helm 3+)
- `name` - Chart name (lowercase, hyphens)
- `version` - Chart version (SemVer)

**Recommended Fields:**

- `appVersion` - Application version
- `description` - Brief description
- `type` - `application` or `library`
- `maintainers` - Chart maintainers

## values.yaml Design

### Well-Structured Values File

```yaml
replicaCount: 2

image:
  repository: myregistry/my-app
  pullPolicy: IfNotPresent
  tag: ""  # Overrides appVersion

serviceAccount:
  create: true
  name: ""

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000

securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: false
  className: nginx
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
```

**Best Practices:**

- Use camelCase for keys
- Group related settings
- Add comments for clarity
- Provide sensible defaults
- Document valid value types

## Template Helpers (_helpers.tpl)

### Essential Helpers

```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "my-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "my-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "my-app.labels" -}}
helm.sh/chart: {{ include "my-app.chart" . }}
{{ include "my-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "my-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "my-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

## Templating Best Practices

### Use Required for Mandatory Values

```yaml
# Fail if value not provided
DATABASE_HOST: {{ required "database.host is required" .Values.database.host }}
```

### Conditional Rendering

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "my-app.fullname" . }}
spec:
  # ... ingress spec
{{- end }}
```

### Range Loops

```yaml
{{- range .Values.ingress.hosts }}
- host: {{ .host | quote }}
  http:
    paths:
    {{- range .paths }}
    - path: {{ .path }}
      pathType: {{ .pathType }}
    {{- end }}
{{- end }}
```

### Checksum Annotations

Trigger pod restarts on config changes:

```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

### Use toYaml for Complex Structures

```yaml
resources:
  {{- toYaml .Values.resources | nindent 12 }}

{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

## Multi-Environment Values

### Environment-Specific Files

```text
my-app/
├── values.yaml          # Defaults
├── values-dev.yaml      # Development
├── values-staging.yaml  # Staging
└── values-prod.yaml     # Production
```

**values-prod.yaml:**

```yaml
replicaCount: 3

image:
  tag: "2.1.0"

resources:
  limits:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20

ingress:
  enabled: true

postgresql:
  enabled: false  # External DB in prod
```

### Deploy with Environment

```bash
# Development
helm install my-app ./my-app -f values-dev.yaml

# Production
helm upgrade --install my-app ./my-app -f values-prod.yaml

# Override specific values
helm upgrade my-app ./my-app \
  -f values-prod.yaml \
  --set image.tag=2.1.1
```

## Chart Dependencies

### Define Dependencies

**Chart.yaml:**

```yaml
dependencies:
  - name: postgresql
    version: 12.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
  - name: redis
    version: 17.x.x
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
```

### Update Dependencies

```bash
# Download dependencies
helm dependency update ./my-app

# List dependencies
helm dependency list ./my-app
```

### Configure Subcharts

**values.yaml:**

```yaml
postgresql:
  enabled: true
  auth:
    username: myapp
    database: myapp
  primary:
    resources:
      requests:
        memory: 256Mi
        cpu: 250m
```

## Secrets Management

### External Secrets

```yaml
# values.yaml
externalSecrets:
  enabled: true
  secretStoreRef: vault-backend
  secrets:
    - name: db-password
      key: database/password

# templates/externalsecret.yaml
{{- if .Values.externalSecrets.enabled }}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "my-app.fullname" . }}
spec:
  secretStoreRef:
    name: {{ .Values.externalSecrets.secretStoreRef }}
  data:
  {{- range .Values.externalSecrets.secrets }}
  - secretKey: {{ .name }}
    remoteRef:
      key: {{ .key }}
  {{- end }}
{{- end }}
```

**Never hardcode secrets in values.yaml or templates.**

## Template Validation

### Render and Validate

```bash
# Render templates locally
helm template my-release ./my-app

# With custom values
helm template my-release ./my-app -f values-prod.yaml

# Validate against Kubernetes
helm template my-release ./my-app | kubectl apply --dry-run=client -f -

# Server-side validation
helm template my-release ./my-app | kubectl apply --dry-run=server -f -
```

### Lint Chart

```bash
# Basic linting
helm lint ./my-app

# With values file
helm lint ./my-app -f values-prod.yaml

# Strict mode
helm lint --strict ./my-app
```

## Chart Testing

### Test Template

**templates/tests/test-connection.yaml:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "my-app.fullname" . }}-test-connection
  annotations:
    "helm.sh/hook": test
spec:
  containers:
  - name: wget
    image: busybox
    command: ['wget']
    args: ['{{ include "my-app.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

### Run Tests

```bash
# Install chart
helm install my-app ./my-app

# Run tests
helm test my-app

# With logs
helm test my-app --logs
```

## NOTES.txt Template

**templates/NOTES.txt:**

```text
Thank you for installing {{ .Chart.Name }}!

Release: {{ .Release.Name }}
Namespace: {{ .Release.Namespace }}

{{- if .Values.ingress.enabled }}
Application URL:
{{- range .Values.ingress.hosts }}
  https://{{ .host }}
{{- end }}
{{- else }}
Get the application URL:
  export POD_NAME=$(kubectl get pods -n {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "my-app.name" . }}" -o jsonpath="{.items[0].metadata.name}")
  kubectl -n {{ .Release.Namespace }} port-forward $POD_NAME 8080:80
{{- end }}
```

## Common Anti-Patterns

### ❌ Hardcoded Values

```yaml
# Bad
image: myregistry/my-app:1.0.0
replicas: 3
```

```yaml
# Good
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
replicas: {{ .Values.replicaCount }}
```

### ❌ No Helper Functions

```yaml
# Bad - repeated in every template
labels:
  app.kubernetes.io/name: my-app
  app.kubernetes.io/instance: {{ .Release.Name }}
```

```yaml
# Good - use helper
labels:
  {{- include "my-app.labels" . | nindent 4 }}
```

### ❌ Missing Validation

```yaml
# Bad
host: {{ .Values.ingress.host }}
```

```yaml
# Good
host: {{ required "ingress.host is required" .Values.ingress.host }}
```

### ❌ Deprecated API Versions

```yaml
# Bad
apiVersion: extensions/v1beta1
kind: Ingress
```

```yaml
# Good
apiVersion: networking.k8s.io/v1
kind: Ingress
```

## Best Practices Summary

### Chart Development

✅ **DO:**

- Use Helm 3+ with `apiVersion: v2`
- Follow standard directory structure
- Create comprehensive `_helpers.tpl`
- Use semantic versioning
- Provide sensible defaults
- Add comments explaining values
- Include NOTES.txt
- Write chart tests
- Use `required` for mandatory values
- Validate with `helm lint`

❌ **DON'T:**

- Hardcode values in templates
- Use deprecated API versions
- Skip linting and testing
- Expose secrets in values files
- Use `latest` as default tag
- Create overly complex templates

### Template Style

✅ **DO:**

- Use descriptive helper names
- Keep templates readable
- Use `toYaml` for complex structures
- Add checksum annotations
- Use conditionals for features
- Validate generated manifests

❌ **DON'T:**

- Mix logic and content
- Create deeply nested conditionals
- Repeat code (use helpers)
- Forget edge cases

## Packaging and Distribution

### Package Chart

```bash
# Package chart
helm package ./my-app

# With specific version
helm package ./my-app --version 1.2.3
```

### Chart Repository

```bash
# Create repository index
helm repo index ./charts

# Push to OCI registry
helm push my-app-1.2.3.tgz oci://registry.example.com/charts
```

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Chart Template Guide](https://helm.sh/docs/chart_template_guide/)
- [Artifact Hub](https://artifacthub.io/)

For complete examples, see `assets/helm-values-example.yaml`.
