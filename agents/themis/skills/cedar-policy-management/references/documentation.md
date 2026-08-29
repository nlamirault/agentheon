# Cedar Documentation Resources

Comprehensive collection of official Cedar documentation, tutorials, guides, and community resources.

## Official Documentation

### Core Documentation

**Cedar Website**

- URL: <https://www.cedarpolicy.com/>
- Content: Overview, getting started, key concepts
- Audience: Everyone

**Cedar Documentation**

- URL: <https://docs.cedarpolicy.com/>
- Content: Complete language reference, guides, tutorials
- Audience: Developers, security engineers

**Cedar Specification**

- URL: <https://cedar-policy.github.io/cedar-spec/>
- Content: Formal language specification, semantics, type system
- Audience: Language implementers, advanced users

### GitHub Repositories

**Cedar Main Repository**

- URL: <https://github.com/cedar-policy/cedar>
- Content: Source code, CLI, Rust SDK
- License: Apache 2.0

**Cedar Examples**

- URL: <https://github.com/cedar-policy/cedar-examples>
- Content: Example policies, schemas, use cases
- Topics: RBAC, ABAC, ReBAC, photo sharing, document management

**Cedar Java SDK**

- URL: <https://github.com/cedar-policy/cedar-java>
- Content: Java language bindings
- Use: Java applications

**Cedar Go SDK**

- URL: <https://github.com/cedar-policy/cedar-go>
- Content: Go language bindings
- Use: Go applications

**Cedar Wasm**

- URL: <https://github.com/cedar-policy/cedar/tree/main/cedar-wasm>
- Content: WebAssembly bindings
- Use: Browser, edge computing

## Language SDKs

### Rust SDK

**Installation:**

```toml
[dependencies]
cedar-policy = "4.0"
```

**Documentation:**

- Crate: <https://crates.io/crates/cedar-policy>
- API Docs: <https://docs.rs/cedar-policy/>
- Guide: <https://docs.cedarpolicy.com/rust/>

**Basic usage:**

```rust
use cedar_policy::{Authorizer, Context, Decision, Entities, EntityUid, PolicySet, Request};

let policies = PolicySet::from_str(policy_src)?;
let entities = Entities::from_json_value(entities_json, None)?;
let request = Request::new(principal, action, resource, Context::empty(), None)?;

let authorizer = Authorizer::new();
let response = authorizer.is_authorized(&request, &policies, &entities);

match response.decision() {
    Decision::Allow => println!("Authorized"),
    Decision::Deny => println!("Denied"),
}
```

### Java SDK

**Installation (Maven):**

```xml
<dependency>
    <groupId>com.cedarpolicy</groupId>
    <artifactId>cedar-java</artifactId>
    <version>3.0.0</version>
</dependency>
```

**Documentation:**

- Maven Central: <https://central.sonatype.com/artifact/com.cedarpolicy/cedar-java>
- JavaDoc: <https://cedar-policy.github.io/cedar-java/>
- Guide: <https://docs.cedarpolicy.com/java/>

**Basic usage:**

```java
import com.cedarpolicy.AuthorizationEngine;
import com.cedarpolicy.model.*;

PolicySet policies = PolicySet.parsePolicies(policySource);
Entities entities = Entities.parseEntities(entitiesJson);
Request request = new Request(principal, action, resource, context);

AuthorizationEngine engine = new AuthorizationEngine();
AuthorizationResponse response = engine.isAuthorized(request, policies, entities);

if (response.isAllowed()) {
    System.out.println("Authorized");
} else {
    System.out.println("Denied");
}
```

### Go SDK

**Installation:**

```bash
go get github.com/cedar-policy/cedar-go
```

**Documentation:**

- pkg.go.dev: <https://pkg.go.dev/github.com/cedar-policy/cedar-go>
- Guide: <https://docs.cedarpolicy.com/go/>

**Basic usage:**

```go
import "github.com/cedar-policy/cedar-go"

policies, _ := cedar.NewPolicySetFromBytes(policyBytes)
entities, _ := cedar.NewEntitySetFromJSON(entitiesJSON)
request := cedar.Request{
    Principal: principal,
    Action:    action,
    Resource:  resource,
    Context:   context,
}

decision, _ := policies.IsAuthorized(entities, request)
if decision.Allow {
    fmt.Println("Authorized")
} else {
    fmt.Println("Denied")
}
```

### WebAssembly

**Installation:**

```bash
npm install @cedar-policy/cedar-wasm
```

**Documentation:**

- npm: <https://www.npmjs.com/package/@cedar-policy/cedar-wasm>
- Repository: <https://github.com/cedar-policy/cedar/tree/main/cedar-wasm>

**Basic usage (JavaScript):**

```javascript
import init, { isAuthorized } from '@cedar-policy/cedar-wasm';

await init();

const result = isAuthorized({
  principal: 'User::"alice"',
  action: 'Action::"view"',
  resource: 'Photo::"photo.jpg"',
  policies: policiesString,
  entities: entitiesJSON,
  schema: schemaJSON
});

if (result.decision === 'Allow') {
  console.log('Authorized');
}
```

## CLI Tools

### Cedar CLI

**Installation:**

```bash
# macOS
brew install cedar

# Cargo (Rust)
cargo install cedar-policy-cli

# From source
git clone https://github.com/cedar-policy/cedar.git
cd cedar && cargo build --release
```

**Commands:**

- `cedar validate` - Validate policies against schema
- `cedar authorize` - Test authorization decision
- `cedar format` - Format policy files
- `cedar evaluate` - Evaluate policy expressions
- `cedar check-parse` - Check syntax

**Documentation:**

- Repository: <https://github.com/cedar-policy/cedar-cli>
- Usage: `cedar --help`

## Tutorials and Guides

### Getting Started

**Quick Start Tutorial**

- URL: <https://docs.cedarpolicy.com/tutorials/getting-started.html>
- Duration: 15 minutes
- Topics: Basic policies, schema, authorization

**Photo Sharing Application**

- URL: <https://docs.cedarpolicy.com/tutorials/photo-app.html>
- Duration: 30 minutes
- Topics: RBAC, resource hierarchies, context

**Document Management System**

- URL: <https://docs.cedarpolicy.com/tutorials/document-app.html>
- Duration: 45 minutes
- Topics: ABAC, attribute-based decisions, conditions

### Advanced Topics

**Policy Analysis and Validation**

- URL: <https://docs.cedarpolicy.com/policies/validation.html>
- Topics: Syntax validation, semantic validation, conflict detection

**Schema Design**

- URL: <https://docs.cedarpolicy.com/schema/schema-design.html>
- Topics: Entity types, relationships, attributes, namespaces

**Authorization Patterns**

- URL: <https://docs.cedarpolicy.com/patterns/>
- Topics: RBAC, ABAC, ReBAC, hybrid models

**Performance Optimization**

- URL: <https://docs.cedarpolicy.com/deployment/performance.html>
- Topics: Policy evaluation, caching, monitoring

**Testing Strategies**

- URL: <https://docs.cedarpolicy.com/testing/>
- Topics: Unit testing, integration testing, coverage

## Language Reference

### Policy Syntax

**Policy Structure**

- URL: <https://docs.cedarpolicy.com/policies/syntax-policy.html>
- Topics: Effects, scopes, conditions, annotations

**Operators**

- URL: <https://docs.cedarpolicy.com/policies/syntax-operators.html>
- Topics: Comparison, logical, set, string operators

**Functions**

- URL: <https://docs.cedarpolicy.com/policies/syntax-functions.html>
- Topics: Built-in functions, extension functions

**Entity References**

- URL: <https://docs.cedarpolicy.com/policies/syntax-entity.html>
- Topics: Entity UIDs, namespaces, literals

### Schema Syntax

**Schema Format**

- URL: <https://docs.cedarpolicy.com/schema/schema-format.html>
- Topics: JSON schema format, entity types, actions

**Entity Types**

- URL: <https://docs.cedarpolicy.com/schema/entity-types.html>
- Topics: Type definitions, attributes, member relationships

**Common Patterns**

- URL: <https://docs.cedarpolicy.com/schema/common-patterns.html>
- Topics: Hierarchies, inheritance, namespaces

## Integration Guides

### Application Integration

**Authorization in Web Apps**

- URL: <https://docs.cedarpolicy.com/integration/web-apps.html>
- Topics: Middleware, caching, error handling

**Authorization in Microservices**

- URL: <https://docs.cedarpolicy.com/integration/microservices.html>
- Topics: Distributed authorization, policy distribution, consistency

**API Gateway Integration**

- URL: <https://docs.cedarpolicy.com/integration/api-gateway.html>
- Topics: Request authorization, policy enforcement points

### AWS Integration

**Amazon Verified Permissions**

- URL: <https://aws.amazon.com/verified-permissions/>
- Service: Managed Cedar authorization service
- Features: Policy management, decision logging, CloudWatch integration

**Amazon Verified Permissions Documentation**

- URL: <https://docs.aws.amazon.com/verifiedpermissions/>
- Topics: Policy stores, schema management, API reference

**AWS SDK Integration**

- URL: <https://docs.aws.amazon.com/verifiedpermissions/latest/userguide/>
- Topics: CreatePolicyStore, IsAuthorized API calls

## Community Resources

### Blog Posts

**Cedar Announcement**

- URL: <https://aws.amazon.com/blogs/opensource/announcing-cedar/>
- Date: May 2023
- Topics: Introduction, design goals, use cases

**Cedar Policy Analysis**

- URL: <https://www.amazon.science/blog/how-we-built-cedar>
- Topics: Automated reasoning, policy validation

### Videos

**Cedar Introduction (YouTube)**

- Search: "AWS Cedar Policy Language Introduction"
- Topics: Overview, demo, use cases

**Cedar Deep Dive (re:Invent)**

- Search: "AWS re:Invent Cedar"
- Topics: Architecture, design decisions, case studies

### Research Papers

**Automated Reasoning and Language Design for Authorization**

- URL: <https://arxiv.org/abs/2302.03770>
- Topics: Formal methods, policy analysis, SMT solving

## API Reference

### Rust API

**Core Types**

- `PolicySet` - Collection of policies
- `Entities` - Entity store
- `Request` - Authorization request
- `Authorizer` - Decision engine
- `Schema` - Schema validator

**API Documentation**

- URL: <https://docs.rs/cedar-policy/latest/cedar_policy/>

### Java API

**Core Classes**

- `AuthorizationEngine` - Decision engine
- `PolicySet` - Policy collection
- `Entities` - Entity store
- `Request` - Authorization request
- `Schema` - Schema definition

**API Documentation**

- URL: <https://cedar-policy.github.io/cedar-java/>

### Go API

**Core Types**

- `PolicySet` - Policy collection
- `EntitySet` - Entity store
- `Request` - Authorization request
- `Decision` - Authorization result

**API Documentation**

- URL: <https://pkg.go.dev/github.com/cedar-policy/cedar-go>

## Tools and Utilities

### Cedar Playground

**Online IDE**

- URL: <https://www.cedarpolicy.com/playground>
- Features: Interactive policy editor, validation, testing
- Use: Prototype policies, learn syntax, share examples

### VS Code Extension

**Cedar Language Support**

- Marketplace: Search "Cedar Policy Language"
- Features: Syntax highlighting, validation, snippets
- Repository: <https://github.com/cedar-policy/cedar-vscode>

### Policy Formatters

**cedar-format**

- Command: `cedar format --policy policy.cedar`
- Features: Consistent formatting, style enforcement

## Support and Community

### GitHub Discussions

**Cedar Discussions**

- URL: <https://github.com/cedar-policy/cedar/discussions>
- Topics: Questions, feature requests, use cases

### Issue Tracking

**Cedar Issues**

- URL: <https://github.com/cedar-policy/cedar/issues>
- Purpose: Bug reports, feature requests

### Security

**Security Policy**

- URL: <https://github.com/cedar-policy/cedar/security/policy>
- Contact: Report security issues responsibly

### Contributing

**Contributing Guide**

- URL: <https://github.com/cedar-policy/cedar/blob/main/CONTRIBUTING.md>
- Topics: Code contributions, documentation, testing

## Standards and Specifications

### Cedar Specification

**Language Specification**

- URL: <https://cedar-policy.github.io/cedar-spec/>
- Sections: Syntax, semantics, type system, validation

**EBNF Grammar**

- URL: <https://cedar-policy.github.io/cedar-spec/syntax.html>
- Format: Extended Backus-Naur Form
- Use: Parser implementation, language reference

### Schema Specification

**JSON Schema Format**

- URL: <https://docs.cedarpolicy.com/schema/json-schema.html>
- Topics: Entity type definitions, action definitions

**Cedar Schema Grammar**

- URL: <https://docs.cedarpolicy.com/schema/grammar.html>
- Format: Human-readable schema syntax
- Use: Schema authoring, documentation

## Release Notes

### Latest Release

**Current Version**: Check <https://github.com/cedar-policy/cedar/releases>

**Release Notes**

- URL: <https://github.com/cedar-policy/cedar/blob/main/CHANGELOG.md>
- Content: New features, bug fixes, breaking changes

**Migration Guides**

- URL: <https://docs.cedarpolicy.com/migration/>
- Topics: Upgrade procedures, breaking changes, compatibility

## Additional Resources

### Academic Resources

**Formal Methods Papers**

- Search: Google Scholar "Cedar Policy Language"
- Topics: Verification, analysis, automated reasoning

### Conference Talks

**AWS re:Invent Sessions**

- Search: "re:Invent Cedar" on YouTube
- Topics: Case studies, best practices, roadmap

### Case Studies

**Customer Success Stories**

- URL: <https://aws.amazon.com/verified-permissions/customers/>
- Topics: Real-world implementations, lessons learned

---

This documentation collection provides comprehensive resources for learning, implementing, and mastering Cedar
authorization policies. Refer to official documentation for the most up-to-date information.
