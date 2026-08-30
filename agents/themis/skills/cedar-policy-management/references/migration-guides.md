# Cedar Migration Guides

Comprehensive guides for migrating from various authorization systems to Cedar.

## Migration Overview

### Why Migrate to Cedar?

Benefits of migrating to Cedar:

- **Declarative policies**: Easier to understand and audit than imperative code
- **Formal verification**: Automated reasoning catches errors before deployment
- **Performance**: Microsecond policy evaluation
- **Separation of concerns**: Policies separate from application code
- **Type safety**: Schema validation prevents errors

### Migration Approach

**Recommended migration strategy:**

1. **Analyze current system**: Document existing authorization logic
2. **Design Cedar model**: Map concepts to Cedar entities and policies
3. **Implement incrementally**: Migrate component by component
4. **Test thoroughly**: Verify behavior matches original system
5. **Deploy gradually**: Canary deployment with monitoring
6. **Decommission old system**: Remove legacy authorization code

## Migrating from Code-Based Authorization

### From Imperative Code

**Before (Python):**

```python
def can_edit_document(user, document):
    # Inline authorization logic
    if user.role == "admin":
        return True

    if document.owner_id == user.id:
        return True

    if user.role == "editor" and user.department == document.department:
        return True

    return False
```

**After (Cedar):**

```cedar
// Admin can edit any document
permit(
  principal in Role::"admin",
  action == Action::"edit",
  resource is Document
);

// Owner can edit their documents
permit(
  principal,
  action == Action::"edit",
  resource
) when {
  resource.owner == principal
};

// Editors can edit department documents
permit(
  principal in Role::"editor",
  action == Action::"edit",
  resource is Document
) when {
  principal.department == resource.department
};
```

**Application code:**

```python
from cedar_policy import Authorizer, Request

def can_edit_document(user, document):
    request = Request(
        principal=f'User::"{user.id}"',
        action='Action::"edit"',
        resource=f'Document::"{document.id}"'
    )

    response = authorizer.is_authorized(request, policies, entities)
    return response.is_allowed()
```

### From Annotation-Based Authorization

**Before (Java annotations):**

```java
@RestController
public class DocumentController {

    @PreAuthorize("hasRole('ADMIN') or @documentSecurity.isOwner(#id, principal)")
    @PutMapping("/documents/{id}")
    public Document updateDocument(@PathVariable Long id, @RequestBody Document doc) {
        return documentService.update(id, doc);
    }
}
```

**After (Cedar with middleware):**

```java
@RestController
public class DocumentController {

    @CedarAuthorize(action = "edit", resourceType = "Document")
    @PutMapping("/documents/{id}")
    public Document updateDocument(@PathVariable Long id, @RequestBody Document doc) {
        return documentService.update(id, doc);
    }
}
```

**Cedar middleware:**

```java
@Aspect
@Component
public class CedarAuthorizationAspect {

    @Around("@annotation(cedarAuthorize)")
    public Object authorize(ProceedingJoinPoint joinPoint, CedarAuthorize cedarAuthorize) {
        String principal = getCurrentUser();
        String action = cedarAuthorize.action();
        String resource = extractResourceId(joinPoint);

        Request request = new Request(principal, action, resource);
        AuthorizationResponse response = authorizationEngine.isAuthorized(request, policies, entities);

        if (!response.isAllowed()) {
            throw new AccessDeniedException("Not authorized");
        }

        return joinPoint.proceed();
    }
}
```

## Migrating from AWS IAM

### IAM Policy Structure

**IAM policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::my-bucket/*",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalTag/Department": "Engineering"
        }
      }
    }
  ]
}
```

**Equivalent Cedar:**

```cedar
permit(
  principal,
  action in [Action::"s3:GetObject", Action::"s3:PutObject"],
  resource in Bucket::"my-bucket"
) when {
  principal.department == "Engineering"
};
```

### IAM Concepts to Cedar

| IAM Concept     | Cedar Equivalent | Notes                     |
| --------------- | ---------------- | ------------------------- |
| Principal (ARN) | Principal entity | Map ARN to entity UID     |
| Action          | Action           | Direct mapping            |
| Resource (ARN)  | Resource entity  | Map ARN to entity UID     |
| Condition       | `when` clause    | Map condition operators   |
| Effect: Allow   | `permit`         | Direct mapping            |
| Effect: Deny    | `forbid`         | `forbid` takes precedence |

### IAM Condition Operators

**StringEquals:**

```json
"Condition": {
  "StringEquals": {
    "aws:PrincipalTag/Department": "Engineering"
  }
}
```

**Cedar:**

```cedar
when {
  principal.department == "Engineering"
}
```

**NumericGreaterThan:**

```json
"Condition": {
  "NumericGreaterThan": {
    "custom:ClearanceLevel": "2"
  }
}
```

**Cedar:**

```cedar
when {
  principal.clearanceLevel > 2
}
```

**DateGreaterThan:**

```json
"Condition": {
  "DateGreaterThan": {
    "aws:CurrentTime": "2024-01-01T00:00:00Z"
  }
}
```

**Cedar:**

```cedar
when {
  context.currentTime > "2024-01-01T00:00:00Z"
}
```

## Migrating from OPA (Open Policy Agent)

### OPA Rego to Cedar

**OPA policy (Rego):**

```rego
package authz

import future.keywords.if

default allow = false

allow if {
    input.method == "GET"
    input.path[0] == "documents"
    input.user.role == "viewer"
}

allow if {
    input.method == "POST"
    input.path[0] == "documents"
    input.user.role == "editor"
    input.user.department == input.document.department
}
```

**Equivalent Cedar:**

```cedar
// Viewers can GET documents
permit(
  principal in Role::"viewer",
  action == Action::"GET",
  resource is Document
);

// Editors can POST documents in their department
permit(
  principal in Role::"editor",
  action == Action::"POST",
  resource is Document
) when {
  principal.department == resource.department
};
```

### OPA to Cedar Migration Steps

1. **Extract OPA rules**: Identify authorization rules in Rego
2. **Map input to entities**: Convert OPA input structure to Cedar entities
3. **Convert rules to policies**: Transform Rego rules to Cedar policies
4. **Test equivalence**: Verify same authorization decisions
5. **Deploy Cedar**: Replace OPA with Cedar authorization engine

### Conceptual Mapping

| OPA Concept    | Cedar Equivalent | Notes                   |
| -------------- | ---------------- | ----------------------- |
| input.user     | Principal entity | Map input to entity     |
| input.resource | Resource entity  | Map input to entity     |
| input.action   | Action           | Direct mapping          |
| allow = true   | `permit`         | Default deny in both    |
| allow = false  | (implicit)       | No policy means deny    |
| package        | Policy namespace | Use policy IDs          |
| import         | (not needed)     | Cedar is self-contained |

## Migrating from Zanzibar

### Zanzibar ReBAC Model

**Zanzibar tuple:**

```text
document:doc1#viewer@user:alice
document:doc1#owner@user:bob
folder:folder1#member@document:doc1
```

**Zanzibar check:**

```text
check(user:alice, view, document:doc1)
```

**Equivalent Cedar entities:**

```json
[
  {
    "uid": { "type": "User", "id": "alice" },
    "attrs": {},
    "parents": []
  },
  {
    "uid": { "type": "User", "id": "bob" },
    "attrs": {},
    "parents": []
  },
  {
    "uid": { "type": "Document", "id": "doc1" },
    "attrs": {
      "owner": { "type": "User", "id": "bob" },
      "viewers": [{ "type": "User", "id": "alice" }]
    },
    "parents": [{ "type": "Folder", "id": "folder1" }]
  }
]
```

**Equivalent Cedar policies:**

```cedar
// Owners can view documents
permit(
  principal,
  action == Action::"view",
  resource
) when {
  resource.owner == principal
};

// Viewers can view documents
permit(
  principal,
  action == Action::"view",
  resource
) when {
  principal in resource.viewers
};
```

### Zanzibar Concepts to Cedar

| Zanzibar Concept | Cedar Equivalent        | Notes                               |
| ---------------- | ----------------------- | ----------------------------------- |
| Tuple            | Entity relationship     | Use `parents` or attributes         |
| Object           | Resource entity         | Direct mapping                      |
| Subject          | Principal entity        | Direct mapping                      |
| Relation         | Attribute or membership | Model as entity attribute or parent |
| Check            | Authorization request   | Use `is_authorized` API             |
| Expand           | (not needed)            | Cedar evaluates transitively        |

### Zanzibar Userset Rewrite

**Zanzibar (union):**

```text
userset_rewrite {
  union {
    child { _this {} }
    child { computed_userset { relation: "editor" } }
  }
}
```

**Cedar:**

```cedar
// Union: viewer or editor can read
permit(
  principal,
  action == Action::"read",
  resource
) when {
  principal in resource.viewers ||
  principal in resource.editors
};
```

## Migrating from Custom RBAC Systems

### Database-Driven RBAC

**Before (SQL):**

```sql
-- Tables
CREATE TABLE users (id, name, role_id);
CREATE TABLE roles (id, name);
CREATE TABLE role_permissions (role_id, permission);

-- Query to check permission
SELECT COUNT(*) FROM role_permissions rp
JOIN users u ON u.role_id = rp.role_id
WHERE u.id = ? AND rp.permission = ?;
```

**After (Cedar):**

```cedar
// Define role-based permissions
permit(
  principal in Role::"admin",
  action,
  resource
);

permit(
  principal in Role::"editor",
  action in [Action::"read", Action::"write"],
  resource is Document
);

permit(
  principal in Role::"viewer",
  action == Action::"read",
  resource is Document
);
```

**Entity loading:**

```python
# Load entities from database
def load_entities():
    users = db.query("SELECT id, role_id FROM users")
    roles = db.query("SELECT id, name FROM roles")

    entities = []

    for role in roles:
        entities.append({
            "uid": {"type": "Role", "id": role.name},
            "attrs": {},
            "parents": []
        })

    for user in users:
        role_name = get_role_name(user.role_id)
        entities.append({
            "uid": {"type": "User", "id": str(user.id)},
            "attrs": {},
            "parents": [{"type": "Role", "id": role_name}]
        })

    return entities
```

### Configuration-File RBAC

**Before (YAML):**

```yaml
roles:
  admin:
    permissions:
      - "*:*:*"
  editor:
    permissions:
      - "documents:read:*"
      - "documents:write:*"
  viewer:
    permissions:
      - "documents:read:*"
```

**After (Cedar):**

```cedar
permit(
  principal in Role::"admin",
  action,
  resource
);

permit(
  principal in Role::"editor",
  action in [Action::"read", Action::"write"],
  resource is Document
);

permit(
  principal in Role::"viewer",
  action == Action::"read",
  resource is Document
);
```

## Migration Patterns

### Incremental Migration

Migrate one component at a time:

```python
class HybridAuthorizationService:
    def __init__(self):
        self.cedar_authorizer = CedarAuthorizer()
        self.legacy_authorizer = LegacyAuthorizer()
        self.cedar_enabled_resources = {"Document", "Folder"}

    def authorize(self, principal, action, resource):
        resource_type = get_resource_type(resource)

        if resource_type in self.cedar_enabled_resources:
            # Use Cedar for migrated resources
            return self.cedar_authorizer.authorize(principal, action, resource)
        else:
            # Use legacy system for not-yet-migrated resources
            return self.legacy_authorizer.authorize(principal, action, resource)
```

### Shadow Mode

Run Cedar alongside legacy system for validation:

```python
def authorize_with_validation(principal, action, resource):
    # Get decision from legacy system
    legacy_decision = legacy_authorizer.authorize(principal, action, resource)

    # Get decision from Cedar
    cedar_decision = cedar_authorizer.authorize(principal, action, resource)

    # Log discrepancies
    if legacy_decision != cedar_decision:
        log_authorization_mismatch(principal, action, resource, legacy_decision, cedar_decision)

    # Return legacy decision (Cedar is in shadow mode)
    return legacy_decision
```

### Parallel Evaluation

Compare results before full migration:

```python
def authorize_with_comparison(principal, action, resource):
    # Evaluate both systems
    legacy_result = legacy_authorizer.authorize(principal, action, resource)
    cedar_result = cedar_authorizer.authorize(principal, action, resource)

    # Emit metrics
    metrics.increment("authorization.legacy", tags={"decision": legacy_result})
    metrics.increment("authorization.cedar", tags={"decision": cedar_result})

    if legacy_result != cedar_result:
        metrics.increment("authorization.mismatch")
        alert_security_team(principal, action, resource, legacy_result, cedar_result)

    # Return legacy result for now
    return legacy_result
```

## Migration Checklist

### Pre-Migration

- [ ] Document current authorization logic
- [ ] Identify all authorization decision points
- [ ] List all principals, resources, and actions
- [ ] Map current model to Cedar concepts
- [ ] Design Cedar schema
- [ ] Write Cedar policies
- [ ] Create test cases for current behavior
- [ ] Set up Cedar infrastructure

### Migration Phase

- [ ] Implement Cedar authorization engine
- [ ] Load entities from existing systems
- [ ] Deploy Cedar in shadow mode
- [ ] Compare Cedar decisions with legacy system
- [ ] Fix discrepancies
- [ ] Achieve 100% match rate
- [ ] Migrate one component in production
- [ ] Monitor for issues
- [ ] Gradually migrate remaining components

### Post-Migration

- [ ] Remove legacy authorization code
- [ ] Update documentation
- [ ] Train team on Cedar
- [ ] Establish policy review process
- [ ] Set up monitoring and alerting
- [ ] Plan for policy evolution

## Common Migration Challenges

### Challenge: Complex Business Logic

**Problem**: Authorization embedded with complex business logic

**Solution**: Extract pure authorization logic to Cedar, keep business rules in application

```python
# Before: Mixed authorization and business logic
def can_approve_purchase(user, purchase):
    if not user.has_permission("approve_purchase"):
        return False

    if purchase.amount > user.approval_limit:
        return False

    if purchase.department != user.department:
        return False

    # Business rule (not authorization)
    if purchase.vendor.is_blacklisted:
        return False

    return True

# After: Separated concerns
def can_approve_purchase(user, purchase):
    # Authorization in Cedar
    if not cedar_authorizer.is_authorized(user, "approve", purchase):
        return False

    # Business rule in application
    if purchase.vendor.is_blacklisted:
        return False

    return True
```

**Cedar policy:**

```cedar
permit(
  principal,
  action == Action::"approve",
  resource is Purchase
) when {
  resource.amount <= principal.approvalLimit &&
  resource.department == principal.department
};
```

### Challenge: Dynamic Permissions

**Problem**: Permissions change frequently at runtime

**Solution**: Use entity attributes for dynamic data, policies for static logic

```cedar
// Static policy structure
permit(
  principal,
  action == Action::"access",
  resource
) when {
  principal in resource.authorizedUsers &&
  context.currentTime < resource.accessExpiresAt
};
```

**Dynamic entity updates:**

```python
# Update entity attributes dynamically
def grant_temporary_access(user, resource, duration):
    entities.update_entity(
        resource_id=resource.id,
        attrs={
            "authorizedUsers": resource.authorized_users + [user.id],
            "accessExpiresAt": now() + duration
        }
    )
```

### Challenge: Performance Requirements

**Problem**: High-throughput authorization checks

**Solution**: Cache policy evaluation results, optimize entity loading

```python
class CachedCedarAuthorizer:
    def __init__(self):
        self.authorizer = CedarAuthorizer()
        self.cache = TTLCache(maxsize=10000, ttl=300)  # 5-minute cache

    def authorize(self, principal, action, resource):
        cache_key = f"{principal}:{action}:{resource}"

        if cache_key in self.cache:
            return self.cache[cache_key]

        result = self.authorizer.authorize(principal, action, resource)
        self.cache[cache_key] = result
        return result
```

## Migration Tools

### Policy Generator

Automate policy generation from existing configuration:

```python
# Convert YAML roles to Cedar policies
def generate_cedar_policies(yaml_config):
    policies = []

    for role_name, role_config in yaml_config["roles"].items():
        for permission in role_config["permissions"]:
            resource_type, action, resource_id = permission.split(":")

            policy = f"""
permit(
  principal in Role::"{role_name}",
  action == Action::"{action}",
  resource is {resource_type.capitalize()}
);
"""
            policies.append(policy)

    return policies
```

### Entity Exporter

Export entities from existing database:

```python
def export_entities_from_database():
    users = db.query("SELECT * FROM users")
    groups = db.query("SELECT * FROM groups")
    memberships = db.query("SELECT * FROM user_groups")

    entities = []

    # Export groups
    for group in groups:
        entities.append({
            "uid": {"type": "Group", "id": group.name},
            "attrs": {"description": group.description},
            "parents": []
        })

    # Export users with group memberships
    for user in users:
        user_groups = [m.group_id for m in memberships if m.user_id == user.id]
        parents = [{"type": "Group", "id": g} for g in user_groups]

        entities.append({
            "uid": {"type": "User", "id": str(user.id)},
            "attrs": {
                "email": user.email,
                "department": user.department
            },
            "parents": parents
        })

    return entities
```

---

Migrating to Cedar provides long-term benefits of declarative, analyzable, and maintainable authorization. Follow
incremental migration strategies to minimize risk and validate correctness at each step.
