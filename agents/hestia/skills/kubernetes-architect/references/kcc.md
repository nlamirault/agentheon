# Kubernetes / Config Connector (KCC)

This reference provides comprehensive guidance for using Google Cloud Config Connector to manage GCP resources
declaratively from Kubernetes, including authentication, resource provisioning, and best practices.

## Overview

Config Connector (KCC) is a Kubernetes addon that enables management of Google Cloud resources through Kubernetes custom
resources. It provides a declarative way to provision and manage GCP services using familiar Kubernetes patterns.

## Installation

### GKE Cluster with Config Connector

```bash
# Create GKE cluster with Config Connector enabled
gcloud container clusters create production-cluster \
  --addons ConfigConnector \
  --workload-pool=PROJECT_ID.svc.id.goog \
  --enable-stackdriver-kubernetes \
  --zone us-central1-a

# Verify installation
kubectl get crds | grep cnrm.cloud.google.com
kubectl get pods -n cnrm-system
```

### Manual Installation

```bash
# Install Config Connector
kubectl apply -f https://github.com/GoogleCloudPlatform/k8s-config-connector/releases/latest/download/install-bundle.yaml

# Create ConfigConnector resource
kubectl apply -f - <<EOF
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  googleServiceAccount: config-connector@PROJECT_ID.iam.gserviceaccount.com
EOF
```

## Authentication

### Workload Identity (Recommended)

```bash
# Create Google Service Account
gcloud iam service-accounts create config-connector

# Grant permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:config-connector@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

# Enable Workload Identity binding
gcloud iam service-accounts add-iam-policy-binding \
  config-connector@PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[cnrm-system/cnrm-controller-manager]" \
  --role="roles/iam.workloadIdentityUser"

# Annotate Kubernetes service account
kubectl annotate serviceaccount cnrm-controller-manager \
  -n cnrm-system \
  iam.gke.io/gcp-service-account=config-connector@PROJECT_ID.iam.gserviceaccount.com
```

### Namespaced Mode

```yaml
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnectorContext
metadata:
  name: configconnectorcontext.core.cnrm.cloud.google.com
  namespace: production
spec:
  googleServiceAccount: production-sa@PROJECT_ID.iam.gserviceaccount.com
  requestProjectPolicy: RESOURCE_PROJECT_ONLY
```

## Projects and Billing

### Project

```yaml
apiVersion: resourcemanager.cnrm.cloud.google.com/v1beta1
kind: Project
metadata:
  name: production-project
  namespace: config-connector
spec:
  name: production-project
  projectID: my-prod-project-123
  billingAccountRef:
    external: "012345-6789AB-CDEF01"
  folderRef:
    name: production-folder
```

## Storage

### GCS Bucket

```yaml
apiVersion: storage.cnrm.cloud.google.com/v1beta1
kind: StorageBucket
metadata:
  name: prod-app-data-bucket
  namespace: production
spec:
  location: US
  storageClass: STANDARD
  uniformBucketLevelAccess: true
  versioning:
    enabled: true
  lifecycleRule:
  - action:
      type: Delete
    condition:
      age: 365
      numNewerVersions: 3
  - action:
      type: SetStorageClass
      storageClass: NEARLINE
    condition:
      age: 90
  encryption:
    defaultKmsKeyRef:
      name: storage-encryption-key
```

### Bucket IAM

```yaml
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMPolicy
metadata:
  name: prod-app-data-bucket-policy
  namespace: production
spec:
  resourceRef:
    apiVersion: storage.cnrm.cloud.google.com/v1beta1
    kind: StorageBucket
    name: prod-app-data-bucket
  bindings:
  - role: roles/storage.objectViewer
    members:
    - serviceAccount:app-service@PROJECT_ID.iam.gserviceaccount.com
  - role: roles/storage.objectAdmin
    members:
    - serviceAccount:backup-service@PROJECT_ID.iam.gserviceaccount.com
```

## Cloud SQL

### PostgreSQL Instance

```yaml
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLInstance
metadata:
  name: production-postgres
  namespace: production
spec:
  databaseVersion: POSTGRES_15
  region: us-central1
  settings:
    tier: db-custom-2-7680
    diskSize: 100
    diskType: PD_SSD
    availabilityType: REGIONAL
    backupConfiguration:
      enabled: true
      pointInTimeRecoveryEnabled: true
      startTime: "02:00"
      transactionLogRetentionDays: 7
      backupRetentionSettings:
        retainedBackups: 30
        retentionUnit: COUNT
    ipConfiguration:
      ipv4Enabled: false
      privateNetworkRef:
        name: production-vpc
      requireSsl: true
    databaseFlags:
    - name: max_connections
      value: "200"
    - name: shared_buffers
      value: "2097152"  # 2GB in 8KB pages
    maintenanceWindow:
      day: 7
      hour: 2
      updateTrack: stable
    insightsConfig:
      queryInsightsEnabled: true
      queryStringLength: 1024
      recordApplicationTags: true
```

### Database and User

```yaml
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLDatabase
metadata:
  name: application-db
  namespace: production
spec:
  instanceRef:
    name: production-postgres
  charset: UTF8
  collation: en_US.UTF8
---
apiVersion: sql.cnrm.cloud.google.com/v1beta1
kind: SQLUser
metadata:
  name: app-user
  namespace: production
spec:
  instanceRef:
    name: production-postgres
  password:
    valueFrom:
      secretKeyRef:
        name: db-password
        key: password
```

## Pub/Sub

### Topic and Subscription

```yaml
apiVersion: pubsub.cnrm.cloud.google.com/v1beta1
kind: PubSubTopic
metadata:
  name: order-events
  namespace: production
spec:
  messageRetentionDuration: 604800s  # 7 days
  kmsKeyRef:
    name: pubsub-encryption-key
---
apiVersion: pubsub.cnrm.cloud.google.com/v1beta1
kind: PubSubSubscription
metadata:
  name: order-processor-sub
  namespace: production
spec:
  topicRef:
    name: order-events
  ackDeadlineSeconds: 60
  messageRetentionDuration: 604800s
  retryPolicy:
    minimumBackoff: 10s
    maximumBackoff: 600s
  expirationPolicy:
    ttl: 2678400s  # 31 days
  deadLetterPolicy:
    deadLetterTopicRef:
      name: order-events-dlq
    maxDeliveryAttempts: 5
```

## Cloud KMS

### KeyRing and CryptoKey

```yaml
apiVersion: kms.cnrm.cloud.google.com/v1beta1
kind: KMSKeyRing
metadata:
  name: production-keyring
  namespace: production
spec:
  location: us-central1
---
apiVersion: kms.cnrm.cloud.google.com/v1beta1
kind: KMSCryptoKey
metadata:
  name: storage-encryption-key
  namespace: production
spec:
  keyRingRef:
    name: production-keyring
  purpose: ENCRYPT_DECRYPT
  rotationPeriod: 7776000s  # 90 days
  versionTemplate:
    algorithm: GOOGLE_SYMMETRIC_ENCRYPTION
    protectionLevel: SOFTWARE
```

## Networking

### VPC Network

```yaml
apiVersion: compute.cnrm.cloud.google.com/v1beta1
kind: ComputeNetwork
metadata:
  name: production-vpc
  namespace: production
spec:
  autoCreateSubnetworks: false
  routingMode: REGIONAL
---
apiVersion: compute.cnrm.cloud.google.com/v1beta1
kind: ComputeSubnetwork
metadata:
  name: gke-subnet
  namespace: production
spec:
  ipCidrRange: 10.0.0.0/20
  region: us-central1
  networkRef:
    name: production-vpc
  privateIpGoogleAccess: true
  secondaryIpRange:
  - rangeName: gke-pods
    ipCidrRange: 10.4.0.0/14
  - rangeName: gke-services
    ipCidrRange: 10.8.0.0/20
  logConfig:
    aggregationInterval: INTERVAL_5_SEC
    flowSampling: 0.5
    metadata: INCLUDE_ALL_METADATA
```

### Firewall Rules

```yaml
apiVersion: compute.cnrm.cloud.google.com/v1beta1
kind: ComputeFirewall
metadata:
  name: allow-internal
  namespace: production
spec:
  networkRef:
    name: production-vpc
  priority: 1000
  direction: INGRESS
  sourceRanges:
  - 10.0.0.0/8
  allowed:
  - protocol: tcp
  - protocol: udp
  - protocol: icmp
---
apiVersion: compute.cnrm.cloud.google.com/v1beta1
kind: ComputeFirewall
metadata:
  name: allow-health-checks
  namespace: production
spec:
  networkRef:
    name: production-vpc
  priority: 1000
  direction: INGRESS
  sourceRanges:
  - 35.191.0.0/16
  - 130.211.0.0/22
  allowed:
  - protocol: tcp
    ports:
    - "80"
    - "443"
    - "8080"
```

## IAM

### Service Account

```yaml
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMServiceAccount
metadata:
  name: application-sa
  namespace: production
spec:
  displayName: Application Service Account
---
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMPolicy
metadata:
  name: application-sa-workload-identity
  namespace: production
spec:
  resourceRef:
    apiVersion: iam.cnrm.cloud.google.com/v1beta1
    kind: IAMServiceAccount
    name: application-sa
  bindings:
  - role: roles/iam.workloadIdentityUser
    members:
    - serviceAccount:PROJECT_ID.svc.id.goog[production/app-ksa]
```

### IAM Policy Bindings

```yaml
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMPolicyMember
metadata:
  name: app-storage-access
  namespace: production
spec:
  member: serviceAccount:application-sa@PROJECT_ID.iam.gserviceaccount.com
  role: roles/storage.objectViewer
  resourceRef:
    apiVersion: storage.cnrm.cloud.google.com/v1beta1
    kind: StorageBucket
    name: prod-app-data-bucket
```

## Monitoring

### Log Metric

```yaml
apiVersion: logging.cnrm.cloud.google.com/v1beta1
kind: LoggingLogMetric
metadata:
  name: error-rate
  namespace: production
spec:
  description: Count of error log entries
  filter: 'severity>=ERROR'
  metricDescriptor:
    metricKind: DELTA
    valueType: INT64
    labels:
    - key: service
      valueType: STRING
      description: Service name
```

### Alert Policy

```yaml
apiVersion: monitoring.cnrm.cloud.google.com/v1beta1
kind: MonitoringAlertPolicy
metadata:
  name: high-error-rate
  namespace: production
spec:
  displayName: High Error Rate Alert
  combiner: OR
  conditions:
  - displayName: Error rate too high
    conditionThreshold:
      filter: metric.type="logging.googleapis.com/user/error-rate"
      comparison: COMPARISON_GT
      thresholdValue: 10
      duration: 60s
      aggregations:
      - alignmentPeriod: 60s
        perSeriesAligner: ALIGN_RATE
  notificationChannels:
  - name: pagerduty-channel
```

## Common Anti-Patterns

### ❌ Missing Project References

```yaml
# Bad - ambiguous project
apiVersion: storage.cnrm.cloud.google.com/v1beta1
kind: StorageBucket
metadata:
  name: my-bucket
```

```yaml
# Good - explicit project annotation
apiVersion: storage.cnrm.cloud.google.com/v1beta1
kind: StorageBucket
metadata:
  name: my-bucket
  annotations:
    cnrm.cloud.google.com/project-id: my-project-123
```

### ❌ Public Access

```yaml
# Bad - bucket publicly accessible
apiVersion: storage.cnrm.cloud.google.com/v1beta1
kind: StorageBucket
metadata:
  name: my-bucket
spec:
  location: US
```

```yaml
# Good - uniform bucket level access
apiVersion: storage.cnrm.cloud.google.com/v1beta1
kind: StorageBucket
metadata:
  name: my-bucket
spec:
  location: US
  uniformBucketLevelAccess: true
```

### ❌ Hardcoded Credentials

```yaml
# Bad - password in manifest
spec:
  password:
    value: MyP@ssw0rd123
```

```yaml
# Good - secret reference
spec:
  password:
    valueFrom:
      secretKeyRef:
        name: db-password
        key: password
```

### ❌ No Backup Configuration

```yaml
# Bad - no backups
spec:
  settings:
    tier: db-custom-2-7680
```

```yaml
# Good - automated backups
spec:
  settings:
    tier: db-custom-2-7680
    backupConfiguration:
      enabled: true
      pointInTimeRecoveryEnabled: true
      startTime: "02:00"
```

### ❌ IPv4 Public IP for Cloud SQL

```yaml
# Bad - public IP exposed
spec:
  settings:
    ipConfiguration:
      ipv4Enabled: true
```

```yaml
# Good - private IP only
spec:
  settings:
    ipConfiguration:
      ipv4Enabled: false
      privateNetworkRef:
        name: production-vpc
      requireSsl: true
```

### ❌ No Resource Labels

```yaml
# Bad - no labels for cost tracking
metadata:
  name: my-bucket
spec:
  location: US
```

```yaml
# Good - comprehensive labels
metadata:
  name: my-bucket
  labels:
    environment: production
    cost-center: engineering
    team: backend
spec:
  location: US
  labels:
    managed-by: config-connector
    project: customer-portal
```

## GitOps Integration

### Argo CD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gcp-resources
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/k8s-manifests
    targetRevision: main
    path: gcp-resources
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: false  # Don't auto-delete GCP resources
      selfHeal: true
```

### Flux Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: gcp-resources
  namespace: flux-system
spec:
  interval: 10m
  path: ./gcp-resources
  prune: false  # Don't auto-delete GCP resources
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
  - apiVersion: storage.cnrm.cloud.google.com/v1beta1
    kind: StorageBucket
    name: prod-app-data-bucket
    namespace: production
```

## Validation Commands

```bash
# Check Config Connector installation
kubectl get crds | grep cnrm.cloud.google.com
kubectl get pods -n cnrm-system

# List GCP resources
kubectl get storagebuckets
kubectl get sqlinstances
kubectl get pubsubtopics
kubectl get computenetworks

# Check resource status
kubectl describe storagebucket prod-app-data-bucket
kubectl get storagebucket prod-app-data-bucket -o yaml

# View status conditions
kubectl get storagebucket prod-app-data-bucket -o jsonpath='{.status.conditions}'

# Check for errors
kubectl get events -n production --field-selector type=Warning

# Validate before apply
kubectl apply --dry-run=server -f storage-bucket.yaml

# Monitor controller logs
kubectl logs -n cnrm-system -l cnrm.cloud.google.com/component=cnrm-controller-manager -f

# Check reconciliation status
kubectl get storagebucket prod-app-data-bucket -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

## Additional Resources

- [Config Connector Documentation](https://cloud.google.com/config-connector/docs/overview)
- [Supported Resources](https://cloud.google.com/config-connector/docs/reference/overview)
- [Config Connector GitHub](https://github.com/GoogleCloudPlatform/k8s-config-connector)
- [Authentication Guide](https://cloud.google.com/config-connector/docs/how-to/install-upgrade-uninstall)
- [Best Practices](https://cloud.google.com/config-connector/docs/how-to/managing-resources-with-config-connector)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
