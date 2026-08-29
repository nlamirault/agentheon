# Flowcharts Reference

Flowcharts visualize processes, algorithms, decision trees, and user journeys — anything with a sequential or branching
structure.

## Basic Syntax

```mermaid
flowchart TD
    A[Start] --> B{Decision?}
    B -->|Yes| C[Action]
    B -->|No| D[Other action]
    C --> E[End]
    D --> E
```

**Direction:**

- `TD` / `TB` — Top to Bottom (default, best for processes)
- `LR` — Left to Right (best for pipelines, timelines)
- `BT` — Bottom to Top
- `RL` — Right to Left

## Node Shapes

| Shape | Syntax | Use for |
|-------|--------|---------|
| Rectangle | `A[Step]` | Process, action |
| Rounded rect | `A([Start/End])` | Start and end points |
| Stadium/Pill | `A(Step)` | Alternative rounded nodes |
| Rhombus | `A{Decision?}` | Decision / branching |
| Cylinder | `A[(Database)]` | Storage, databases |
| Circle | `A((Event))` | Events, triggers |
| Subroutine | `A[[Subprocess]]` | Sub-process / reusable block |
| Parallelogram | `A[/Input/]` | Input / output |
| Hexagon | `A{{Config}}` | Configuration / condition |

## Connections

```mermaid
flowchart LR
    A --> B                        %% Arrow
    C --- D                        %% No arrow
    E -->|Label| F                 %% Labeled arrow
    G -.-> H                       %% Dotted arrow
    I ==> J                        %% Bold arrow
    K -.->|Optional| L             %% Labeled dotted
```

## Subgraphs (grouping)

```mermaid
flowchart TB
    subgraph CI [CI Pipeline]
        direction LR
        Lint --> Test --> Build
    end

    subgraph CD [CD Pipeline]
        direction LR
        Deploy --> HealthCheck
    end

    Build --> Deploy
```

Subgraphs support their own `direction` directive.

## Styling

```mermaid
flowchart TD
    A([Start]):::green --> B{Condition?}
    B -->|Yes| C[Success]:::blue
    B -->|No| D[Error]:::red

    classDef green fill:#90EE90,stroke:#2d8a2d
    classDef blue fill:#87CEEB,stroke:#1a6fa0
    classDef red fill:#FF6B6B,stroke:#cc0000
```

Alternatively use `style` for individual nodes:

```text
style NodeId fill:#color,stroke:#color,stroke-width:2px,color:#textcolor
```

## Full Example — CI/CD Pipeline

```mermaid
flowchart LR
    subgraph Dev [Developer]
        Commit[Commit code] --> Push[Push to branch]
    end

    subgraph CI [Continuous Integration]
        direction TB
        Push --> Checkout[Checkout]
        Checkout --> Lint[Lint & format]
        Lint --> UnitTest[Unit tests]
        UnitTest --> Build[Build image]
        Build --> ScanImage{Security scan}
    end

    subgraph CD [Continuous Delivery]
        direction TB
        ScanImage -->|Pass| DeployStaging[Deploy to staging]
        DeployStaging --> IntegTest[Integration tests]
        IntegTest --> ManualApproval{Manual approval}
    end

    subgraph Prod [Production]
        ManualApproval -->|Approved| BlueGreen[Blue/green deploy]
        BlueGreen --> HealthCheck{Health check?}
        HealthCheck -->|Pass| Done([Live in production])
        HealthCheck -->|Fail| Rollback[Rollback]
    end

    ScanImage -->|Fail| Notify[Notify developer]
    ManualApproval -->|Rejected| Notify
    Rollback --> Notify
    Notify --> Commit

    style Done fill:#90EE90,stroke:#2d8a2d
    style Notify fill:#FF6B6B,stroke:#cc0000
```

## Full Example — User Authentication Flow

```mermaid
flowchart TD
    Start([User opens app]) --> CheckToken{Valid token\nin storage?}

    CheckToken -->|Yes| CheckExpiry{Token expired?}
    CheckToken -->|No| ShowLogin[Show login form]

    CheckExpiry -->|No| LoadApp([Load app])
    CheckExpiry -->|Yes| TryRefresh[Attempt token refresh]
    TryRefresh --> RefreshResult{Refresh OK?}
    RefreshResult -->|Yes| LoadApp
    RefreshResult -->|No| ShowLogin

    ShowLogin --> EnterCreds[User enters credentials]
    EnterCreds --> Validate{Valid format?}
    Validate -->|No| ShowErrors[Show validation errors]
    ShowErrors --> ShowLogin

    Validate -->|Yes| CallAuth[POST /auth/login]
    CallAuth --> AuthResult{Auth service\nresponse?}

    AuthResult -->|200 OK| StoreToken[Store JWT + refresh token]
    StoreToken --> LoadApp

    AuthResult -->|401| FailCount{Attempts >= 3?}
    FailCount -->|No| ShowLoginError[Show invalid credentials]
    ShowLoginError --> ShowLogin

    FailCount -->|Yes| LockAccount[Lock account + show message]
    LockAccount --> End([End])

    AuthResult -->|500| ShowServiceError[Show service unavailable]
    ShowServiceError --> End

    style Start fill:#90EE90,stroke:#2d8a2d
    style LoadApp fill:#90EE90,stroke:#2d8a2d
    style End fill:#ccc,stroke:#888
    style LockAccount fill:#FF6B6B,stroke:#cc0000
```

## Common Patterns

### Decision + merge

```mermaid
flowchart TD
    A --> B{Condition?}
    B -->|True| C[Path A]
    B -->|False| D[Path B]
    C --> E[Merge]
    D --> E
```

### Retry loop

```mermaid
flowchart TD
    A[Attempt operation] --> B{Success?}
    B -->|Yes| C[Continue]
    B -->|No| D{Retries left?}
    D -->|Yes| A
    D -->|No| E[Fail]
```

### Fan-out + join

```mermaid
flowchart LR
    A[Trigger] --> B[Task 1]
    A --> C[Task 2]
    A --> D[Task 3]
    B --> E[Join]
    C --> E
    D --> E
```

## Best Practices

1. **Start/End**: always use `([Stadium])` shapes to mark entry and exit points
2. **Decisions as diamonds**: `{Question?}` for all branching
3. **Label every branch**: add `|Yes|` / `|No|` or meaningful labels on edges leaving decisions
4. **One direction**: choose `TD` or `LR` and stick to it; use subgraph `direction` to override locally
5. **Group with subgraphs**: cluster related steps by environment, team, or system boundary
6. **Color code**: use green for success/end, red for errors/failures, blue for main path
7. **Keep it focused**: one process per diagram; link to sub-diagrams for detail
