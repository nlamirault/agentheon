---
name: "api-design"
description: "Use this skill when designing or reviewing REST APIs — defining endpoints, resource models, HTTP methods, status codes, pagination, versioning strategies, or error response formats. Trigger when the user says 'design an API', 'add an endpoint', 'REST API structure', 'HTTP conventions', or asks how to model a resource — even without asking for best practices."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - rest
  - grpc
  - http
  task: [configure, review, build]
  persona: [developer]
  workload: [application]
---

# REST API Design Best Practices

## Guiding Principles

- **Resource-Oriented:** Design APIs around Resources (nouns), not Actions (verbs). Use standard HTTP methods (GET,
  POST, PUT, PATCH, DELETE) to operate on these resources.
- **URI Naming:** Use plural nouns for resource collections (e.g., `/users`, `/orders`). Use resource IDs for specific
  instances (e.g., `/users/123`, `/orders/456`). Avoid verbs in URIs.
- **HTTP Methods:**
  - `GET`: Retrieve resources (safe, idempotent).
  - `POST`: Create new resources within a collection (not idempotent) or trigger actions.
  - `PUT`: Replace an existing resource entirely (idempotent).
  - `PATCH`: Partially update an existing resource (not necessarily idempotent).
  - `DELETE`: Remove a resource (idempotent).
- **HTTP Status Codes:** Use standard HTTP status codes accurately to indicate the outcome of requests (e.g., `200 OK`,
  `201 Created`, `204 No Content`, `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`,
  `500 Internal Server Error`).
- **Request/Response Formats:** Use standard formats like JSON for request and response bodies. Be consistent.
- **Filtering, Sorting, Pagination:** Provide mechanisms for clients to filter, sort, and paginate collection results
  using query parameters (e.g., `/users?status=active&sort=lastName&limit=25&offset=50`).
- **Versioning:** Implement API versioning (e.g., via URI path `/v1/users`, custom request header `Api-Version: 1.0`, or
  Accept header `Accept: application/vnd.myapi.v1+json`) to manage changes without breaking clients.
- **HATEOAS (Hypermedia as the Engine of Application State):** Consider including links within responses to guide
  clients to related resources or possible actions.
- **Error Handling:** Provide clear, informative error messages in response bodies (e.g., JSON format) along with
  appropriate status codes.
- **Statelessness:** Each request from a client should contain all information needed to understand and process it. Do
  not store client state on the server between requests.
- **Idempotency:** Understand and leverage idempotency of GET, PUT, DELETE for reliable interactions.

## Gotchas

- **Using `PUT` when you mean `PATCH` (or vice versa) causes data loss.** `PUT` replaces the entire resource — a client
  that sends only the fields it wants to change will silently null out all other fields. Use `PATCH` for partial
  updates.
- **Return `202 Accepted`, not `200 OK`, for long-running async operations.** Returning 200 implies the operation is
  complete. For async jobs, return 202 with a `Location` header pointing to a status endpoint.
- **Sensitive filter values in query parameters appear in server logs and browser history.**
  `GET /users?ssn=123-45-6789` logs the SSN in your access logs, CDN logs, and browser history. Use `POST` with a
  request body for sensitive search criteria.
- **Exposing sequential integer IDs enables enumeration attacks.** `GET /users/1`, `/users/2`, etc. lets anyone scrape
  your entire user base. Use UUIDs or opaque tokens as resource identifiers.
- **Inconsistent casing between request and response bodies causes client bugs.** Pick `snake_case` or `camelCase` and
  apply it everywhere — mixing conventions (request body in `snake_case`, response in `camelCase`) forces clients to
  handle both.
- **Returning `200 OK` with `{"error": "Not found"}` in the body breaks every HTTP client and monitoring tool.** Status
  codes must accurately reflect the outcome. Reserve `200` for success; use `4xx` for client errors and `5xx` for server
  errors.
- **Inconsistent plural vs. singular resource naming breaks client SDK generation.** Choose plurals for collections
  (`/users`, `/orders`) and stick to it across the entire API surface.
