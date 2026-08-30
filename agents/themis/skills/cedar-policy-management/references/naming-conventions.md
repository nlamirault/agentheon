# Cedar Naming Conventions

Comprehensive guide to Cedar naming conventions for entity types, entity IDs, attributes, actions, and context keys
based on official Cedar documentation.

**Reference**: <https://docs.cedarpolicy.com/bestpractices/bp-naming-conventions.html>

## Core Principle

**Consistent naming conventions help ensure uniformity across Cedar policies.** Establishing clear patterns for all
schema elements maintains readability and reduces errors.

## Entity Type Naming

### Convention: PascalCase

Capitalize the first letter of entity type names.

**Enforce:**

- Use PascalCase for all entity types
- Capitalize first letter of each word
- No spaces or special characters
- Use singular nouns (not plural)

**Examples:**

```cedar
// Good: PascalCase entity types
User::"alice"
Document::"report.pdf"
PhotoAlbum::"vacation2024"
SupportCase::"case-12345"
ExpenseReport::"exp-2024-01"

// Avoid: Other cases
user::"alice"              // lowercase
DOCUMENT::"report.pdf"     // UPPERCASE
photo_album::"vacation"    // snake_case
support-case::"12345"      // kebab-case
```

**Common entity types:**

- `User` - Individual users
- `Group` - Collections of users
- `Role` - Permission sets
- `Team` - Organizational units
- `Department` - Company divisions
- `Document` - Files or documents
- `Folder` - Document containers
- `Project` - Work initiatives
- `Resource` - Generic resources
- `Application` - Software applications

**Multi-word entity types:**

```cedar
// Good: PascalCase for multi-word types
PhotoAlbum::"album1"
SupportCase::"case123"
ExpenseReport::"report456"
UserAccount::"account789"
AccessToken::"token012"

// Avoid: Other separators
Photo_Album::"album1"      // snake_case
photo-album::"album1"      // kebab-case
photoalbum::"album1"       // all lowercase (ambiguous)
```

**Why PascalCase:**

- Standard convention in schema languages
- Clear word boundaries
- Distinguishes types from instances
- Better readability in policies
- Consistent with industry practice

## Entity Instance ID Naming

### Convention: Opaque IDs or camelCase

Use opaque identifiers (UUIDs, hashes) or camelCase for entity instance IDs.

**Enforce:**

- Prefer opaque, immutable identifiers
- Use UUIDs for permanent entities
- Use camelCase for readable action names
- Avoid human-readable mutable identifiers

**Examples:**

```cedar
// Good: Opaque IDs (preferred)
User::"fcaf664d4f89fec0cda8"
User::"123e4567-e89b-12d3-a456-426614174000"
Document::"7f3d8e9c-1a2b-3c4d-5e6f-7890abcdef12"

// Good: camelCase for actions or descriptive IDs
Action::"viewFile"
Action::"createSupportCase"
Action::"approveExpense"

// Avoid: Mutable identifiers
User::"alice@example.com"          // Email can change
User::"alice.smith"                // Username can change
Document::"Q4-2024-Budget.xlsx"    // Filename can change
```

**Opaque ID benefits:**

- Immutable (prevents authorization drift)
- No personally identifiable information
- Database-friendly
- Consistent length
- No special character issues

**When to use camelCase IDs:**

- Action definitions (always camelCase)
- Static, immutable concepts
- Well-known constants
- System-level identifiers

**UUID formats:**

```cedar
// Standard UUID v4
User::"550e8400-e29b-41d4-a716-446655440000"

// Short opaque IDs (hex strings)
User::"fcaf664d4f89fec0cda8"

// Custom prefixed IDs
User::"usr_2eQx7jK9mP3nL5vR"
Document::"doc_7hG3pL9kM2nQ8sT"
```

**Action ID conventions:**

```cedar
// Good: camelCase actions
Action::"viewFile"
Action::"editDocument"
Action::"deleteResource"
Action::"createSupportCase"
Action::"approveExpense"
Action::"publishArticle"

// Avoid: Other cases
Action::"view-file"        // kebab-case
Action::"EditDocument"     // PascalCase
Action::"delete_resource"  // snake_case
Action::"APPROVE_EXPENSE"  // SCREAMING_SNAKE_CASE
```

## Attribute Naming

### Convention: camelCase

Use camelCase for all attribute names.

**Enforce:**

- Start with lowercase letter
- Capitalize subsequent words
- No spaces or special characters
- Use descriptive, clear names

**Examples:**

```cedar
// Good: camelCase attributes
resource.countryOfOrigin
resource.createdBy
resource.lastModifiedAt
principal.clearanceLevel
principal.departmentName
context.uploadFileSize

// Avoid: Other cases
resource.CountryOfOrigin   // PascalCase
resource.country_of_origin // snake_case
resource.created-by        // kebab-case
resource.CREATED_BY        // SCREAMING_SNAKE_CASE
```

**Common attribute patterns:**

```cedar
// Identity and ownership
resource.owner
resource.createdBy
resource.modifiedBy
principal.userId
principal.email

// Timestamps (use descriptive names)
resource.createdAt
resource.updatedAt
resource.publishedAt
resource.expiresAt
resource.deletedAt

// Status and state
resource.status
resource.isActive
resource.isPublic
resource.isArchived
principal.isEnabled

// Relationships
resource.parentFolder
resource.department
principal.manager
principal.team

// Business attributes
resource.classification
resource.priority
resource.category
principal.clearanceLevel
principal.jobTitle

// Multi-word attributes
resource.countryOfOrigin
resource.lastAccessTime
principal.phoneNumber
context.requestTimestamp
```

**Boolean attributes:**

```cedar
// Good: Boolean prefixes
resource.isPublic
resource.hasExpired
resource.canDelete
principal.isActive
principal.hasAccess

// Avoid: Ambiguous boolean names
resource.public            // Use isPublic
resource.expired           // Use hasExpired
principal.active           // Use isActive
```

**Nested attributes:**

```cedar
// Good: Nested camelCase
resource.metadata.contentType
resource.metadata.fileSize
principal.profile.firstName
principal.profile.lastName
context.request.ipAddress
context.security.mfaEnabled

// Consistent camelCase throughout
resource.userPermissions.canRead
resource.userPermissions.canWrite
resource.auditInfo.lastModifiedBy
resource.auditInfo.lastModifiedAt
```

## Context Key Naming

### Convention: camelCase

Use camelCase for context keys and nested context properties.

**Enforce:**

- Context keys use camelCase
- Nested keys use camelCase
- Group related context into objects
- Use descriptive, clear names

**Examples:**

```cedar
// Good: camelCase context keys
context.uploadFileSize
context.currentTime
context.ipAddress
context.userAgent

// Good: Nested context with camelCase
context.http.headers.userAgent
context.http.headers.contentType
context.request.method
context.request.timestamp
context.security.mfaVerified
context.security.deviceTrusted
context.time.hour
context.time.dayOfWeek

// Avoid: Other cases
context.UploadFileSize     // PascalCase
context.upload_file_size   // snake_case
context.upload-file-size   // kebab-case
```

**Context organization patterns:**

```cedar
// Time-related context
context.time.hour
context.time.minute
context.time.dayOfWeek
context.time.timestamp
context.time.timezone

// Network-related context
context.network.ipAddress
context.network.location
context.network.region
context.network.connectionType

// Security-related context
context.security.mfaVerified
context.security.mfaMethod
context.security.deviceTrusted
context.security.deviceId
context.security.sessionAge

// Request-related context
context.request.method
context.request.path
context.request.userAgent
context.request.referer
context.request.requestId

// HTTP-specific context
context.http.headers.authorization
context.http.headers.contentType
context.http.headers.accept
context.http.method
context.http.statusCode
```

**Best practices for context:**

```cedar
// Group related data
context.device.type          // "mobile", "desktop"
context.device.os            // "iOS", "Android", "Windows"
context.device.trusted       // boolean

// Use clear, specific names
context.uploadFileSize       // Good: specific
context.size                 // Avoid: ambiguous

context.userGeolocation      // Good: specific
context.location             // Avoid: could mean many things

// Consistent patterns across context
context.request.timestamp
context.session.timestamp
context.action.timestamp     // Consistent naming
```

## Action Naming

### Convention: camelCase (Business Operations)

**CRITICAL**: Actions should map to business domain operations, not HTTP methods or generic CRUD.

**Enforce:**

- Use camelCase for action names
- Map to business operations
- Use verb + noun pattern
- Be specific and descriptive

**Examples:**

```cedar
// Good: Business-focused camelCase actions
Action::"createSupportCase"
Action::"assignTicket"
Action::"closeCase"
Action::"approveExpense"
Action::"submitInvoice"
Action::"publishArticle"
Action::"reviewContent"
Action::"archivePost"
Action::"grantPermission"
Action::"revokeAccess"

// Avoid: HTTP methods
Action::"POST"
Action::"GET"
Action::"PUT"
Action::"DELETE"

// Avoid: Generic CRUD without business context
Action::"create"
Action::"read"
Action::"update"
Action::"delete"
Action::"write"
```

**Action naming patterns by domain:**

**Support/Ticketing:**

```cedar
Action::"createSupportCase"
Action::"assignTicket"
Action::"updateTicketStatus"
Action::"closeCase"
Action::"reopenCase"
Action::"escalateTicket"
```

**Finance:**

```cedar
Action::"submitExpense"
Action::"approveExpense"
Action::"rejectExpense"
Action::"processPayment"
Action::"generateInvoice"
Action::"reconcileAccount"
```

**Content Management:**

```cedar
Action::"createArticle"
Action::"editContent"
Action::"publishArticle"
Action::"unpublishArticle"
Action::"archivePost"
Action::"reviewContent"
Action::"moderateComment"
```

**HR/People:**

```cedar
Action::"submitTimeOff"
Action::"approveLeave"
Action::"rejectLeave"
Action::"viewPayroll"
Action::"updateBenefits"
Action::"conductReview"
```

**Project Management:**

```cedar
Action::"createProject"
Action::"assignTask"
Action::"updateMilestone"
Action::"completeTask"
Action::"closeProject"
Action::"trackProgress"
```

**When generic CRUD is acceptable:**

```cedar
// System-level operations where business context isn't specific
Action::"createResource"
Action::"readResource"
Action::"updateResource"
Action::"deleteResource"

// But prefer specific actions when possible:
Action::"createDocument"     // Better than createResource
Action::"viewDocument"       // Better than readResource
Action::"editDocument"       // Better than updateResource
Action::"removeDocument"     // Better than deleteResource
```

## Namespace Conventions

### Convention: Reverse domain notation (optional)

When using namespaces, follow reverse domain notation or organizational hierarchy.

**Recommend:**

```cedar
// Reverse domain notation
com::example::app::User::"alice"
com::example::app::Document::"doc123"

// Organizational hierarchy
MyOrg::Engineering::User::"alice"
MyOrg::Sales::Document::"quote456"

// Application namespaces
PhotoApp::User::"user123"
PhotoApp::Photo::"photo456"
PhotoApp::Album::"album789"
```

**Namespace patterns:**

```cedar
// Single-level namespace (simplest)
MyApp::User::"alice"
MyApp::Document::"doc1"

// Multi-level namespace (organizational)
Company::Division::Team::User::"alice"
Company::Division::Team::Resource::"resource1"

// Reverse domain (enterprise)
com::example::myapp::v1::User::"alice"
com::example::myapp::v1::Document::"doc1"
```

**When to use namespaces:**

- Multiple applications sharing entity types
- Multi-tenant systems
- Avoiding entity type name collisions
- Versioning entity schemas
- Organizational boundaries

**When namespaces may not be needed:**

- Single application
- No name collision risk
- Simpler authorization model

## Consistency Patterns

### Cross-Schema Consistency

Use consistent naming patterns across all schema elements.

**Enforce:**

```json
{
  "User": {
    "memberOfTypes": ["Group"],
    "shape": {
      "type": "Record",
      "attributes": {
        "userId": { "type": "String" },
        "email": { "type": "String" },
        "createdAt": { "type": "String" },
        "isActive": { "type": "Boolean" }
      }
    }
  },
  "Document": {
    "memberOfTypes": ["Folder"],
    "shape": {
      "type": "Record",
      "attributes": {
        "documentId": { "type": "String" },
        "title": { "type": "String" },
        "createdAt": { "type": "String" },
        "isPublic": { "type": "Boolean" }
      }
    }
  }
}
```

**Consistency checklist:**

- ✓ Entity types: PascalCase
- ✓ Entity IDs: Opaque or camelCase
- ✓ Attributes: camelCase
- ✓ Context keys: camelCase
- ✓ Actions: camelCase
- ✓ Timestamps: `*At` suffix (createdAt, updatedAt)
- ✓ Booleans: `is*`, `has*`, `can*` prefix
- ✓ IDs: `*Id` suffix (userId, documentId)

### Timestamp Naming

Use consistent timestamp attribute names.

**Enforce:**

```cedar
// Good: Consistent timestamp naming
resource.createdAt
resource.updatedAt
resource.publishedAt
resource.deletedAt
resource.expiresAt
resource.archivedAt

// Avoid: Inconsistent naming
resource.createdOn        // Inconsistent suffix
resource.updateTime       // Inconsistent format
resource.publishDate      // Inconsistent suffix
resource.deleted          // Missing 'At' suffix
```

**Timestamp format:**

- Use ISO 8601 format: `"2024-01-15T14:30:00Z"`
- Store as String type in schema
- Use descriptive suffixes: `*At`, `*Date`, `*Time`
- Prefer `*At` for consistency

### ID Attribute Naming

Use consistent ID attribute patterns.

**Enforce:**

```cedar
// Good: Consistent ID naming
principal.userId
resource.documentId
resource.ownerId
resource.parentId
context.requestId
context.sessionId

// Avoid: Inconsistent patterns
principal.user_id         // snake_case
resource.docId            // Abbreviated
resource.ownerUid         // Inconsistent suffix
resource.parent           // Missing 'Id'
```

### Boolean Attribute Naming

Use consistent boolean prefixes.

**Enforce:**

```cedar
// Good: Boolean prefixes
resource.isPublic
resource.isArchived
resource.isActive
principal.isEnabled
principal.hasAccess
principal.canApprove
context.mfaVerified       // Past participle for status

// Avoid: No prefix
resource.public
resource.archived
principal.enabled
```

## Common Naming Anti-Patterns

### Anti-Pattern: Inconsistent Casing

**Avoid:**

```cedar
// Mixing cases in same schema
User::"alice"              // Entity type: PascalCase ✓
Document::"report.pdf"     // Entity type: PascalCase ✓
resource.country_of_origin // Attribute: snake_case ✗
resource.CreatedBy         // Attribute: PascalCase ✗
context.upload-file-size   // Context: kebab-case ✗
```

**Fix:**

```cedar
User::"alice"
Document::"report.pdf"
resource.countryOfOrigin   // All camelCase ✓
resource.createdBy
context.uploadFileSize
```

### Anti-Pattern: Abbreviations

**Avoid:**

```cedar
// Cryptic abbreviations
User::"alice"
Doc::"report"              // Should be Document
Usr::"bob"                 // Should be User
resource.cty               // Should be category
resource.dept              // Should be department
context.req                // Should be request
```

**Fix:**

```cedar
User::"alice"
Document::"report"
User::"bob"
resource.category
resource.department
context.request
```

### Anti-Pattern: Mutable Identifiers

**Avoid:**

```cedar
// Changeable identifiers in entity UIDs
User::"alice@example.com"          // Email can change
User::"alice.smith"                // Username can change
Document::"Q4-Budget.xlsx"         // Filename can change
Resource::"Engineering Dashboard"   // Display name can change
```

**Fix:**

```cedar
// Immutable identifiers
User::"550e8400-e29b-41d4-a716-446655440000"
Document::"7f3d8e9c-1a2b-3c4d-5e6f-7890abcdef12"
Resource::"res_2eQx7jK9mP3nL5vR"

// Store mutable data in attributes
resource.fileName = "Q4-Budget.xlsx"
resource.displayName = "Engineering Dashboard"
principal.email = "alice@example.com"
principal.username = "alice.smith"
```

### Anti-Pattern: Generic Names

**Avoid:**

```cedar
// Overly generic names
Action::"do"
Action::"perform"
Action::"execute"
resource.data
resource.info
resource.value
context.stuff
```

**Fix:**

```cedar
// Specific, descriptive names
Action::"approveExpense"
Action::"publishArticle"
Action::"createTicket"
resource.documentContent
resource.userProfile
resource.configurationValue
context.requestMetadata
```

## Documentation Standards

### Comment Naming Elements

Document naming decisions in schema and policies.

**Recommend:**

```json
{
  "User": {
    "// Convention": "Use UUID v4 for user IDs",
    "// Example": "User::\"550e8400-e29b-41d4-a716-446655440000\"",
    "memberOfTypes": ["Group"],
    "shape": {
      "type": "Record",
      "attributes": {
        "userId": {
          "type": "String",
          "// Description": "Immutable UUID identifier"
        },
        "email": {
          "type": "String",
          "// Description": "User email address (mutable)"
        }
      }
    }
  }
}
```

### Naming Style Guide

Maintain a naming style guide for your project.

**Recommend documenting:**

- Entity type conventions
- Entity ID format and generation
- Attribute naming patterns
- Action naming patterns
- Context key organization
- Timestamp formats
- Boolean conventions
- ID attribute patterns

**Example style guide section:**

```markdown
# Cedar Naming Conventions

## Entity Types

- Format: PascalCase
- Pattern: Singular nouns
- Examples: User, Document, PhotoAlbum

## Entity IDs

- Format: UUID v4
- Pattern: {type}::"uuid"
- Example: User::"550e8400-e29b-41d4-a716-446655440000"

## Attributes

- Format: camelCase
- Patterns:
  - IDs: {entity}Id
  - Timestamps: {action}At
  - Booleans: is{State}, has{Property}, can{Action}
```

## Summary

**Key Naming Conventions:**

| Element      | Convention               | Example                                    |
| ------------ | ------------------------ | ------------------------------------------ |
| Entity Types | PascalCase               | `User`, `Document`, `PhotoAlbum`           |
| Entity IDs   | Opaque or camelCase      | `"fcaf664d4f89"`, `"viewFile"`             |
| Attributes   | camelCase                | `countryOfOrigin`, `createdAt`             |
| Context Keys | camelCase                | `uploadFileSize`, `http.headers.userAgent` |
| Actions      | camelCase (business ops) | `createSupportCase`, `approveExpense`      |

**Benefits of Consistent Naming:**

- Improved readability
- Reduced errors
- Easier maintenance
- Better collaboration
- Clear understanding across team
- Consistent policy structure

**Enforcement:**

- Document conventions in style guide
- Use linters and validators
- Code review for naming consistency
- Provide examples and templates
- Train team on conventions

---

Following these naming conventions ensures Cedar policies remain clear, maintainable, and consistent across your
authorization system.
