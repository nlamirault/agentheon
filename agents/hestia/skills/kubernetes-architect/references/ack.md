# Kubernetes / AWS Controllers for Kubernetes (ACK)

This reference provides comprehensive guidance for AWS Controllers for Kubernetes (ACK), enabling declarative management
of AWS resources from Kubernetes.

## Overview

ACK lets you define and use AWS service resources directly from Kubernetes, using Kubernetes CRDs. Instead of managing
AWS resources through the AWS console or Terraform, you can manage them as Kubernetes objects.

## Core Validation Requirements

### Resource Specifications

Validate:

- Proper resource specifications for ACK-managed AWS services (e.g., S3Bucket, DynamoDBTable)
- Confirm AWS IAM permissions and roles associated with ACK controllers

### Best Practices

Recommend:

- Using tags and labels for resource tracking and cost allocation
- Defining `spec.forProvider` fields explicitly for idempotent resources
- Using Kubernetes-native Secrets for AWS credentials securely

### Validation Warnings

Warn if:

- Resource specs omit required properties or use deprecated fields
- Conflicts arise between ACK resources and existing AWS infrastructure

## Authentication and Authorization

### EKS Pod Identity (Recommended)

**Enforce:** Use **EKS Pod Identity** for ACK controller authentication instead of IRSA (IAM Roles for Service
Accounts).

EKS Pod Identity is the modern, simplified approach for granting AWS permissions to Kubernetes workloads:

**Benefits over IRSA:**

- Simpler configuration without OIDC provider setup
- Automatic credential rotation
- Better scalability across multiple clusters
- Reduced operational overhead
- Native AWS IAM integration

**Configuration Example:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ack-s3-controller
  namespace: ack-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/ack-s3-controller-role
```

**Required AWS IAM Trust Policy for Pod Identity:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
```

### IRSA (Legacy)

**Warn if:** Using IRSA for new ACK deployments. IRSA is the legacy approach and should be replaced with EKS Pod
Identity for new implementations.

IRSA requires additional OIDC provider configuration and is more complex to manage at scale. While still supported, it
is no longer the recommended approach.

## Best Practices

- **Least Privilege:** Grant ACK controllers only the minimum IAM permissions required for the AWS resources they manage
- **Namespace Isolation:** Deploy ACK controllers in dedicated namespaces (e.g., `ack-system`)
- **Resource Tags:** Always tag ACK-managed AWS resources with Kubernetes metadata for tracking
- **Version Pinning:** Pin ACK controller versions in production to prevent unexpected changes
- **Monitoring:** Enable CloudWatch logging and metrics for ACK controllers

## Available ACK Controllers

Common ACK controllers and their resources:

### S3 Controller

Manage S3 buckets and objects:

```yaml
apiVersion: s3.services.k8s.aws/v1alpha1
kind: Bucket
metadata:
  name: my-app-bucket
  namespace: production
spec:
  name: my-company-app-bucket-prod
  versioning:
    status: Enabled
  encryption:
    rules:
    - applyServerSideEncryptionByDefault:
        sseAlgorithm: AES256
  tags:
  - key: Environment
    value: production
  - key: ManagedBy
    value: ack
```

### DynamoDB Controller

Manage DynamoDB tables:

```yaml
apiVersion: dynamodb.services.k8s.aws/v1alpha1
kind: Table
metadata:
  name: users-table
  namespace: production
spec:
  tableName: users
  attributeDefinitions:
  - attributeName: userId
    attributeType: S
  keySchema:
  - attributeName: userId
    keyType: HASH
  billingMode: PAY_PER_REQUEST
  sseSpecification:
    enabled: true
  tags:
  - key: Environment
    value: production
```

### RDS Controller

Manage RDS databases:

```yaml
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBInstance
metadata:
  name: postgres-db
  namespace: production
spec:
  allocatedStorage: 20
  dbInstanceClass: db.t3.micro
  dbInstanceIdentifier: app-postgres-prod
  engine: postgres
  engineVersion: "15.3"
  masterUsername: admin
  masterUserPassword:
    namespace: production
    name: db-master-password
    key: password
  vpcSecurityGroupIDs:
  - sg-0123456789abcdef
  dbSubnetGroupName: prod-db-subnet-group
  backupRetentionPeriod: 7
  storageEncrypted: true
  tags:
  - key: Environment
    value: production
```

### EC2 Controller

Manage EC2 resources (VPCs, security groups, etc.):

```yaml
apiVersion: ec2.services.k8s.aws/v1alpha1
kind: SecurityGroup
metadata:
  name: app-sg
  namespace: production
spec:
  name: app-security-group
  description: Security group for application
  vpcID: vpc-0123456789abcdef
  ingressRules:
  - ipProtocol: tcp
    fromPort: 443
    toPort: 443
    ipRanges:
    - cidrIP: 0.0.0.0/0
  tags:
  - key: Environment
    value: production
```

### ElastiCache Controller

Manage ElastiCache clusters:

```yaml
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: CacheCluster
metadata:
  name: redis-cluster
  namespace: production
spec:
  cacheClusterID: app-redis-prod
  cacheNodeType: cache.t3.micro
  engine: redis
  engineVersion: "7.0"
  numCacheNodes: 1
  cacheSubnetGroupName: prod-cache-subnet-group
  securityGroupIDs:
  - sg-0123456789abcdef
  tags:
  - key: Environment
    value: production
```

## Resource Lifecycle Management

### Creation and Status

ACK controllers reconcile Kubernetes resources to AWS:

```bash
# Create resource
kubectl apply -f s3-bucket.yaml

# Check status
kubectl get bucket my-app-bucket -o yaml

# Status conditions show AWS state
status:
  conditions:
  - type: ACK.ResourceSynced
    status: "True"
    lastTransitionTime: "2024-01-15T10:30:00Z"
  ackResourceMetadata:
    arn: arn:aws:s3:::my-company-app-bucket-prod
    ownerAccountID: "123456789012"
```

### Updates

ACK handles declarative updates:

```bash
# Update resource spec
kubectl edit bucket my-app-bucket

# ACK controller updates AWS resource
```

### Deletion

Use deletion policies to control AWS resource cleanup:

```yaml
apiVersion: s3.services.k8s.aws/v1alpha1
kind: Bucket
metadata:
  name: my-app-bucket
  annotations:
    services.k8s.aws/deletion-policy: "retain"  # or "delete"
```

**Deletion policies:**

- `delete` (default): Deletes AWS resource when Kubernetes resource is deleted
- `retain`: Keeps AWS resource when Kubernetes resource is deleted

## Monitoring and Troubleshooting

### Controller Logs

Check ACK controller logs:

```bash
# Get controller pod name
kubectl get pods -n ack-system

# View logs
kubectl logs -n ack-system ack-s3-controller-xxx

# Follow logs
kubectl logs -n ack-system ack-s3-controller-xxx -f
```

### Resource Status

Check resource conditions:

```bash
# Get detailed status
kubectl describe bucket my-app-bucket

# Check conditions
kubectl get bucket my-app-bucket -o jsonpath='{.status.conditions[*]}'
```

### Common Issues

**Problem:** Resource stuck in "Pending" state

**Solution:** Check IAM permissions and controller logs

```bash
# Check IAM role
kubectl get sa ack-s3-controller -n ack-system -o yaml

# Verify role annotation
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/ack-s3-controller-role
```

**Problem:** Permission denied errors

**Solution:** Verify IAM policy includes required permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning"
      ],
      "Resource": "*"
    }
  ]
}
```

## Multi-Tenancy and Resource Organization

### Namespace-Based Isolation

Organize resources by namespace:

```yaml
# Development namespace
apiVersion: v1
kind: Namespace
metadata:
  name: dev
  labels:
    environment: development
---
apiVersion: s3.services.k8s.aws/v1alpha1
kind: Bucket
metadata:
  name: app-bucket
  namespace: dev
spec:
  name: company-app-bucket-dev
  tags:
  - key: Environment
    value: development
```

### Cross-Namespace References

Reference secrets or configs across namespaces:

```yaml
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBInstance
metadata:
  name: db
  namespace: production
spec:
  masterUserPassword:
    namespace: secrets  # Different namespace
    name: db-password
    key: password
```

## GitOps Integration

### Argo CD Example

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aws-resources
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/k8s-manifests
    targetRevision: main
    path: ack-resources
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: false  # Don't auto-delete AWS resources
      selfHeal: true
```

### Flux Example

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: aws-resources
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/k8s-manifests
  ref:
    branch: main
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: aws-resources
  namespace: flux-system
spec:
  interval: 5m
  path: ./ack-resources
  prune: false  # Don't auto-delete AWS resources
  sourceRef:
    kind: GitRepository
    name: aws-resources
```

## Testing and Validation

### Dry-Run Validation

```bash
# Validate resource before creation
kubectl apply --dry-run=client -f s3-bucket.yaml

# Server-side validation
kubectl apply --dry-run=server -f s3-bucket.yaml
```

### Integration Testing

Test ACK resource creation:

```bash
#!/bin/bash
# Test S3 bucket creation

# Apply resource
kubectl apply -f s3-bucket.yaml

# Wait for ready
kubectl wait --for=condition=ACK.ResourceSynced bucket/my-app-bucket --timeout=300s

# Verify in AWS
aws s3 ls | grep my-company-app-bucket-prod

# Cleanup
kubectl delete -f s3-bucket.yaml
```

## Additional Resources

- [ACK Documentation](https://aws-controllers-k8s.github.io/community/)
- [ACK Service Controllers](https://github.com/aws-controllers-k8s)
- [EKS Pod Identity Guide](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html)
- [ACK Best Practices](https://aws-controllers-k8s.github.io/community/docs/user-docs/best-practices/)
