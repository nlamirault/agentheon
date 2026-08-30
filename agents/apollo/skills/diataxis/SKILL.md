---
name: diataxis
description: Comprehensive guidance on the Diátaxis documentation framework for technical writing
license: Apache-2.0
allowed-tools: Read Write Glob Grep TodoWrite
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - markdown
  task: [review, document]
  persona: [technical-writer, developer]
  workload: [documentation]
---

# Diátaxis Documentation Framework

Apply the Diátaxis framework to create, organize, and improve technical documentation.
Diátaxis provides a systematic approach organizing content into four distinct types based on user needs and context.

## The Four Documentation Types

Diátaxis organizes documentation along two axes:

**Acquisition vs Application** (horizontal axis)

- **Acquisition**: Learning and studying
- **Application**: Working and achieving goals

**Theory vs Practice** (vertical axis)

- **Practice**: Hands-on, action-oriented
- **Theory**: Knowledge-based, information-oriented

This creates four quadrants:

### 1. Tutorials (Learning + Practice)

**Purpose**: Guide newcomers through first experiences
**Nature**: Learning-oriented lessons
**User need**: "Teach me to cook"

**Key characteristics**:

- Learning by doing meaningful work
- Teacher bears responsibility for success
- Early, visible results
- Concrete, specific steps
- Repetition for confidence
- No alternatives or explanations

**When to write**: Onboarding new users, teaching fundamentals

### 2. How-to Guides (Application + Practice)

**Purpose**: Solve specific real-world problems
**Nature**: Task-oriented directions
**User need**: "I want to prepare a meal"

**Key characteristics**:

- Goal-focused
- Assumes existing competence
- Addresses real problems
- Logical sequencing
- Practical scope
- Conditional imperatives

**When to write**: Common user tasks, specific workflows

### 3. Reference (Application + Theory)

**Purpose**: Describe technical machinery accurately
**Nature**: Information-oriented specifications
**User need**: "What ingredients do I have?"

**Key characteristics**:

- Neutral, factual descriptions
- Consistent structure
- Mirrors product architecture
- Austere presentation
- Examples without instruction
- Consulted, not read sequentially

**When to write**: API docs, configuration options, specifications

### 4. Explanation (Learning + Theory)

**Purpose**: Deepen understanding and context
**Nature**: Understanding-oriented discussion
**User need**: "Tell me about nutrition"

**Key characteristics**:

- Discursive treatment
- Makes connections
- Provides context
- Discusses alternatives
- Acknowledges perspectives
- Read away from the product

**When to write**: Design decisions, concepts, architecture

## Applying Diátaxis

### Identify Documentation Type

Ask these questions:

1. **Is the user learning or working?** → Learning = Tutorial/Explanation, Working = How-to/Reference
2. **Is content practical or theoretical?** → Practical = Tutorial/How-to, Theoretical = Reference/Explanation

### Write for Each Type

**For Tutorials**:

- Start with what users will build
- Provide step-by-step guidance
- Use first-person plural ("We will...")
- Show expected results after each step
- Ensure perfect reliability
- Omit explanations (link to Explanation docs)

**For How-to Guides**:

- State the goal clearly
- Assume competence
- Focus on solving the problem
- Use conditional imperatives ("If x, do y")
- Link to Reference for details
- Keep practical scope

**For Reference**:

- Describe what exists
- Maintain neutral tone
- Use consistent structure
- Match product organization
- Include brief examples
- State facts without opinion

**For Explanation**:

- Discuss the "why"
- Make connections between concepts
- Provide historical context
- Present alternatives and tradeoffs
- Acknowledge different perspectives
- Encourage reflection

## Common Mistakes

**Mixing types**: Most documentation problems arise from mixing types in a single document. Keep them separate.

**Tutorial mistakes**:

- Teaching abstractions too early
- Providing too many options
- Including lengthy explanations
- Making steps unreliable

**How-to mistakes**:

- Writing from machinery perspective
- Teaching when users need solutions
- Including unnecessary completeness
- Unclear goal statements

**Reference mistakes**:

- Including instructions
- Adding opinions
- Inconsistent structure
- Missing key information

**Explanation mistakes**:

- Including step-by-step instructions
- Just restating reference material
- Too narrow or too broad scope
- Avoiding necessary opinion

## Documentation Structure

Organize your docs folder:

```text
docs/
├── tutorials/
│   ├── getting-started.md
│   └── first-project.md
├── how-to/
│   ├── deploy-production.md
│   └── configure-auth.md
├── reference/
│   ├── api.md
│   └── configuration.md
└── explanation/
    ├── architecture.md
    └── design-decisions.md
```

## Quick Decision Tree

```text
User's question:
├─ "How do I...?" → How-to Guide
├─ "What is...?" → Reference or Explanation
│   ├─ Factual answer → Reference
│   └─ Conceptual understanding → Explanation
├─ "Why does...?" → Explanation
└─ "Can you teach me...?" → Tutorial
```

## Cross-References

For detailed guidance on each type, see:

- **references/tutorials.md** - Complete tutorial writing guide
- **references/how-to.md** - How-to guide best practices
- **references/reference.md** - Reference documentation standards
- **references/explanation.md** - Explanation writing guidance
- **references/overview.md** - Framework foundation and principles

## Progressive Application

Start with one type:

1. Identify your most critical documentation need
2. Choose the matching Diátaxis type
3. Write or restructure following that type's principles
4. Gradually separate mixed content into appropriate types
5. Create clear navigation between types

The framework becomes more powerful as you maintain clear boundaries between documentation types.

## External Resources

- Diátaxis official site: <https://diataxis.fr/>
- Interactive framework: <https://diataxis.fr/map/>
- Compass tool: <https://diataxis.fr/compass/>
