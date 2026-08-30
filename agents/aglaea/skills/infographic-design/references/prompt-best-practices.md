# Prompt Engineering Best Practices

This reference provides general prompt engineering principles applicable across all content generation types
(infographics, newsletters, FAQs, etc.).

## Core Principles

### 1. Specificity Over Vagueness

**Principle:** Provide explicit details rather than general descriptions.

**Poor:**

```text
Make it look nice and professional.
```

**Better:**

```text
Use flat design style with navy blue (#003366) and white (#FFFFFF), san-serif fonts, and clean geometric shapes.
```

**Why:** AI models work better with concrete specifications than subjective judgments. "Professional" means different
things in different contexts.

---

### 2. Structured Organization

**Principle:** Organize prompts into clear, labeled sections.

**Poor:**

```text
Create an infographic about climate change for students that shows the causes and effects and make it colorful with a timeline and use simple language...
```

**Better:**

```text
Topic: Climate Change Causes and Effects
Audience: Middle school students (ages 11-14)
Visual Style: Colorful cartoon style
Layout: Timeline format
Language: Simple, grade-appropriate vocabulary
```

**Why:** Structured prompts are easier to parse and ensure all requirements are addressed.

---

### 3. Explicit Text Content

**Principle:** Provide exact text rather than descriptions of text.

**Poor:**

```text
Add a catchy title about recycling.
```

**Better:**

```text
Title: "5 Simple Ways to Recycle at Home"
```

**Why:** AI-generated text often contains spelling errors or "gibberish" text. Providing exact wording prevents this
issue.

---

### 4. Iterative Refinement

**Principle:** Start with a strong prompt, then refine incrementally.

**Pattern:**

```text
First prompt: Generate initial version
Refinement: "Leave everything else the same, but [specific change]"
```

**Example:**

```text
Initial: Creates infographic
Refinement: "Leave everything else exactly the same, but increase the font size of the title by 20% and change the background from light blue to white."
```

**Why:** Incremental changes preserve successful elements while addressing specific issues.

---

### 5. Context and Purpose

**Principle:** Explain why the content is needed and how it will be used.

**Include:**

- Target audience
- Purpose (educate, persuade, entertain, inform)
- Distribution channel (social media, print, presentation)
- Viewing context (mobile, desktop, projection)

**Example:**

```text
Purpose: Educational infographic for classroom display
Audience: 5th grade students studying water cycle
Context: Will be printed as 24"x36" poster and displayed on classroom wall
Goal: Students should understand and remember the 4 stages of water cycle
```

**Why:** Context helps the AI make appropriate style and complexity decisions.

---

### 6. Constraints and Requirements

**Principle:** Specify limitations and mandatory elements upfront.

**Include:**

- Dimensions and format
- Color restrictions or brand colors
- Required elements (logo, specific imagery)
- Accessibility requirements
- File format needs

**Example:**

```text
Dimensions: 1080x1920 pixels (vertical)
Colors: Must use brand colors - Primary: #FF6B35, Secondary: #004E89, Accent: #F7FFF7
Required: Company logo in bottom right corner
Accessibility: High contrast for readability, minimum 14pt font
Format: PNG with transparent background
```

**Why:** Prevents wasted iterations on outputs that don't meet basic requirements.

---

### 7. Examples and References

**Principle:** Provide examples of desired style or similar content.

**Approaches:**

- Link to similar examples: "Style similar to [URL]"
- Describe comparable works: "Layout like a New York Times infographic"
- Reference known styles: "Visual style inspired by Saul Bass"

**Example:**

```text
Reference Style: Similar to Kurzgesagt YouTube channel infographics - flat design, bold colors, simple characters, educational but playful
```

**Why:** Examples provide concrete visual targets that descriptions alone cannot convey.

---

### 8. Negative Prompts

**Principle:** Specify what to avoid as explicitly as what to include.

**Include:**

- Unwanted styles
- Elements to exclude
- Inappropriate treatments

**Example:**

```text
Avoid:
- Cluttered or busy designs
- Serif fonts
- Photorealistic imagery
- Dark or muted colors
- Complex gradients
```

**Why:** Prevents common mistakes and unwanted interpretations.

---

### 9. Hierarchy and Priority

**Principle:** Indicate relative importance of elements.

**Specify:**

- Most important information (largest, most prominent)
- Secondary information
- Supporting details
- Optional enhancements

**Example:**

```text
Priority Hierarchy:
1. Primary: Main statistic "73% Increase" - largest, center, bold
2. Secondary: Supporting data points - medium size, arranged around primary
3. Tertiary: Source citation and methodology - smallest, footer
```

**Why:** Ensures visual emphasis matches information importance.

---

### 10. Output Format Requirements

**Principle:** Specify exactly how you want the final output delivered.

**Include:**

- File format (PNG, SVG, PDF, JPEG)
- Resolution and dimensions
- Color space (RGB, CMYK)
- Compression settings
- Layering (if editable file needed)

**Example:**

```text
Output Requirements:
- Format: PNG with transparent background
- Resolution: 300 DPI for print quality
- Dimensions: 1920x1080 pixels
- Color Space: RGB
- Include editable source file (if available)
```

**Why:** Ensures output is usable for intended purpose without conversion.

---

## Prompt Structure Template

Use this template as a foundation for all content generation prompts:

```text
[CONTENT TYPE]

Topic: [Main subject]
Purpose: [Why this content is needed]
Audience: [Who will view/use this]
Context: [Where and how it will be used]

Visual Style: [Specific style with details]
Layout: [Structural pattern]
Color Palette: [Specific colors with hex codes if available]

Content:
- Title: "[Exact text]"
- Section 1: [Exact text or description]
- Section 2: [Exact text or description]
- Data: [Specific numbers and statistics]

Dimensions: [Width x Height]
Format: [File type and specifications]

Requirements:
- [Mandatory element 1]
- [Mandatory element 2]

Avoid:
- [Unwanted element 1]
- [Unwanted element 2]

Reference Style: [Example or inspiration]
```

---

## Common Mistakes to Avoid

### Mistake 1: Vague Descriptions

❌ **Bad:**

```text
Make it modern and cool
```

✅ **Good:**

```text
Use gradient mesh modern style with vibrant purple-to-pink gradients, san-serif fonts, and geometric shapes
```

---

### Mistake 2: Assuming Knowledge

❌ **Bad:**

```text
Use our standard brand style
```

✅ **Good:**

```text
Brand Style: Minimalist flat design, Montserrat font, navy (#003366) and gold (#FFD700), clean lines
```

**Why:** The AI doesn't know your brand unless you specify it explicitly.

---

### Mistake 3: Ambiguous Quantities

❌ **Bad:**

```text
Show some statistics about sales
```

✅ **Good:**

```text
Display these 3 statistics: "45% increase in Q4", "$2.3M revenue", "1,200 new customers"
```

---

### Mistake 4: Unclear Priority

❌ **Bad:**

```text
Include the company name, product features, pricing, testimonials, and contact info
```

✅ **Good:**

```text
Primary: Product name and key feature (largest, top)
Secondary: Pricing and testimonial (medium, middle)
Tertiary: Contact info (smallest, bottom)
```

---

### Mistake 5: No Success Criteria

❌ **Bad:**

```text
Create an infographic
```

✅ **Good:**

```text
Create an infographic that enables viewers to understand the 5-step process in under 30 seconds
```

**Why:** Success criteria help evaluate if output meets goals.

---

## Refinement Techniques

### Technique 1: Preserve and Modify

When refining, explicitly preserve successful elements:

```text
Keep everything exactly the same, but make these specific changes:
- Increase title font from 36pt to 48pt
- Change background color from #F0F0F0 to white
- Add 20px padding around all elements
```

---

### Technique 2: Incremental Changes

Make one category of changes at a time:

**Round 1:** Color adjustments
**Round 2:** Typography refinements
**Round 3:** Layout tweaks
**Round 4:** Content additions

---

### Technique 3: A/B Variations

Request multiple variations for comparison:

```text
Generate 3 variations of this infographic:
Variation A: Flat design style
Variation B: Hand-drawn style
Variation C: Isometric 3D style

Keep all other elements consistent for fair comparison.
```

---

### Technique 4: Progressive Enhancement

Build complexity gradually:

**Version 1:** Basic structure and main content
**Version 2:** Add visual style and colors
**Version 3:** Refine typography and spacing
**Version 4:** Add decorative elements and polish

---

## Platform-Specific Considerations

### Social Media

**Requirements:**

- Square format (1080x1080) or vertical (1080x1350)
- Mobile-first design
- High contrast for small screens
- Large text (minimum 14-16pt)
- Eye-catching visual hooks

---

### Print

**Requirements:**

- High resolution (300 DPI minimum)
- CMYK color space
- Bleed area consideration
- Print-safe colors (no pure RGB)
- Readability at intended viewing distance

---

### Presentations

**Requirements:**

- 16:9 aspect ratio (1920x1080)
- High contrast for projector visibility
- Large fonts (minimum 24pt)
- Simple, uncluttered design
- Readable from back of room

---

### Web/Digital

**Requirements:**

- RGB color space
- 72-96 DPI sufficient
- Optimized file size
- Responsive design considerations
- Accessible color contrast ratios

---

## Accessibility Guidelines

### Color Contrast

**Requirement:** Minimum 4.5:1 contrast ratio for normal text, 3:1 for large text (WCAG AA standard)

**Implementation:**

```text
Use high contrast:
- Dark text (#000000 or #333333) on light backgrounds (#FFFFFF or #F5F5F5)
- Light text (#FFFFFF) on dark backgrounds (#000000 or #333333)
Avoid: Medium colors on medium backgrounds
```

---

### Text Size

**Minimums:**

- Body text: 14pt minimum (16pt recommended)
- Headers: 24pt minimum
- Captions: 12pt minimum (with high contrast)

---

### Alt Text and Descriptions

**Include:**

```text
Alternative text description for accessibility:
"Infographic showing 5-step recycling process with icons and labels. Steps are: Sort, Clean, Collect, Process, Reuse. Each step includes brief description and colorful icon."
```

---

## Quality Checklist

Before finalizing any generated content, verify:

**Content:**

- [ ] All text spelled correctly
- [ ] Data and statistics accurate
- [ ] Key information present
- [ ] Hierarchy clear

**Visual:**

- [ ] Style matches specification
- [ ] Colors correct (if specified)
- [ ] Layout appropriate for content
- [ ] Dimensions correct

**Technical:**

- [ ] File format correct
- [ ] Resolution sufficient
- [ ] File size reasonable
- [ ] Output usable for intended platform

**Accessibility:**

- [ ] Color contrast sufficient
- [ ] Text size adequate
- [ ] Information clear without color alone
- [ ] Alt text provided

---

## Advanced Techniques

### Conditional Prompting

Specify different treatments based on context:

```text
If audience is children (under 12):
- Use cartoon style, bright colors, simple language

If audience is professionals:
- Use minimalist style, muted colors, technical terminology
```

---

### Multi-stage Prompts

Break complex requests into sequential stages:

**Stage 1:** Generate basic structure
**Stage 2:** Add detailed content
**Stage 3:** Apply visual styling
**Stage 4:** Refine and polish

---

### Constraint-based Creativity

Use constraints to focus creativity:

```text
Constraints:
- Must use only 3 colors
- All icons must be circular
- Total word count under 50 words
- Must fit on single screen without scrolling
```

---

## Testing and Validation

### User Testing

Test with representative audience members:

- Can they understand the content in 10 seconds?
- Do they notice the most important information first?
- Can they explain the key message back to you?

---

### Technical Validation

Verify technical specifications:

- Open files in target applications
- Test print quality at actual size
- View on target devices (mobile, desktop)
- Check accessibility with screen readers

---

### Iteration Tracking

Document what works:

- Successful prompt patterns
- Effective refinement techniques
- Preferred styles for specific audiences
- Common issues and solutions

Build a prompt library for future reference.

---

## Summary

Effective prompts are:

1. **Specific** - Concrete details, not vague descriptions
2. **Structured** - Organized in clear sections
3. **Complete** - All requirements explicitly stated
4. **Context-aware** - Understand audience and purpose
5. **Testable** - Include success criteria
6. **Refineable** - Support iterative improvement

Master these principles to generate high-quality content consistently across all content types.
