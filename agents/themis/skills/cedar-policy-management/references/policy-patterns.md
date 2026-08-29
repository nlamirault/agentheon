# Cedar Policy Patterns

Comprehensive collection of policy patterns for implementing various authorization models with Cedar.

## Role-Based Access Control (RBAC)

RBAC grants permissions based on roles assigned to users. Users inherit permissions from their role membership.

### Basic RBAC

Grant permissions to users based on single role membership:

```cedar
// Administrators have full access
permit(
  principal in Role::"admin",
  action,
  resource
);

// Editors can read and write
permit(
  principal in Role::"editor",
  action in [Action::"read", Action::"write"],
  resource is Document
);

// Viewers can only read
permit(
  principal in Role::"viewer",
  action == Action::"read",
  resource is Document
);
```

### Hierarchical RBAC

Implement role hierarchies where senior roles inherit junior role permissions:

```cedar
// Define role hierarchy: Admin > Manager > Employee

// Employees can read documents
permit(
  principal in Role::"employee",
  action == Action::"read",
  resource is Document
);

// Managers inherit employee permissions plus approval rights
permit(
  principal in Role::"manager",
  action in [Action::"read", Action::"approve"],
  resource is Document
);

// Admins inherit all permissions
permit(
  principal in Role::"admin",
  action in [Action::"read", Action::"write", Action::"delete", Action::"approve"],
  resource is Document
);
```

### Role with Constraints

Add conditions to role-based permissions:

```cedar
// Editors can modify documents in their department
permit(
  principal in Role::"editor",
  action in [Action::"write", Action::"update"],
  resource is Document
) when {
  principal.department == resource.department
};

// Analysts can read reports during business hours
permit(
  principal in Role::"analyst",
  action == Action::"read",
  resource is Report
) when {
  context.time.hour >= 9 && context.time.hour < 17
};
```

### Multiple Role Assignment

Handle users with multiple roles:

```cedar
// Grant permissions based on any role membership
permit(
  principal in Role::"developer",
  action in [Action::"read", Action::"write", Action::"execute"],
  resource is Code
);

permit(
  principal in Role::"security-reviewer",
  action in [Action::"read", Action::"audit"],
  resource is Code
);

// User in both roles gets union of permissions
```

## Attribute-Based Access Control (ABAC)

ABAC makes decisions based on attributes of the principal, resource, action, and context.

### Resource Attribute-Based

Grant access based on resource attributes:

```cedar
// Anyone can read public resources
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.visibility == "public"
};

// Employees can read internal resources
permit(
  principal in Group::"employees",
  action == Action::"read",
  resource
) when {
  resource.visibility == "internal"
};

// Read confidential resources with appropriate clearance
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.classification == "confidential" &&
  principal.clearanceLevel >= resource.requiredClearance
};
```

### Principal Attribute-Based

Grant access based on principal attributes:

```cedar
// Department-based access
permit(
  principal,
  action in [Action::"read", Action::"write"],
  resource is Document
) when {
  principal.department == resource.department
};

// Location-based access
permit(
  principal,
  action == Action::"access",
  resource
) when {
  principal.location in resource.allowedLocations
};

// Experience-based access
permit(
  principal,
  action == Action::"approve",
  resource is PurchaseOrder
) when {
  principal.yearsExperience >= 5 &&
  resource.amount <= 10000
};
```

### Multi-Attribute Conditions

Combine multiple attributes for fine-grained control:

```cedar
// Complex approval workflow
permit(
  principal,
  action == Action::"approve",
  resource is Expense
) when {
  // Small expenses: Any manager
  (resource.amount < 1000 && principal in Role::"manager") ||

  // Medium expenses: Senior manager in same department
  (resource.amount < 5000 &&
   principal in Role::"senior-manager" &&
   principal.department == resource.department) ||

  // Large expenses: Director or above
  (resource.amount < 25000 && principal in Role::"director") ||

  // Very large: C-level only
  (principal in Role::"executive")
};
```

### Context-Based Decisions

Use request context for dynamic decisions:

```cedar
// Time-based access
permit(
  principal in Group::"contractors",
  action,
  resource
) when {
  context.time.hour >= 9 && context.time.hour < 17 &&
  context.time.dayOfWeek != "Saturday" &&
  context.time.dayOfWeek != "Sunday"
};

// Location-based access
permit(
  principal,
  action == Action::"access",
  resource is SensitiveData
) when {
  context.ip_address.isInRange(ip("10.0.0.0/8")) &&
  context.mfaVerified
};

// Device-based access
permit(
  principal,
  action == Action::"read",
  resource is Email
) when {
  context.device.managed &&
  context.device.encryptionEnabled
};
```

## Relationship-Based Access Control (ReBAC)

ReBAC bases decisions on relationships between entities.

### Owner-Based Access

Grant access to resource owners:

```cedar
// Owners have full control
permit(
  principal,
  action in [Action::"read", Action::"write", Action::"delete", Action::"share"],
  resource
) when {
  resource.owner == principal
};

// Creators can modify their creations
permit(
  principal,
  action in [Action::"edit", Action::"delete"],
  resource
) when {
  resource.createdBy == principal
};
```

### Relationship Lists

Grant access based on explicit relationship lists:

```cedar
// Editors can modify documents they're listed on
permit(
  principal,
  action in [Action::"read", Action::"write"],
  resource
) when {
  principal in resource.editors
};

// Viewers can read documents they're shared with
permit(
  principal,
  action == Action::"read",
  resource
) when {
  principal in resource.viewers
};

// Collaborators can comment
permit(
  principal,
  action == Action::"comment",
  resource
) when {
  principal in resource.collaborators
};
```

### Hierarchical Relationships

Navigate entity hierarchies:

```cedar
// Access documents in accessible folders
permit(
  principal,
  action == Action::"read",
  resource is Document
) when {
  resource in principal.accessibleFolders
};

// Managers can access subordinate resources
permit(
  principal,
  action,
  resource
) when {
  resource.owner in principal.subordinates
};

// Team members can access team resources
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource in principal.team.resources
};
```

### Transitive Relationships

Follow relationship chains:

```cedar
// Organization hierarchy: User -> Team -> Department -> Company
permit(
  principal,
  action == Action::"read",
  resource is Document
) when {
  // Direct team access
  resource.team == principal.team ||

  // Department access
  resource.team in principal.team.department.teams ||

  // Company-wide access
  resource.companyWide
};
```

## Hybrid Models

Combine RBAC, ABAC, and ReBAC for comprehensive authorization.

### RBAC + ABAC

Combine role and attribute checks:

```cedar
// Managers can approve expenses in their department
permit(
  principal in Role::"manager",
  action == Action::"approve",
  resource is Expense
) when {
  principal.department == resource.department &&
  resource.amount <= principal.approvalLimit
};
```

### RBAC + ReBAC

Combine role and relationship checks:

```cedar
// Editors can modify documents, owners can additionally delete
permit(
  principal in Role::"editor",
  action in [Action::"read", Action::"write"],
  resource is Document
);

permit(
  principal,
  action == Action::"delete",
  resource is Document
) when {
  resource.owner == principal
};
```

### ABAC + ReBAC

Combine attributes and relationships:

```cedar
// Access based on clearance and relationship
permit(
  principal,
  action == Action::"read",
  resource is ClassifiedDocument
) when {
  (principal.clearanceLevel >= resource.requiredClearance &&
   principal in resource.authorizedPersonnel) ||
  resource.owner == principal
};
```

## Delegation Patterns

Enable users to delegate permissions to others.

### Explicit Delegation

Allow resource owners to delegate access:

```cedar
// Owner can delegate permissions
permit(
  principal,
  action == Action::"delegate",
  resource
) when {
  resource.owner == principal
};

// Delegates have granted permissions
permit(
  principal,
  action,
  resource
) when {
  principal in resource.delegates &&
  action in resource.delegatedActions
};
```

### Time-Limited Delegation

Delegate with expiration:

```cedar
// Temporary access grants
permit(
  principal,
  action,
  resource
) when {
  principal in resource.temporaryAccess &&
  context.currentTime < resource.accessExpiresAt
};
```

### Scoped Delegation

Limit delegation scope:

```cedar
// Delegate specific actions only
permit(
  principal,
  action == Action::"read",
  resource
) when {
  principal in resource.readDelegates
};

permit(
  principal,
  action == Action::"write",
  resource
) when {
  principal in resource.writeDelegates
};
```

## Hierarchical Resource Patterns

Implement resource hierarchies with inheritance.

### Folder Hierarchies

Inherit permissions from parent folders:

```cedar
// Access to folder grants access to contents
permit(
  principal,
  action,
  resource
) when {
  resource in principal.accessibleFolders
};

// Explicit permission on parent folder
permit(
  principal in Group::"engineering",
  action == Action::"read",
  resource in Folder::"engineering-docs"
);
```

### Organization Hierarchies

Model organizational structures:

```cedar
// Company -> Department -> Team -> Individual
permit(
  principal,
  action == Action::"read",
  resource is Document
) when {
  // Same team
  resource.team == principal.team ||

  // Same department
  (resource.team in principal.team.department.teams &&
   resource.visibility == "department") ||

  // Company-wide
  resource.visibility == "company"
};
```

### Resource Categories

Group resources by category:

```cedar
// Category-based access
permit(
  principal in Group::"finance-team",
  action in [Action::"read", Action::"write"],
  resource in Category::"financial-data"
);

permit(
  principal in Group::"hr-team",
  action in [Action::"read", Action::"write"],
  resource in Category::"personnel-data"
);
```

## Multi-Tenancy Patterns

Isolate tenants in multi-tenant systems.

### Strict Tenant Isolation

Ensure complete tenant separation:

```cedar
// All operations require tenant match
permit(
  principal,
  action,
  resource
) when {
  principal.tenantId == resource.tenantId
};

// Forbid cross-tenant access
forbid(
  principal,
  action,
  resource
) when {
  principal.tenantId != resource.tenantId
};
```

### Tenant Administrators

Grant tenant-scoped administrative access:

```cedar
// Tenant admins manage their tenant
permit(
  principal,
  action,
  resource
) when {
  principal.role == "tenant-admin" &&
  principal.tenantId == resource.tenantId
};
```

### Super Admin Access

Allow platform admins to access all tenants:

```cedar
// Platform admins can access any tenant
permit(
  principal in Group::"platform-admins",
  action,
  resource
);

// Regular users: tenant isolation
permit(
  principal,
  action,
  resource
) when {
  principal.tenantId == resource.tenantId
};
```

## Data Classification Patterns

Implement security levels and data classification.

### Classification Levels

Enforce hierarchical security levels:

```cedar
// Public: Everyone can read
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.classification == "public"
};

// Internal: Employees only
permit(
  principal in Group::"employees",
  action == Action::"read",
  resource
) when {
  resource.classification == "internal"
};

// Confidential: Need appropriate clearance
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.classification == "confidential" &&
  principal.clearanceLevel >= 2
};

// Secret: High clearance required
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.classification == "secret" &&
  principal.clearanceLevel >= 3
};
```

### Need-to-Know

Combine clearance with need-to-know:

```cedar
permit(
  principal,
  action == Action::"read",
  resource
) when {
  resource.classification == "classified" &&
  principal.clearanceLevel >= resource.requiredClearance &&
  principal in resource.authorizedPersonnel
};
```

### Write-Down Prevention

Prevent writing high-classified data to low-classified resources:

```cedar
// Cannot write classified content to public resources
forbid(
  principal,
  action == Action::"write",
  resource
) when {
  principal.maxClassification > resource.classification
};
```

## Temporal Patterns

Implement time-based access control.

### Business Hours

Restrict access to business hours:

```cedar
permit(
  principal in Group::"contractors",
  action,
  resource
) when {
  context.time.hour >= 9 &&
  context.time.hour < 17 &&
  context.time.dayOfWeek in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
};
```

### Temporary Access

Grant time-limited access:

```cedar
// Access with expiration
permit(
  principal,
  action,
  resource
) when {
  principal in resource.temporaryUsers &&
  context.currentTime >= resource.accessStartsAt &&
  context.currentTime < resource.accessExpiresAt
};
```

### Scheduled Access

Enable access during specific periods:

```cedar
// Maintenance window access
permit(
  principal in Group::"operations",
  action == Action::"system-maintenance",
  resource
) when {
  context.currentTime >= resource.maintenanceStart &&
  context.currentTime < resource.maintenanceEnd
};
```

### Recurring Schedules

Implement recurring time-based policies:

```cedar
// Weekend-only access for batch processing
permit(
  principal in Group::"batch-jobs",
  action == Action::"bulk-process",
  resource
) when {
  context.time.dayOfWeek in ["Saturday", "Sunday"]
};
```

## Break-Glass Patterns

Provide emergency access mechanisms.

### Emergency Access

Allow override for emergencies:

```cedar
// Normal access restrictions
permit(
  principal in Group::"doctors",
  action == Action::"read",
  resource is PatientRecord
) when {
  resource.assignedDoctor == principal
};

// Emergency override with audit
permit(
  principal in Group::"doctors",
  action == Action::"read",
  resource is PatientRecord
) when {
  context.emergencyOverride &&
  context.justificationProvided
};
```

### Approval-Based Override

Require approval for break-glass:

```cedar
// Override requires real-time approval
permit(
  principal,
  action,
  resource
) when {
  context.emergencyAccess &&
  context.approvedBy in Group::"security-team" &&
  context.approvalTimestamp.secondsSince() < 300  // 5-minute approval window
};
```

## Separation of Duties

Enforce segregation of responsibilities.

### Two-Person Rule

Require multiple people for sensitive operations:

```cedar
// Initiate transaction
permit(
  principal in Group::"financial-officers",
  action == Action::"initiate-wire-transfer",
  resource is WireTransfer
);

// Approve transaction (different person)
permit(
  principal in Group::"financial-officers",
  action == Action::"approve-wire-transfer",
  resource is WireTransfer
) when {
  resource.initiatedBy != principal
};
```

### Role Segregation

Prevent same user from having conflicting roles:

```cedar
// Cannot be both requester and approver
forbid(
  principal,
  action == Action::"approve",
  resource is PurchaseRequest
) when {
  resource.requestedBy == principal
};
```

## Conditional Policies

Advanced condition patterns.

### Attribute Existence Checks

Check for attribute presence:

```cedar
// Require MFA for sensitive operations
permit(
  principal,
  action == Action::"delete",
  resource is CriticalData
) when {
  context.has("mfaVerified") && context.mfaVerified
};
```

### Complex Boolean Logic

Combine multiple conditions:

```cedar
permit(
  principal,
  action == Action::"approve",
  resource is Contract
) when {
  // Regular approval path
  (principal in Role::"contract-manager" &&
   resource.value < 100000) ||

  // Executive approval for large contracts
  (principal in Role::"executive" &&
   resource.value < 1000000) ||

  // Board approval for very large contracts
  (principal in Role::"board-member")
};
```

### Set Operations

Work with sets of values:

```cedar
// Check if principal has required skills
permit(
  principal,
  action == Action::"work-on",
  resource is Project
) when {
  resource.requiredSkills.containsAll(principal.skills)
};

// Check if any skill matches
permit(
  principal,
  action == Action::"contribute",
  resource is Project
) when {
  resource.desiredSkills.containsAny(principal.skills)
};
```

---

These patterns provide building blocks for implementing comprehensive authorization systems with Cedar. Combine and
adapt patterns to meet specific requirements while maintaining security and clarity.
