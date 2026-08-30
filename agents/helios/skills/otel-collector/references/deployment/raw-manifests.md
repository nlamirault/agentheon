# Raw Kubernetes Manifests and Docker Compose

This reference provides complete, production-ready manifests for deploying the OpenTelemetry Collector without the Helm
chart or the Operator. Use this approach when you need maximum control over the Kubernetes resources or when deploying
to environments without Helm.

---

## Agent Mode — DaemonSet

A DaemonSet deploys one Collector pod per node. The agent receives OTLP from local workloads, reads pod logs from
`/var/log`, and forwards to a central gateway.

### Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: observability
  labels:
    app.kubernetes.io/part-of: opentelemetry
```

### ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: otel-agent
  namespace: observability
  labels:
    app.kubernetes.io/name: otel-agent
    app.kubernetes.io/component: agent
    app.kubernetes.io/part-of: opentelemetry
```

### ClusterRole (k8sattributes)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: otel-agent-k8sattributes
  labels:
    app.kubernetes.io/name: otel-agent
    app.kubernetes.io/part-of: opentelemetry
rules:
  - apiGroups: [""]
    resources: [pods, namespaces, nodes]
    verbs: [get, list, watch]
  - apiGroups: [apps]
    resources: [replicasets, deployments, daemonsets, statefulsets]
    verbs: [get, list, watch]
  - apiGroups: [extensions]
    resources: [replicasets]
    verbs: [get, list, watch]
```

### ClusterRoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: otel-agent-k8sattributes
  labels:
    app.kubernetes.io/name: otel-agent
    app.kubernetes.io/part-of: opentelemetry
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: otel-agent-k8sattributes
subjects:
  - kind: ServiceAccount
    name: otel-agent
    namespace: observability
```

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-agent-config
  namespace: observability
  labels:
    app.kubernetes.io/name: otel-agent
    app.kubernetes.io/component: agent
    app.kubernetes.io/part-of: opentelemetry
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      filelog:
        include:
          - /var/log/pods/*/*/*.log
        start_at: beginning
        include_file_path: true
        include_file_name: false
        operators:
          - type: router
            id: get-format
            routes:
              - output: parser-docker
                expr: 'body matches "^\\{"'
              - output: parser-containerd
                expr: 'body matches "^[^ Z]+ "'
          - type: json_parser
            id: parser-docker
            output: extract-metadata-from-filepath
          - type: regex_parser
            id: parser-containerd
            regex: '^(?P<time>[^ Z]+) (?P<stream>stdout|stderr) (?P<logtag>[^ ]*) ?(?P<log>.*)$'
            output: extract-metadata-from-filepath
          - type: regex_parser
            id: extract-metadata-from-filepath
            regex: '^.*\/(?P<namespace>[^_]+)_(?P<pod_name>[^_]+)_(?P<uid>[a-f0-9\-]+)\/(?P<container_name>[^\._]+)\/(?P<restart_count>\d+)\.log$'
            parse_from: attributes["log.file.path"]

      hostmetrics:
        collection_interval: 30s
        scrapers:
          cpu:
          memory:
          disk:
          network:
          filesystem:

    processors:
      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 20

      resourcedetection:
        detectors: [env, k8snode]
        timeout: 5s
        override: false

      k8sattributes:
        auth_type: serviceAccount
        passthrough: false
        extract:
          metadata:
            - k8s.namespace.name
            - k8s.pod.name
            - k8s.pod.uid
            - k8s.pod.start_time
            - k8s.deployment.name
            - k8s.replicaset.name
            - k8s.daemonset.name
            - k8s.statefulset.name
            - k8s.container.name
            - k8s.node.name
        pod_association:
          - sources:
              - from: resource_attribute
                name: k8s.pod.ip
          - sources:
              - from: resource_attribute
                name: k8s.pod.uid
          - sources:
              - from: connection

      batch:
        send_batch_size: 512
        timeout: 10s

    exporters:
      otlp:
        endpoint: otel-gateway.observability.svc.cluster.local:4317
        tls:
          insecure: false

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, resourcedetection, k8sattributes, batch]
          exporters: [otlp]
        metrics:
          receivers: [otlp, hostmetrics]
          processors: [memory_limiter, resourcedetection, k8sattributes, batch]
          exporters: [otlp]
        logs:
          receivers: [otlp, filelog]
          processors: [memory_limiter, resourcedetection, k8sattributes, batch]
          exporters: [otlp]
```

### DaemonSet

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: otel-agent
  namespace: observability
  labels:
    app.kubernetes.io/name: otel-agent
    app.kubernetes.io/component: agent
    app.kubernetes.io/part-of: opentelemetry
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: otel-agent
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/name: otel-agent
        app.kubernetes.io/component: agent
        app.kubernetes.io/part-of: opentelemetry
    spec:
      serviceAccountName: otel-agent

      securityContext:
        runAsNonRoot: false   # hostmetrics and filelog require elevated access

      tolerations:
        - key: node-role.kubernetes.io/control-plane
          effect: NoSchedule

      containers:
        - name: otel-agent
          image: otel/opentelemetry-collector-contrib:0.100.0
          args:
            - --config=/conf/config.yaml

          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false

          ports:
            - name: otlp-grpc
              containerPort: 4317
              hostPort: 4317
              protocol: TCP
            - name: otlp-http
              containerPort: 4318
              hostPort: 4318
              protocol: TCP

          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi

          livenessProbe:
            httpGet:
              path: /
              port: 13133
            initialDelaySeconds: 15
            periodSeconds: 20

          readinessProbe:
            httpGet:
              path: /
              port: 13133
            initialDelaySeconds: 5
            periodSeconds: 10

          volumeMounts:
            - name: config
              mountPath: /conf
              readOnly: true
            - name: varlog
              mountPath: /var/log
              readOnly: true
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: tmpdir
              mountPath: /tmp

      volumes:
        - name: config
          configMap:
            name: otel-agent-config
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: tmpdir
          emptyDir: {}
```

### Service (for agent OTLP endpoint)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: otel-agent
  namespace: observability
  labels:
    app.kubernetes.io/name: otel-agent
    app.kubernetes.io/component: agent
    app.kubernetes.io/part-of: opentelemetry
spec:
  selector:
    app.kubernetes.io/name: otel-agent
  ports:
    - name: otlp-grpc
      port: 4317
      protocol: TCP
      targetPort: otlp-grpc
    - name: otlp-http
      port: 4318
      protocol: TCP
      targetPort: otlp-http
  clusterIP: None   # headless — applications use the node's host IP via hostPort
```

---

## Gateway Mode — Deployment with HPA

A gateway Deployment receives telemetry from agents or applications, applies centralised processing, and forwards to the
observability backend.

### ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-gateway-config
  namespace: observability
  labels:
    app.kubernetes.io/name: otel-gateway
    app.kubernetes.io/component: gateway
    app.kubernetes.io/part-of: opentelemetry
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

    processors:
      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 20

      batch:
        send_batch_size: 1024
        timeout: 10s
        send_batch_max_size: 2048

    exporters:
      otlp:
        endpoint: "${env:OTLP_BACKEND_ENDPOINT}"
        headers:
          authorization: "${env:OTLP_BACKEND_TOKEN}"
        retry_on_failure:
          enabled: true
          initial_interval: 5s
          max_interval: 30s
          max_elapsed_time: 300s
        sending_queue:
          enabled: true
          num_consumers: 10
          queue_size: 5000

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp]
```

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-gateway
  namespace: observability
  labels:
    app.kubernetes.io/name: otel-gateway
    app.kubernetes.io/component: gateway
    app.kubernetes.io/part-of: opentelemetry
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: otel-gateway
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app.kubernetes.io/name: otel-gateway
        app.kubernetes.io/component: gateway
        app.kubernetes.io/part-of: opentelemetry
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001

      containers:
        - name: otel-gateway
          image: otel/opentelemetry-collector-contrib:0.100.0
          args:
            - --config=/conf/config.yaml

          securityContext:
            readOnlyRootFilesystem: true
            allowPrivilegeEscalation: false
            capabilities:
              drop: [ALL]

          ports:
            - name: otlp-grpc
              containerPort: 4317
            - name: otlp-http
              containerPort: 4318
            - name: health
              containerPort: 13133

          env:
            - name: OTLP_BACKEND_ENDPOINT
              valueFrom:
                secretKeyRef:
                  name: otlp-backend-credentials
                  key: endpoint
            - name: OTLP_BACKEND_TOKEN
              valueFrom:
                secretKeyRef:
                  name: otlp-backend-credentials
                  key: token

          resources:
            requests:
              cpu: 200m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi

          livenessProbe:
            httpGet:
              path: /
              port: health
            initialDelaySeconds: 15
            periodSeconds: 20

          readinessProbe:
            httpGet:
              path: /
              port: health
            initialDelaySeconds: 5
            periodSeconds: 10

          volumeMounts:
            - name: config
              mountPath: /conf
              readOnly: true
            - name: tmpdir
              mountPath: /tmp

      volumes:
        - name: config
          configMap:
            name: otel-gateway-config
        - name: tmpdir
          emptyDir: {}
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: otel-gateway
  namespace: observability
  labels:
    app.kubernetes.io/name: otel-gateway
    app.kubernetes.io/component: gateway
    app.kubernetes.io/part-of: opentelemetry
spec:
  selector:
    app.kubernetes.io/name: otel-gateway
  ports:
    - name: otlp-grpc
      port: 4317
      protocol: TCP
      targetPort: otlp-grpc
    - name: otlp-http
      port: 4318
      protocol: TCP
      targetPort: otlp-http
```

### HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: otel-gateway
  namespace: observability
  labels:
    app.kubernetes.io/name: otel-gateway
    app.kubernetes.io/part-of: opentelemetry
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otel-gateway
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 75
```

---

## Setting k8s.pod.uid via Downward API in Application Pod Spec

The `k8sattributes` processor uses the pod UID to look up metadata. Injecting it as an environment variable allows the
SDK to include it as a resource attribute, enabling correlation even before the Collector enriches the span.

```yaml
spec:
  containers:
    - name: my-service
      image: myregistry/my-service:1.0.0
      env:
        # Service identity
        - name: OTEL_SERVICE_NAME
          value: my-service

        # Resource attributes including pod UID from Downward API
        - name: MY_POD_UID
          valueFrom:
            fieldRef:
              fieldPath: metadata.uid
        - name: MY_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: MY_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: MY_NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName

        - name: OTEL_RESOURCE_ATTRIBUTES
          value: >-
            k8s.pod.uid=$(MY_POD_UID),
            k8s.pod.name=$(MY_POD_NAME),
            k8s.namespace.name=$(MY_NAMESPACE),
            k8s.node.name=$(MY_NODE_NAME),
            deployment.environment=production,
            service.version=1.0.0

        # OTLP exporter — send to local agent on host port
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: http://$(HOST_IP):4317

        - name: HOST_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
```

### OTEL_RESOURCE_ATTRIBUTES and OTEL_SERVICE_NAME

`OTEL_SERVICE_NAME` sets the `service.name` resource attribute and takes precedence over any value set in
`OTEL_RESOURCE_ATTRIBUTES`.

`OTEL_RESOURCE_ATTRIBUTES` is a comma-separated list of `key=value` pairs. The SDK merges these with programmatically
configured resource attributes. Environment variable values override SDK-detected values.

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: payment-service
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "service.version=2.3.0,deployment.environment=staging,team=payments"
```

---

## Docker Compose Example

Use Docker Compose for local development. The Collector receives OTLP from the application service and forwards to a
backend.

```yaml
# docker-compose.yaml
version: "3.8"

services:
  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:0.100.0
    command: ["--config=/etc/otelcol/config.yaml"]
    volumes:
      - ./otel-collector-config.yaml:/etc/otelcol/config.yaml:ro
    ports:
      - "4317:4317"   # OTLP gRPC
      - "4318:4318"   # OTLP HTTP
      - "8888:8888"   # Collector metrics
      - "8889:8889"   # Prometheus exporter
    restart: unless-stopped
    # Run as non-root
    user: "10001:10001"

  # Example application service
  my-service:
    build: .
    environment:
      OTEL_SERVICE_NAME: my-service
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317
      OTEL_RESOURCE_ATTRIBUTES: "deployment.environment=development,service.version=dev"
      OTEL_TRACES_EXPORTER: otlp
      OTEL_METRICS_EXPORTER: otlp
      OTEL_LOGS_EXPORTER: otlp
    depends_on:
      - otel-collector
    ports:
      - "8080:8080"
```

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512

  batch:
    send_batch_size: 256
    timeout: 5s

exporters:
  # Debug exporter — logs telemetry to stdout for local inspection
  debug:
    verbosity: detailed

  # Forward to an OTLP backend (optional)
  otlp:
    endpoint: "${env:OTLP_BACKEND_ENDPOINT}"
    headers:
      authorization: "${env:OTLP_BACKEND_TOKEN}"

  # Expose metrics in Prometheus format for local scraping
  prometheus:
    endpoint: 0.0.0.0:8889

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug, otlp]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug, prometheus]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
```

---

## Security Context

Apply security hardening to Collector pods whenever possible.

```yaml
# Pod-level security context
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001
  seccompProfile:
    type: RuntimeDefault

# Container-level security context
securityContext:
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

**Exceptions**: The agent DaemonSet requires `runAsNonRoot: false` and a writable `/tmp` when using the `filelog`
receiver or `hostmetrics` scraper, because these components access host paths requiring elevated permissions. Mount an
`emptyDir` volume at `/tmp` to satisfy the `readOnlyRootFilesystem` constraint.

---

## References

- [OpenTelemetry Collector Kubernetes deployment](https://opentelemetry.io/docs/collector/deployment/agent/)
- [k8sattributes processor](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/k8sattributesprocessor)
- [filelog receiver](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/filelogreceiver)
- [Downward API documentation](https://kubernetes.io/docs/concepts/workloads/pods/downward-api/)
- [OTEL_RESOURCE_ATTRIBUTES specification](https://opentelemetry.io/docs/specs/otel/resource/sdk/#specifying-resource-information-via-an-environment-variable)
- [Kubernetes security contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)
