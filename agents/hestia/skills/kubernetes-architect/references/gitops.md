# Kubernetes / GitOps

This reference provides comprehensive GitOps guidance for Kubernetes, covering Flux CD, Argo CD, repository structure,
multi-cluster management, and progressive delivery patterns.

## Overview

GitOps is a declarative approach to continuous delivery where Git serves as the single source of truth for
infrastructure and application definitions. Changes are made through Git commits, and automated agents synchronize the
desired state to clusters.

## Core Principles

**Declarative** - All resources defined declaratively
**Versioned** - Git history provides complete audit trail
**Automated** - Agents automatically sync desired state
**Reconciliation** - Continuous drift detection and correction

## Flux CD

Flux is a CNCF graduated project for GitOps delivery, built on GitOps Toolkit components.

### Installation

#### Bootstrap Flux

```bash
# Install Flux CLI
brew install fluxcd/tap/flux

# Bootstrap Flux to GitHub
flux bootstrap github \
  --owner=myorg \
  --repository=fleet-infra \
  --branch=main \
  --path=clusters/production \
  --personal

# Bootstrap to GitLab
flux bootstrap gitlab \
  --owner=myorg \
  --repository=fleet-infra \
  --branch=main \
  --path=clusters/production \
  --token-auth
```

### Source Management

#### GitRepository Source

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform-apps
  namespace: flux-system
spec:
  interval: 1m0s
  url: https://github.com/myorg/platform-apps
  ref:
    branch: main
  secretRef:
    name: git-credentials
  ignore: |
    # Exclude development files
    /**/dev/
    /**/.terraform/
    /**/tmp/
```

#### HelmRepository Source

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: bitnami
  namespace: flux-system
spec:
  interval: 10m0s
  url: https://charts.bitnami.com/bitnami
  timeout: 5m0s
```

#### OCIRepository Source

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 5m0s
  url: oci://ghcr.io/stefanprodan/manifests/podinfo
  ref:
    tag: latest
```

### Application Deployment

#### Basic Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 10m0s
  retryInterval: 1m0s
  timeout: 5m0s
  sourceRef:
    kind: GitRepository
    name: platform-apps
  path: ./infrastructure/base
  prune: true
  wait: true
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: cert-manager
    namespace: cert-manager
```

#### Multi-Environment Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps-production
  namespace: flux-system
spec:
  interval: 5m0s
  sourceRef:
    kind: GitRepository
    name: platform-apps
  path: ./apps/production
  prune: true
  # Apply infrastructure first
  dependsOn:
  - name: infrastructure
  postBuild:
    substitute:
      CLUSTER_NAME: "production-us-east-1"
      DOMAIN: "example.com"
    substituteFrom:
    - kind: ConfigMap
      name: cluster-vars
    - kind: Secret
      name: cluster-secrets
```

#### Progressive Delivery with Dependencies

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: backend-canary
  namespace: flux-system
spec:
  interval: 1m0s
  sourceRef:
    kind: GitRepository
    name: platform-apps
  path: ./apps/backend
  prune: true
  # Wait for database migration
  dependsOn:
  - name: database-migrations
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: backend
    namespace: production
  - apiVersion: v1
    kind: Service
    name: backend
    namespace: production
```

### Helm Release Management

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: ingress-nginx
  namespace: flux-system
spec:
  interval: 10m0s
  chart:
    spec:
      chart: ingress-nginx
      version: '4.8.x'
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx
        namespace: flux-system
  install:
    crds: Create
    remediation:
      retries: 3
  upgrade:
    crds: CreateReplace
    remediation:
      retries: 3
      remediateLastFailure: true
    cleanupOnFail: true
  rollback:
    recreate: true
    cleanupOnFail: true
  values:
    controller:
      replicaCount: 3
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
      service:
        annotations:
          service.beta.kubernetes.io/aws-load-balancer-type: nlb
      metrics:
        enabled: true
  valuesFrom:
  - kind: ConfigMap
    name: ingress-values
    valuesKey: values.yaml
```

### Notifications

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: gitops-alerts
  secretRef:
    name: slack-webhook
---
apiVersion: notification.toolkit.fluxcd.io/v1beta2
kind: Alert
metadata:
  name: on-deployment-failure
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: error
  eventSources:
  - kind: Kustomization
    name: '*'
  - kind: HelmRelease
    name: '*'
```

## Argo CD

Argo CD is a declarative GitOps continuous delivery tool for Kubernetes.

### Installation

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

patches:
- target:
    kind: ConfigMap
    name: argocd-cm
  patch: |-
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: argocd-cm
    data:
      timeout.reconciliation: 180s
      statusbadge.enabled: "true"
```

### Application Management

#### Basic Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  finalizers:
  - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/applications
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

#### Multi-Source Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: multi-source-app
  namespace: argocd
spec:
  project: default
  sources:
  - repoURL: https://github.com/myorg/helm-charts
    targetRevision: main
    path: charts/my-app
    helm:
      valueFiles:
      - $values/apps/my-app/values.yaml
  - repoURL: https://github.com/myorg/app-config
    targetRevision: main
    ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

#### ApplicationSet with Git Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
  namespace: argocd
spec:
  generators:
  - git:
      repoURL: https://github.com/myorg/fleet-config
      revision: HEAD
      directories:
      - path: clusters/*
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/fleet-config
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: '{{path.basename}}'
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

#### ApplicationSet with Cluster Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-components
  namespace: argocd
spec:
  generators:
  - clusters:
      selector:
        matchLabels:
          environment: production
  template:
    metadata:
      name: '{{name}}-cert-manager'
    spec:
      project: platform
      source:
        repoURL: https://github.com/myorg/platform
        targetRevision: HEAD
        path: infrastructure/cert-manager
      destination:
        server: '{{server}}'
        namespace: cert-manager
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
        - CreateNamespace=true
```

### Project Management

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production applications
  sourceRepos:
  - 'https://github.com/myorg/*'
  destinations:
  - namespace: 'prod-*'
    server: https://kubernetes.default.svc
  - namespace: production
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: 'rbac.authorization.k8s.io'
    kind: ClusterRole
  - group: 'rbac.authorization.k8s.io'
    kind: ClusterRoleBinding
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
  orphanedResources:
    warn: true
  roles:
  - name: developers
    description: Developers can sync apps
    policies:
    - p, proj:production:developers, applications, sync, production/*, allow
    groups:
    - myorg:developers
```

### Notifications

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} is now running new version.
    slack:
      attachments: |
        [{
          "title": "{{ .app.metadata.name}}",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "color": "good",
          "fields": [{
            "title": "Sync Status",
            "value": "{{.app.status.sync.status}}",
            "short": true
          }]
        }]
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
type: Opaque
stringData:
  slack-token: xoxb-your-token-here
```

## Repository Structure

### Monorepo Structure

```text
fleet-infra/
├── clusters/
│   ├── production/
│   │   ├── flux-system/
│   │   │   ├── gotk-components.yaml
│   │   │   └── kustomization.yaml
│   │   ├── infrastructure.yaml
│   │   └── apps.yaml
│   └── staging/
│       ├── flux-system/
│       ├── infrastructure.yaml
│       └── apps.yaml
├── infrastructure/
│   ├── base/
│   │   ├── cert-manager/
│   │   ├── ingress-nginx/
│   │   └── kustomization.yaml
│   ├── production/
│   │   └── kustomization.yaml
│   └── staging/
│       └── kustomization.yaml
└── apps/
    ├── base/
    │   ├── backend/
    │   ├── frontend/
    │   └── kustomization.yaml
    ├── production/
    │   └── kustomization.yaml
    └── staging/
        └── kustomization.yaml
```

### Multi-Repo Structure

```text
# Infrastructure Repo
infrastructure/
├── base/
│   ├── networking/
│   ├── security/
│   └── monitoring/
└── overlays/
    ├── production/
    └── staging/

# Application Repos (per team)
team-backend/
├── manifests/
│   ├── base/
│   └── overlays/
└── helm-charts/

team-frontend/
├── manifests/
│   ├── base/
│   └── overlays/
└── helm-charts/
```

## Multi-Cluster Management

### Flux Multi-Cluster

```yaml
# clusters/production-us-east-1/flux-system/kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps/production
  prune: true
  postBuild:
    substitute:
      CLUSTER_REGION: us-east-1
      CLUSTER_NAME: production-us-east-1
```

### Argo CD Multi-Cluster

```bash
# Add cluster to Argo CD
argocd cluster add production-us-west-2 \
  --name production-us-west-2 \
  --label environment=production \
  --label region=us-west-2

# Create ApplicationSet for multi-cluster
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-app
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - cluster: production-us-east-1
        url: https://prod-us-east-1.example.com
      - cluster: production-us-west-2
        url: https://prod-us-west-2.example.com
  template:
    metadata:
      name: '{{cluster}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/apps
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{url}}'
        namespace: default
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
EOF
```

## Progressive Delivery

### Flagger with Flux

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: backend
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  progressDeadlineSeconds: 600
  service:
    port: 8080
    targetPort: 8080
  analysis:
    interval: 1m
    threshold: 10
    maxWeight: 50
    stepWeight: 5
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 1m
    webhooks:
    - name: load-test
      url: http://flagger-loadtester/
      timeout: 5s
      metadata:
        cmd: "hey -z 1m -q 10 -c 2 http://backend-canary.production:8080/"
```

### Argo Rollouts

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: frontend
  namespace: production
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 5m}
      - setWeight: 40
      - pause: {duration: 5m}
      - setWeight: 60
      - pause: {duration: 5m}
      - setWeight: 80
      - pause: {duration: 5m}
      canaryService: frontend-canary
      stableService: frontend-stable
      trafficRouting:
        istio:
          virtualService:
            name: frontend
            routes:
            - primary
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: myregistry/frontend:v2
        ports:
        - containerPort: 8080
```

## Secrets Management

### Sealed Secrets with Flux

```bash
# Install kubeseal
brew install kubeseal

# Create sealed secret
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secretpass \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml
```

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-credentials
  namespace: production
spec:
  encryptedData:
    username: AgBH8...
    password: AgCK9...
  template:
    metadata:
      name: db-credentials
      namespace: production
```

### External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-credentials
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: db-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: prod/database/credentials
      property: username
  - secretKey: password
    remoteRef:
      key: prod/database/credentials
      property: password
```

## Common Anti-Patterns

### ❌ Direct Cluster Access

```bash
# Bad - manual kubectl apply
kubectl apply -f deployment.yaml
```

```bash
# Good - commit to Git
git add deployment.yaml
git commit -m "Update deployment"
# Let GitOps agent sync
```

### ❌ Secrets in Git

```yaml
# Bad - plain secret in Git
apiVersion: v1
kind: Secret
metadata:
  name: db-password
stringData:
  password: supersecret123
```

```yaml
# Good - use sealed secrets or external secrets
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-password
spec:
  encryptedData:
    password: AgBH8...
```

### ❌ No Prune Strategy

```yaml
# Bad - resources orphaned when removed from Git
spec:
  prune: false
```

```yaml
# Good - enable pruning
spec:
  prune: true
  # For Argo CD
  syncPolicy:
    automated:
      prune: true
```

### ❌ Missing Dependencies

```yaml
# Bad - no dependency ordering
kind: Kustomization
metadata:
  name: app
spec:
  path: ./app
```

```yaml
# Good - explicit dependencies
kind: Kustomization
metadata:
  name: app
spec:
  path: ./app
  dependsOn:
  - name: infrastructure
  - name: database
```

### ❌ Single Branch for All Environments

```bash
# Bad - all environments in main branch without structure
everything-mixed/
```

```bash
# Good - structured paths or environment branches
fleet-infra/
  └── clusters/
      ├── production/
      └── staging/
# Or separate branches with clear promotion path
```

## Validation Commands

```bash
# Flux validation
flux check
flux get sources git
flux get kustomizations
flux get helmreleases
flux logs --follow

# Reconcile resources manually
flux reconcile source git flux-system
flux reconcile kustomization apps

# Argo CD validation
argocd app list
argocd app get myapp
argocd app sync myapp
argocd app diff myapp
argocd app history myapp

# Check sync status
argocd app wait myapp --health --sync --timeout 300

# Repository structure validation
kustomize build ./apps/production
helm template my-release ./charts/my-app
```

## Additional Resources

- [Flux Documentation](https://fluxcd.io/docs/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Flagger Progressive Delivery](https://flagger.app/)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
