# Sequence Diagrams Reference

Sequence diagrams show interactions between participants over time — ideal for API flows, authentication sequences,
microservice communication, and any scenario where the *order* and *direction* of messages matters.

## Basic Syntax

```mermaid
sequenceDiagram
    participant A as Service A
    participant B as Service B
    A->>B: Request
    B-->>A: Response
```

## Participants and Actors

- `participant` — system component (service, database, cache, class)
- `actor` — external entity (user, external system, browser)

```mermaid
sequenceDiagram
    actor User
    participant API as API Gateway
    participant Auth as Auth Service
    participant DB as Database

    User->>API: POST /login
    API->>Auth: Validate credentials
    Auth->>DB: Query user
    DB-->>Auth: User record
    Auth-->>API: JWT token
    API-->>User: 200 OK + token
```

## Arrow Types

| Syntax | Meaning |
|--------|---------|
| `->>` | Solid arrow — synchronous request |
| `-->>` | Dashed arrow — synchronous response |
| `-)` | Open arrow — async message (fire and forget) |
| `--)` | Dashed open arrow — async response |
| `-x` | Cross — message terminated / deleted |
| `--x` | Dashed cross — async termination |

## Activations

Show when a participant is actively processing:

```mermaid
sequenceDiagram
    participant C as Client
    participant S as Server

    C->>+S: HTTP Request
    S-->>-C: HTTP Response
```

Use `+` to activate and `-` to deactivate. The `+` and `-` are appended to the arrow syntax.

## Control Flow

### Conditional: alt / else

```mermaid
sequenceDiagram
    actor User
    participant API

    User->>API: GET /resource
    alt authenticated
        API-->>User: 200 OK + data
    else not authenticated
        API-->>User: 401 Unauthorized
    end
```

### Optional: opt

```mermaid
sequenceDiagram
    participant App
    participant Cache
    participant DB

    App->>Cache: GET key
    opt cache miss
        App->>DB: SELECT row
        DB-->>App: row data
        App->>Cache: SET key
    end
    Cache-->>App: value
```

### Parallel: par

```mermaid
sequenceDiagram
    participant Orchestrator
    participant ServiceA
    participant ServiceB

    par Parallel calls
        Orchestrator->>ServiceA: fetch data
    and
        Orchestrator->>ServiceB: fetch config
    end
    ServiceA-->>Orchestrator: data
    ServiceB-->>Orchestrator: config
```

### Loop

```mermaid
sequenceDiagram
    participant Client
    participant Server

    loop Retry up to 3 times
        Client->>Server: Request
        alt success
            Server-->>Client: 200 OK
        else failure
            Server-->>Client: 503 Error
        end
    end
```

### Break (early exit)

```mermaid
sequenceDiagram
    participant A
    participant B

    A->>B: Request
    break on error
        B-->>A: 500 Internal Error
    end
    B-->>A: 200 OK
```

## Notes

```mermaid
sequenceDiagram
    participant A
    participant B

    Note over A: Processing starts
    A->>B: Message
    Note right of B: B handles it
    B-->>A: Response
    Note over A,B: Transaction complete
```

## Auto-numbering

Add `autonumber` to label each message step automatically:

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant API
    participant DB

    User->>API: Login request
    API->>DB: Validate credentials
    DB-->>API: User found
    API-->>User: JWT token
```

## Full Example — OAuth2 Authorization Code Flow

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as Client App
    participant Auth as Auth Server
    participant Resource as Resource Server

    User->>App: Click "Login with OAuth"
    App->>Auth: Redirect to /authorize?response_type=code&client_id=...
    Auth-->>User: Show consent screen
    User->>Auth: Grant permission
    Auth-->>App: Redirect with ?code=AUTH_CODE

    App->>+Auth: POST /token {code, client_secret}
    Auth-->>-App: {access_token, refresh_token}

    App->>+Resource: GET /api/data Authorization: Bearer <token>
    Resource->>Auth: Validate token
    Auth-->>Resource: Token valid
    Resource-->>-App: 200 OK + data

    App-->>User: Show protected content
```

## Full Example — Microservices Order Processing

```mermaid
sequenceDiagram
    autonumber
    actor Customer
    participant Gateway as API Gateway
    participant Orders as Order Service
    participant Inventory as Inventory Service
    participant Payment as Payment Service
    participant Notify as Notification Service

    Customer->>Gateway: POST /orders
    Gateway->>+Orders: Create order

    Orders->>+Inventory: Reserve items
    alt items available
        Inventory-->>-Orders: Reserved OK
    else out of stock
        Inventory-->>Orders: Insufficient stock
        Orders-->>Gateway: 422 Unprocessable
        Gateway-->>Customer: 422 Items unavailable
    end

    Orders->>+Payment: Charge customer
    alt payment success
        Payment-->>-Orders: Charged OK
        Orders->>Notify: Send confirmation email
        Notify-->>Orders: Queued
        Orders-->>-Gateway: 201 Order created
        Gateway-->>Customer: 201 + Order ID
    else payment failed
        Payment-->>Orders: Payment declined
        Orders->>Inventory: Release reservation
        Orders-->>Gateway: 402 Payment Required
        Gateway-->>Customer: 402 Payment failed
    end
```

## Best Practices

1. Put actors on the left, databases/storage on the right
2. Use `autonumber` for flows with more than ~5 steps
3. Group related conditional logic with `alt`/`opt`
4. Show both success and error paths
5. Use activations (`+`/`-`) for long-running operations to show processing time
6. Keep participant names short; use `as` alias for display
7. Split very long sequences into sub-diagrams (e.g., auth flow + business logic separately)
