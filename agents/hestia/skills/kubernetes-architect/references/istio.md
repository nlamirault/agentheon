# Kubernetes / Istio Service Mesh

This reference provides comprehensive Istio service mesh guidance, covering installation, traffic management, security
policies, observability, and multi-cluster deployments.

## Overview

Istio is an open-source service mesh that provides traffic management, security, and observability for microservices. It
uses a sidecar proxy (Envoy) injected into each pod to intercept and manage network traffic.

## Core Components

**Istiod** - Control plane (pilot, citadel, galley consolidated)
**Envoy Proxy** - Data plane sidecar for traffic management
**Ingress Gateway** - Entry point for external traffic
**Egress Gateway** - Controlled exit point for external traffic

## Installation

### IstioOperator Configuration

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-control-plane
  namespace: istio-system
spec:
  profile: production
  meshConfig:
    accessLogFile: /dev/stdout
    accessLogEncoding: JSON
    defaultConfig:
      holdApplicationUntilProxyStarts: true
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
          limits:
            cpu: 1000m
            memory: 4Gi
        hpaSpec:
          minReplicas: 2
          maxReplicas: 5
    ingressGateways:
    - name: istio-ingressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 2000m
            memory: 1Gi
        hpaSpec:
          minReplicas: 3
          maxReplicas: 10
        service:
          type: LoadBalancer
          annotations:
            service.beta.kubernetes.io/aws-load-balancer-type: nlb
    egressGateways:
    - name: istio-egressgateway
      enabled: true
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
```

### Installation Commands

```bash
# Install istioctl
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with operator
istioctl operator init

# Apply configuration
kubectl apply -f istio-operator.yaml

# Verify installation
istioctl verify-install

# Check control plane status
kubectl get pods -n istio-system
```

## Namespace Configuration

### Enable Sidecar Injection

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: enabled
```

```bash
# Label existing namespace
kubectl label namespace production istio-injection=enabled

# Verify injection
kubectl get namespace -L istio-injection
```

### Selective Injection

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    sidecar.istio.io/inject: "true"  # Override namespace default
spec:
  containers:
  - name: app
    image: myapp:latest
```

## Traffic Management

### Gateway Configuration

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: public-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*.example.com"
    tls:
      httpsRedirect: true
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "*.example.com"
    tls:
      mode: SIMPLE
      credentialName: example-com-tls
```

### VirtualService Configuration

#### Basic HTTP Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: frontend
  namespace: production
spec:
  hosts:
  - frontend.example.com
  gateways:
  - istio-system/public-gateway
  http:
  - match:
    - uri:
        prefix: /api/v2
    route:
    - destination:
        host: backend-v2
        port:
          number: 8080
  - route:
    - destination:
        host: backend-v1
        port:
          number: 8080
```

#### Traffic Splitting (Canary)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-canary
  namespace: production
spec:
  hosts:
  - backend
  http:
  - match:
    - headers:
        x-canary:
          exact: "true"
    route:
    - destination:
        host: backend
        subset: v2
  - route:
    - destination:
        host: backend
        subset: v1
      weight: 90
    - destination:
        host: backend
        subset: v2
      weight: 10
```

#### Header-Based Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: header-routing
  namespace: production
spec:
  hosts:
  - myservice
  http:
  - match:
    - headers:
        user-agent:
          regex: ".*Mobile.*"
    route:
    - destination:
        host: myservice-mobile
  - match:
    - headers:
        x-user-type:
          exact: "premium"
    route:
    - destination:
        host: myservice-premium
  - route:
    - destination:
        host: myservice-standard
```

#### Retry and Timeout Configuration

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: resilient-service
  namespace: production
spec:
  hosts:
  - backend
  http:
  - route:
    - destination:
        host: backend
    timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: 5xx,reset,connect-failure,refused-stream
```

### DestinationRule Configuration

#### Circuit Breaking

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-circuit-breaker
  namespace: production
spec:
  host: backend
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 100
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
      minHealthPercent: 40
```

#### Load Balancing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-lb
  namespace: production
spec:
  host: backend
  trafficPolicy:
    loadBalancer:
      consistentHash:
        httpHeaderName: x-user-id
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
    trafficPolicy:
      loadBalancer:
        simple: LEAST_REQUEST
```

#### TLS Configuration

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-mtls
  namespace: production
spec:
  host: backend.production.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
    portLevelSettings:
    - port:
        number: 443
      tls:
        mode: SIMPLE
        caCertificates: /etc/certs/ca.crt
```

## Security

### Peer Authentication

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: backend-mtls
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  mtls:
    mode: STRICT
  portLevelMtls:
    8080:
      mode: PERMISSIVE  # Allow non-mTLS for migration
```

### Authorization Policies

#### Service-to-Service Authorization

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: backend-authz
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - cluster.local/ns/production/sa/frontend
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/api/*"]
```

#### JWT Validation

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  jwtRules:
  - issuer: "https://auth.example.com"
    jwksUri: "https://auth.example.com/.well-known/jwks.json"
    audiences:
    - "backend-api"
---
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
  namespace: production
spec:
  selector:
    matchLabels:
      app: backend
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]
    when:
    - key: request.auth.claims[role]
      values: ["admin", "user"]
```

#### Deny Policy

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-external
  namespace: production
spec:
  selector:
    matchLabels:
      app: internal-api
  action: DENY
  rules:
  - from:
    - source:
        notNamespaces: ["production", "staging"]
```

## Egress Control

### ServiceEntry for External Services

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-api
  namespace: production
spec:
  hosts:
  - api.external.com
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

### Egress Gateway

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: egress-gateway
  namespace: istio-system
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - api.external.com
    tls:
      mode: PASSTHROUGH
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: direct-external-through-egress
  namespace: production
spec:
  hosts:
  - api.external.com
  gateways:
  - mesh
  - istio-system/egress-gateway
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        port:
          number: 443
  - match:
    - gateways:
      - istio-system/egress-gateway
      port: 443
    route:
    - destination:
        host: api.external.com
        port:
          number: 443
```

## Observability

### Telemetry Configuration

```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: default
  namespace: istio-system
spec:
  tracing:
  - providers:
    - name: jaeger
    randomSamplingPercentage: 1.0
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: REQUEST_COUNT
      tagOverrides:
        response_code:
          operation: UPSERT
```

### Distributed Tracing

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    enableTracing: true
    defaultConfig:
      tracing:
        sampling: 1.0
        zipkin:
          address: jaeger-collector.observability:9411
```

### Access Logging

```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: access-logs
  namespace: production
spec:
  accessLogging:
  - providers:
    - name: envoy
    filter:
      expression: response.code >= 400
```

## Multi-Cluster

### Primary-Remote Configuration

```yaml
# Primary cluster
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster1
      network: network1
```

```bash
# Generate remote secret
istioctl create-remote-secret \
  --context=cluster1 \
  --name=cluster1 | \
  kubectl apply -f - --context=cluster2
```

### Multi-Network Service

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: cross-cluster-service
  namespace: production
spec:
  hosts:
  - backend.production.global
  ports:
  - number: 8080
    name: http
    protocol: HTTP
  location: MESH_INTERNAL
  resolution: DNS
  endpoints:
  - address: backend.cluster1.local
    network: network1
  - address: backend.cluster2.local
    network: network2
```

## Common Anti-Patterns

### ❌ Missing Resource Limits

```yaml
# Bad - no resource limits on sidecar
spec:
  containers:
  - name: app
    image: myapp:latest
```

```yaml
# Good - explicit sidecar resources
metadata:
  annotations:
    sidecar.istio.io/proxyCPU: "100m"
    sidecar.istio.io/proxyMemory: "128Mi"
    sidecar.istio.io/proxyCPULimit: "2000m"
    sidecar.istio.io/proxyMemoryLimit: "1Gi"
```

### ❌ Wildcard Authorization

```yaml
# Bad - overly permissive
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["*"]
```

```yaml
# Good - explicit principals
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/frontend/sa/web"
        - "cluster.local/ns/backend/sa/api"
```

### ❌ No Circuit Breaking

```yaml
# Bad - no circuit breaker
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend
spec:
  host: backend
```

```yaml
# Good - circuit breaker configured
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend
spec:
  host: backend
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

### ❌ ALLOW_ANY Egress

```yaml
# Bad - allow all egress
meshConfig:
  outboundTrafficPolicy:
    mode: ALLOW_ANY
```

```yaml
# Good - registry only with explicit entries
meshConfig:
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY
# Create ServiceEntry for each external service
```

### ❌ No Health Check Configuration

```yaml
# Bad - default health check behavior
spec:
  containers:
  - name: app
    image: myapp:latest
```

```yaml
# Good - configure health checks
metadata:
  annotations:
    sidecar.istio.io/rewriteAppHTTPProbers: "true"
spec:
  containers:
  - name: app
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
```

## Validation Commands

```bash
# Verify Istio installation
istioctl verify-install

# Check proxy configuration
istioctl proxy-config cluster <pod-name> -n <namespace>
istioctl proxy-config route <pod-name> -n <namespace>
istioctl proxy-config listener <pod-name> -n <namespace>

# Analyze configuration issues
istioctl analyze -n production

# Check mTLS status
istioctl authn tls-check <pod-name>.<namespace>

# Debug traffic
istioctl dashboard envoy <pod-name>.<namespace>

# Test connectivity
kubectl exec <pod> -c istio-proxy -- curl -v http://backend:8080

# View access logs
kubectl logs <pod> -c istio-proxy -f

# Check certificate expiration
istioctl proxy-config secret <pod-name> -o json | jq '.dynamicActiveSecrets[0].secret.tlsCertificate.certificateChain.inlineBytes' -r | base64 -d | openssl x509 -noout -dates
```

## Additional Resources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Best Practices](https://istio.io/latest/docs/ops/best-practices/)
- [Istio Performance and Scalability](https://istio.io/latest/docs/ops/deployment/performance-and-scalability/)
- [Envoy Proxy Documentation](https://www.envoyproxy.io/docs/envoy/latest/)
- [Istio Security Best Practices](https://istio.io/latest/docs/ops/best-practices/security/)
- [Istio Traffic Management](https://istio.io/latest/docs/concepts/traffic-management/)
