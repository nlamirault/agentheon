# Architecture Diagrams Reference

Architecture diagrams visualize cloud infrastructure, CI/CD pipelines, and service topology using Mermaid's
`architecture-beta` syntax (requires Mermaid v11.1.0+).

> **Note:** This is a distinct diagram type from flowcharts — it uses a dedicated `architecture-beta` block with its own
> primitives (`group`, `service`, `junction`).

## Basic Syntax

```mermaid
architecture-beta
    group vpc(cloud)[VPC]
    service api(server)[API Server] in vpc
    service db(database)[Database] in vpc

    api:R --> L:db
```

## Building Blocks

### Groups — logical boundaries

```text
group {id}({icon})[{label}] (in {parentGroupId})?
```

Groups represent environments, VPCs, networks, or logical layers:

```mermaid
architecture-beta
    group internet(cloud)[Internet]
    group private_vpc(cloud)[Private VPC]
    group db_subnet(cloud)[DB Subnet] in private_vpc
```

### Services — nodes / components

```text
service {id}({icon})[{label}] (in {groupId})?
```

```mermaid
architecture-beta
    group public(cloud)[Public]
    service lb(server)[Load Balancer] in public
    service cdn(internet)[CDN] in public
```

### Junctions — fan-out / fan-in points

```text
junction {id} (in {groupId})?
```

```mermaid
architecture-beta
    service input(server)[API Gateway]
    junction j1
    service svc1(server)[Service A]
    service svc2(server)[Service B]

    input:R --> L:j1
    j1:T --> B:svc1
    j1:B --> T:svc2
```

## Edge Syntax

```text
{serviceId}:{side} {arrow} {side}:{serviceId}
```

**Sides:** `T` (top), `B` (bottom), `L` (left), `R` (right)

**Arrow types:**

- `-->` — directed (with arrowhead)
- `--` — undirected (no arrowhead)
- `<-->` — bidirectional

```mermaid
architecture-beta
    service A(server)[Service A]
    service B(database)[Database]
    service C(server)[Service C]

    A:R --> L:B       %% A calls B
    A:B <--> T:C      %% A and C communicate
```

**Connecting groups** (using `{group}` modifier on the service):

```mermaid
architecture-beta
    group frontend(cloud)[Frontend]
    group backend(cloud)[Backend]
    service ui(server)[UI] in frontend
    service api(server)[API] in backend

    ui{group}:R --> L:api{group}
```

## Built-in Icons

| Icon name | Represents |
|-----------|-----------|
| `cloud` | Cloud / internet |
| `database` | Database / storage |
| `disk` | Disk / file system |
| `internet` | Internet / browser |
| `server` | Server / compute |

## Tech Brand Icons (with @iconify-json/logos)

Install with: `npm i @iconify-json/logos @mermaid-js/mermaid-cli`

Popular `logos:` icons:

- `logos:aws` `logos:azure` `logos:google-cloud`
- `logos:kubernetes` `logos:docker` `logos:terraform`
- `logos:github` `logos:github-actions` `logos:gitlab`
- `logos:prometheus` `logos:grafana` `logos:elasticsearch`
- `logos:nginx` `logos:redis` `logos:postgresql`
- `logos:kafka` `logos:rabbitmq`

Usage:

```mermaid
architecture-beta
    service k8s(logos:kubernetes)[Kubernetes]
    service registry(logos:docker)[Container Registry]
    registry:R --> L:k8s
```

## Full Example — AWS Three-Tier Web Application

```mermaid
architecture-beta
    group internet(cloud)[Internet]
    group public_subnet(cloud)[Public Subnet]
    group private_subnet(cloud)[Private Subnet]
    group data_subnet(cloud)[Data Subnet]

    service user(internet)[Users] in internet
    service cdn(server)[CloudFront CDN] in public_subnet
    service lb(server)[Application Load Balancer] in public_subnet

    service app1(server)[App Server 1] in private_subnet
    service app2(server)[App Server 2] in private_subnet
    junction j_app in private_subnet

    service rds(database)[RDS Primary] in data_subnet
    service replica(database)[RDS Read Replica] in data_subnet
    service cache(disk)[ElastiCache Redis] in data_subnet

    user:R --> L:cdn
    cdn:R --> L:lb
    lb:R --> L:j_app
    j_app:T --> B:app1
    j_app:B --> T:app2
    app1:R --> L:cache
    app2:R --> L:cache
    app1:B --> T:rds
    app2:B --> T:rds
    rds:R --> L:replica
```

## Full Example — GitHub Actions CI/CD Pipeline

```mermaid
architecture-beta
    group developer(cloud)[Developer Workstation]
    group github(cloud)[GitHub]
    group registry(cloud)[Container Registry]
    group k8s_cluster(cloud)[Kubernetes Cluster]
    group monitoring(cloud)[Monitoring]

    service dev(server)[Developer] in developer

    service repo(server)[GitHub Repo] in github
    service actions(server)[GitHub Actions] in github
    service scanner(server)[Security Scan] in github

    service ecr(database)[Container Registry] in registry

    service staging(server)[Staging Namespace] in k8s_cluster
    service prod(server)[Production Namespace] in k8s_cluster

    service prom(server)[Prometheus] in monitoring
    service grafana(server)[Grafana] in monitoring

    dev:R --> L:repo
    repo:R --> L:actions
    actions:B --> T:scanner
    scanner:R --> L:ecr
    ecr:R --> L:staging
    staging:R --> L:prod
    prod:B --> T:prom
    prom:R --> L:grafana
```

## Full Example — Microservices with Message Broker

```mermaid
architecture-beta
    group public(cloud)[Public Zone]
    group services(cloud)[Services Zone]
    group messaging(cloud)[Messaging]
    group storage(cloud)[Storage]

    service gateway(server)[API Gateway] in public
    service auth(server)[Auth Service] in services
    service orders(server)[Order Service] in services
    service inventory(server)[Inventory Service] in services
    service notify(server)[Notification Service] in services

    service broker(server)[Kafka] in messaging
    junction j_kafka in messaging

    service orders_db(database)[Orders DB] in storage
    service inventory_db(database)[Inventory DB] in storage
    service cache(disk)[Redis Cache] in storage

    gateway:R --> L:auth
    gateway:B --> T:orders
    orders:R --> L:orders_db
    orders:B --> T:j_kafka
    j_kafka:R --> L:inventory
    j_kafka:T --> B:notify
    inventory:R --> L:inventory_db
    orders:T --> B:cache
    auth:B --> T:cache
```

## Best Practices

1. **Group by boundary** — use groups for VPCs, environments (dev/staging/prod), layers (frontend/backend/data), or
   teams
2. **Consistent icons** — pick one icon per service type (all DBs use `database`, all servers use `server`) unless
   specifically differentiating
3. **Edge direction matters** — place services spatially so edges flow naturally (e.g., left-to-right for request flow)
4. **Label edges** when the protocol/relationship is non-obvious (HTTPS, gRPC, async, etc.) — though `architecture-beta`
   doesn't natively support edge labels, add a comment `%%` near the edge
5. **Junctions for fan-out** — use `junction` instead of showing multiple arrows from one source to keep the diagram
   clean
6. **Split large diagrams** — a 20+ service diagram is hard to read; split by layer or domain and cross-reference
7. **Nest groups sparingly** — up to 2 levels (e.g., region > VPC) works well; deeper nesting becomes hard to follow

## Limitations of architecture-beta

- Edge labels are not supported in `architecture-beta` — use comments or a legend
- Styling (CSS classes) is not supported — use icon choice and grouping to convey meaning
- Requires Mermaid v11.1.0+ — older renderers will fall back to an error; test on your target platform
- For very complex flows where you need labels on edges, consider using a `flowchart LR` instead with cylindrical/server
  shapes
