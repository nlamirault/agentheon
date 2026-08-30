---
name: infographic-design
description: This skill should be used when the user asks to "create an infographic prompt", "generate infographic with Gemini", "design an infographic visual", "help with infographic layouts", or mentions visual styles for infographics. Provides comprehensive guidance for creating effective Gemini prompts for infographic generation.
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - markdown
  - image
  task: [build, review]
  persona: [developer, designer]
  workload: [content]
allowed-tools: Write Read LS Glob AskUserQuestion(*)
---

# Infographic Design for AI Generation

## Purpose

This skill provides guidance for creating effective prompts that generate high-quality infographics using Google Gemini.
Focus on structuring prompts with clear visual styles, appropriate layouts, and best practices for text legibility and
visual hierarchy.

## When to Use This Skill

Use this skill when:

- Creating prompts for Gemini to generate infographic visuals
- Selecting appropriate visual styles for specific audiences
- Choosing layout patterns that match content structure
- Ensuring text placement and legibility in generated infographics
- Refining existing infographic prompts for better results

## Core Prompt Structure

Structure every infographic prompt with these essential components:

### 1. Topic and Context

Define the main subject clearly and concisely:

```text
Topic: [Main subject matter]
Context: [Background information or data to include]
```

Start with a clear topic statement that defines what the infographic covers. Provide any necessary context, data points,
or key information that must appear in the visual.

### 2. Audience and Purpose

Specify who will view the infographic and why:

```text
Audience: [Target viewers - students, professionals, general public, etc.]
Purpose: [Educational, informative, persuasive, entertaining]
```

Match visual complexity and style to audience sophistication. Educational content for children requires different
treatment than professional business infographics.

### 3. Title and Text Placement

Define title positioning and hierarchy:

```text
Title: "[Exact title text]"
Title Position: [Top center, top left, integrated into design]
Text Hierarchy: [Priority order of information]
```

Specify exact title text to avoid AI-generated gibberish. Define where the title should appear and establish clear
hierarchy for additional text elements.

### 4. Visual Style

Select from 20+ available visual styles based on audience and purpose. See `references/visual-styles.md` for complete
catalog.

**Most Popular Styles:**

- **Paper Cutout**: Collage-like, construction paper aesthetic
- **Kawaii/Cute Vector**: Simplified shapes, rounded edges, pastel colors
- **Isometric 3D**: Grid-based 3D perspective, video game style
- **Flat Design**: Minimalist, solid colors, clean lines
- **Hand-Drawn**: Sketch-like, organic, personal feel

Specify style explicitly in prompt:

```text
Visual Style: Paper cutout style with layered construction paper look
```

### 5. Layout Pattern

Choose layout that matches content structure. See `references/layout-patterns.md` for complete catalog.

**Common Layouts:**

- **Linear Timeline**: Chronological events or sequential steps
- **Pyramid/Funnel**: Hierarchical information or filtering processes
- **Circular Flow**: Cyclical processes or interconnected concepts
- **Split Screen**: Direct comparisons or contrasts
- **Grid Layout**: Multiple equal-weight items or categories

Specify layout explicitly:

```text
Layout: Linear timeline flowing left to right with 5 major events
```

### 6. Dimensions and Format

Define output dimensions:

```text
Dimensions: 1080x1920 (vertical) or 1920x1080 (horizontal)
Format: Digital display, print, social media
```

Standard dimensions ensure compatibility with target platforms. Vertical format works well for mobile and social media;
horizontal suits presentations and digital displays.

## Prompt Construction Workflow

Follow this systematic approach to build effective prompts:

### Step 1: Define Core Content

Start with topic, audience, and key information:

- What is the main message?
- Who will view this?
- What data or facts must be included?
- What action should viewers take?

Write these elements in clear, complete sentences.

### Step 2: Select Visual Style

Match style to audience and purpose:

- **Children/Education**: Kawaii, cartoon, hand-drawn
- **Business/Professional**: Flat design, minimalist, infographic style
- **Creative/Artistic**: Watercolor, paper cutout, illustrated
- **Technical/Data**: Isometric 3D, blueprint, technical diagram
- **Modern/Trendy**: Cyberpunk, neon, gradient mesh

Consult `references/visual-styles.md` for detailed descriptions and use cases for each style.

### Step 3: Choose Layout Pattern

Select layout based on content structure:

- **Sequential/Timeline**: Use linear timeline or process flow
- **Hierarchical**: Use pyramid, funnel, or tree structure
- **Comparative**: Use split screen or side-by-side
- **Categorical**: Use grid layout or modular blocks
- **Cyclical**: Use circular flow or cycle diagram

Consult `references/layout-patterns.md` for visual examples and detailed guidance on each pattern.

### Step 4: Specify Text Requirements

Define all text elements explicitly:

- Title text (exact wording)
- Section headers
- Data labels
- Key statistics or facts
- Call-to-action text

Explicit text specification prevents AI-generated gibberish and ensures accuracy.

### Step 5: Add Visual Details

Include specific guidance for visual elements:

- Color palette (if specific colors required)
- Icon style (simple, detailed, realistic, abstract)
- Background treatment (solid, gradient, textured)
- Visual metaphors or imagery to include
- Elements to avoid

More specificity yields better results.

### Step 6: Assemble Complete Prompt

Combine all components into structured prompt:

```text
Create an infographic with the following specifications:

Topic: [Main subject]
Audience: [Target viewers]
Purpose: [Goal of the infographic]

Title: "[Exact title text]"
Title Position: [Placement]

Visual Style: [Selected style with description]
Layout: [Selected layout with structure details]

Content:
- [Key point 1]
- [Key point 2]
- [Key point 3]
[Additional content as needed]

Dimensions: [Width x Height]

Additional requirements:
- [Specific color requirements]
- [Text legibility requirements]
- [Any other specifications]
```

## Text Legibility Best Practices

Ensure generated text is readable and professional:

### Font and Size

- Specify minimum text sizes for readability
- Request hierarchy through size variation (title largest, body smallest)
- Ask for high-contrast font choices (dark text on light backgrounds)

### Placement

- Position text in clear, uncluttered areas
- Avoid placing text over complex imagery
- Request background boxes or overlays for text on busy backgrounds
- Ensure adequate padding around text elements

### Spelling and Accuracy

- Provide exact text for all elements to prevent AI gibberish
- Spell out numbers and statistics rather than expecting AI to calculate
- Review all generated text carefully for accuracy
- Use refinement prompts to correct any spelling errors

## Iterative Refinement

Improve initial results through targeted refinement prompts:

### Refinement Technique

When requesting changes, use this pattern:

```text
Leave everything else exactly the same, but make these specific changes:
- [Change 1]
- [Change 2]
- [Change 3]
```

This preserves successful elements while addressing specific issues.

### Common Refinements

- **Text corrections**: "Fix the spelling of 'environment' in the title"
- **Color adjustments**: "Make the background darker for better text contrast"
- **Layout tweaks**: "Increase spacing between timeline items"
- **Element additions**: "Add an icon for each section header"
- **Style modifications**: "Make the overall style more minimalist"

Focus refinements on specific, actionable changes rather than vague requests.

## Quality Checklist

Before finalizing a prompt, verify:

**Content:**

- [ ] Topic clearly defined
- [ ] Audience and purpose specified
- [ ] All text spelled out exactly
- [ ] Key data and facts included

**Visual:**

- [ ] Visual style selected and described
- [ ] Layout pattern chosen and specified
- [ ] Dimensions provided
- [ ] Color requirements stated (if any)

**Legibility:**

- [ ] Title text provided exactly
- [ ] Text hierarchy defined
- [ ] High contrast requested
- [ ] Text placement specified

**Structure:**

- [ ] Prompt organized in clear sections
- [ ] All requirements explicit
- [ ] No ambiguous language
- [ ] Refinement strategy planned

## Additional Resources

### Reference Files

Consult these detailed references for comprehensive guidance:

- **`references/visual-styles.md`** - Complete catalog of 20+ visual styles with descriptions, use cases, and example
  prompts
- **`references/layout-patterns.md`** - Detailed guide to 24+ layout patterns with visual examples and content structure
  recommendations
- **`references/prompt-best-practices.md`** - General prompt engineering best practices applicable to all content types

### Example Files

Working examples in `examples/`:

- **`examples/prompts.md`** - Complete example prompts for various infographic types with analysis

### Utility Scripts

Helper scripts in `scripts/`:

- **`scripts/validate-prompt.sh`** - Validates prompt structure and completeness
- **`scripts/format-prompt.py`** - Formats prompt for Gemini API usage

## Common Pitfalls to Avoid

**Vague Descriptions:**

- ❌ "Make it look nice"
- ✅ "Use flat design style with bold colors and clean lines"

**Missing Text:**

- ❌ "Add a title about climate change"
- ✅ "Title: 'Climate Change: 5 Actions You Can Take Today'"

**Unclear Layout:**

- ❌ "Show the information clearly"
- ✅ "Use a linear timeline layout with 5 events flowing left to right"

**Ambiguous Style:**

- ❌ "Make it modern"
- ✅ "Use cyberpunk style with dark backgrounds and neon blue/pink accents"

## Quick Start Guide

For rapid prompt creation:

1. Define topic and audience
2. Choose style from `references/visual-styles.md`
3. Select layout from `references/layout-patterns.md`
4. Write exact title and key text
5. Specify dimensions
6. Assemble structured prompt
7. Generate and refine iteratively

Consult reference files for detailed guidance on styles and layouts.
