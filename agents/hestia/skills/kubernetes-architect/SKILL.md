---
name: kubernetes-architect
description: Comprehensive Kubernetes and Helm expertise for cloud-native architecture, including deployments, networking, security, reliability (zero-downtime deployments, PodDisruptionBudgets, topology spread constraints, node affinity, pod anti-affinity, taints/tolerations), service mesh (Istio), GitOps workflows, and cloud provider integrations (AWS ACK, Azure ASO, GCP Config Connector). Covers production best practices, manifest creation/validation, Helm chart development, RBAC, network policies, and CRD design for Kubernetes 1.29+.
license: Apache-2.0
compatibility: Requires kubectl and helm CLI tools for manifest validation. Network access needed for cloud provider operator integrations.
allowed-tools: Bash(kubectl:*) Bash(helm:*) Bash(docker:*) Bash(git:*) Read Write Edit Grep Glob
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - kubernetes
  - helm
  task: [configure, review, deploy]
  persona: [platform-engineer, devops]
  workload: [platform]
---

# Kubernetes Architect Skill

This skill provides comprehensive Kubernetes and Helm expertise across the entire cloud-native ecosystem. Use this skill
for guidance on Kubernetes deployments, networking, security, service mesh, GitOps, and cloud provider integrations.

## Core Knowledge Areas

This skill encompasses Kubernetes knowledge across multiple domains, organized as reference files for progressive
disclosure:

### Kubernetes Best Practices

@references/best-practices.md

Core Kubernetes best practices for production workloads including resource limits, health checks, deployment strategies,
and recommended labels.

### Naming Conventions

@references/naming.md

Resource naming standards and labeling best practices for Kubernetes objects.

### Security

@references/security.md

Security hardening, RBAC, Pod Security Standards, and access control patterns.

### Networking

@references/networking.md

Networking concepts, Gateway API, Ingress patterns, and service communication.

### Helm Charts

@references/helm.md

Helm chart development, templating best practices, and package management.

### Custom Resource Definitions

@references/crds.md

Custom Resource Definition design, validation, and versioning strategies.

### GitOps

@references/gitops.md

GitOps workflows with Argo CD and Flux for continuous deployment.

### Service Mesh - Istio

@references/istio.md

Service mesh patterns, Istio configuration, traffic management, and security policies.

### Cloud Provider Operators

#### AWS Controllers for Kubernetes (ACK)

@references/ack.md

AWS Controllers for Kubernetes integration for managing AWS resources.

#### Azure Service Operator (ASO)

@references/aso.md

Azure Service Operator patterns and usage for Azure resource management.

#### Google Cloud Config Connector (KCC)

@references/kcc.md

Google Cloud Config Connector for managing GCP resources declaratively.

### Kubernetes Resource Operator (KRO)

@references/kro.md

Kubernetes Resource Operator patterns for custom controllers.

### Reliability & Resiliency

@references/reliability.md

Zero-downtime rolling update strategies, readiness probes, graceful shutdown patterns, PodDisruptionBudgets,
topology spread constraints for AZ/node distribution, and node assignment (affinity, anti-affinity, taints/tolerations)
for scheduling control and resiliency.

---

## General Guidance

When working with Kubernetes:

- **Think holistically**: Consider how different Kubernetes resources interact and depend on each other
- **Follow cloud-native principles**: Embrace declarative configuration, immutability, and GitOps workflows
- **Prioritize security**: Apply defense in depth with RBAC, NetworkPolicies, and Pod Security Standards
- **Design for reliability**: Use health checks, resource limits, pod disruption budgets, and high availability patterns
- **Optimize for observability**: Ensure resources are properly labeled and instrumented for monitoring
- **Maintain consistency**: Follow naming conventions and labeling standards across all resources

## Kubernetes Version

Target Kubernetes version: **1.29+**

When providing guidance or examples, assume Kubernetes 1.29 or later unless otherwise specified.

---

## Working with Helm

For Helm-specific tasks:

- Consult `references/helm.md` for chart structure and templating patterns
- Use `assets/helm-values-example.yaml` as a comprehensive values template
- Follow chart versioning best practices (semantic versioning)
- Validate charts with `helm lint` and template rendering
- Consider chart dependencies and repository management

## Working with Manifests

When creating or validating Kubernetes manifests:

- Consult `references/best-practices.md` for resource configuration standards
- Use asset examples as templates for common resource types
- Validate against Kubernetes API schemas
- Apply security contexts and resource constraints
- Include appropriate labels and annotations

## Security Considerations

For all Kubernetes resources:

- Consult `references/security.md` for security hardening
- Apply least privilege RBAC policies
- Use Pod Security Standards
- Implement network policies for pod isolation
- Enable audit logging and monitoring

## Cloud Integration

When integrating with cloud providers:

- For AWS: Consult `references/ack.md` for ACK controller usage
- For Azure: Consult `references/aso.md` for Azure Service Operator patterns
- For GCP: Consult `references/kcc.md` for Config Connector usage
- Follow cloud-specific best practices for IAM, networking, and storage

---

## Scripted Validation

Use the bundled script to catch manifest issues before deploying:

```bash
python3 ${CLAUDE_SKILL_ROOT}/scripts/validate_manifest.py <manifest.yaml>
python3 ${CLAUDE_SKILL_ROOT}/scripts/validate_manifest.py k8s/           # scan a directory
```

The script checks for: missing resource limits (memory/CPU), missing health probes (liveness/readiness), privileged
containers, running as root, unpinned `:latest` images, deprecated API versions, and missing recommended labels. Run it
on any manifest you create or modify before `kubectl apply`.

## Safety Protocol for Destructive Operations

When this skill is active, apply these guardrails for operations that can cause downtime or data loss:

**Always confirm before running:**

- `kubectl delete <anything>` — verify the resource name and namespace; check if there's a PodDisruptionBudget
- `kubectl drain <node>` — confirm the node is being decommissioned and PDBs allow eviction
- `kubectl rollout restart` on a production deployment — verify replicas > 1 and readinessProbe is configured
- Deleting a PersistentVolumeClaim — check `reclaimPolicy` (Delete vs Retain); deleted PVCs with `Delete` policy destroy
  data immediately

**Refuse and explain if:**

- `kubectl delete namespace` is attempted without explicit confirmation — this cascades to all resources in the
  namespace
- `kubectl apply --force` is used — this bypasses conflict resolution and can cause unexpected state
- Any operation targets a resource whose name contains `prod`, `production`, or `live` without the user having
  explicitly stated they intend to modify production

**Verification pattern:** Before any destructive command, run the read-only equivalent first:

```bash
kubectl get <resource> <name> -n <namespace>   # confirm resource exists and is what you think
kubectl describe <resource> <name> -n <namespace>  # check state before modifying
```

## Additional Resources

For a complete index of all references, asset templates, and detailed usage guidance:

**@references/index.md** - Comprehensive reference index

This index provides:

- Complete list of all 12 reference files with line counts and when to use each
- Quick decision guide ("I need to..." → which reference to consult)
- Detailed reference file summaries
- Asset template catalog
- Usage patterns for common scenarios (new apps, cloud integration, custom operators, service mesh)
- Validation strategy (pre-deployment, post-deployment, continuous monitoring)

### Quick Reference Summary

**Core Kubernetes:**

- `best-practices.md` (193 lines) - Production best practices, resource limits, health checks
- `naming.md` (628 lines) - Naming conventions, labels, annotations
- `security.md` (399 lines) - Pod Security Standards, RBAC, NetworkPolicy
- `networking.md` (713 lines) - Gateway API, Services, NetworkPolicy, DNS
- `reliability.md` (260+ lines) - Zero-downtime deployments, PodDisruptionBudgets, topology spread constraints, node assignment (affinity, anti-affinity, taints/tolerations)

**Tools & Frameworks:**

- `helm.md` (563 lines) - Chart development, templating, multi-environment
- `crds.md` (821 lines) - CRD design, validation, versioning, webhooks
- `gitops.md` (914 lines) - Argo CD, Flux, multi-cluster, progressive delivery
- `istio.md` (806 lines) - Service mesh, traffic management, mTLS, observability

**Cloud Integration:**

- `ack.md` (480 lines) - AWS Controllers (S3, RDS, DynamoDB, etc.)
- `aso.md` (670 lines) - Azure Service Operator (Storage, SQL, Key Vault, etc.)
- `kcc.md` (681 lines) - Google Cloud Config Connector (GCS, Cloud SQL, etc.)
- `kro.md` (839 lines) - Kubernetes Resource Orchestrator, composition patterns

### Asset Templates

Production-ready YAML examples in `assets/`:

- `deployment-example.yaml` - Secure Deployment with observability
- `service-example.yaml` - Service types and patterns
- `ingress-example.yaml` - Multi-controller Ingress with TLS
- `networkpolicy-example.yaml` - Zero-trust NetworkPolicy
- `rbac-example.yaml` - Least privilege RBAC
- `helm-values-example.yaml` - Multi-environment Helm values
- `pdb-example.yaml` - PodDisruptionBudget (minAvailable / maxUnavailable variants)
