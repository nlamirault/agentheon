# Explanation - Understanding-Oriented Documentation

## Core Definition

Explanation documentation is **a discursive treatment of a subject, that permits reflection** and is fundamentally
**understanding-oriented**. It deepens readers' comprehension by providing clarity, context, and connections across a
broader knowledge area.

## Purpose and Value

Explanation answers the question: **"Can you tell me about...?"**

Rather than instructing users on tasks or documenting technical machinery, explanation takes a wider perspective. It's
**documentation that it makes sense to read while away from the product itself**—conceptual material meant for
contemplation rather than immediate application.

### Why Explanation Matters

While seemingly less urgent than tutorials, how-to guides, or reference materials, explanation is equally important.

Practitioners without understanding:

- Lack mastery
- Exercise their craft anxiously
- Make poor decisions
- Can't adapt to changes
- Miss bigger picture

Explanation weaves together fragmented knowledge into cohesive understanding.

## Key Characteristics

### Reflective and Contextual

Goes beyond immediate practical concerns to provide:

- Historical context
- Design rationale
- Conceptual frameworks
- Theoretical foundations

### Discursive Tone

Discusses rather than instructs:

- Explores topics
- Considers alternatives
- Weighs tradeoffs
- Acknowledges complexity

### Bounded Scope

Covers a meaningful topic area, not the entire subject:

- One concept at a time
- Related ideas grouped together
- Clear boundaries
- Focused discussion

### Perspective-Informed

Acknowledges opinions, design decisions, and alternatives:

- States perspectives
- Discusses choices made
- Presents alternatives considered
- Explains reasoning

## Writing Best Practices

### 1. Make Connections

Link ideas across topics to create understanding networks.

**Techniques**:

- "This concept relates to X because..."
- "Understanding Y helps explain Z..."
- "This pattern appears in both A and B..."
- "The relationship between X and Y is..."

**Example**: "Our caching strategy connects to our database design. Because we chose eventual consistency (explained in
[Database Architecture]), we can safely cache data for longer periods without complex invalidation logic."

### 2. Provide Context

Explain the **"why"**—design decisions, historical reasons, and technical constraints.

**Questions to answer**:

- Why was this approach chosen?
- What problem does it solve?
- What were the alternatives?
- What constraints influenced the decision?
- What are the tradeoffs?

**Example**: "We use event-driven architecture rather than direct database access. This choice stems from our need to
scale horizontally and maintain loose coupling between services. While it adds complexity in debugging, it provides the
flexibility needed for our growth trajectory."

### 3. Address Broader Questions

Explore history, alternatives, choices, and justifications.

**Topics to cover**:

- **History**: "Originally we used X, but switched to Y because..."
- **Alternatives**: "We considered A, B, and C. We chose B because..."
- **Evolution**: "This approach emerged from our experience with..."
- **Context**: "In the broader landscape of similar systems..."

### 4. Acknowledge Perspectives

Discuss multiple approaches and counter-examples. Opinion is appropriate here.

**Phrases**:

- "In our view..."
- "We believe that..."
- "Some teams prefer X, while others choose Y..."
- "This approach works well when..."
- "The tradeoff here is..."

**Example**: "Some teams prefer microservices for every component. We've taken a more pragmatic approach, using
microservices only where they provide clear benefits. This reflects our team size and operational capabilities rather
than a belief that monoliths are superior."

### 5. Stay Focused

Resist including instructions or technical descriptions that belong elsewhere.

**Don't include**:

- Step-by-step instructions → How-to guide
- API specifications → Reference
- Hands-on lessons → Tutorial

**Do include**:

- Conceptual understanding
- Design rationale
- Theoretical foundations
- Strategic thinking

## Language Examples

Explanation uses distinctive language patterns:

### Causal Explanations

- "The reason for X is because historically, Y..."
- "This happens because of the relationship between..."
- "X leads to Y, which causes Z..."

### Comparative Assessments

- "W is better than Z, because..."
- "While X offers advantage A, Y provides benefit B..."
- "Compared to traditional approaches..."

### Acknowledging Alternatives

- "Some users prefer W (because Z). This can be a good approach, but..."
- "Alternative strategies include X and Y, each with different tradeoffs..."
- "In some contexts, approach A makes sense, while others benefit from B..."

### Contextual Framing

- "In the context of modern web applications..."
- "Given our constraints of..."
- "Considering the evolution of..."

## Explanation Structure

### Standard Template

```markdown
# [Concept or Topic Name]

## Overview

[High-level introduction to the topic]

## Background

[Historical context, why this matters]

## Core Concepts

[Key ideas explained]

### Concept 1

[Discussion]

### Concept 2

[Discussion]

## How It Works

[Conceptual explanation, not instructions]

## Design Decisions

[Why things are the way they are]

## Tradeoffs

[Advantages and disadvantages]

## Alternatives

[Other approaches and when they make sense]

## Common Misconceptions

[Clarify misunderstandings]

## Related Concepts

- [Link to related explanation]
- [Link to reference for specs]
- [Link to how-to for implementation]

## Further Reading

[External resources for deeper understanding]
```

### Opening Sections

**Overview**: Set the stage

- What is this about?
- Why does it matter?
- What will be covered?

**Background**: Provide context

- Historical development
- Problem being addressed
- Evolution of the approach

### Core Content Sections

**Conceptual explanations**: Discuss ideas

- Break down complex concepts
- Make connections
- Use analogies and metaphors

**Design decisions**: Explain choices

- What was decided
- Why it was decided
- What alternatives existed
- What tradeoffs were made

**Tradeoffs**: Acknowledge costs and benefits

- Advantages of approach
- Disadvantages or limitations
- When to use vs avoid

### Closing Sections

**Related concepts**: Connect to other understanding
**Further reading**: External resources

## Alternative Naming

Documentation sections might use different titles:

- **Discussion** - Topical discussions
- **Background** - Context and history
- **Conceptual Guides** - Concept explanations
- **Topics** - Thematic coverage
- **Architecture** - System design rationale
- **Design** - Decision documentation

All serve the same purpose: understanding-oriented content.

## Common Topics for Explanation

### Architecture and Design

- System architecture overview
- Microservices vs monolith reasoning
- Database schema design rationale
- API design philosophy
- Security model explanation

### Concepts and Principles

- Core concepts in the domain
- Theoretical foundations
- Design patterns used
- Best practices rationale
- Guiding principles

### Decisions and Tradeoffs

- Technology choices
- Architectural decisions (ADRs)
- Performance vs maintainability tradeoffs
- Scalability strategies
- Technical debt decisions

### Domain Knowledge

- Domain model explanation
- Business logic rationale
- Workflow explanations
- Data model concepts
- Integration patterns

## Examples of Good Explanation Titles

- "Why We Chose Event-Driven Architecture"
- "Understanding Our Caching Strategy"
- "The Evolution of Our API Design"
- "Database Consistency Model Explained"
- "Authentication Architecture and Decisions"
- "Microservices Boundaries: Our Approach"

## Examples of Bad Explanation Titles

- "How to Set Up Authentication" (how-to guide)
- "API Reference" (reference documentation)
- "Build Your First Feature" (tutorial)
- "Database Configuration Options" (reference)

## Common Problems and Solutions

### Problem: Including Step-by-Step Instructions

**Issue**: Explanation turns into a how-to guide.

**Solution**: Describe concepts and rationale. Link to how-to for implementation.

**Example**:

- Bad: "First, configure the cache settings. Then, add these lines to your code..."
- Good: "Our caching strategy uses a two-tier approach: application-level for hot data, database-level for consistency.
  For implementation, see [How to configure caching](link)."

### Problem: Just Restating Reference Material

**Issue**: Repeating technical descriptions without adding understanding.

**Solution**: Provide context, rationale, and connections.

**Example**:

- Bad: "The authenticate() function takes a username and password and returns a boolean."
- Good: "Authentication in our system follows a token-based model because it aligns with our stateless service
  architecture. This choice enables horizontal scaling but requires careful token management. See
  [authenticate() reference](link) for technical details."

### Problem: Too Narrow or Too Broad Scope

**Issue**: Either too detailed on implementation or too vague on concepts.

**Solution**: Focus on one conceptual area at appropriate depth.

**Example**:

- Too narrow: "The index on column X"
- Too broad: "Everything about our system"
- Right: "Database Indexing Strategy and Performance"

### Problem: Avoiding Necessary Opinion

**Issue**: Trying to stay neutral when perspective would help.

**Solution**: State opinions clearly and explain reasoning.

**Example**:

- Bad (too neutral): "Some teams use microservices, others use monoliths."
- Good (clear perspective): "We use a modular monolith rather than microservices because our team size and operational
  maturity make monolith maintenance more practical. As we grow, we may extract services, but premature distribution
  would add unnecessary complexity."

## Quality Checklist

Before publishing explanation documentation, verify:

- [ ] Focuses on understanding, not instructions
- [ ] Provides historical context or background
- [ ] Explains design decisions and rationale
- [ ] Discusses alternatives and tradeoffs
- [ ] Makes connections between concepts
- [ ] Appropriate scope (not too narrow or broad)
- [ ] Clear perspective where appropriate
- [ ] No step-by-step instructions
- [ ] No duplication of reference material
- [ ] Links to how-to for implementation
- [ ] Links to reference for specifications
- [ ] Links to tutorial for learning
- [ ] Readable away from the product
- [ ] Encourages reflection

## When to Write Explanation

Create explanation documentation when:

### After Design Decisions

Document architectural choices:

- Architecture Decision Records (ADRs)
- Technology selection rationale
- Pattern choices

### When Patterns Emerge

Explain recurring patterns:

- Common approaches in codebase
- Standard solutions to problems
- Team conventions

### For Complex Concepts

Clarify difficult topics:

- Domain concepts
- Theoretical foundations
- Complex interactions

### After Team Discussions

Capture shared understanding:

- Design debates resolution
- Team decisions
- Lessons learned

### When Users Ask "Why?"

Respond to understanding questions:

- "Why did you choose X?"
- "What's the reasoning behind Y?"
- "How does Z relate to W?"

## Relationship to Other Documentation

Explanation connects to other documentation types:

**Complements Reference**:

- Reference: what it is
- Explanation: why it is

**Informs How-to Guides**:

- Explanation: conceptual understanding
- How-to: practical implementation

**Deepens Tutorial Learning**:

- Tutorial: hands-on experience
- Explanation: theoretical understanding

**Enables Better Usage**:
Users with understanding:

- Make better decisions
- Adapt to new situations
- Troubleshoot effectively
- Contribute confidently

## The Value of Understanding

Explanation documentation creates:

**Confidence**: Users understand why things work
**Adaptability**: Users can handle new situations
**Mastery**: Users work without anxiety
**Contribution**: Users can extend and improve
**Efficiency**: Users make informed decisions

Without explanation, users may successfully complete tasks but lack the understanding needed for mastery.

With explanation, users transform from following instructions to exercising informed judgment.

Keep explanation pure: discursive, contextual, perspective-informed discussions that deepen understanding.

---

**Source**: <https://diataxis.fr/explanation/>
