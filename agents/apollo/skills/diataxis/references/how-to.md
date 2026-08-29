# How-to Guides - Task-Oriented Documentation

## Definition and Purpose

How-to guides are **directions that guide the reader through a problem or towards a result** and are fundamentally
**goal-oriented**. They help users accomplish specific tasks correctly and safely by navigating real-world problems.

## Core Characteristics

How-to guides share these essential traits:

### Task-Focused

Address specific, achievable goals rather than broad concepts. Each guide solves one particular problem.

### User-Centric

Written from the perspective of what users need to accomplish, not machinery functions.

### Action-Oriented

Contain only practical steps with no teaching or explanations. Get straight to solving the problem.

### Assume Competence

Presume readers already know what they want to achieve and have basic familiarity with the tools.

## Distinction from Other Documentation

### How-to vs Tutorial

**Tutorials** teach foundational skills to beginners through guided learning experiences.

**How-to guides** serve already-competent users seeking specific solutions to real problems.

Key differences:

| Tutorial                         | How-to Guide              |
| -------------------------------- | ------------------------- |
| Learning-oriented                | Goal-oriented             |
| Takes responsibility for success | Assumes user competence   |
| One prescribed path              | May have variations       |
| Shows what to learn              | Shows how to achieve goal |
| For beginners                    | For practitioners         |

### How-to vs Reference

**Reference** describes what exists comprehensively.

**How-to** shows how to achieve specific goals practically.

How-to guides link to reference for comprehensive details rather than including them inline.

## Key Principles for Writing

### Problem-Based Approach

Guides **must be written from the perspective of the user, not of the machinery.**

This means:

- Start with user's goal, not tool's capabilities
- Address genuine human needs
- Frame around problems users actually face
- Use user language, not technical jargon

**Bad**: "How to configure the authentication middleware"
**Good**: "How to add user login to your application"

### Logical Sequencing

Present steps in a meaningful order that reflects how users actually think and work.

This creates:

- Narrative flow
- Anticipation of user needs
- Logical progression
- Clear dependencies between steps

### Practical Scope

Maintain focus on the specific goal without unnecessary completeness.

**Do**:

- Cover what's needed for this goal
- Link to reference for comprehensive details
- Stay focused on the problem
- Keep it concise

**Don't**:

- Explain every option exhaustively
- Cover tangential topics
- Duplicate reference documentation
- Include background information

### Appropriate Naming

Titles should clearly state what users will accomplish.

**Good examples**:

- "How to integrate application performance monitoring"
- "How to set up automated database backups"
- "How to enable two-factor authentication"
- "How to deploy with zero downtime"

**Bad examples**:

- "Performance monitoring" (not a task)
- "Database setup" (too vague)
- "Authentication features" (not goal-oriented)
- "Deployment" (not specific)

## Language Conventions

### Conditional Imperatives

Use "If you want X, do Y" construction:

- "If you want to enable SSL, add the following configuration..."
- "To allow users to reset passwords, implement these endpoints..."
- "For production deployments, configure these environment variables..."

### Action Verbs

Start steps with clear action verbs:

- "Configure the database connection"
- "Create a new API key"
- "Update the security settings"
- "Test the integration"

### Present Tense

Write in present tense for clarity:

- "The system validates the token" (not "will validate")
- "This command deploys the application" (not "will deploy")

### Direct Address

Address the user directly:

- "You should see..."
- "Your next step is..."
- "You can verify by..."

## How-to Guide Structure

### Standard Template

```markdown
# How to [Accomplish Specific Goal]

## Context

[One paragraph: When you need this and why]

## Prerequisites

- Prerequisite 1
- Prerequisite 2

## Steps

### 1. [First Major Action]

[Instructions for this step]

### 2. [Second Major Action]

[Instructions for this step]

### 3. [Verify It Works]

[How to confirm success]

## Troubleshooting

- **Problem**: [Common issue]
  **Solution**: [How to fix]

## Related Resources

- [Link to reference docs]
- [Link to related how-to]
- [Link to explanation]
```

### Opening Sections

**Context**: One paragraph explaining when this guide applies and what it accomplishes.

**Prerequisites**: What users need before starting:

- Required permissions
- Necessary tools or resources
- Related configuration

### Step Sections

**Major actions**: Break the goal into 3-7 major steps.

**Sub-steps**: Within each major step, provide specific instructions.

**Code and commands**: Give exact commands with placeholder variables clearly marked:

```bash
deploy --environment=<ENVIRONMENT> --version=<VERSION>
```

**Verification**: Include how to verify each major step succeeded.

### Troubleshooting Section

Address common problems users encounter:

- State the problem clearly
- Provide solution
- Explain why problem occurs (briefly)

### Related Resources

Link to:

- **Reference**: For comprehensive details
- **Explanation**: For understanding concepts
- **Related how-tos**: For related tasks
- **Tutorial**: For learning fundamentals

## Real-World Model: Recipes

Recipes exemplify excellent how-to guides because they:

### Clearly Define Outcomes

"Chocolate chip cookies" tells you exactly what you'll make.

### Address Specific Questions

Not "How to bake" but "How to make chocolate chip cookies."

### Exclude Teaching

Assumes you know how to preheat an oven, mix ingredients, etc.

### Maintain Focus on Execution

Doesn't explain baking chemistry or alternative techniques.

### Require Baseline Competence

Assumes basic cooking skills and equipment.

## Common Problems and Solutions

### Problem: Too Much Explanation

**Issue**: Including lengthy background or theory.

**Solution**: Link to explanation documentation. Keep guide focused on steps.

**Example**:

- Bad: "OAuth 2.0 is an authorization framework that... [3 paragraphs]"
- Good: "We'll use OAuth 2.0 for authentication ([see explanation](link)). Configure it as follows..."

### Problem: Machinery Perspective

**Issue**: Writing from tool's viewpoint rather than user's goal.

**Solution**: Reframe around what user wants to accomplish.

**Example**:

- Bad: "How to use the DatabaseConnectionPool class"
- Good: "How to optimize database performance with connection pooling"

### Problem: Unnecessary Completeness

**Issue**: Documenting every possible option and variation.

**Solution**: Cover common case. Link to reference for options.

**Example**:

- Bad: "The `--timeout` flag accepts any positive integer representing milliseconds, with a default of 30000. You can
  set it to 1000 for... [extensive options documentation]"
- Good: "Set `--timeout=5000` for faster failover. See [timeout reference](link) for all options."

### Problem: Unclear Goal

**Issue**: Title doesn't clearly state what will be accomplished.

**Solution**: Make title specific and goal-oriented.

**Example**:

- Bad: "Working with the API"
- Good: "How to authenticate API requests with OAuth"

## Quality Checklist

Before publishing a how-to guide, verify:

- [ ] Title clearly states goal
- [ ] Context explains when to use this guide
- [ ] Prerequisites are listed
- [ ] Steps are logically ordered
- [ ] Each step has clear action verb
- [ ] Code/commands are copy-pastable
- [ ] Placeholders are clearly marked
- [ ] Verification steps included
- [ ] Common problems addressed
- [ ] Links to reference for details
- [ ] No teaching or tutorials
- [ ] No lengthy explanations
- [ ] Tested and works
- [ ] Assumes appropriate competence level

## Examples of Good How-to Titles

- "How to set up continuous deployment with GitHub Actions"
- "How to add user authentication with OAuth"
- "How to optimize Docker image build times"
- "How to migrate from SQLite to PostgreSQL"
- "How to implement rate limiting for your API"
- "How to configure automated database backups"

## Examples of Bad How-to Titles

- "Authentication Guide" (not task-oriented)
- "Using Docker" (too broad)
- "Introduction to CI/CD" (learning-oriented, use tutorial)
- "Everything About Databases" (not specific)
- "API Best Practices" (use explanation)

## Multiple Entry Points

Real-world problems often have multiple entry points or paths. This is okay for how-to guides, unlike tutorials which
must have one prescribed path.

**Example**: "How to deploy your application"

Different users might start from different points:

- "If using Docker, follow section 2.1"
- "For serverless deployment, skip to section 3"
- "If migrating from legacy system, see section 4"

Provide clear navigation for different scenarios while keeping each path focused.

## Relationship to Other Documentation

How-to guides connect to other documentation types:

**Uses Reference**:

- Links to comprehensive API documentation
- Points to configuration reference
- References command-line options

**Builds on Tutorial**:

- Assumes knowledge from tutorials
- Links back to tutorials for foundational learning

**Connects to Explanation**:

- Links to explanation for the "why"
- References design decisions
- Points to conceptual understanding

**Complements Other How-tos**:

- Links to related tasks
- Suggests next steps
- References prerequisite guides

## Maintaining Focus

The key to effective how-to guides is maintaining unwavering focus on the user's goal. Every sentence should serve the
purpose of helping accomplish that specific goal.

**Ask constantly**: "Does this sentence help the user accomplish this specific goal?"

If no, remove it or link to appropriate documentation type:

- Background → Explanation
- Comprehensive details → Reference
- Learning fundamentals → Tutorial
- Related task → Another how-to

Keep how-to guides lean, focused, and goal-oriented.

---

**Source**: <https://diataxis.fr/how-to-guides/>
