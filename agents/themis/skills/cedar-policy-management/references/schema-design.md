# Cedar Schema Design

Comprehensive guide to designing Cedar schemas for authorization systems.

## Schema Fundamentals

### What is a Cedar Schema?

A Cedar schema defines:

- **Entity types**: Principals, resources, and their structures
- **Action definitions**: Available operations
- **Relationships**: How entities connect (hierarchies, memberships)
- **Attributes**: Data attached to entities

Schemas enable:

- Policy validation at authoring time
- Type checking for policy correctness
- IDE support and autocompletion
- Documentation of authorization model

### Schema Format

Cedar schemas use JSON format:

```json
{
  "EntityTypeName": {
    "memberOfTypes": ["ParentType"],
    "shape": {
      "type": "Record",
      "attributes": {
        "attributeName": { "type": "String" }
      }
    }
  },
  "actions": {
    "actionName": {
      "appliesTo": {
        "principalTypes": ["User"],
        "resourceTypes": ["Document"]
      }
    }
  }
}
```

## Entity Type Design

### Principal Architecture: Single User Type Pattern

**CRITICAL BEST PRACTICE**: Use a single `User` entity type for all users, with role differentiation through `Group`
membership rather than creating multiple user types.

**Why single user type:**

- Simpler schema and policies
- Flexible role changes (just update group membership)
- Easier to add new roles without schema changes
- Single identity across the entire system
- Centralized permission management at group level

**Enforce:**

```json
{
  "User": {
    "memberOfTypes": ["Group"],
    "shape": {
      "type": "Record",
      "attributes": {
        "userId": { "type": "String", "required": true },
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
        "groupType": { "type": "String", "required": true }  // "role", "team", "department"
      }
    }
  }
}
```

**Usage in policies:**

```cedar
// Grant permissions based on group membership
permit(
  principal in Group::"editors",
  action == Action::"EditDocument",
  resource is Document
);

permit(
  principal in Group::"admins",
  action,
  resource
);

permit(
  principal in Group::"engineering-team",
  action == Action::"ViewDocument",
  resource in Folder::"engineering-docs"
);
```

**Avoid: Multiple user types**

```json
// Anti-pattern: Don't create separate entity types for each role
{
  "AdminUser": {
    "shape": { "type": "Record", "attributes": {...} }
  },
  "EditorUser": {
    "shape": { "type": "Record", "attributes": {...} }
  },
  "ViewerUser": {
    "shape": { "type": "Record", "attributes": {...} }
  }
}
```

**Problems with multiple user types:**

- Schema changes required for new roles
- Complex role transitions (must change entity type)
- Multiple identities for same person
- Harder to maintain and reason about
- Duplicated attributes across user types

### Principal Types

Define who can perform actions using the single user type pattern:

```json
{
  "User": {
    "memberOfTypes": ["Group", "Role"],
    "shape": {
      "type": "Record",
      "attributes": {
        "userId": { "type": "String", "required": true },
        "email": { "type": "String", "required": true },
        "department": { "type": "String", "required": true },
        "clearanceLevel": { "type": "Long", "required": false },
        "manager": { "type": "Entity", "name": "User", "required": false }
      }
    }
  },
  "Group": {
    "memberOfTypes": [],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String", "required": true },
        "description": { "type": "String", "required": false }
      }
    }
  },
  "Role": {
    "memberOfTypes": [],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String", "required": true },
        "permissions": {
          "type": "Set",
          "element": { "type": "String" },
          "required": true
        }
      }
    }
  }
}
```

### Resource Types

Define what can be accessed:

```json
{
  "Document": {
    "memberOfTypes": ["Folder"],
    "shape": {
      "type": "Record",
      "attributes": {
        "title": { "type": "String", "required": true },
        "owner": { "type": "Entity", "name": "User", "required": true },
        "classification": { "type": "String", "required": true },
        "createdAt": { "type": "String", "required": true },
        "tags": {
          "type": "Set",
          "element": { "type": "String" },
          "required": false
        }
      }
    }
  },
  "Folder": {
    "memberOfTypes": [],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String", "required": true },
        "parent": { "type": "Entity", "name": "Folder", "required": false }
      }
    }
  }
}
```

### Action Definitions

Define available operations:

```json
{
  "actions": {
    "read": {
      "appliesTo": {
        "principalTypes": ["User"],
        "resourceTypes": ["Document", "Folder"]
      }
    },
    "write": {
      "appliesTo": {
        "principalTypes": ["User"],
        "resourceTypes": ["Document"]
      }
    },
    "delete": {
      "appliesTo": {
        "principalTypes": ["User"],
        "resourceTypes": ["Document"]
      }
    },
    "share": {
      "appliesTo": {
        "principalTypes": ["User"],
        "resourceTypes": ["Document"]
      },
      "memberOf": []
    }
  }
}
```

## Attribute Design

### Choosing Attribute Types

Cedar supports these attribute types:

**Primitive Types:**

- `String` - Text values
- `Long` - Integer numbers
- `Boolean` - True/false values

**Complex Types:**

- `Entity` - References to other entities
- `Set` - Collection of values
- `Record` - Nested structure

**Example:**

```json
{
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "email": { "type": "String" },              // Primitive
        "age": { "type": "Long" },                   // Primitive
        "active": { "type": "Boolean" },             // Primitive
        "manager": { "type": "Entity", "name": "User" },  // Entity reference
        "skills": { "type": "Set", "element": { "type": "String" } },  // Set
        "metadata": {
          "type": "Record",                          // Nested record
          "attributes": {
            "lastLogin": { "type": "String" },
            "loginCount": { "type": "Long" }
          }
        }
      }
    }
  }
}
```

### Required vs Optional Attributes

Mark attributes as required or optional:

```json
{
  "Document": {
    "shape": {
      "type": "Record",
      "attributes": {
        "title": { "type": "String", "required": true },      // Must exist
        "owner": { "type": "Entity", "name": "User", "required": true },
        "description": { "type": "String", "required": false }, // Optional
        "expiresAt": { "type": "String", "required": false }
      }
    }
  }
}
```

**Best practices:**

- Mark core identity attributes as required
- Mark business-critical attributes as required
- Use optional for metadata and supplementary information
- Use `has()` in policies when accessing optional attributes

### Attribute Naming Conventions

Use consistent, clear attribute names:

**Enforce:**

- Use camelCase: `firstName`, `clearanceLevel`, `createdAt`
- Use descriptive names: `classification` not `class`
- Use full words: `department` not `dept`
- Prefix booleans with `is`, `has`, `can`: `isActive`, `hasAccess`, `canApprove`

**Examples:**

```json
{
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "userId": { "type": "String" },           // Good: camelCase, clear
        "isActive": { "type": "Boolean" },        // Good: boolean prefix
        "clearanceLevel": { "type": "Long" },     // Good: descriptive
        "dept": { "type": "String" }              // Avoid: abbreviated
      }
    }
  }
}
```

## Relationship Modeling

### Membership Relationships

Use `memberOfTypes` for hierarchies:

```json
{
  "User": {
    "memberOfTypes": ["Group", "Team", "Role"],
    "shape": { "type": "Record", "attributes": {} }
  },
  "Document": {
    "memberOfTypes": ["Folder", "Collection"],
    "shape": { "type": "Record", "attributes": {} }
  }
}
```

**Policy usage:**

```cedar
// User in Group
permit(
  principal in Group::"engineers",
  action == Action::"read",
  resource is Document
);

// Document in Folder
permit(
  principal,
  action == Action::"read",
  resource in Folder::"public-docs"
);
```

### Entity Reference Relationships

Use entity attributes for directed relationships:

```json
{
  "Document": {
    "shape": {
      "type": "Record",
      "attributes": {
        "owner": { "type": "Entity", "name": "User" },
        "approver": { "type": "Entity", "name": "User" },
        "parentFolder": { "type": "Entity", "name": "Folder" }
      }
    }
  }
}
```

**Policy usage:**

```cedar
// Owner relationship
permit(
  principal,
  action,
  resource
) when {
  resource.owner == principal
};
```

### Many-to-Many Relationships

Use sets of entity references:

```json
{
  "Document": {
    "shape": {
      "type": "Record",
      "attributes": {
        "editors": {
          "type": "Set",
          "element": { "type": "Entity", "name": "User" }
        },
        "viewers": {
          "type": "Set",
          "element": { "type": "Entity", "name": "User" }
        }
      }
    }
  }
}
```

**Policy usage:**

```cedar
permit(
  principal,
  action == Action::"edit",
  resource
) when {
  principal in resource.editors
};
```

### Hierarchical Relationships

Model multi-level hierarchies:

```json
{
  "Folder": {
    "memberOfTypes": ["Folder"],  // Folders can contain folders
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String" }
      }
    }
  },
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "manager": { "type": "Entity", "name": "User" }  // User reports to User
      }
    }
  }
}
```

## Action Design

### Action Hierarchies

Create action hierarchies for policy reuse:

```json
{
  "actions": {
    "read": {
      "appliesTo": {
        "principalTypes": ["User"],
        "resourceTypes": ["Document"]
      }
    },
    "list": {
      "appliesTo": {
        "principalTypes": ["User"],
        "resourceTypes": ["Document"]
      },
      "memberOf": [{ "id": "read" }]  // list implies read permission
    },
    "view": {
      "appliesTo": {
        "principalTypes": ["User"],
        "resourceTypes": ["Document"]
      },
      "memberOf": [{ "id": "read" }]  // view implies read permission
    }
  }
}
```

**Policy usage:**

```cedar
// Grant read permission
permit(
  principal in Group::"viewers",
  action == Action::"read",
  resource is Document
);

// Automatically grants list and view as well
```

### Action Naming

Use consistent action naming:

**Enforce:**

- Use verbs: `read`, `write`, `delete`, `approve`
- Use present tense: `read` not `reads` or `reading`
- Be specific: `approve` not `process`
- Group related actions: `read`, `write`, `delete` for CRUD

**Common action names:**

- **Read operations**: `read`, `view`, `list`, `search`
- **Write operations**: `write`, `update`, `edit`, `modify`
- **Delete operations**: `delete`, `remove`, `archive`
- **Admin operations**: `approve`, `reject`, `grant`, `revoke`

### Action Constraints

Limit actions to appropriate entity types:

```json
{
  "actions": {
    "executeCode": {
      "appliesTo": {
        "principalTypes": ["User", "ServiceAccount"],
        "resourceTypes": ["CodeRepository", "BuildPipeline"]
      }
    },
    "viewPatientRecord": {
      "appliesTo": {
        "principalTypes": ["Doctor", "Nurse"],
        "resourceTypes": ["PatientRecord"]
      }
    }
  }
}
```

## Schema Patterns

### Multi-Tenancy Schema

Design for tenant isolation:

```json
{
  "Tenant": {
    "memberOfTypes": [],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String", "required": true }
      }
    }
  },
  "User": {
    "memberOfTypes": ["Tenant", "Group"],
    "shape": {
      "type": "Record",
      "attributes": {
        "tenantId": { "type": "String", "required": true }
      }
    }
  },
  "Document": {
    "memberOfTypes": ["Tenant", "Folder"],
    "shape": {
      "type": "Record",
      "attributes": {
        "tenantId": { "type": "String", "required": true }
      }
    }
  }
}
```

### Organizational Hierarchy

Model organizational structures:

```json
{
  "Company": {
    "memberOfTypes": [],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String" }
      }
    }
  },
  "Department": {
    "memberOfTypes": ["Company"],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String" }
      }
    }
  },
  "Team": {
    "memberOfTypes": ["Department"],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String" }
      }
    }
  },
  "User": {
    "memberOfTypes": ["Team"],
    "shape": {
      "type": "Record",
      "attributes": {
        "name": { "type": "String" }
      }
    }
  }
}
```

### Classification Levels

Implement security classification:

```json
{
  "ClassificationLevel": {
    "memberOfTypes": [],
    "shape": {
      "type": "Record",
      "attributes": {
        "level": { "type": "Long", "required": true },
        "name": { "type": "String", "required": true }
      }
    }
  },
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "clearanceLevel": { "type": "Long", "required": true }
      }
    }
  },
  "Document": {
    "shape": {
      "type": "Record",
      "attributes": {
        "classification": { "type": "String", "required": true },
        "requiredClearance": { "type": "Long", "required": true }
      }
    }
  }
}
```

## Schema Best Practices

### Keep Entity Types Focused

Each entity type should represent a single concept:

**Good:**

```json
{
  "User": { ... },          // People who use the system
  "Group": { ... },         // Collections of users
  "Document": { ... },      // Files/documents
  "Folder": { ... }         // Document containers
}
```

**Avoid:**

```json
{
  "Thing": {  // Too generic
    "attributes": {
      "type": { "type": "String" },  // Indicates multiple concepts
      "role": { "type": "String" }
    }
  }
}
```

### Minimize Attribute Count

Include only authorization-relevant attributes:

**Good:**

```json
{
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "department": { "type": "String" },        // Relevant for policies
        "clearanceLevel": { "type": "Long" },      // Relevant for policies
        "manager": { "type": "Entity", "name": "User" }  // Relevant for policies
      }
    }
  }
}
```

**Avoid:**

```json
{
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "department": { "type": "String" },
        "clearanceLevel": { "type": "Long" },
        "favoriteColor": { "type": "String" },     // Not relevant for authorization
        "lastVacation": { "type": "String" },      // Not relevant for authorization
        "phoneNumber": { "type": "String" }        // Not relevant for authorization
      }
    }
  }
}
```

### Use Consistent Patterns

Apply consistent patterns across entity types:

**Consistent ownership:**

```json
{
  "Document": {
    "shape": {
      "type": "Record",
      "attributes": {
        "owner": { "type": "Entity", "name": "User" }
      }
    }
  },
  "Project": {
    "shape": {
      "type": "Record",
      "attributes": {
        "owner": { "type": "Entity", "name": "User" }  // Same pattern
      }
    }
  }
}
```

**Consistent timestamps:**

```json
{
  "Document": {
    "shape": {
      "type": "Record",
      "attributes": {
        "createdAt": { "type": "String" },
        "updatedAt": { "type": "String" }
      }
    }
  },
  "Comment": {
    "shape": {
      "type": "Record",
      "attributes": {
        "createdAt": { "type": "String" },
        "updatedAt": { "type": "String" }  // Same pattern
      }
    }
  }
}
```

### Document Your Schema

Add comments and documentation:

```json
{
  "User": {
    "memberOfTypes": ["Group", "Role"],
    "shape": {
      "type": "Record",
      "attributes": {
        "department": {
          "type": "String",
          "required": true,
          "description": "User's department code (e.g., 'ENG', 'SALES')"
        },
        "clearanceLevel": {
          "type": "Long",
          "required": true,
          "description": "Security clearance level (0=none, 1=confidential, 2=secret, 3=top-secret)"
        }
      }
    }
  }
}
```

### Version Your Schema

Track schema changes:

```json
{
  "$schema": "https://schema.cedarpolicy.com/v1.0",
  "$version": "2.1.0",
  "$changelog": "Added classification attribute to Document",
  "User": { ... }
}
```

## Schema Validation

### Validate Schema Syntax

Use Cedar CLI to validate schema:

```bash
cedar validate-schema --schema schema.cedarschema.json
```

### Test Schema with Policies

Validate policies against schema:

```bash
cedar validate --schema schema.cedarschema.json --policy-set policies/
```

### Schema Evolution

Handle schema changes safely:

**Adding attributes:**

- Optional attributes: Safe, no policy changes needed
- Required attributes: Requires entity data updates

**Removing attributes:**

- Check policies for references first
- Update policies before removing from schema

**Changing attribute types:**

- Breaking change
- Update policies and entity data together

## Common Schema Anti-Patterns

### Overly Generic Types

**Avoid:**

```json
{
  "Entity": {  // Too generic
    "shape": {
      "type": "Record",
      "attributes": {
        "properties": { "type": "String" }  // Unstructured
      }
    }
  }
}
```

**Prefer:**

```json
{
  "User": { ... },
  "Document": { ... },
  "Folder": { ... }
}
```

### Deep Nesting

**Avoid:**

```json
{
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "profile": {
          "type": "Record",
          "attributes": {
            "personal": {
              "type": "Record",
              "attributes": {
                "address": {
                  "type": "Record",  // Too deep
                  "attributes": { ... }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

**Prefer:**

```json
{
  "User": {
    "shape": {
      "type": "Record",
      "attributes": {
        "city": { "type": "String" },
        "country": { "type": "String" }  // Flatten structure
      }
    }
  }
}
```

### Circular Relationships

**Avoid:**

```json
{
  "A": {
    "shape": {
      "type": "Record",
      "attributes": {
        "b": { "type": "Entity", "name": "B" }
      }
    }
  },
  "B": {
    "shape": {
      "type": "Record",
      "attributes": {
        "a": { "type": "Entity", "name": "A" }  // Circular
      }
    }
  }
}
```

---

Well-designed schemas enable expressive, maintainable policies while ensuring type safety and validation. Follow these
principles to create robust authorization models.
