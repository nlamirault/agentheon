# Reference - Information-Oriented Documentation

## Purpose and Definition

Reference guides serve as **technical descriptions of the machinery and how to operate it**. They provide
information-oriented content featuring propositional and theoretical knowledge that users consult during their work
rather than read sequentially.

## Core Characteristics

Reference material is fundamentally **descriptive**. It functions like a map—offering accurate information about a
product's territory without requiring users to verify details themselves.

Good technical reference is essential to provide users with the confidence to do their work.

### Consulted, Not Read

Reference documentation is **austere** in nature. Users consult it for specific information rather than reading it
leisurely from start to finish.

### Provides Truth and Certainty

The primary goal is delivering accuracy and reliability. Users must trust that reference documentation tells the truth
about how the software behaves.

## Key Principles

### 1. Describe Neutrally

Content must maintain objectivity and factuality through austere, uncompromising style.

**Do**:

- State facts about behavior
- Describe what exists
- Document actual functionality
- Use neutral language

**Don't**:

- Mix in explanations
- Include instructions
- Express opinions
- Add teaching material

The framework warns against mixing in explanation, instruction, or opinion—common pitfalls since neutral description
contradicts natural communication patterns.

**Why it's hard**: Natural communication involves:

- Context and background
- Instructions for use
- Opinions and recommendations
- Stories and examples

Reference requires suppressing these natural inclinations.

**Solution**: Link to how-to guides and tutorials for instructional content. Link to explanation for context and
understanding.

### 2. Maintain Consistency

**Reference material is useful when it is consistent.**

Standard patterns enable effective navigation. Readers expect:

- Familiar formatting
- Predictable information placement
- Consistent naming conventions
- Standard section organization

**Example**: If API endpoints are documented as:

```text
Endpoint: /api/users
Method: GET
Parameters: ...
Returns: ...
```

Use this exact structure for every endpoint.

### 3. Mirror Product Structure

Documentation architecture should reflect the product's logical organization.

This helps users:

- Navigate code and documentation simultaneously
- Find information predictably
- Understand system organization
- Map concepts to implementation

**Example**: If your product has modules for:

- Authentication
- Database
- API
- UI

Your reference should have corresponding sections organized identically.

### 4. Include Illustrative Examples

Examples demonstrate usage without explaining or instructing.

**Purpose**: Provide succinct context for how something works.

**Keep examples**:

- Brief (1-5 lines typically)
- Illustrative, not instructional
- Focused on showing behavior
- Without explanation

**Example**:

```python
user.authenticate(password="secret123")
# Returns: True if authenticated, False otherwise
```

Not a tutorial on authentication, just showing the method signature and return value.

## Language Standards

Reference guides employ direct, factual statements.

### State Facts About Behavior

**Good**:

- "Returns a list of User objects"
- "Raises ValueError if input is negative"
- "Accepts integers between 1 and 100"
- "Defaults to 30-second timeout"

**Bad**:

- "You can use this to get users" (instructional)
- "This is useful for..." (opinion)
- "We designed this to..." (explanation)
- "Try setting the timeout to..." (instruction)

### List Operations

Use clear, structured lists:

**Methods**:

- `authenticate(credentials)` - Validates user credentials
- `authorize(user, resource)` - Checks access permissions
- `logout(session_id)` - Terminates user session

### Provide Necessary Warnings

State important constraints or side effects:

**Format**:

- "**Warning**: This operation cannot be undone"
- "**Note**: Requires administrator privileges"
- "**Caution**: May cause data loss"

## Reference Structure

### Standard API Reference Template

````markdown
# Class/Module/Function Name

[One-sentence description]

## Syntax

```language
function_name(param1, param2, **kwargs)
```
````

## Parameters

- **param1** (type): Description
- **param2** (type): Description
- **kwargs** (dict, optional): Additional options

## Returns

- **return_type**: Description of return value

## Raises

- **ExceptionType**: When this exception occurs

## Examples

```language
# Basic usage
result = function_name("value", 42)
```

## See Also

- [Related function](link)
- [Related concept explanation](link)

````text
### Standard Configuration Reference Template

```markdown
# Configuration Option Name

## Description

[What this option controls]

## Type

`string` | `integer` | `boolean` | `array`

## Default Value
````

default_value

```text
## Valid Values

- `value1` - [When to use]
- `value2` - [When to use]

## Example
```

option_name: value

```text
## Related Options

- [option_a](link) - Often used together
- [option_b](link) - Mutually exclusive with
```

### Standard CLI Reference Template

```markdown
# command-name

## Synopsis
```

command-name [OPTIONS] <required-arg> [optional-arg]

````text
## Description

[What this command does]

## Arguments

- `required-arg` - Description
- `optional-arg` - Description (optional)

## Options

### `-f, --flag`
Description of flag behavior

### `-o, --option <value>`
- **Type**: string
- **Default**: default_value
- Description

## Exit Codes

- `0` - Success
- `1` - General error
- `2` - Specific error condition

## Examples

```bash
# Basic usage
command-name arg

# With options
command-name --flag --option=value arg
````

## See Also

- [related-command](link)

```text
## Real-World Model: Food Packaging Labels

Reference documentation mirrors food packaging labels—legally governed, precise information presented predictably.

Food labels consistently show:
- Ingredients (what's in it)
- Nutritional facts (measurable properties)
- Warnings (important constraints)
- Storage instructions (how to maintain)

All presented neutrally without:
- Recipes (how-to guides)
- Cooking lessons (tutorials)
- Nutrition science (explanation)

## Organization Strategies

### By Category

Group related items:
```

API Reference
├── Authentication
│ ├── login()
│ ├── logout()
│ └── refresh_token()
├── Users
│ ├── create_user()
│ ├── get_user()
│ └── update_user()
└── Data
├── query()
├── insert()
└── delete()

```text
### By Type

Organize by component type:
```

Reference
├── Classes
│ ├── User
│ ├── Session
│ └── Database
├── Functions
│ ├── authenticate()
│ ├── authorize()
│ └── validate()
└── Constants
├── API_VERSION
├── MAX_RETRIES
└── TIMEOUT

```text
### Alphabetically

For large APIs, alphabetical listing with category tags:
```

authenticate() [Authentication]
authorize() [Authorization]
create_user() [Users]
delete() [Data]
...

```text
## Common Problems and Solutions

### Problem: Including Instructions

**Issue**: Reference starts teaching how to use features.

**Solution**: Describe what exists. Link to how-to guides for usage.

**Example**:
- Bad: "To authenticate users, first call authenticate() with credentials, then..."
- Good: "authenticate(credentials) - Validates user credentials. Returns boolean. See [How to implement authentication](link)."

### Problem: Adding Explanations

**Issue**: Explaining why features exist or design decisions.

**Solution**: Link to explanation documentation.

**Example**:
- Bad: "We use JWT tokens because they're stateless and scalable..."
- Good: "Returns JWT token. See [Authentication architecture](link) for design rationale."

### Problem: Inconsistent Structure

**Issue**: Each section formatted differently.

**Solution**: Create templates and follow them religiously.

**Use**:
- Standard section headings
- Consistent parameter formatting
- Predictable organization
- Uniform examples style

### Problem: Missing Information

**Issue**: Reference omits important details.

**Solution**: Include comprehensive information:
- All parameters (including optional)
- All return values
- All exceptions
- All side effects
- All constraints

Users should never need to check source code for basic facts.

### Problem: Opinions and Judgments

**Issue**: Reference includes recommendations or opinions.

**Solution**: State facts only. Move opinions to explanation.

**Example**:
- Bad: "This is the best method for most use cases"
- Good: "Returns results in O(log n) time"

## Quality Checklist

Before publishing reference documentation, verify:

- [ ] Purely descriptive (no instructions, teaching, or opinions)
- [ ] Consistent structure throughout
- [ ] Mirrors product organization
- [ ] All parameters documented
- [ ] All return values documented
- [ ] All exceptions documented
- [ ] Examples are illustrative not instructional
- [ ] Links to how-to for usage
- [ ] Links to explanation for understanding
- [ ] Accurate and verified
- [ ] Complete (no missing items)
- [ ] Neutral tone throughout
- [ ] Version-specific
- [ ] Searchable and navigable

## Completeness vs Usability

Reference documentation should be:

**Complete**: Document everything
- All public APIs
- All configuration options
- All commands and flags
- All return values and exceptions

**Organized**: Group logically
- By feature area
- By component type
- By user task
- With clear navigation

**Searchable**: Enable finding information
- Good names and titles
- Search functionality
- Index or table of contents
- Cross-references

## Auto-Generated vs Manual Reference

### Auto-Generated Reference

**Advantages**:
- Always in sync with code
- Complete coverage
- Consistent format
- Low maintenance

**Disadvantages**:
- Often too technical
- Missing context
- Poor organization
- Unclear descriptions

**Solution**: Generate structure, enhance with:
- Clear descriptions
- Useful examples
- Better organization
- Cross-references

### Manual Reference

**Advantages**:
- Optimized for users
- Better explanations
- Logical organization
- Curated examples

**Disadvantages**:
- Can get out of sync
- Requires maintenance
- May have gaps
- More expensive

**Solution**: Combine approaches:
- Generate base from code
- Enhance manually
- Automate validation
- Regular sync checks

## Relationship to Other Documentation

Reference works with other documentation types:

**Supports How-to Guides**:
- How-tos link here for details
- Reference provides comprehensive info
- How-tos provide practical usage

**Complements Explanation**:
- Reference: what it is
- Explanation: why it is

**Differs from Tutorial**:
- Tutorial: teaches through doing
- Reference: describes comprehensively

**Multiple purposes**:
- During work: Quick lookup
- Learning: Comprehensive understanding
- Troubleshooting: Verify behavior
- Development: Implementation details

Keep reference pure: neutral, complete, consistent, structured information users can trust.

---

**Source**: https://diataxis.fr/reference/
```
