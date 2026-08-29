# Kubernetes / Reliability & Resiliency

## Zero-Downtime Deployment Strategy

Zero-downtime requires three things working together: rolling update config, readiness probes, and graceful shutdown.
Each is necessary; none is sufficient alone.

### 1. Rolling Update Configuration

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0   # never terminate a pod before its replacement is Ready
      maxSurge: 1         # allow 1 extra pod above desired count during rollout
```

- `maxUnavailable: 0` — Kubernetes waits for the new pod to pass its readiness probe before terminating the old one
- `maxSurge: 1` — required when `maxUnavailable: 0`, otherwise the rollout deadlocks (nothing can be removed and
  capacity is full)
- Both values accept integers or percentages (e.g., `25%`). The Kubernetes default of `maxUnavailable: 25%` does **not**
  guarantee zero downtime

### 2. Readiness Probe (the real gatekeeper)

The readiness probe is the mechanism that makes `maxUnavailable: 0` meaningful. Without it, Kubernetes marks pods Ready
immediately on start, before the application is actually serving traffic.

```yaml
readinessProbe:
  httpGet:
    path: /healthz       # lightweight endpoint, no DB calls
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3    # 3 failures = 15s before pod is marked NotReady
```

Distinguish from liveness:

- **Readiness**: "Is this pod ready to receive traffic?" — gates traffic routing
- **Liveness**: "Is this pod alive?" — triggers restart if it fails

### 3. Graceful Shutdown (often forgotten)

When a pod is terminated, kube-proxy takes a few seconds to remove it from `iptables` rules. Without a shutdown delay,
in-flight requests hit the pod after it starts shutting down — even with `maxUnavailable: 0`.

```yaml
spec:
  terminationGracePeriodSeconds: 30    # must be > app shutdown time
  containers:
  - name: app
    lifecycle:
      preStop:
        exec:
          command: ["sleep", "5"]      # wait for kube-proxy to drain connections
```

The app must also handle `SIGTERM` gracefully: stop accepting new connections, finish in-flight requests, then exit
cleanly. Many frameworks (Spring Boot, Express, FastAPI, Go `http.Server`) require this to be explicitly enabled.

**Without `preStop` sleep**: pod starts shutting down → load balancer still routes traffic → dropped requests

**With `preStop` sleep**: sleep 5s → kube-proxy removes pod from routing → SIGTERM sent → app drains and exits cleanly

### Zero-Downtime Checklist

| Concern | Solution |
|---|---|
| No pod killed before replacement ready | `maxUnavailable: 0` + `maxSurge ≥ 1` |
| Replacement actually serves traffic | Readiness probe on correct path/port |
| In-flight requests not dropped on termination | `preStop` sleep (5s minimum) |
| App handles `SIGTERM` | App-level graceful shutdown enabled |
| Enough time for full shutdown | `terminationGracePeriodSeconds` > app drain time |

### Service Mesh Note

If using Istio or Linkerd, connection draining is handled at the sidecar level (Envoy), making the `preStop` sleep less
critical. However, it remains good practice and provides defense-in-depth.

---

## PodDisruptionBudget

Protect against voluntary disruptions (node drains, cluster upgrades) by ensuring a minimum number of pods are always
available. Ref: https://kubernetes.io/docs/tasks/run-application/configure-pdb/

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: example-app-pdb
spec:
  minAvailable: 2            # absolute floor — always keep 2 pods running
  # maxUnavailable: 1        # alternative: express as max pods down at once
  selector:
    matchLabels:
      app.kubernetes.io/name: example-app
  unhealthyPodEvictionPolicy: IfHealthyBudget   # default; see below
```

### minAvailable vs maxUnavailable

| Field | Semantics | Example |
|-------|-----------|---------|
| `minAvailable: 2` | At least 2 pods must be available at all times | Use for absolute HA floor |
| `minAvailable: "50%"` | At least 50% of pods must be available | Use for relative floors |
| `maxUnavailable: 1` | At most 1 pod may be disrupted at once | Simpler for rolling drains |
| `maxUnavailable: "25%"` | At most 25% of pods may be disrupted | Mirrors default RollingUpdate |

**Never set both** `minAvailable` and `maxUnavailable` — use one or the other.

### unhealthyPodEvictionPolicy

Controls eviction when already-unhealthy pods exist:

- `IfHealthyBudget` (default) — unhealthy pods can only be evicted if the budget is not yet breached. Prevents evicting
  all pods when a deployment is stuck.
- `AlwaysAllow` — unhealthy pods can always be evicted regardless of budget. Use when you want node drains to proceed
  even if pods are crashlooping.

### PDB + Cluster Autoscaler

Cluster Autoscaler respects PDBs during scale-down. A node will not be drained if evicting its pods would violate any
PDB. This means:

- A PDB with `minAvailable: <replicas>` blocks all evictions — set `minAvailable` below the replica count
- A single-replica workload with `minAvailable: 1` blocks the Autoscaler from draining its node

### Required for HA

Any workload with `replicas > 1` needs a PDB to be truly HA. Without one, a node drain can evict all pods
simultaneously.

---

## Topology Spread Constraints

Distribute pods across failure domains (zones, nodes) to limit the blast radius of node or zone failures.
Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/

```yaml
spec:
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: example-app
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: example-app
```

### Key Fields

| Field | Description |
|-------|-------------|
| `maxSkew` | Max allowed difference in pod count between any two topology domains. `1` means at most 1 pod difference across zones. |
| `topologyKey` | Label key defining the domain. `topology.kubernetes.io/zone` for AZ spread; `kubernetes.io/hostname` for per-node spread. |
| `whenUnsatisfiable` | `DoNotSchedule` — block scheduling if constraint cannot be met. `ScheduleAnyway` — prefer even spread but allow violation. |
| `labelSelector` | Selects pods to count when computing skew. Must match the Deployment's pod template labels. |
| `minDomains` | Minimum number of domains that must have matching pods. Prevents all pods landing in 1 zone when only 1 is available. |

### Zone Spread Pattern (Multi-AZ HA)

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app.kubernetes.io/name: example-app
  minDomains: 3   # require pods in at least 3 AZs
```

- Requires `replicas ≥ 3` (one per zone minimum)
- `DoNotSchedule` is the safe default for production — pods stay Pending until spread is achievable
- `ScheduleAnyway` is useful during rolling updates to avoid scheduling deadlock

### Node-Level Spread (no hotspots)

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: ScheduleAnyway
  labelSelector:
    matchLabels:
      app.kubernetes.io/name: example-app
```

Use `ScheduleAnyway` at the node level — strict node spread can deadlock when nodes are heterogeneous.

### nodeAffinityPolicy and nodeTaintsPolicy (1.26+)

Control how topology spread interacts with node affinity and taints:

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app.kubernetes.io/name: example-app
  nodeAffinityPolicy: Honor    # only count nodes matching pod's nodeAffinity
  nodeTaintsPolicy: Honor      # only count nodes without taints (or with matching tolerations)
```

Both default to `Honor` in 1.26+, which is the correct behavior for most workloads.

### Topology Spread + PDB

Use both together for full HA:
- Topology spread ensures pods land on different zones/nodes
- PDB ensures voluntary disruptions cannot remove all pods from a zone simultaneously

---

## Node Assignment

Control where pods schedule using nodeSelector, affinity, and taints/tolerations.
Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/

### nodeSelector (simple)

Require a specific node label. Simplest but inflexible:

```yaml
spec:
  nodeSelector:
    disktype: ssd
    kubernetes.io/arch: amd64
```

Prefer `nodeAffinity` for production — it supports operators (`In`, `NotIn`, `Exists`) and soft preferences.

### Node Affinity

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:   # hard requirement
        nodeSelectorTerms:
        - matchExpressions:
          - key: topology.kubernetes.io/zone
            operator: In
            values: [us-east-1a, us-east-1b, us-east-1c]
      preferredDuringSchedulingIgnoredDuringExecution:  # soft preference
      - weight: 100
        preference:
          matchExpressions:
          - key: node.kubernetes.io/instance-type
            operator: In
            values: [m6i.xlarge, m6i.2xlarge]
```

- `required...` — pod stays Pending if no matching node exists. Use for hard constraints (GPU nodes, specific regions).
- `preferred...` — scheduler tries to place on matching node; falls back if none available. Use for cost optimization
  or performance preferences.
- `IgnoredDuringExecution` — affinity is not re-evaluated after pod is running. Pod stays on node even if labels change.

### Pod Anti-Affinity (resiliency pattern)

Prevent multiple replicas from co-scheduling on the same node or zone:

```yaml
spec:
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:   # hard: never on same node
      - labelSelector:
          matchLabels:
            app.kubernetes.io/name: example-app
        topologyKey: kubernetes.io/hostname
      preferredDuringSchedulingIgnoredDuringExecution:  # soft: prefer different zones
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: example-app
          topologyKey: topology.kubernetes.io/zone
```

**Warning**: `required` pod anti-affinity with `hostname` topology and `replicas > nodes` causes scheduling deadlock.
Use `preferred` when the replica count may exceed the node count, or combine with topology spread constraints instead.

### Pod Affinity (co-location pattern)

Schedule pods near related workloads (e.g., app near its cache):

```yaml
spec:
  affinity:
    podAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: redis
          topologyKey: kubernetes.io/hostname
```

Use `preferred` — hard co-location requirements create fragile scheduling. Prefer topology spread over hard pod affinity.

### Taints and Tolerations

Taints repel pods from nodes; tolerations allow specific pods to schedule on tainted nodes:

```yaml
# On the node (via kubectl taint or node spec):
# kubectl taint nodes node1 dedicated=gpu:NoSchedule

# In the pod spec:
spec:
  tolerations:
  - key: dedicated
    operator: Equal
    value: gpu
    effect: NoSchedule
  - key: node.kubernetes.io/not-ready
    operator: Exists
    effect: NoExecute
    tolerationSeconds: 300   # evict after 300s if node stays not-ready
```

Taint effects:
- `NoSchedule` — new pods without toleration won't schedule. Existing pods unaffected.
- `PreferNoSchedule` — soft version; scheduler avoids but does not block.
- `NoExecute` — evicts existing pods without toleration (after `tolerationSeconds` if set).

Common use cases:
- Dedicate GPU nodes: taint `dedicated=gpu:NoSchedule`, tolerate only in GPU workload specs
- Node not-ready tolerance: built-in `node.kubernetes.io/not-ready` with `tolerationSeconds` controls eviction timing
- Spot/preemptible nodes: taint spot nodes, add toleration to fault-tolerant workloads only

### Scheduling Decision Hierarchy

Kubernetes applies these in order. All must pass for a pod to schedule:

1. `nodeSelector` / `nodeAffinity` (required) — hard node constraints
2. Taints / tolerations — node exclusion
3. `podAffinity` / `podAntiAffinity` (required) — hard inter-pod constraints
4. Topology spread constraints (`DoNotSchedule`) — spread enforcement
5. Soft preferences (`preferred` affinity, `ScheduleAnyway` spread) — optimization

### Resiliency Combination Pattern

For a production HA workload, combine all three mechanisms:

```yaml
spec:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: example-app
          topologyKey: kubernetes.io/hostname
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: example-app
```

Topology spread enforces the zone distribution (hard); pod anti-affinity adds a soft preference for node-level spread
on top. This avoids the deadlock risk of hard anti-affinity while still optimizing for node spread.
