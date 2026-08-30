# Kubernetes / Azure Service Operator (ASO)

This reference provides comprehensive guidance for using Azure Service Operator to manage Azure resources declaratively
from Kubernetes, including authentication, resource provisioning, and best practices.

## Overview

Azure Service Operator (ASO) enables management of Azure resources using Kubernetes custom resources. It provides a
declarative way to provision and configure Azure services directly from Kubernetes manifests.

## Installation

### Cert-Manager Prerequisite

```bash
# Install cert-manager (required for ASO)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Verify cert-manager
kubectl wait --for=condition=Available --timeout=300s -n cert-manager deployment/cert-manager
```

### Install ASO with Helm

```bash
# Add Helm repository
helm repo add aso https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo update

# Create namespace
kubectl create namespace azureserviceoperator-system

# Install ASO
helm install aso aso/azure-service-operator \
  --namespace azureserviceoperator-system \
  --set azureSubscriptionID=<subscription-id> \
  --set azureTenantID=<tenant-id> \
  --set azureClientID=<client-id> \
  --set azureClientSecret=<client-secret>

# Verify installation
kubectl get pods -n azureserviceoperator-system
kubectl get crds | grep azure.com
```

## Authentication

### Workload Identity (Recommended)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aso-controller
  namespace: azureserviceoperator-system
  annotations:
    azure.workload.identity/client-id: <client-id>
    azure.workload.identity/tenant-id: <tenant-id>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azureserviceoperator-controller-manager
  namespace: azureserviceoperator-system
spec:
  template:
    metadata:
      labels:
        azure.workload.identity/use: "true"
    spec:
      serviceAccountName: aso-controller
```

### Service Principal

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: aso-credentials
  namespace: azureserviceoperator-system
type: Opaque
stringData:
  AZURE_SUBSCRIPTION_ID: "<subscription-id>"
  AZURE_TENANT_ID: "<tenant-id>"
  AZURE_CLIENT_ID: "<client-id>"
  AZURE_CLIENT_SECRET: "<client-secret>"
```

## Resource Groups

```yaml
apiVersion: resources.azure.com/v1api20200601
kind: ResourceGroup
metadata:
  name: production-rg
  namespace: production
spec:
  location: eastus
  tags:
    environment: production
    managed-by: aso
    cost-center: engineering
```

## Storage Accounts

### Basic Storage Account

```yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: prodappstorage001
  namespace: production
spec:
  location: eastus
  kind: StorageV2
  sku:
    name: Standard_LRS
  owner:
    name: production-rg
  properties:
    minimumTlsVersion: TLS1_2
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    encryption:
      services:
        blob:
          enabled: true
        file:
          enabled: true
      keySource: Microsoft.Storage
    networkAcls:
      defaultAction: Deny
      bypass: AzureServices
      ipRules:
      - value: 203.0.113.0/24
        action: Allow
```

### Storage Account with Containers

```yaml
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: prodappstorage002
  namespace: production
spec:
  location: eastus
  kind: StorageV2
  sku:
    name: Standard_GRS
  owner:
    name: production-rg
---
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccountsBlobService
metadata:
  name: prodappstorage002-default
  namespace: production
spec:
  owner:
    name: prodappstorage002
  properties:
    deleteRetentionPolicy:
      enabled: true
      days: 30
---
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccountsBlobServicesContainer
metadata:
  name: application-data
  namespace: production
spec:
  owner:
    name: prodappstorage002-default
  properties:
    publicAccess: None
```

## Azure SQL Database

### SQL Server

```yaml
apiVersion: sql.azure.com/v1api20211101
kind: Server
metadata:
  name: prod-sql-server-001
  namespace: production
spec:
  location: eastus
  owner:
    name: production-rg
  properties:
    administratorLogin: sqladmin
    administratorLoginPassword:
      name: sql-admin-password
      key: password
    version: "12.0"
    minimalTlsVersion: "1.2"
    publicNetworkAccess: Disabled
  azureADOnlyAuthentication: true
```

### SQL Database

```yaml
apiVersion: sql.azure.com/v1api20211101
kind: ServersDatabase
metadata:
  name: production-app-db
  namespace: production
spec:
  location: eastus
  owner:
    name: prod-sql-server-001
  sku:
    name: S3
    tier: Standard
  properties:
    collation: SQL_Latin1_General_CP1_CI_AS
    maxSizeBytes: 268435456000  # 250 GB
    catalogCollation: SQL_Latin1_General_CP1_CI_AS
    zoneRedundant: true
    readScale: Enabled
    storageAccountType: GRS
```

### Firewall Rules

```yaml
apiVersion: sql.azure.com/v1api20211101
kind: ServersFirewallRule
metadata:
  name: allow-azure-services
  namespace: production
spec:
  owner:
    name: prod-sql-server-001
  properties:
    startIpAddress: 0.0.0.0
    endIpAddress: 0.0.0.0
---
apiVersion: sql.azure.com/v1api20211101
kind: ServersFirewallRule
metadata:
  name: allow-office-network
  namespace: production
spec:
  owner:
    name: prod-sql-server-001
  properties:
    startIpAddress: 203.0.113.0
    endIpAddress: 203.0.113.255
```

## Azure Cosmos DB

```yaml
apiVersion: documentdb.azure.com/v1api20231115
kind: DatabaseAccount
metadata:
  name: prod-cosmos-account
  namespace: production
spec:
  location: eastus
  owner:
    name: production-rg
  kind: GlobalDocumentDB
  properties:
    databaseAccountOfferType: Standard
    locations:
    - locationName: eastus
      failoverPriority: 0
      isZoneRedundant: true
    - locationName: westus
      failoverPriority: 1
      isZoneRedundant: true
    consistencyPolicy:
      defaultConsistencyLevel: Session
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    enableAutomaticFailover: true
    enableMultipleWriteLocations: false
    publicNetworkAccess: Disabled
    capabilities:
    - name: EnableServerless
```

## Azure Key Vault

```yaml
apiVersion: keyvault.azure.com/v1api20230701
kind: Vault
metadata:
  name: prod-app-kv-001
  namespace: production
spec:
  location: eastus
  owner:
    name: production-rg
  properties:
    sku:
      family: A
      name: standard
    tenantId: <tenant-id>
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true
    networkAcls:
      defaultAction: Deny
      bypass: AzureServices
      ipRules:
      - value: 203.0.113.0/24
```

## Azure Cache for Redis

```yaml
apiVersion: cache.azure.com/v1api20230801
kind: Redis
metadata:
  name: prod-redis-cache
  namespace: production
spec:
  location: eastus
  owner:
    name: production-rg
  properties:
    sku:
      name: Premium
      family: P
      capacity: 1
    enableNonSslPort: false
    minimumTlsVersion: "1.2"
    publicNetworkAccess: Disabled
    redisConfiguration:
      maxmemory-policy: allkeys-lru
    redisVersion: "6"
  zones:
  - "1"
  - "2"
```

## Virtual Networks

```yaml
apiVersion: network.azure.com/v1api20201101
kind: VirtualNetwork
metadata:
  name: prod-vnet
  namespace: production
spec:
  location: eastus
  owner:
    name: production-rg
  properties:
    addressSpace:
      addressPrefixes:
      - 10.0.0.0/16
    subnets:
    - name: aks-subnet
      properties:
        addressPrefix: 10.0.1.0/24
    - name: database-subnet
      properties:
        addressPrefix: 10.0.2.0/24
        serviceEndpoints:
        - service: Microsoft.Sql
        - service: Microsoft.Storage
    - name: private-endpoints-subnet
      properties:
        addressPrefix: 10.0.3.0/24
        privateEndpointNetworkPolicies: Disabled
```

## Managed Identity Integration

```yaml
apiVersion: managedidentity.azure.com/v1api20230131
kind: UserAssignedIdentity
metadata:
  name: prod-app-identity
  namespace: production
spec:
  location: eastus
  owner:
    name: production-rg
---
# Use identity in pod
apiVersion: v1
kind: Pod
metadata:
  name: app
  namespace: production
  labels:
    aadpodidbinding: prod-app-identity
spec:
  containers:
  - name: app
    image: myapp:latest
    env:
    - name: AZURE_CLIENT_ID
      value: <identity-client-id>
```

## Secret Management

### Reference Azure Key Vault Secret

```yaml
apiVersion: keyvault.azure.com/v1api20230701
kind: VaultsSecret
metadata:
  name: database-password
  namespace: production
spec:
  owner:
    name: prod-app-kv-001
  properties:
    value: <secret-value>
---
# Create Kubernetes Secret from ASO resource
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: production
type: Opaque
data:
  db-password: <base64-encoded-reference>
```

### Using operatorSpec for Secret Export

```yaml
apiVersion: sql.azure.com/v1api20211101
kind: ServersDatabase
metadata:
  name: production-app-db
  namespace: production
spec:
  location: eastus
  owner:
    name: prod-sql-server-001
  operatorSpec:
    secrets:
      fullyQualifiedDomainName:
        name: db-connection
        key: fqdn
```

## Common Anti-Patterns

### ❌ Missing Owner References

```yaml
# Bad - no owner reference
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorage
spec:
  location: eastus
```

```yaml
# Good - explicit owner
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorage
spec:
  location: eastus
  owner:
    name: production-rg
```

### ❌ Hardcoded Credentials

```yaml
# Bad - plaintext secret
spec:
  administratorLoginPassword: MyP@ssw0rd123
```

```yaml
# Good - secret reference
spec:
  administratorLoginPassword:
    name: sql-admin-password
    key: password
```

### ❌ Public Access Enabled

```yaml
# Bad - public access allowed
spec:
  properties:
    publicNetworkAccess: Enabled
    allowBlobPublicAccess: true
```

```yaml
# Good - private access only
spec:
  properties:
    publicNetworkAccess: Disabled
    allowBlobPublicAccess: false
    networkAcls:
      defaultAction: Deny
```

### ❌ No Backup Configuration

```yaml
# Bad - no backup/retention policy
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccount
metadata:
  name: mystorage
```

```yaml
# Good - backup and retention configured
apiVersion: storage.azure.com/v1api20230101
kind: StorageAccountsBlobService
spec:
  properties:
    deleteRetentionPolicy:
      enabled: true
      days: 30
    containerDeleteRetentionPolicy:
      enabled: true
      days: 7
```

### ❌ Weak TLS Version

```yaml
# Bad - old TLS version
spec:
  properties:
    minimumTlsVersion: TLS1_0
```

```yaml
# Good - modern TLS version
spec:
  properties:
    minimumTlsVersion: TLS1_2
```

### ❌ No Resource Tags

```yaml
# Bad - no tags for cost tracking
metadata:
  name: production-rg
spec:
  location: eastus
```

```yaml
# Good - comprehensive tags
metadata:
  name: production-rg
spec:
  location: eastus
  tags:
    environment: production
    cost-center: engineering
    project: customer-portal
    managed-by: aso
    owner: platform-team
```

## GitOps Integration

### Argo CD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: azure-resources
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/k8s-manifests
    targetRevision: main
    path: azure-resources
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: false  # Don't auto-delete Azure resources
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### Flux Kustomization

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: azure-resources
  namespace: flux-system
spec:
  interval: 10m
  path: ./azure-resources
  prune: false  # Don't auto-delete Azure resources
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
  - apiVersion: storage.azure.com/v1api20230101
    kind: StorageAccount
    name: prodappstorage001
    namespace: production
```

## Validation Commands

```bash
# Check ASO installation
kubectl get pods -n azureserviceoperator-system
kubectl get crds | grep azure.com

# List Azure resources
kubectl get resourcegroups
kubectl get storageaccounts
kubectl get servers  # SQL servers
kubectl get vaults   # Key Vaults

# Check resource status
kubectl describe storageaccount prodappstorage001
kubectl get storageaccount prodappstorage001 -o yaml

# Check for errors
kubectl get events -n production --field-selector type=Warning

# Validate before apply
kubectl apply --dry-run=server -f storage-account.yaml

# Monitor reconciliation
kubectl logs -n azureserviceoperator-system -l app.kubernetes.io/name=azure-service-operator -f

# Check Azure resource provisioning status
kubectl get storageaccount prodappstorage001 -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

## Additional Resources

- [Azure Service Operator Documentation](https://azure.github.io/azure-service-operator/)
- [ASO v2 Supported Resources](https://azure.github.io/azure-service-operator/reference/)
- [ASO GitHub Repository](https://github.com/Azure/azure-service-operator)
- [Authentication Guide](https://azure.github.io/azure-service-operator/guide/authentication/)
- [Best Practices](https://azure.github.io/azure-service-operator/guide/best-practices/)
- [Azure Workload Identity](https://azure.github.io/azure-workload-identity/)
