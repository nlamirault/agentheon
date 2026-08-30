# Kubernetes Architect Reference Index

This index provides a complete overview of all reference files, asset templates, and when to use each resource.

## Reference Files

### Core Kubernetes

| Reference | Lines | When to Use | Content |
|-----------|-------|-------------|---------|
| `best-practices.md` | 193 | Any Kubernetes resource creation | Production best practices, resource limits, health checks, recommended labels, anti-patterns, validation commands |
| `naming.md` | 628 | Naming resources and labels | Naming conventions for all resource types, standard labels (app.kubernetes.io/*), annotation patterns, anti-patterns |
| `security.md` | 399 | Security hardening and RBAC | Pod Security Standards (Privileged/Baseline/Restricted), security contexts, RBAC best practices, NetworkPolicy, secrets management |
| `networking.md` | 713 | Network configuration and traffic management | Gateway API (HTTPRoute, traffic splitting, header routing), legacy Ingress, Services (ClusterIP/LoadBalancer), NetworkPolicy, DNS |
| `reliability.md` | 260+ | Zero-downtime deployments, HA patterns, and pod scheduling resiliency | Rolling update strategy (maxUnavailable: 0), readiness probes as traffic gatekeeper, graceful shutdown with preStop sleep, PodDisruptionBudgets (unhealthyPodEvictionPolicy, CA interaction), topology spread constraints (zone/node spread, minDomains), node assignment (nodeAffinity, podAntiAffinity, taints/tolerations) |

### Tools and Frameworks

| Reference | Lines | When to Use | Content |
|-----------|-------|-------------|---------|
| `helm.md` | 563 | Helm chart development | Chart structure, Chart.yaml, values.yaml design, template helpers (_helpers.tpl), templating best practices, multi-environment values, dependencies, secrets management, validation |
| `crds.md` | 821 | Custom resource design | CRD structure with OpenAPI v3 schema, advanced validation with CEL, version management, conversion webhooks, subresources (status/scale), controller patterns, RBAC for CRDs |
| `gitops.md` | 914 | GitOps workflows and CD | Argo CD (Applications, sync policies, hooks), Flux (GitRepository, Kustomization, HelmRelease), multi-cluster, progressive delivery, secrets management, troubleshooting |
| `istio.md` | 806 | Service mesh and traffic management | Istio installation, Gateway, VirtualService, DestinationRule, traffic splitting, circuit breakers, mTLS, AuthorizationPolicy, JWT validation, observability |
| `opentelemetry.md` | 800+ | Observability and distributed tracing | OpenTelemetry Operator, auto-instrumentation (Java/Python/Node.js/.NET/Go), resource attributes with annotations, collector deployment patterns, RBAC, sampling configuration, troubleshooting |

### Cloud Provider Integration

| Reference | Lines | When to Use | Content |
|-----------|-------|-------------|---------|
| `ack.md` | 480 | AWS resource management from Kubernetes | AWS Controllers for Kubernetes, EKS Pod Identity authentication, S3, DynamoDB, RDS, EC2, ElastiCache examples, lifecycle management, monitoring, GitOps integration |
| `aso.md` | 670 | Azure resource management from Kubernetes | Azure Service Operator, Workload Identity, Storage Accounts, Azure SQL, Cosmos DB, Key Vault, Redis Cache, Virtual Networks, Managed Identity, GitOps integration |
| `kcc.md` | 681 | GCP resource management from Kubernetes | Google Cloud Config Connector, Workload Identity, GCS, Cloud SQL, Pub/Sub, Cloud KMS, VPC/Firewall, IAM, monitoring, GitOps integration |
| `kro.md` | 839 | Custom operators and resource composition | Kubernetes Resource Orchestrator, ResourceGroup creation, composition patterns (web apps with databases, microservices), conditional resources, environment-specific configuration |

## Quick Decision Guide

**I need to:**

### Create Resources

- Create a Deployment → `best-practices.md`, `security.md`, `naming.md`
- Name resources properly → `naming.md`
- Configure networking → `networking.md`
- Set up Ingress/Gateway → `networking.md` (prefer Gateway API)
- Apply security contexts → `security.md`
- Create RBAC policies → `security.md`
- Ensure zero-downtime rollouts → `reliability.md`
- Protect against node drains / cluster upgrades → `reliability.md`
- Spread pods across zones for AZ resiliency → `reliability.md`
- Prevent pod co-location on same node → `reliability.md`
- Dedicate nodes to specific workloads (GPU, spot) → `reliability.md`
- Control pod scheduling placement (affinity, taints) → `reliability.md`

### Tools and Frameworks

- Develop a Helm chart → `helm.md`
- Design a CRD → `crds.md`
- Set up GitOps with Argo CD → `gitops.md`
- Set up GitOps with Flux → `gitops.md`
- Configure service mesh → `istio.md`
- Set up observability and distributed tracing → `opentelemetry.md`
- Enable auto-instrumentation → `opentelemetry.md`

### Cloud Integration

- Integrate with AWS (S3, RDS, etc.) → `ack.md`
- Integrate with Azure (Storage, SQL, etc.) → `aso.md`
- Integrate with GCP (GCS, Cloud SQL, etc.) → `kcc.md`
- Build custom operators → `kro.md`

### Review and Validation

- Review security posture → `security.md`
- Validate names and labels → `naming.md`
- Check best practices compliance → `best-practices.md`
- Review network policies → `networking.md`, `security.md`

## Reference File Details

### best-practices.md (193 lines)

**Core focus:** Production-ready Kubernetes manifests

**Key sections:**

- Mandatory configuration (health probes, resource limits, imagePullPolicy)
- Configuration to avoid (latest tag, missing securityContext, hostPath)
- Recommended practices (namespace scoping, NetworkPolicy, RollingUpdate)
- Kubernetes recommended labels (app.kubernetes.io/*)
- Label placement and validation
- Anti-patterns with examples
- Validation commands

**Use when:** Creating any Kubernetes resource, reviewing existing manifests

### naming.md (628 lines)

**Core focus:** Naming conventions and labeling standards

**Key sections:**

- Resource naming conventions (63 char limit, lowercase, hyphens)
- Standard labels (app.kubernetes.io/name, instance, version, component, part-of, managed-by)
- Annotations for documentation and tooling
- Naming patterns for all resource types (Deployment, Service, ConfigMap, Secret, etc.)
- Container, volume, and port naming
- ServiceAccount naming patterns
- Anti-patterns and validation

**Use when:** Naming any Kubernetes resource, setting up labeling standards

### security.md (399 lines)

**Core focus:** Security hardening and access control

**Key sections:**

- Pod Security Standards (Privileged/Baseline/Restricted) with namespace enforcement
- Security contexts (pod-level and container-level) with examples
- RBAC best practices (least privilege, avoid ClusterRole, explicit ServiceAccount)
- NetworkPolicy patterns (default deny, allow specific traffic, cross-namespace)
- Secrets management (External Secrets Operator, never hardcode)
- Anti-patterns (running as root, privileged containers, wildcard RBAC)
- Security scanning and compliance

**Use when:** Implementing security, creating RBAC policies, applying Pod Security Standards

### reliability.md (260+ lines)

**Core focus:** Zero-downtime deployments, high availability, and pod scheduling resiliency

**Key sections:**

- Rolling update strategy: `maxUnavailable: 0` + `maxSurge: 1` with explanation of why both are needed
- Readiness probe as the real traffic gatekeeper (vs liveness probe distinction)
- Graceful shutdown: `terminationGracePeriodSeconds`, `preStop` sleep for kube-proxy drain, SIGTERM handling
- Zero-downtime checklist (5 concerns mapped to solutions)
- Service mesh note: Istio/Linkerd sidecar draining context
- PodDisruptionBudget: `minAvailable` vs `maxUnavailable`, `unhealthyPodEvictionPolicy`, Cluster Autoscaler interaction
- Topology Spread Constraints: zone/node spread, `maxSkew`, `whenUnsatisfiable`, `minDomains`, `nodeAffinityPolicy`
- Node Assignment: `nodeSelector`, node affinity (required vs preferred), pod anti-affinity for co-location prevention,
  taints and tolerations for node dedication, scheduling decision hierarchy

**Use when:** Designing zero-downtime rollouts, protecting workloads during node drains, configuring PodDisruptionBudgets,
spreading pods across availability zones, preventing pod co-location, dedicating nodes to specific workloads

### networking.md (713 lines)

**Core focus:** Kubernetes networking and traffic management

**Key sections:**

- Gateway API (recommended) - Gateway, HTTPRoute with canary, header-based routing, request modification
- Legacy Ingress deprecation path with migration examples
- Service types (ClusterIP, LoadBalancer, NodePort, Headless)
- NetworkPolicy patterns (default deny, allow specific traffic, cross-namespace, DNS/HTTPS egress)
- DNS and service discovery
- External traffic management (ExternalName, Service Endpoints)
- Anti-patterns and validation commands

**Use when:** Configuring networking, setting up ingress/gateway, implementing NetworkPolicies

### helm.md (563 lines)

**Core focus:** Helm chart development and best practices

**Key sections:**

- Chart structure (Chart.yaml, values.yaml, templates/, _helpers.tpl)
- Template helpers (name, fullname, labels, selectorLabels)
- Templating best practices (required, conditionals, range loops, checksum annotations, toYaml)
- Multi-environment values (dev/staging/prod)
- Chart dependencies (postgresql, redis configuration)
- Secrets management (External Secrets, Sealed Secrets)
- Validation (helm lint, helm template)
- Anti-patterns (hardcoded values, no helpers, missing validation)

**Use when:** Creating or maintaining Helm charts, templating Kubernetes manifests

### crds.md (821 lines)

**Core focus:** Custom Resource Definition design and implementation

**Key sections:**

- CRD structure with OpenAPI v3 schema
- Advanced validation (CEL expressions, immutability, required fields)
- Version management (v1alpha1 → v1beta1 → v1) with conversion webhooks
- Subresources (status, scale) for better controller integration
- additionalPrinterColumns for kubectl output
- Controller patterns and RBAC for CRDs
- Anti-patterns (weak validation, missing versioning, no status subresource)

**Use when:** Designing CRDs, building Kubernetes operators, versioning APIs

### gitops.md (914 lines)

**Core focus:** GitOps workflows with Argo CD and Flux

**Key sections:**

- Argo CD (Application resources, sync policies, Helm/Kustomize, App of Apps, sync hooks)
- Flux (GitRepository, Kustomization, HelmRelease, HelmRepository, image automation)
- Multi-tenancy patterns
- Repository structures (monorepo vs multi-repo)
- Secrets management (Sealed Secrets, External Secrets)
- Troubleshooting (OutOfSync, sync failures, health degraded)
- Anti-patterns (manual kubectl, secrets in Git, mixed approaches)

**Use when:** Setting up GitOps, deploying with Argo CD or Flux, automating deployments

### istio.md (806 lines)

**Core focus:** Istio service mesh configuration and management

**Key sections:**

- Installation with IstioOperator
- Traffic management (Gateway, VirtualService with canary/mirroring, DestinationRule with circuit breakers)
- Security (PeerAuthentication for mTLS, AuthorizationPolicy, RequestAuthentication for JWT)
- Egress control (ServiceEntry, DestinationRule for external services)
- Multi-cluster mesh (east-west gateway)
- Observability (metrics, distributed tracing, access logs)
- Anti-patterns and troubleshooting

**Use when:** Configuring service mesh, managing traffic, implementing mTLS, controlling egress

### opentelemetry.md (800+ lines)

**Core focus:** OpenTelemetry observability framework for Kubernetes

**Key sections:**

- OpenTelemetry Operator installation and configuration
- Auto-instrumentation (Java, Python, Node.js, .NET, Go) with language-specific annotations
- Resource attributes configuration using pod/namespace annotations (resource-attr.opentelemetry.io/*)
- Instrumentation resource configuration (exporter, propagators, sampler)
- Collector deployment patterns (gateway, sidecar, daemonset)
- k8sattributes processor for Kubernetes metadata enrichment
- RBAC configuration for collector
- Production deployment patterns and best practices
- Troubleshooting auto-instrumentation and collector issues

**Use when:** Setting up distributed tracing, configuring auto-instrumentation, deploying collectors, adding resource
attributes for observability context

### ack.md (480 lines)

**Core focus:** AWS Controllers for Kubernetes

**Key sections:**

- Authentication with EKS Pod Identity (recommended over IRSA)
- Available controllers (S3, DynamoDB, RDS, EC2, ElastiCache) with examples
- Resource lifecycle (creation, updates, deletion with deletion policies)
- Monitoring and troubleshooting (logs, status conditions, common issues)
- Multi-tenancy and resource organization
- GitOps integration (Argo CD, Flux)
- Testing and validation

**Use when:** Managing AWS resources from Kubernetes, integrating EKS with AWS services

### aso.md (670 lines)

**Core focus:** Azure Service Operator

**Key sections:**

- Authentication (Workload Identity recommended, Service Principal)
- Resource examples (Storage Accounts, Azure SQL, Cosmos DB, Key Vault, Redis Cache)
- Virtual Networks and Managed Identity
- Resource lifecycle and status management
- Secret management (Key Vault integration, Kubernetes Secrets)
- GitOps integration
- Anti-patterns and troubleshooting

**Use when:** Managing Azure resources from Kubernetes, integrating AKS with Azure services

### kcc.md (681 lines)

**Core focus:** Google Cloud Config Connector

**Key sections:**

- Authentication with Workload Identity
- Resource examples (GCS buckets, Cloud SQL, Pub/Sub, Cloud KMS)
- Networking (VPC, Firewall rules)
- IAM (ServiceAccount, IAMPolicy, IAMPolicyMember)
- Monitoring and alerting (Log Metrics, Alert Policies)
- Resource lifecycle and dependencies
- GitOps integration
- Anti-patterns and troubleshooting

**Use when:** Managing GCP resources from Kubernetes, integrating GKE with Google Cloud services

### kro.md (839 lines)

**Core focus:** Kubernetes Resource Orchestrator

**Key sections:**

- ResourceGroup CRD (defining compositions of resources)
- Schema definition (input parameters, resources, exports)
- Advanced patterns (web app with database, microservices platform)
- Conditional resources based on environment
- Expressions and references
- Controller and reconciliation
- Anti-patterns (over-abstraction, tight coupling, missing validation)

**Use when:** Building custom operators, composing multiple resources, creating platform abstractions

## Asset Templates

Production-ready YAML examples in `assets/`:

| Asset | Description | Use Case |
|-------|-------------|----------|
| `deployment-example.yaml` | Production-ready Deployment with security contexts, health probes, resource limits, topology spread, recommended labels | Starting point for new Deployments |
| `service-example.yaml` | Service types and patterns (ClusterIP, LoadBalancer, NodePort, Headless) | Creating Services |
| `ingress-example.yaml` | Multi-controller Ingress with TLS, security headers, annotations | Legacy Ingress configuration |
| `networkpolicy-example.yaml` | Zero-trust NetworkPolicy patterns (default deny, allow specific traffic) | Implementing network isolation |
| `rbac-example.yaml` | RBAC roles, bindings, least privilege patterns, ServiceAccount | Setting up access control |
| `helm-values-example.yaml` | Comprehensive Helm values for multi-environment deployments | Helm chart configuration |
| `pdb-example.yaml` | PodDisruptionBudget with minAvailable (active) and maxUnavailable (commented) variants | Protecting workloads during node drains and cluster upgrades |

## Usage Patterns

### Starting a New Application

1. **Design phase:** Consult `best-practices.md`, `security.md`, `naming.md`
2. **Create manifests:** Use `assets/deployment-example.yaml` as template
3. **Add networking:** Follow `networking.md` for Services and Gateway/Ingress
4. **Security hardening:** Apply patterns from `security.md`
5. **Reliability:** Configure zero-downtime rollouts and PDB from `reliability.md`
6. **Package with Helm:** Follow `helm.md` for chart structure
7. **Set up GitOps:** Use `gitops.md` for Argo CD or Flux

### Cloud Integration

**AWS:**

1. Read `ack.md` for controller setup
2. Configure EKS Pod Identity
3. Create ACK resources (S3, RDS, etc.)
4. Integrate with GitOps

**Azure:**

1. Read `aso.md` for operator setup
2. Configure Workload Identity
3. Create ASO resources (Storage, SQL, etc.)
4. Integrate with GitOps

**GCP:**

1. Read `kcc.md` for Config Connector setup
2. Configure Workload Identity
3. Create KCC resources (GCS, Cloud SQL, etc.)
4. Integrate with GitOps

### Building Custom Operators

1. **Design CRD:** Follow `crds.md` for schema, validation, versioning
2. **Implement controller:** Use patterns from `kro.md`
3. **Set up RBAC:** Apply patterns from `security.md`
4. **Test and validate:** Use validation commands from relevant references

### Service Mesh Adoption

1. **Install Istio:** Follow `istio.md` installation guide
2. **Enable sidecar injection:** Configure namespace labels
3. **Configure traffic management:** VirtualService, DestinationRule
4. **Enable mTLS:** PeerAuthentication policies
5. **Set up authorization:** AuthorizationPolicy patterns
6. **Monitor:** Integrate with observability tools

## Validation Strategy

### Pre-Deployment

1. Lint manifests: `kubectl apply --dry-run=client`
2. Server-side validation: `kubectl apply --dry-run=server`
3. Security scanning: `kubesec scan` or `checkov`
4. Helm validation: `helm lint`, `helm template`

### Post-Deployment

1. Verify resources: `kubectl get`, `kubectl describe`
2. Check logs: `kubectl logs`
3. Validate networking: Test service connectivity
4. Security audit: Review RBAC, NetworkPolicies

### Continuous Monitoring

1. GitOps sync status (Argo CD/Flux)
2. Resource health checks
3. Security compliance scanning
4. Cost optimization reviews

## Progressive Disclosure

This index enables **progressive disclosure** of Kubernetes knowledge:

**Level 1 (Always loaded):** SKILL.md with core guidance and pointers
**Level 2 (Loaded as needed):** Reference files for specific domains
**Level 3 (Loaded by Claude):** Detailed examples and patterns within references

This three-tier approach keeps context usage efficient while providing comprehensive guidance when needed.

## Additional Resources

### Official Documentation

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Flux Documentation](https://fluxcd.io/docs/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Gateway API](https://gateway-api.sigs.k8s.io/)

### Cloud Provider Resources

- [AWS Controllers for Kubernetes](https://aws-controllers-k8s.github.io/community/)
- [Azure Service Operator](https://azure.github.io/azure-service-operator/)
- [Google Cloud Config Connector](https://cloud.google.com/config-connector/docs)

### Tools and Utilities

- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [kustomize](https://kustomize.io/)
- [kubesec](https://kubesec.io/)
- [Artifact Hub](https://artifacthub.io/)
