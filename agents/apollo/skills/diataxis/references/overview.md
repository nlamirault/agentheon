# Diátaxis Framework Overview

## What is Diátaxis?

Diátaxis is a systematic framework for technical documentation authoring and architecture. The name comes from the Greek
_διάταξις_ meaning "arrangement" or "organization."

The framework solves a fundamental problem in technical documentation:
**how to organize content so users can find what they need, when they need it.**

## The Core Problem

Technical documentation often fails because it:

- Mixes different types of content
- Doesn't match user needs to content types
- Lacks clear organization
- Tries to serve all purposes in one place

This creates frustrated users who can't find answers and documentation that's difficult to maintain.

## The Diátaxis Solution

Diátaxis organizes documentation into four distinct types based on two axes:

### The Two Axes

**1. User's State: Acquisition vs Application**

- **Acquisition** (Study): Learning and understanding
- **Application** (Work): Getting things done

**2. Content Nature: Practice vs Theory**

- **Practice**: Hands-on, doing
- **Theory**: Knowledge, information

### The Four Quadrants

These axes create four documentation types:

```text
                   Practice              Theory
             ┌──────────────────┬──────────────────┐
Acquisition  │                  │                  │
  (Study)    │    Tutorials     │   Explanation    │
             │  Learning-oriented│Understanding-oriented│
             ├──────────────────┼──────────────────┤
Application  │                  │                  │
  (Work)     │   How-to Guides  │    Reference     │
             │  Task-oriented   │Information-oriented│
             └──────────────────┴──────────────────┘
```

Each quadrant serves distinct user needs and requires different writing approaches.

## The Four Types in Detail

### Tutorials (Learning + Practice)

**Analogy**: Cooking lessons
**User need**: "Teach me to cook"
**Purpose**: Help users learn through guided doing

**Characteristics**:

- Step-by-step lessons
- One prescribed path
- Early visible results
- Minimal explanation
- Perfect reliability

**When users are**: Learning fundamentals, getting started, building confidence

### How-to Guides (Work + Practice)

**Analogy**: Recipes
**User need**: "Help me prepare a meal"
**Purpose**: Guide users to solve specific problems

**Characteristics**:

- Goal-oriented
- Assumes competence
- Multiple possible paths
- Conditional instructions
- Practical scope

**When users are**: Working on specific tasks, solving problems, achieving goals

### Reference (Work + Theory)

**Analogy**: Ingredient encyclopedia
**User need**: "What ingredients do I have?"
**Purpose**: Provide accurate technical information

**Characteristics**:

- Purely descriptive
- Comprehensive
- Consistent structure
- Neutral tone
- Consulted not read

**When users are**: Working and need facts, verifying behavior, checking options

### Explanation (Learning + Theory)

**Analogy**: Food science
**User need**: "Tell me about nutrition"
**Purpose**: Deepen understanding of concepts

**Characteristics**:

- Discursive
- Contextual
- Makes connections
- Discusses alternatives
- Opinion appropriate

**When users are**: Seeking understanding, learning concepts, making decisions

## Why Diátaxis Works

### 1. Matches User Needs

Users come to documentation in different states:

- **Learning**: Need tutorials and explanation
- **Working**: Need how-to guides and reference

By separating content types, you serve each need effectively.

### 2. Reduces Cognitive Load

When documentation types mix:

- Learners get overwhelmed by options
- Workers waste time on teaching content
- No one finds what they need quickly

Separation makes documentation faster to navigate and use.

### 3. Improves Maintainability

Clear boundaries make it easier to:

- Know where new content belongs
- Update without cascading changes
- Identify gaps in coverage
- Assign authoring responsibilities

### 4. Enables Team Alignment

Shared vocabulary helps teams:

- Discuss documentation needs clearly
- Make authoring decisions
- Review content effectively
- Plan documentation strategy

## Common Documentation Problems Solved

### Problem: "I can't find how to do X"

**Cause**: How-to guides mixed with reference or missing entirely
**Solution**: Separate task-oriented how-to guides

### Problem: "I followed the tutorial but it doesn't work"

**Cause**: Tutorial lacks reliability or includes too many options
**Solution**: Tested, single-path tutorials with clear steps

### Problem: "I need to know what parameters this function accepts"

**Cause**: Reference documentation missing or mixed with instruction
**Solution**: Comprehensive, neutral reference material

### Problem: "I don't understand why this is designed this way"

**Cause**: Lack of explanation documentation
**Solution**: Understanding-oriented explanation discussing rationale

### Problem: "Documentation is everywhere/nowhere"

**Cause**: No clear organization principle
**Solution**: Four-quadrant structure with clear boundaries

## Implementing Diátaxis

### Start Small

You don't need to reorganize everything at once:

1. **Identify your biggest pain point**
   - Users can't complete tasks → Add how-to guides
   - Users can't learn → Add tutorials
   - Users can't find specifications → Improve reference
   - Users don't understand concepts → Add explanation

2. **Create one example of that type**
   - Follow Diátaxis principles strictly
   - Test with real users
   - Iterate based on feedback

3. **Gradually expand**
   - Create more of that type
   - Add other types
   - Reorganize existing content

### Audit Existing Documentation

Review current docs and identify:

- **Mixed content**: Documents serving multiple purposes
- **Missing types**: Gaps in documentation coverage
- **Misplaced content**: Content in wrong type

### Reorganize Incrementally

Transform documentation gradually:

**Phase 1**: Separate most problematic mixed content
**Phase 2**: Fill critical gaps
**Phase 3**: Reorganize folder structure
**Phase 4**: Create navigation between types

## Maintaining Boundaries

The key to Diátaxis success is maintaining clear boundaries:

### What Tutorials Must NOT Include

- ❌ Explanations of concepts
- ❌ Multiple optional paths
- ❌ Comprehensive details
- ✅ Link to explanation for "why"
- ✅ Link to reference for complete info
- ✅ Focus on guided learning

### What How-to Guides Must NOT Include

- ❌ Teaching of fundamentals
- ❌ Lengthy background
- ❌ Complete specifications
- ✅ Link to tutorials for learning
- ✅ Link to reference for details
- ✅ Focus on achieving goals

### What Reference Must NOT Include

- ❌ Instructions or guidance
- ❌ Explanations or opinions
- ❌ Teaching content
- ✅ Link to how-to for usage
- ✅ Link to explanation for rationale
- ✅ Focus on facts

### What Explanation Must NOT Include

- ❌ Step-by-step instructions
- ❌ Technical specifications
- ❌ Hands-on lessons
- ✅ Link to how-to for implementation
- ✅ Link to reference for specs
- ✅ Focus on understanding

## Signs of Good Diátaxis Implementation

You know Diátaxis is working when:

✅ Users find answers quickly
✅ Documentation feels natural to navigate
✅ Team knows where to add new content
✅ Maintenance is straightforward
✅ Different user needs are clearly served
✅ Content doesn't duplicate across types
✅ Clear paths between related content

## Common Misconceptions

### "Every project needs all four types"

**Reality**: Start with what you need most. Small projects might start with just reference and how-to guides.

### "Each document must be only one type"

**Reality**: Yes, keep types separate. Don't mix tutorials with reference in one document.

### "Tutorials must be comprehensive"

**Reality**: Tutorials should be focused lessons. Create multiple tutorials rather than one exhaustive guide.

### "Reference means auto-generated API docs"

**Reality**: While auto-generation helps, reference needs human curation for clarity and organization.

### "Explanation is optional"

**Reality**: Explanation is critical for user mastery and confidence. Don't skip it.

## Diátaxis and Other Methodologies

### Diátaxis Complements

- **Docs-as-code**: Diátaxis provides structure for docs-as-code workflows
- **Style guides**: Focus on how to write; Diátaxis on what to write
- **Information architecture**: Diátaxis is IA specifically for technical docs
- **Documentation templates**: Templates implement Diátaxis patterns

### Diátaxis Differs From

- **DITA**: XML-based standard; Diátaxis is framework-agnostic
- **Minimalism**: Writing style; Diátaxis is organizational
- **Topic-based authoring**: Focuses on reusable chunks; Diátaxis on user needs

## Resources

### Official Diátaxis Resources

- **Main site**: <https://diataxis.fr/>
- **Interactive map**: <https://diataxis.fr/map/>
- **Compass tool**: <https://diataxis.fr/compass/>

### Each Documentation Type

- **Tutorials**: <https://diataxis.fr/tutorials/>
- **How-to guides**: <https://diataxis.fr/how-to-guides/>
- **Reference**: <https://diataxis.fr/reference/>
- **Explanation**: <https://diataxis.fr/explanation/>

### Community

- **GitHub discussions**: <https://github.com/evildmp/diataxis-documentation-framework/discussions>
- **Examples**: Many projects list Diátaxis implementations on the official site

## Quick Decision Guide

When creating documentation, ask:

**1. Is the user learning or working?**

- Learning → Tutorial or Explanation
- Working → How-to or Reference

**2. Is content practical or theoretical?**

- Practical → Tutorial or How-to
- Theoretical → Reference or Explanation

**3. Specifically:**

| User Goal                     | Create This  |
| ----------------------------- | ------------ |
| "Teach me the basics"         | Tutorial     |
| "Help me do X"                | How-to Guide |
| "What are the options for Y?" | Reference    |
| "Why does Z work this way?"   | Explanation  |

## Success Metrics

Track documentation effectiveness:

- **Findability**: Can users locate answers quickly?
- **Completion**: Do users successfully complete tasks?
- **Understanding**: Do users grasp concepts?
- **Satisfaction**: Do users report positive experiences?
- **Maintenance**: Is documentation easy to update?

Diátaxis directly improves all these metrics by providing clear structure matching user needs.

---

The Diátaxis framework transforms technical documentation from a catch-all knowledge dump into a well-organized system
serving distinct user needs effectively.

**Source**: <https://diataxis.fr/>
