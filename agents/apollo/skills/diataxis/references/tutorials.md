# Tutorials - Learning-Oriented Documentation

## Definition and Purpose

A tutorial is fundamentally **an experience that takes place under the guidance of a tutor** and remains
**always learning-oriented**.

Tutorials serve learner acquisition rather than task completion. A tutorial serves the user's acquisition of skills and
knowledge—their study. Its purpose is not to help the user get something done, but to help them learn. Essentially, a
tutorial functions as a structured lesson.

## Core Characteristics

### Learning Through Action

Tutorials involve practical activities where students learn by doing meaningful work toward achievable goals. While
students learn through doing, what the student does is not necessarily what they learn. Students acquire facts,
understanding, familiarity with tools, workflows, and concepts through guided practice.

### Teacher-Student Relationship

Tutorials require a pedagogical contract where the instructor bears primary responsibility for what learners will
accomplish, what they'll do, and their success. The learner's responsibility is simply to remain attentive and follow
directions.

## Essential Principles for Tutorial Creation

### Pedagogical Requirements

Tutorials must satisfy four standards:

1. **Meaningful** exercises providing achievement
2. **Successful** completion within reach
3. **Logical** progression making sense
4. **Usefully complete** encounters with necessary concepts and tools

### Anti-Patterns to Avoid

The framework identifies temptations that undermine learning:

- Abstraction and generalization
- Excessive explanation
- Presenting multiple choices
- Information overload

**The first rule of teaching is simply: don't try to teach.** Instead, provide experiences enabling self-directed
learning.

## Key Instructional Strategies

### Early, Visible Results

Show learners what they'll achieve upfront so they can visualize progress. Deliver comprehensible results after every
step, however small.

### Narrative and Feedback

Maintain continuous narrative providing expectations through phrases like:

- "You will notice that..."
- "The output should look like..."
- "You should see..."

Provide actual example output. Prepare learners for potentially surprising outcomes and flag common mistakes.

### Concrete Focus

Concentrate on specific actions and results rather than abstract concepts.
**All learning moves in one direction: from the concrete and particular, towards the general and abstract.**

Start concrete. Stay concrete as long as possible. Abstract concepts come later, after learners have hands-on
experience.

### Minimize Explanation

Ruthlessly limit explanatory content during tutorials. **A tutorial is not the place for explanation.**

When necessary, provide brief justifications with links to detailed resources elsewhere:

- "We use X because it handles Y well (see [explanation doc] for details)"
- "This approach is common in production environments"

Keep explanations to one sentence maximum, then move on.

### Permit Repetition

Design tutorials allowing learners to repeat successful steps, reinforcing confidence and establishing procedural
fluency. Repetition helps learners experience the pleasure of mastering skills.

Examples:

- "Now create another endpoint for DELETE requests"
- "Add two more test cases using the same pattern"
- "Let's add another component, this time for user profiles"

### Omit Alternatives

Ignore optional approaches and alternative methods. Keep guidance focused on the direct path to the goal, maintaining
brevity and reducing cognitive load.

**Bad**: "You can use either SQLite or PostgreSQL for this tutorial. If you choose PostgreSQL..."

**Good**: "We'll use PostgreSQL for this tutorial."

The learner doesn't need to know about alternatives until they've mastered the basics.

### Perfect Reliability

Tutorials must **inspire confidence** through flawless execution. When learners follow directions but encounter
unexpected results, confidence erodes. Your tutorial ought to be so well constructed that things can't go wrong.

This requires:

- Extensive testing with actual users
- Clear prerequisites and setup instructions
- Tested on multiple platforms
- Version-specific dependencies
- Fallback instructions for common issues

## Language Patterns

Effective tutorials employ specific linguistic conventions:

### First-Person Plural

"We..." affirms the teacher-learner relationship:

- "We'll start by creating a new project"
- "Now we'll add authentication"
- "Let's test what we've built"

### Clear Imperatives

Direct, action-focused commands:

- "First, do x. Now, do y."
- "Create a new file named `config.py`"
- "Run the following command"

### Expectation-Setting

Tell them what they should see:

- "The output should look something like..."
- "You should see a message confirming..."
- "Your browser will display..."

### Observational Cues

Draw attention to important details:

- "Notice that the response includes..."
- "Remember that we defined this earlier"
- "Observe how the system handles..."

### Celebration of Accomplishment

Acknowledge what learners have built:

- "Congratulations! You've built a working API"
- "You now have a functional authentication system"
- "You've successfully deployed your first application"

## Tutorial Structure

### Standard Template

```markdown
# Tutorial Title: Build [Specific Thing]

## What You'll Learn

- Skill 1
- Skill 2
- Skill 3

## What You'll Build

[Clear description with screenshot/diagram of end result]

## Prerequisites

- Requirement 1 (with version numbers)
- Requirement 2
- Estimated time: X minutes

## Step 1: [Action-Oriented Title]

[Clear instructions]
[Expected output]

## Step 2: [Next Action]

[Instructions building on Step 1]
[Expected output]

...

## What You've Accomplished

[Summary of what they built and learned]

## Next Steps

- [Link to related how-to guide]
- [Link to explanation of concepts used]
- [Link to reference documentation]
```

### Opening Sections

**Title**: Be specific about what they'll build

- Good: "Build a REST API with Authentication"
- Bad: "Introduction to APIs"

**What You'll Learn**: List specific skills
**What You'll Build**: Show the end result upfront
**Prerequisites**: Be explicit and specific

### Step Sections

**Naming**: Use action verbs

- "Create the database schema"
- "Add user authentication"
- "Deploy to production"

**Content**: One major action per step

- Give the exact code or commands
- Show expected output
- Note what they should observe

**Transitions**: Connect steps logically

- "Now that we have X, we can..."
- "With Y in place, let's..."

### Closing Sections

**What You've Accomplished**: Celebrate success
**Next Steps**: Direct to other documentation types

- How-to guides for variations
- Explanation for deeper understanding
- Reference for specifications

## The Cooking Analogy

The framework illustrates principles through teaching a child to cook:

**Success in a cooking lesson with a child is not the culinary outcome...but when the child acquires the knowledge and
skills you were hoping to impart.**

Important insights:

- A child might not complete the intended recipe, yet still benefit through learning foundational techniques
- Small achievements with enjoyment matter more than perfect execution
- Skills develop through repeated visits and progressive building
- The goal is learning, not the perfect dish

## Common Challenges and Solutions

### Challenge: Tutorial Gets Out of Date

**Problem**: Product evolution necessitates continuous updates. Changes cascade throughout the entire narrative.

**Solutions**:

- Use stable, released versions (not latest)
- Document exact version numbers
- Automate tutorial testing
- Schedule regular review cycles
- Consider using reproducible environments (Docker, etc.)

### Challenge: Too Much to Teach

**Problem**: Wanting to teach everything in one tutorial.

**Solution**:

- Create a series of tutorials
- Each tutorial teaches 3-5 specific skills
- Link tutorials in a learning path
- Later tutorials build on earlier ones

### Challenge: Explaining vs Teaching

**Problem**: Temptation to explain every concept in detail.

**Solution**:

- Link to explanation documentation
- Brief justifications only: "We use X because..." (1 sentence)
- Trust that understanding follows experience
- Remember: students learn by doing, not reading

### Challenge: Different User Backgrounds

**Problem**: Users come with different skill levels.

**Solution**:

- State clear prerequisites
- Link to prerequisite tutorials
- Create beginner and advanced tutorial paths
- Keep each tutorial focused on one skill level

## Quality Checklist

Before publishing a tutorial, verify:

- [ ] Clear, specific goal stated upfront
- [ ] Exact prerequisites listed with versions
- [ ] Every step tested on fresh system
- [ ] Each step has expected output shown
- [ ] No alternatives or options presented
- [ ] Explanations minimal (< 1 sentence each)
- [ ] Steps build logically on each other
- [ ] Repetition used for skill reinforcement
- [ ] Celebration of accomplishment at end
- [ ] Links to how-to/explanation/reference docs
- [ ] Tested by someone unfamiliar with topic
- [ ] Works reliably (tested 3+ times)

## Examples of Good Tutorial Titles

- "Build Your First React Component"
- "Create a REST API with Flask"
- "Deploy a Django App to Heroku"
- "Set Up Automated Testing with Pytest"
- "Build a Real-Time Chat Application"

## Examples of Bad Tutorial Titles

- "Introduction to React" (not specific)
- "Working with APIs" (too broad)
- "Advanced Django Techniques" (not action-oriented)
- "Everything You Need to Know About Testing" (too comprehensive)

## Relationship to Other Documentation Types

Tutorials work together with other documentation:

**During Tutorial**:

- Avoid explanation → Link to explanation docs
- Avoid comprehensive details → Link to reference
- Focus on single path → Link to how-to for variations

**After Tutorial**:

- User wants to apply learning → How-to guides
- User wants to understand concepts → Explanation
- User needs comprehensive info → Reference

Keep tutorials pure: learning-oriented, hands-on, guided experiences that build confidence through successful
completion.

---

**Source**: <https://diataxis.fr/tutorials/>
