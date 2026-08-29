# Kubernetes / Networking

This reference provides comprehensive Kubernetes networking guidance, covering Services, Gateway API, legacy Ingress,
NetworkPolicies, and traffic management patterns.

## Overview

Kubernetes networking enables communication between pods, services, and external clients. Modern networking in
Kubernetes centers on the Gateway API, which replaces legacy Ingress with more powerful and flexible routing
capabilities.

## Gateway API (Recommended)

The Gateway API is the modern approach to Kubernetes networking, replacing Ingress with more expressive and extensible
APIs.

### Core Resources

**Gateway** - Infrastructure definition (load balancer, listeners)
**HTTPRoute** - HTTP traffic routing rules
**GRPCRoute** - gRPC traffic routing
**TLSRoute** - TLS traffic routing
**TCPRoute** - TCP traffic routing
**UDPRoute** - UDP traffic routing

### Gateway Configuration

#### Basic Gateway with TLS

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: production-gateway
  namespace: gateway-system
spec:
  gatewayClassName: istio
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "*.example.com"
  - name: https
    protocol: HTTPS
    port: 443
    hostname: "*.example.com"
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: example-com-tls
        namespace: gateway-system
```

#### Multi-Tenant Gateway

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: shared-gateway
  namespace: gateway-system
spec:
  gatewayClassName: nginx
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    allowedRoutes:
      namespaces:
        from: All  # Allow routes from any namespace
  - name: https
    protocol: HTTPS
    port: 443
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            gateway: allowed
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: wildcard-tls
```

### HTTPRoute Configuration

#### Basic HTTP Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
  namespace: production
spec:
  parentRefs:
  - name: production-gateway
    namespace: gateway-system
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: backend-service
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: frontend-service
      port: 80
```

#### Canary Deployment (Traffic Splitting)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary-route
  namespace: production
spec:
  parentRefs:
  - name: production-gateway
    namespace: gateway-system
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: app-v1
      port: 8080
      weight: 90  # 90% to stable version
    - name: app-v2
      port: 8080
      weight: 10  # 10% to canary version
```

#### Header-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: header-route
  namespace: production
spec:
  parentRefs:
  - name: production-gateway
    namespace: gateway-system
  hostnames:
  - "api.example.com"
  rules:
  - matches:
    - headers:
      - type: Exact
        name: X-Version
        value: "beta"
    backendRefs:
    - name: api-beta
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: api-stable
      port: 8080
```

#### Request/Response Modification

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: modified-route
  namespace: production
spec:
  parentRefs:
  - name: production-gateway
    namespace: gateway-system
  rules:
  - filters:
    - type: RequestHeaderModifier
      requestHeaderModifier:
        add:
        - name: X-Custom-Header
          value: "added-by-gateway"
        remove:
        - "X-Internal-Header"
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /v2
    backendRefs:
    - name: api-service
      port: 8080
```

#### Request Redirects

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: redirect-route
  namespace: production
spec:
  parentRefs:
  - name: production-gateway
    namespace: gateway-system
  hostnames:
  - "old.example.com"
  rules:
  - filters:
    - type: RequestRedirect
      requestRedirect:
        hostname: new.example.com
        statusCode: 301
```

### Gateway API Migration from Ingress

#### Before (Legacy Ingress)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

#### After (Gateway API)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
spec:
  parentRefs:
  - name: production-gateway
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: app-service
      port: 80
```

**Benefits:**

- More expressive routing rules
- Header-based routing
- Traffic splitting
- Request/response modification
- Better multi-tenancy
- Vendor-neutral

## Legacy Ingress (Deprecation Path)

### Validation Requirements

For legacy Ingress resources:

**Check:**

- All `Ingress` objects have TLS configured (`tls` block)
- `IngressClassName` is specified
- Host-based routing is configured
- HTTPS redirection is enabled

**Warn:**

- Flag all Ingress objects as "Legacy" and provide migration path to HTTPRoute
- Missing host-based routing
- No TLS configuration
- Using deprecated annotations

### Minimal Compliant Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: legacy-app
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.example.com
    secretName: app-tls
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-service
            port:
              number: 80
```

## Services

### Service Types

#### ClusterIP (Default)

Internal-only service:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: production
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: backend
  ports:
  - name: http
    port: 8080
    targetPort: 8080
    protocol: TCP
```

#### LoadBalancer

External load balancer:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: production
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
  - name: https
    port: 443
    targetPort: 8080
```

#### NodePort (Avoid Unless Needed)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: debug-service
spec:
  type: NodePort
  selector:
    app: debug
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30080  # External port on each node
```

**Warning:** NodePort exposes service on all nodes. Use LoadBalancer or Ingress instead for production.

#### Headless Service

For StatefulSets or direct pod access:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: database
spec:
  clusterIP: None  # Headless service
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
```

### Service Validation

**Check:**

- Services have `selector` labels matching pod labels
- Appropriate `type` is used (avoid `NodePort` unless needed)
- Internal-only services use `ClusterIP`
- External services use `LoadBalancer` or are exposed via Gateway/Ingress
- LoadBalancer annotations are correct (e.g., internal vs external)

**Warn if:**

- Service is missing `selector`
- Using `NodePort` in production
- External service lacks security annotations
- Port names don't follow conventions (http, https, grpc, etc.)

## NetworkPolicies

### Default Deny All

Start with default deny:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Allow Specific Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app.kubernetes.io/name: frontend
    ports:
    - protocol: TCP
      port: 8080
```

### Allow DNS and External HTTPS

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-and-https
  namespace: production
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53  # DNS
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 443  # HTTPS
```

### Cross-Namespace Communication

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: production
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    - podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 8080
```

## Network Security Best Practices

### Recommendations

**Default Deny:**

- Start with default deny-all NetworkPolicy
- Explicitly allow only required traffic
- Apply both ingress and egress policies

**Service Isolation:**

- Use ClusterIP for internal services
- Restrict external access with LoadBalancer annotations
- Implement NetworkPolicies for pod-to-pod communication

**TLS Everywhere:**

- Configure TLS termination at Gateway/Ingress
- Use cert-manager for automated certificate management
- Enable HTTPS redirection

**Gateway API Adoption:**

- Migrate from Ingress to Gateway API
- Use HTTPRoute for advanced routing
- Leverage traffic splitting for canary deployments

### Anti-Patterns

#### ❌ No NetworkPolicy

```yaml
# No NetworkPolicy - all traffic allowed
```

**Problem:** Pods can communicate freely, no isolation

#### ❌ NodePort in Production

```yaml
spec:
  type: NodePort
  ports:
  - nodePort: 30080  # Exposed on all nodes
```

**Problem:** Security risk, port conflicts, not production-ready

#### ❌ Missing TLS

```yaml
# Ingress without TLS
spec:
  rules:
  - host: app.example.com
    # No tls block
```

**Problem:** Unencrypted traffic, security vulnerability

#### ❌ Wildcard NetworkPolicy

```yaml
ingress:
- from:
  - podSelector: {}  # Allows all pods
```

**Problem:** Too permissive, defeats purpose of NetworkPolicy

## DNS and Service Discovery

### Service DNS

Services are accessible via DNS:

```text
<service-name>.<namespace>.svc.cluster.local
```

**Examples:**

- `backend.production.svc.cluster.local`
- `database.data.svc.cluster.local`
- `redis.cache.svc.cluster.local`

### Short DNS Names

Within same namespace:

```text
<service-name>
```

Across namespaces:

```text
<service-name>.<namespace>
```

### Headless Service DNS

Headless services provide pod-specific DNS:

```text
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

**Example:**

```text
postgres-0.database.data.svc.cluster.local
postgres-1.database.data.svc.cluster.local
```

## External Traffic Management

### ExternalName Service

For external DNS-based services:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: api.external-service.com
```

**Warning:** Use only for DNS-only services. For direct external access, use Service Endpoints or Gateway API
ServiceImport.

### Service Endpoints

For external IPs without DNS:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-database
spec:
  ports:
  - port: 5432
---
apiVersion: v1
kind: Endpoints
metadata:
  name: external-database
subsets:
- addresses:
  - ip: 192.168.1.100
  ports:
  - port: 5432
```

## Validation Commands

```bash
# Validate Gateway API resources
kubectl apply --dry-run=server -f gateway.yaml

# Test service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod: wget -O- http://service-name:port

# Check NetworkPolicy
kubectl get networkpolicies -A
kubectl describe networkpolicy policy-name -n namespace

# Debug service endpoints
kubectl get endpoints service-name -n namespace
```

## Additional Resources

- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)
- [Kubernetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

For complete examples, see:

- `assets/service-example.yaml`
- `assets/ingress-example.yaml`
- `assets/networkpolicy-example.yaml`
- `examples/gateway-api/`
