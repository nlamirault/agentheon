---
name: cedar-policy-management
description: This skill should be used when the user asks about "cedar-policy", "cedar best practices", "cedar management", "authorization policies", "policy validation", "schema design", or mentions Cedar policy syntax, entity types, or permission modeling. Provides comprehensive guidance for AWS Cedar authorization policies and schemas.
license: Apache-2.0
allowed-tools: Read Write Glob
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - cedar
  - aws-verified-access
  task: [configure, secure, audit]
  persona: [security-engineer, developer]
  workload: [security]
---

# Cedar Policy Management

Cedar is a language for defining permissions as policies, which describe who should have access to what. Cedar is
designed to be easy to understand, fast to evaluate, and integrated into your application. This skill provides guidance
on writing, validating, and architecting Cedar authorization policies and schemas.

## Core Concepts

### What is Cedar?

Cedar is an open-source language for writing authorization policies that you can use in your applications. Policies are
separate from application code, enabling security teams to review, audit, and modify access control logic without
changing code.

**Key characteristics:**

- **Declarative**: Express authorization logic as policies, not procedural code
- **Expressive**: Support RBAC, ABAC, ReBAC, and hybrid models
- **Fast**: Policies evaluate in microseconds
- **Analyzable**: Automated reasoning validates policies before deployment
- **Auditable**: Human-readable policies facilitate security reviews

### Cedar Components

**Policies**: Rules that grant or forbid actions on resources
**Schemas**: Define entity types, relationships, and attributes
**Entities**: Principals (users, roles), resources (documents, files), and actions (read, write)
**Context**: Additional request information for policy evaluation

## Architectural Principles

Cedar follows specific architectural best practices based on official Cedar documentation:

### Action Design

Actions should map to **business domain operations** rather than HTTP methods or generic CRUD. Use descriptive action
names like `CreateSupportCase`, `ApproveExpense`, `PublishArticle` instead of `POST`, `write`, or `create`.

### Single User Type Pattern

Use **one `User` entity type** for all users, with role differentiation through `Group` membership. Avoid creating
separate entity types for each role (e.g., `AdminUser`, `EditorUser`). This provides simpler schema, flexible role
changes, and centralized permission management.

### Comprehensive Policy Model

Move **ALL permissions determination logic** to Cedar policies. Avoid maintaining dual authorization systems where some
decisions are in Cedar and others are in application code or database tables.

### Resource Containers

**Every resource should reside within a container structure** for organizational clarity and policy management. Design
hierarchical resource structures (Documents → Folders → Departments → Organization).

### Principal-Container Separation

Keep principals (users, groups) **architecturally distinct** from resource containers. Separate user hierarchies from
resource hierarchies and use attributes to link them.

### Data Handling

- **Normalize input data** before authorization API calls
- **Context field discipline**: Context should contain only request-specific data (time, IP, MFA status), not principal,
  action, or resource information
- **Immutable identifiers**: Use UUIDs or permanent IDs, not changeable identifiers like email addresses or usernames

For comprehensive details on these principles, see `references/best-practices.md` sections on Core Authorization
Principles, Architectural Principles, and Data Handling Principles.

## Policy Structure

Cedar policies follow a standard structure:

```cedar
permit(
  principal == User::"alice",
  action == Action::"viewPhoto",
  resource == Photo::"VacationPhoto94.jpg"
);
```

**Key elements:**

- **Effect**: `permit` or `forbid`
- **Principal scope**: Who the policy applies to
- **Action scope**: What actions are allowed
- **Resource scope**: Which resources are affected
- **Conditions** (optional): Additional constraints using `when` or `unless`

### Policy Anatomy

```cedar
permit(
  principal in Group::"admins",
  action in [Action::"read", Action::"write"],
  resource in Folder::"protected"
)
when {
  context.ip_address.isInRange(ip("10.0.0.0/8"))
};
```

**Principal clause**: Defines who the policy applies to

- `principal == User::"alice"` - Specific user
- `principal in Group::"admins"` - Members of a group
- `principal is User` - Any user entity type

**Action clause**: Specifies allowed actions

- `action == Action::"read"` - Single action
- `action in [Action::"read", Action::"write"]` - Multiple actions
- `action in Action::"read"` - Action hierarchy

**Resource clause**: Identifies target resources

- `resource == Photo::"photo.jpg"` - Specific resource
- `resource in Folder::"documents"` - Resources in a container
- `resource is Document` - Any resource of a type

**Conditions**: Additional constraints

- `when { ... }` - Must be true for policy to apply
- `unless { ... }` - Must be false for policy to apply

## Policy Patterns

### Role-Based Access Control (RBAC)

Grant permissions based on role membership:

```cedar
permit(
  principal in Role::"editor",
  action in [Action::"read", Action::"write", Action::"delete"],
  resource is Document
);
```

### Attribute-Based Access Control (ABAC)

Use attributes for fine-grained control:

```cedar
permit(
  principal,
  action == Action::"read",
  resource
)
when {
  resource.classification == "public" ||
  (resource.classification == "internal" && principal.department == resource.department)
};
```

### Relationship-Based Access Control (ReBAC)

Base decisions on relationships between entities:

```cedar
permit(
  principal,
  action == Action::"edit",
  resource
)
when {
  resource.owner == principal ||
  principal in resource.editors
};
```

For comprehensive patterns including hierarchies, delegation, and time-based policies, see
`references/policy-patterns.md`.

## Schema Design

Schemas define entity types and their relationships. Well-designed schemas enable expressive policies while maintaining
clarity.

### Entity Types

Define principals, resources, and their attributes:

```json
{
  "User": {
    "memberOfTypes": ["Group"],
    "shape": {
      "type": "Record",
      "attributes": {
        "department": { "type": "String" },
        "clearanceLevel": { "type": "Long" }
      }
    }
  }
}
```

### Relationships

Model entity hierarchies and memberships:

```json
{
  "Document": {
    "memberOfTypes": ["Folder"],
    "shape": {
      "type": "Record",
      "attributes": {
        "owner": { "type": "Entity", "name": "User" },
        "classification": { "type": "String" }
      }
    }
  }
}
```

For detailed schema design principles including inheritance, common entity types, and attribute patterns, see
`references/schema-design.md`.

## Policy Validation

Validate policies before deployment to catch errors and ensure correctness.

### Syntax Validation

Check policy syntax using Cedar CLI:

```bash
cedar validate --schema schema.cedarschema.json --policy-set policies/
```

### Semantic Validation

Verify policies are consistent with schema:

- Entity types exist in schema
- Attributes are defined for entity types
- Actions are valid for resource types

### Policy Analysis

Use automated reasoning to detect:

- **Conflicting policies**: `permit` and `forbid` for same request
- **Unreachable policies**: Policies that can never apply
- **Over-permissive policies**: Policies granting excessive access

For comprehensive testing strategies including unit tests, integration tests, and regression testing, see
`references/testing-strategies.md`.

## Best Practices

### Principle of Least Privilege

Grant minimum necessary permissions:

```cedar
// Good: Specific action and resource
permit(
  principal in Role::"viewer",
  action == Action::"read",
  resource in Folder::"public-documents"
);

// Avoid: Broad permissions
permit(
  principal in Role::"viewer",
  action,  // Any action
  resource // Any resource
);
```

### Explicit Deny

Use `forbid` policies for explicit denials:

```cedar
// Explicitly forbid deletion of critical resources
forbid(
  principal,
  action == Action::"delete",
  resource in Folder::"critical-data"
);
```

### Policy Organization

Structure policies for maintainability:

- **Group by role**: All policies for a role together
- **Group by resource**: All policies for a resource type together
- **Use descriptive IDs**: `policy-id` helps debugging and auditing

### Condition Complexity

Keep conditions simple and readable:

```cedar
// Good: Simple, clear condition
when {
  context.time.hour >= 9 && context.time.hour < 17
}

// Avoid: Complex nested conditions
when {
  (context.time.hour >= 9 && context.time.hour < 17) ||
  (context.time.day == "Saturday" && resource.priority == "high") ||
  (principal.onCall && context.severity >= 3)
}
```

For comprehensive best practices including policy review, security patterns, performance optimization, and common
pitfalls, see `references/best-practices.md`.

## Working with Cedar CLI

### Installation

Install Cedar CLI for policy validation and testing:

```bash
# macOS
brew install cedar

# Cargo (Rust)
cargo install cedar-policy-cli

# From source
git clone https://github.com/cedar-policy/cedar.git
cd cedar && cargo build --release
```

### Common Commands

**Validate policies**:

```bash
cedar validate --schema schema.cedarschema.json --policy-set policies/
```

**Format policies**:

```bash
cedar format --policy policy.cedar
```

**Authorize decision** (testing):

```bash
cedar authorize \
  --principal 'User::"alice"' \
  --action 'Action::"read"' \
  --resource 'Document::"doc1"' \
  --policy-set policies/ \
  --schema schema.cedarschema.json
```

### Integration Patterns

**Application integration**:

- Load policies at startup
- Evaluate policies on each authorization request
- Cache evaluation results when appropriate
- Log authorization decisions for audit

**Policy deployment**:

- Version control policies with application code
- Validate policies in CI/CD pipeline
- Test policies before production deployment
- Monitor authorization metrics

## Migration from Other Systems

Migrating to Cedar from existing authorization systems requires understanding mapping patterns and incremental migration
strategies.

### From Code-Based Authorization

Replace inline authorization checks with Cedar policies:

**Before** (code):

```python
if user.role == "admin" or user.id == document.owner_id:
    allow_access()
```

**After** (Cedar):

```cedar
permit(
  principal,
  action == Action::"access",
  resource
)
when {
  principal in Role::"admin" || resource.owner == principal
};
```

### From Policy-Based Systems

Map existing policy formats to Cedar syntax. Each system has different semantics requiring careful translation.

For detailed migration strategies including from OPA, AWS IAM, Zanzibar, and custom systems, see
`references/migration-guides.md`.

## Common Workflows

### Creating a New Policy

1. Identify authorization requirement
2. Determine entity types (principal, action, resource)
3. Write policy with appropriate scope
4. Add conditions if needed
5. Validate against schema
6. Test with sample requests
7. Deploy to production

### Reviewing Existing Policies

1. Load policies and schema
2. Check for conflicting policies
3. Verify least privilege principle
4. Look for over-permissive policies
5. Validate against current schema
6. Test authorization decisions
7. Document findings and recommendations

### Designing Authorization Model

1. Identify principals and resources
2. Define entity types and relationships
3. Create schema with attributes
4. Map authorization requirements to policies
5. Choose policy patterns (RBAC, ABAC, ReBAC)
6. Validate schema and policies
7. Test with realistic scenarios

## Additional Resources

### Reference Files

For detailed guidance on specific topics, consult:

- **`references/best-practices.md`** - Comprehensive best practices, security patterns, performance optimization, and
  common pitfalls
- **`references/documentation.md`** - Official Cedar documentation links, tutorials, and API references
- **`references/naming-conventions.md`** - Cedar naming conventions for entity types, IDs, attributes, actions, and
  context keys
- **`references/policy-patterns.md`** - Detailed policy patterns including hierarchies, delegation, temporal policies,
  and multi-tenancy
- **`references/schema-design.md`** - Schema design principles, common entity types, attribute patterns, and
  relationship modeling
- **`references/testing-strategies.md`** - Policy testing approaches including unit tests, integration tests, and
  regression testing
- **`references/migration-guides.md`** - Migration strategies from OPA, AWS IAM, Zanzibar, and other authorization
  systems

### Cedar Resources

- **Official Website**: <https://www.cedarpolicy.com/>
- **Documentation**: <https://docs.cedarpolicy.com/>
- **GitHub Repository**: <https://github.com/cedar-policy/cedar>
- **Specification**: <https://cedar-policy.github.io/cedar-spec/>
- **Examples**: <https://github.com/cedar-policy/cedar-examples>

### Plugin Commands

Use plugin commands for common tasks:

- **`/cedar:create-policy`** - Generate new policy with templates
- **`/cedar:validate-policy`** - Validate policy syntax and semantics

### Plugin Agent

For architectural guidance and policy review:

- **`cedar-architect`** - Expert Cedar architect for design, review, and optimization

## Quick Reference

### Policy Effects

- `permit` - Allow action
- `forbid` - Deny action (takes precedence)

### Scope Operators

- `==` - Exact match
- `in` - Membership or hierarchy
- `is` - Type check

### Condition Operators

- `&&` - Logical AND
- `||` - Logical OR
- `!` - Logical NOT
- `==`, `!=` - Equality
- `<`, `>`, `<=`, `>=` - Comparison
- `like` - String pattern matching

### Common Functions

- `has()` - Check attribute existence
- `contains()` - Check set membership
- `containsAll()`, `containsAny()` - Set operations
- `isInRange()` - IP address range check

---

Use this skill when working with Cedar policies to ensure secure, efficient, and maintainable authorization systems. For
specific topics, reference the detailed documentation files listed above.
