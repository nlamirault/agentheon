# Cedar Policy Best Practices

Comprehensive guide to writing secure, maintainable, and efficient Cedar authorization policies based on official Cedar
documentation and industry best practices.

## Core Authorization Principles

### Action Design

Actions should map to business domain operations rather than HTTP methods or generic CRUD operations.

**Enforce:**

- Use descriptive action names that reflect business intent
- Map actions to what users are trying to accomplish
- Avoid HTTP methods (GET, POST, PUT, DELETE) as action names
- Avoid generic CRUD when business operations are more specific

**Example:**

```cedar
// Good: Business-focused actions (camelCase)
permit(
  principal in Group::"support-agents",
  action == Action::"createSupportCase",
  resource is SupportSystem
);

permit(
  principal in Group::"managers",
  action == Action::"approveExpense",
  resource is ExpenseReport
);

permit(
  principal in Group::"editors",
  action == Action::"publishArticle",
  resource is Article
);

// Avoid: HTTP-focused or overly generic actions
permit(
  principal in Group::"support-agents",
  action == Action::"POST",  // What does POST mean in business terms?
  resource is SupportSystem
);

permit(
  principal in Group::"editors",
  action == Action::"write",  // Too generic - publish? draft? edit?
  resource is Article
);
```

**Action naming guidelines (use camelCase):**

- Finance: `approveExpense`, `submitInvoice`, `processPayment`
- Support: `createSupportCase`, `assignTicket`, `closeCase`
- Content: `publishArticle`, `reviewContent`, `archivePost`
- HR: `submitTimeOff`, `approveLeave`, `viewPayroll`

**For complete action naming conventions and examples, see `naming-conventions.md`.**

### Comprehensive Policy Model

Move ALL permissions determination logic to Cedar policies. Avoid maintaining dual authorization systems.

**Enforce:**

- Every authorization decision should go through Cedar
- Migrate all permissions logic from application code to policies
- Each row in a legacy permissions table should become a Cedar policy
- Do not duplicate authorization logic in application code

**Example:**

```cedar
// Convert legacy permissions table to policies
// Legacy: users table with role='admin', permission='delete_users'
// Cedar: Explicit policy

permit(
  principal in Role::"admin",
  action == Action::"DeleteUser",
  resource is User
);

// Legacy: permissions table with user_id, resource_id, action='edit'
// Cedar: Relationship-based policy

permit(
  principal,
  action == Action::"EditDocument",
  resource
) when {
  resource.owner == principal ||
  principal in resource.editors
};
```

**Warn if:**

- Application code contains authorization checks outside Cedar
- Permissions are checked in database queries before Cedar evaluation
- Multiple authorization systems exist (e.g., Cedar + legacy tables)

### Fine-Grained Permissions with UI Aggregation

Model permissions with granularity in the authorization engine while aggregating them in the UI for better user
experience.

**Recommend:**

```cedar
// Backend: Fine-grained permissions
permit(
  principal in Group::"editors",
  action == Action::"EditDocumentContent",
  resource is Document
);

permit(
  principal in Group::"editors",
  action == Action::"EditDocumentMetadata",
  resource is Document
);

permit(
  principal in Group::"editors",
  action == Action::"PublishDocument",
  resource is Document
);

// Frontend: Present as "Editor" role with aggregated permissions
// UI shows: "Editors can edit and publish documents"
// Backend: Three distinct authorization checks
```

**Benefits:**

- Precise audit trails
- Flexible permission combinations
- Easier to revoke specific permissions
- Better security through least privilege

## Architectural Principles

### Group-Based Access Control

Create a single user entity type and implement role differentiation through Groups rather than multiple user types.

**Enforce:**

- Use one `User` entity type for all users
- Model roles, teams, and permissions through `Group` membership
- Centralize permission management at group level
- Avoid creating separate entity types for each role

**Example:**

```cedar
// Good: Single User type with Group membership
{
  "User": {
    "memberOfTypes": ["Group"],
    "shape": {
      "type": "Record",
      "attributes": {
        "email": { "type": "String", "required": true },
        "department": { "type": "String", "required": true }
      }
    }
  },
  "Group": {
    "memberOfTypes": [],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String", "required": true },
        "type": { "type": "String", "required": true }  // "role", "team", "department"
      }
    }
  }
}

// Policies use group membership
permit(
  principal in Group::"editors",
  action == Action::"EditDocument",
  resource is Document
);

// Avoid: Multiple user types
{
  "AdminUser": { ... },
  "EditorUser": { ... },
  "ViewerUser": { ... }
}
```

**Benefits:**

- Simpler schema
- Flexible role changes (just change group membership)
- Easier to add new roles
- Single identity across system

### Resource Containers

Every resource should reside within a container structure for organizational clarity and policy management.

**Enforce:**

- Design hierarchical resource structures
- Place all resources in appropriate containers
- Use containers for permission inheritance
- Model organizational structure through containers

**Example:**

```cedar
// Schema: Resources in containers
{
  "Document": {
    "memberOfTypes": ["Folder"],  // Every document in a folder
    "shape": {
      "type": "Record",
      "attributes": {
        "title": { "type": "String", "required": true }
      }
    }
  },
  "Folder": {
    "memberOfTypes": ["Folder"],  // Folders can nest
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String", "required": true }
      }
    }
  }
}

// Policy: Grant access to folder contents
permit(
  principal in Group::"engineering",
  action == Action::"ViewDocument",
  resource in Folder::"engineering-docs"
);
```

**Container patterns:**

- Documents → Folders → Departments → Organization
- Files → Projects → Teams → Company
- Cases → Queues → Regions → Service
- Resources → Subscriptions → Tenants → Platform

### Principal-Container Separation

Keep principals (users, groups) architecturally distinct from resource containers to avoid complexity.

**Enforce:**

- Separate user hierarchies from resource hierarchies
- Do not mix principals and resources in same container structure
- Use attributes or references to link principals to resources

**Example:**

```cedar
// Good: Separate hierarchies
{
  // Principal hierarchy: User → Group → Department
  "User": { "memberOfTypes": ["Group"] },
  "Group": { "memberOfTypes": ["Department"] },
  "Department": { "memberOfTypes": [] },

  // Resource hierarchy: Document → Folder → Collection
  "Document": { "memberOfTypes": ["Folder"] },
  "Folder": { "memberOfTypes": ["Collection"] },
  "Collection": { "memberOfTypes": [] }
}

// Link via attributes, not mixed hierarchy
permit(
  principal,
  action == Action::"ViewDocument",
  resource
) when {
  principal.department == resource.department  // Attribute linking
};

// Avoid: Mixed hierarchy
{
  "User": { "memberOfTypes": ["Folder"] },  // Principal in resource container
  "Document": { "memberOfTypes": ["Department"] }  // Resource in principal container
}
```

**Why separation matters:**

- Clearer authorization logic
- Easier to understand and maintain
- Prevents circular dependencies
- Simpler policy reasoning

### Mutable Identifier Avoidance

Do not use changeable identifiers in policies to prevent authorization drift.

**Enforce:**

- Use immutable identifiers (UUIDs, permanent IDs)
- Avoid using usernames, email addresses, or display names
- Do not reference changeable attributes in entity UIDs
- Store changeable data in attributes, not entity IDs

**Example:**

```cedar
// Good: Immutable user IDs
permit(
  principal == User::"user-123e4567-e89b-12d3-a456-426614174000",
  action == Action::"AdministerSystem",
  resource
);

// Good: Immutable resource IDs
forbid(
  principal,
  action == Action::"Delete",
  resource == Document::"doc-789a0123-b456-78cd-e901-234567890abc"
);

// Avoid: Mutable identifiers
permit(
  principal == User::"alice@example.com",  // Email might change
  action == Action::"AdministerSystem",
  resource
);

forbid(
  principal,
  action == Action::"Delete",
  resource == Document::"Q4-2024-Budget.xlsx"  // Filename might change
);
```

**Authorization drift risks:**

- User changes email → loses access
- Resource renamed → policies no longer apply
- Username changed → security policies broken
- Display name updated → audit trail broken

**Best practice:**

- Entity UID: Immutable identifier
- Entity attributes: Changeable data (name, email, title)
- Policies reference: Entity UIDs and immutable attributes

## Data Handling Principles

### Data Normalization

Normalize input data prior to invoking the authorization APIs to ensure consistency and prevent injection issues.

**Enforce:**

- Normalize all entity UIDs before authorization calls
- Standardize attribute formats (dates, emails, case)
- Validate input data structure
- Sanitize user-provided data

**Example:**

```python
# Good: Normalize before authorization
def authorize_action(user_input, action, resource_input):
    # Normalize user ID
    user_id = normalize_user_id(user_input)  # Trim, lowercase, validate
    principal = f'User::"{user_id}"'

    # Normalize resource ID
    resource_id = normalize_resource_id(resource_input)  # Validate UUID format
    resource = f'Document::"{resource_id}"'

    # Normalize action
    action_name = normalize_action(action)  # Validate against allowed actions
    action_uid = f'Action::"{action_name}"'

    # Now authorize with normalized data
    return authorizer.is_authorized(principal, action_uid, resource)

# Avoid: Direct user input
def authorize_action(user_input, action, resource_input):
    # Dangerous: No normalization
    principal = f'User::"{user_input}"'  # Could contain injection
    resource = f'Document::"{resource_input}"'
    return authorizer.is_authorized(principal, action, resource)
```

**Normalization checklist:**

- Trim whitespace
- Convert case (lowercase emails, IDs)
- Validate format (UUIDs, email format)
- Check against allowed values
- Escape special characters
- Validate entity types

### Context Field Discipline

The context field should contain only request-specific data, not information about the principal, action, or resource.

**Enforce:**

- Context contains: time, IP address, MFA status, request metadata
- Context does NOT contain: user ID, action name, resource ID
- Use designated fields for principal, action, and resource
- Keep context for supplementary authorization factors

**Example:**

```python
# Good: Context for supplementary data
context = {
    "time": {
        "hour": 14,
        "dayOfWeek": "Monday",
        "timestamp": "2024-01-15T14:30:00Z"
    },
    "network": {
        "ipAddress": "10.0.1.50",
        "location": "US-West"
    },
    "security": {
        "mfaVerified": True,
        "deviceTrusted": True
    },
    "request": {
        "userAgent": "Mozilla/5.0...",
        "requestId": "req-12345"
    }
}

# Avoid: Context with principal/action/resource data
context = {
    "userId": "alice",  # Should be in principal field
    "action": "edit",  # Should be in action field
    "documentId": "doc-123",  # Should be in resource field
    "userRole": "editor",  # Should be User entity attribute
    "documentOwner": "bob"  # Should be Document entity attribute
}
```

**Why context discipline matters:**

- Clear separation of concerns
- Correct policy evaluation
- Better performance (Cedar optimizes principal/action/resource)
- Prevents confusion and errors

**Context usage in policies:**

```cedar
// Good: Context for time-based rules
permit(
  principal in Group::"contractors",
  action,
  resource
) when {
  context.time.hour >= 9 && context.time.hour < 17
};

// Good: Context for security requirements
permit(
  principal,
  action == Action::"DeleteResource",
  resource
) when {
  context.security.mfaVerified &&
  resource.owner == principal
};
```

### Policy Scope Population

When feasible, populate the policy evaluation scope to improve performance and clarity.

**Recommend:**

- Provide entity data for all entities referenced in request
- Include entities in the evaluation scope when possible
- Pre-load frequently accessed entities
- Cache entity hierarchies

**Example:**

```python
# Good: Populate scope with relevant entities
def authorize_with_scope(principal_id, action, resource_id):
    # Build complete entity scope
    entities = []

    # Add principal and its parents
    user = get_user(principal_id)
    entities.append(user)
    entities.extend(get_user_groups(principal_id))

    # Add resource and its parents
    document = get_document(resource_id)
    entities.append(document)
    entities.extend(get_document_folders(resource_id))

    # Authorize with full scope
    response = authorizer.is_authorized(
        principal=f'User::"{principal_id}"',
        action=action,
        resource=f'Document::"{resource_id}"',
        entities=entities
    )

    return response.decision

# Less optimal: Minimal scope
def authorize_minimal(principal_id, action, resource_id):
    # Only principal and resource, no hierarchy
    response = authorizer.is_authorized(
        principal=f'User::"{principal_id}"',
        action=action,
        resource=f'Document::"{resource_id}"',
        entities=[]  # Cedar must fetch relationships
    )
    return response.decision
```

**Benefits:**

- Faster policy evaluation
- Complete evaluation context
- Predictable performance
- Better caching

## Security Principles

### Principle of Least Privilege

Grant only the minimum permissions necessary for users to perform their tasks.

**Enforce:**

- Specify explicit principals, actions, and resources
- Avoid wildcard policies unless absolutely necessary
- Use narrow scopes with `==` over broad scopes with `in` when possible
- Review and remove unused permissions regularly

**Example:**

```cedar
// Good: Specific permissions
permit(
  principal in Group::"analysts",
  action == Action::"read",
  resource in Folder::"reports"
);

// Avoid: Overly broad
permit(
  principal in Group::"analysts",
  action,  // Any action
  resource // Any resource
);
```

### Defense in Depth

Layer multiple security controls for comprehensive protection.

**Enforce:**

- Combine Cedar policies with application-level checks
- Use `forbid` policies for critical resources
- Implement both positive (permit) and negative (forbid) policies
- Add context-based conditions for sensitive operations

**Example:**

```cedar
// Permit regular access
permit(
  principal in Group::"editors",
  action in [Action::"read", Action::"write"],
  resource is Document
);

// Explicitly forbid deletion of protected resources
forbid(
  principal,
  action == Action::"delete",
  resource in Folder::"protected"
);
```

### Explicit Deny Over Implicit Deny

Use `forbid` policies to make denials explicit and auditable.

**Enforce:**

- Use `forbid` for security-critical denials
- Document why denials exist
- `forbid` policies take precedence over `permit`

**Example:**

```cedar
// Explicitly prevent deletion of audit logs
forbid(
  principal,
  action == Action::"delete",
  resource in Folder::"audit-logs"
) when {
  !principal.has("auditAdmin")
};
```

## Policy Organization

### Logical Grouping

Organize policies by role, resource type, or security domain.

**Recommend:**

- Group related policies in same file
- Use meaningful file names (e.g., `admin-policies.cedar`, `document-policies.cedar`)
- Maintain consistent organization across projects

**Example structure:**

```text
policies/
├── admin-policies.cedar       # Administrative permissions
├── editor-policies.cedar      # Content editor permissions
├── viewer-policies.cedar      # Read-only permissions
└── system-policies.cedar      # System-level restrictions
```

### Policy Annotations

Add comments to explain policy intent and context.

**Recommend:**

```cedar
// RBAC-001: Grant editors full access to their team's documents
// Owner: Security Team
// Last Updated: 2024-01-15
permit(
  principal in Group::"editors",
  action in [Action::"read", Action::"write", Action::"delete"],
  resource
) when {
  resource.team == principal.team
};
```

### Policy Identifiers

Use descriptive policy IDs for debugging and auditing.

**Recommend:**

```cedar
@id("rbac-editor-document-access")
permit(
  principal in Group::"editors",
  action in [Action::"read", Action::"write"],
  resource is Document
);
```

### Naming Conventions

Follow consistent naming conventions across all Cedar elements.

**Enforce:**

- Entity types: PascalCase (e.g., `User`, `Document`, `PhotoAlbum`)
- Entity IDs: Opaque identifiers (UUIDs) or camelCase for actions
- Attributes: camelCase (e.g., `countryOfOrigin`, `createdAt`)
- Actions: camelCase business operations (e.g., `createSupportCase`, `approveExpense`)
- Context keys: camelCase (e.g., `uploadFileSize`, `http.headers.userAgent`)

**Why consistency matters:**

- Improved readability across policies
- Reduced naming errors and confusion
- Easier collaboration across teams
- Predictable patterns for new developers
- Better maintainability over time

**For comprehensive naming conventions including examples, anti-patterns, and detailed guidance, see
`naming-conventions.md`.**

## Condition Design

### Keep Conditions Simple

Complex conditions are error-prone and hard to audit.

**Enforce:**

- Limit condition depth to 2-3 levels
- Avoid deeply nested logic
- Extract complex logic into entity attributes when possible
- Use descriptive variable names in conditions

**Example:**

```cedar
// Good: Simple, clear condition
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.public || resource.owner == principal
};

// Avoid: Complex nested logic
permit(
  principal,
  action == Action::"read",
  resource
) when {
  (resource.public && context.authenticated) ||
  (resource.internal && principal.department == resource.department) ||
  (resource.confidential && principal.clearanceLevel >= 3 &&
   (principal.team == resource.team || principal.role == "auditor"))
};
```

### Use Context Appropriately

Context provides request-time information for dynamic decisions.

**Recommend:**

- Use context for temporal constraints (time, date)
- Use context for network conditions (IP address, location)
- Use context for request metadata (MFA status, device type)
- Avoid overusing context—prefer entity attributes when possible

**Example:**

```cedar
// Good: Context for time-based access
permit(
  principal,
  action == Action::"access",
  resource
) when {
  context.time.hour >= 9 && context.time.hour < 17
};

// Good: Context for security-sensitive operations
permit(
  principal,
  action == Action::"delete",
  resource
) when {
  context.mfaVerified && resource.owner == principal
};
```

### Condition Testing

Test conditions with various input values.

**Enforce:**

- Test boundary conditions (edge cases)
- Test with missing attributes
- Test with unexpected types
- Document expected behavior

## Schema Design Best Practices

### Well-Defined Entity Types

Create clear, focused entity types with appropriate attributes.

**Enforce:**

- Use specific entity type names (User, Document, File)
- Define only necessary attributes
- Use appropriate types (String, Long, Boolean, Entity)
- Document attribute meanings

**Example:**

```json
{
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "department": { "type": "String", "required": true },
        "clearanceLevel": { "type": "Long", "required": true },
        "manager": { "type": "Entity", "name": "User", "required": false }
      }
    }
  }
}
```

### Relationship Modeling

Model entity relationships to enable expressive policies.

**Recommend:**

- Use `memberOfTypes` for hierarchies (User in Group, File in Folder)
- Use entity attributes for ownership (owner: User)
- Use entity attributes for related entities (approver: User)
- Avoid circular relationships

**Example:**

```json
{
  "Document": {
    "memberOfTypes": ["Folder"],
    "shape": {
      "type": "Record",
      "attributes": {
        "owner": { "type": "Entity", "name": "User", "required": true },
        "editors": { "type": "Set", "element": { "type": "Entity", "name": "User" } }
      }
    }
  }
}
```

### Attribute Consistency

Use consistent attribute names and types across entity types.

**Recommend:**

- Standard attribute names (`owner`, `createdAt`, `classification`)
- Consistent types for same concepts (timestamps as String ISO8601)
- Document attribute conventions
- Validate attribute values in application code

## Performance Optimization

### Policy Evaluation Efficiency

Write policies that evaluate quickly.

**Recommend:**

- Place specific conditions early (short-circuit evaluation)
- Use indexed attributes for common checks
- Avoid expensive operations in conditions
- Limit set operations on large sets

**Example:**

```cedar
// Good: Fast check first
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.public ||                    // Fast check
  resource.owner == principal ||        // Fast check
  principal in resource.editors         // Potentially slower
};

// Avoid: Expensive check first
permit(
  principal,
  action == Action::"read",
  resource
) when {
  principal in resource.largeEditorSet ||  // Potentially slow
  resource.owner == principal              // Fast but checked last
};
```

### Policy Set Size

Limit the number of policies to maintain performance.

**Warn if:**

- Policy set exceeds 1,000 policies
- Individual policy files exceed 100 policies
- Policy evaluation time exceeds 10ms (p99)

**Mitigation:**

- Consolidate similar policies
- Use policy templates for repeated patterns
- Consider policy hierarchies
- Monitor evaluation metrics

### Caching Strategies

Cache policy evaluation results when appropriate.

**Recommend:**

- Cache static authorization decisions (role-based)
- Cache for short-lived tokens (5-10 minutes)
- Invalidate cache on policy updates
- Monitor cache hit rates

**Warn:**

- Don't cache context-dependent decisions
- Don't cache highly dynamic resources
- Ensure cache consistency across instances

## Common Pitfalls

### Over-Permissive Policies

Avoid policies that grant excessive access.

**Warn if:**

- Using bare `principal`, `action`, or `resource` without constraints
- Granting wildcard permissions
- Missing conditions on sensitive operations

**Example:**

```cedar
// Dangerous: Any principal, any action, any resource
permit(principal, action, resource);

// Better: Specific scope
permit(
  principal in Group::"public-viewers",
  action == Action::"read",
  resource in Folder::"public-documents"
);
```

### Policy Conflicts

Conflicting `permit` and `forbid` policies create confusion.

**Warn if:**

- Same principal/action/resource has both `permit` and `forbid`
- Unclear which policy takes precedence
- Missing documentation for conflicts

**Resolution:**

- `forbid` always takes precedence
- Document intentional conflicts
- Use policy analysis tools to detect conflicts

**Example:**

```cedar
// Permit general access
permit(
  principal in Group::"employees",
  action == Action::"read",
  resource is Document
);

// Explicitly forbid sensitive documents
forbid(
  principal in Group::"employees",
  action == Action::"read",
  resource
) when {
  resource.classification == "confidential" &&
  !principal.has("confidentialAccess")
};
```

### Missing Validation

Deploying policies without validation leads to runtime errors.

**Enforce:**

- Validate syntax before deployment
- Validate against schema
- Test with sample requests
- Use CI/CD pipeline validation

**Validation workflow:**

```bash
# Syntax validation
cedar validate --policy-set policies/

# Schema validation
cedar validate --schema schema.cedarschema.json --policy-set policies/

# Test authorization
cedar authorize \
  --principal 'User::"test"' \
  --action 'Action::"read"' \
  --resource 'Document::"test"' \
  --policy-set policies/ \
  --schema schema.cedarschema.json
```

### Attribute Misuse

Incorrect attribute usage causes evaluation errors.

**Warn if:**

- Accessing non-existent attributes
- Wrong attribute types in conditions
- Missing `has()` checks before accessing optional attributes

**Example:**

```cedar
// Dangerous: Attribute might not exist
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.public == true  // Fails if 'public' doesn't exist
};

// Safe: Check attribute existence
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.has("public") && resource.public == true
};
```

## Security Patterns

### Multi-Tenancy Isolation

Ensure tenant data isolation in multi-tenant systems.

**Enforce:**

- Include tenant ID in all resource identifiers
- Check tenant membership in all policies
- Prevent cross-tenant access
- Audit tenant boundary violations

**Example:**

```cedar
permit(
  principal,
  action,
  resource
) when {
  principal.tenantId == resource.tenantId
};
```

### Privilege Escalation Prevention

Prevent users from granting themselves or others excessive permissions.

**Enforce:**

- Restrict permission grant operations
- Require approval for privilege elevation
- Audit permission changes
- Use separate administrative accounts

**Example:**

```cedar
// Only administrators can grant permissions
permit(
  principal in Group::"security-admins",
  action == Action::"grantPermission",
  resource
);

// Forbid self-service privilege escalation
forbid(
  principal,
  action == Action::"grantPermission",
  resource
) when {
  resource == principal  // Can't grant permissions to self
};
```

### Time-Based Access Control

Implement temporal access restrictions.

**Recommend:**

```cedar
// Business hours only
permit(
  principal in Group::"contractors",
  action,
  resource
) when {
  context.time.hour >= 9 && context.time.hour < 17 &&
  context.time.dayOfWeek in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
};

// Temporary access (requires context.expiresAt)
permit(
  principal,
  action,
  resource
) when {
  context.currentTime < resource.accessExpiresAt
};
```

### Data Classification Enforcement

Enforce access based on data classification levels.

**Recommend:**

```cedar
// Public data: Everyone can read
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.classification == "public"
};

// Internal data: Employees only
permit(
  principal in Group::"employees",
  action == Action::"read",
  resource
) when {
  resource.classification == "internal"
};

// Confidential data: Need clearance
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.classification == "confidential" &&
  principal.clearanceLevel >= 3
};
```

## Policy Lifecycle Management

### Version Control

Track policy changes with version control.

**Enforce:**

- Store policies in Git repository
- Use meaningful commit messages
- Tag releases with semantic versioning
- Maintain changelog

**Example workflow:**

```bash
# Commit policy changes
git add policies/
git commit -m "feat(policies): add document classification policies"

# Tag release
git tag -a v1.2.0 -m "Release 1.2.0: Document classification"
git push --tags
```

### Policy Review Process

Establish review process for policy changes.

**Recommend:**

- Require security team review for policy changes
- Use pull requests for policy updates
- Document review criteria
- Maintain approval records

### Deployment Pipeline

Automate policy validation and deployment.

**Enforce:**

- Validate policies in CI/CD
- Test policies before production
- Deploy incrementally (canary deployment)
- Monitor authorization metrics post-deployment

**Example CI/CD:**

```yaml
# .github/workflows/validate-policies.yml
validate:
  steps:
    - name: Validate Cedar policies
      run: |
        cedar validate --schema schema.cedarschema.json --policy-set policies/
    - name: Test authorization
      run: |
        ./scripts/test-authorization.sh
```

### Policy Monitoring

Monitor policy evaluation and authorization metrics.

**Recommend:**

- Log authorization decisions (allowed/denied)
- Track policy evaluation time
- Alert on unusual patterns (sudden increase in denials)
- Audit policy changes

**Metrics to track:**

- Authorization requests per second
- Authorization denials (by policy)
- Policy evaluation latency (p50, p95, p99)
- Policy coverage (unused policies)

## Documentation Standards

### Policy Documentation

Document policies for maintainability and compliance.

**Enforce:**

- Add comments explaining policy intent
- Document security rationale
- Include examples of allowed/denied scenarios
- Maintain policy catalog

**Example:**

```cedar
// POLICY: editor-document-write
// PURPOSE: Allow editors to modify documents in their department
// OWNER: Security Team
// COMPLIANCE: SOC2 requirement for least privilege
// LAST_UPDATED: 2024-01-15
//
// EXAMPLES:
//   ALLOW: Editor in Engineering edits Engineering docs
//   DENY: Editor in Engineering edits Finance docs
permit(
  principal in Group::"editors",
  action in [Action::"write", Action::"update"],
  resource is Document
) when {
  resource.department == principal.department
};
```

### Schema Documentation

Document entity types and relationships.

**Recommend:**

- Describe each entity type's purpose
- Document attribute meanings and constraints
- Explain relationship semantics
- Provide examples

### Change Documentation

Document policy and schema changes.

**Recommend:**

- Maintain CHANGELOG.md
- Document breaking changes
- Provide migration guides
- Include upgrade instructions

---

Following these best practices ensures secure, maintainable, and efficient Cedar authorization policies. Regular review
and continuous improvement of policies maintains security posture over time.
