---
name: design-md
description: >
  Create or improve DESIGN.md — a plain-text, AI-readable design system document that lets AI agents
  generate consistent, pixel-perfect UI without Figma exports or special tooling. Use this skill whenever
  the user wants to: create a DESIGN.md for their project, improve or audit an existing DESIGN.md,
  document a design system for AI consumption, define colors/typography/components for a project,
  make their UI consistent across AI-generated code, or reference an existing brand/design system
  (e.g. "Linear-style", "Vercel aesthetic"). Also generates a companion preview.html visual catalog.
  Trigger on phrases like "create a DESIGN.md", "add a design system", "document my design", "make my
  UI consistent", "design tokens", "design spec", "what's my color palette", "generate a preview for
  my design system", or whenever the user is setting up a new project and mentions UI or branding.
license: Apache-2.0
allowed-tools: Read Write AskUserQuestion Glob Bash
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - markdown
  - github
  task: [document, configure]
  persona: [developer, technical-writer]
  workload: [documentation]
---

# DESIGN.md Skill

You create and improve `DESIGN.md` — a self-contained, plain-text design system document that
combines **machine-readable YAML tokens** with **human-readable markdown guidance**. It serves as
source of truth for both humans and AI tools.

The goal is always a file that is **concrete and actionable**: hex values, pixel measurements,
named semantic roles, and clear component states. Vague descriptions ("a nice blue", "comfortable
spacing") are not useful; exact values and intent are.

**File structure** (required):

1. YAML frontmatter enclosed by `---` delimiters — machine-readable design tokens
2. Markdown body — human-readable sections with design rationale and philosophy

Always generate a companion `preview.html` file alongside DESIGN.md so the design system can be
inspected visually in a browser.

Read `references/design-md-spec.md` before starting — it contains the full spec with annotated
examples from real design systems (Linear, Vercel, Cursor). Run `npx @google/design.md spec` to
get the authoritative spec at any time.

---

## Step 1 — Detect the mode

Check the current project directory for an existing `DESIGN.md`:

```text
Glob: **/DESIGN.md (limit to project root or src/)
```

- **File found → Review/improve mode**: Read it, audit it against the 8-section spec, surface gaps.
- **File not found → Create mode**: Gather a brief and generate from scratch.

If the user explicitly says "create", "generate", or "improve/review/audit", skip detection and follow their intent.

---

## Step 2A — Create mode: gather the brief

Ask only what you don't already know. If the user's message already answers these, skip them:

1. **Brand name / project name** — what are you building?
2. **Aesthetic direction** — pick a direction or describe it. Examples to offer:
   - Dark-native minimal (Linear, GitHub)
   - Clean light professional (Vercel, Stripe)
   - Warm editorial (Notion, Linen)
   - Bold developer (Supabase, PostHog)
   - Soft consumer (Spotify, Airbnb)
   - Or: "reference an existing design system from our collection" (see spec for full list)
3. **Color anchors** — any hex values already decided? A logo color? Brand guideline?
4. **Typography preferences** — system fonts vs custom, serif vs sans, any existing choices?
5. **Platform** — web only, mobile-first, or both?
6. **Dark mode, light mode, or both?**

If the user is in a hurry or says "just create something", make confident creative choices based on
the project name and any context you have. Don't over-ask.

---

## Step 2B — Review/improve mode: audit the existing file

Read the DESIGN.md fully, then evaluate it against the official spec. First check structural
validity — does it have YAML frontmatter? Then evaluate each section:

| Section | What to check |
|---------|---------------|
| YAML frontmatter | Present and valid? Tokens use `{path.to.token}` references where appropriate? |
| Overview | Is brand personality and emotional response guidance concrete? Would an AI understand the intent? |
| Colors | Are all semantic roles covered? Hex values in sRGB (e.g. `"#1A1C1E"`) for every color? |
| Typography | Are `fontFamily`, `fontSize`, `fontWeight`, `lineHeight`, `letterSpacing` all specified? |
| Layout | Is the spacing scale documented? Grid strategy? Dimension values or unitless numbers? |
| Elevation & Depth | Shadow system? Surface hierarchy? z-index? |
| Shapes | Corner radius values? Form language philosophy? |
| Components | Buttons, chips, inputs — all properties (`backgroundColor`, `textColor`, `padding`) + states? |
| Do's and Don'ts | Clear guardrails preventing common AI design mistakes? |

For each gap or weakness, provide a **specific suggested addition** (not just "add hex values" but
the actual content you'd add). Then ask the user whether to apply the improvements directly.

---

## Step 3 — Generate DESIGN.md

Write the file to the project root (or the directory the user specifies). Follow the required
structure exactly. See `references/design-md-spec.md` for section templates and real examples.

**Required structure:**

```text
---
# YAML frontmatter — machine-readable design tokens
colors:
  primary: "#5e6ad2"
  background: "#0f1117"
typography:
  body:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0em"
spacing:
  sm: "8px"
  md: "16px"
rounded:
  sm: "4px"
  md: "8px"
components:
  button:
    backgroundColor: "{colors.primary}"
    textColor: "#ffffff"
    padding: "8px 16px"
---

# Project Name Design System

## Overview
...

## Colors
...

## Typography
...

## Layout
...

## Elevation & Depth
...

## Shapes
...

## Components
...

## Do's and Don'ts
...
```

Key quality standards:

- **YAML frontmatter first** — all token values; use `{path.to.token}` syntax for cross-references
- **Every color** must be hex sRGB (e.g., `"#5e6ad2"`) with a semantic role name
- **Every typography token** must include `fontFamily`, `fontSize`, `fontWeight`, `lineHeight`, `letterSpacing`
- **Spacing/rounded** — dimension strings (`"16px"`) or unitless numbers (`4`)
- **Every component** must describe all interactive states (default, hover, active, disabled, focus)
- **Explain the philosophy** behind each system — not just values but *why* (this is what makes it
  useful to AI agents generating new components that weren't explicitly covered)

Write concrete, specific content. A DESIGN.md that says "use consistent spacing" is useless. One
that says "spacing scale: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64px — always use multiples of 4" is
actionable.

---

## Step 3.5 — Validate with the linter

After writing DESIGN.md, run the official linter to catch broken token references, WCAG contrast
violations, and structural errors:

```bash
npx @google/design.md lint DESIGN.md
```

The linter exits `1` if errors are found. Parse the JSON output and fix all errors before
proceeding. Common issues to fix:

- Broken `{path.to.token}` references (token path doesn't exist in frontmatter)
- Missing required sections
- Duplicate sections
- Invalid color formats (must be hex sRGB)

If the user wants to compare against a previous version (regression check):

```bash
npx @google/design.md diff DESIGN.md DESIGN-v2.md
```

---

## Step 4 — Generate preview.html

Generate a standalone `preview.html` in the same directory as DESIGN.md. This file requires no
server — just open in a browser. Read `references/preview-template.md` for the structure.

The preview must show:

- **Color palette**: swatches for every color with hex value, name, and semantic role
- **Typography scale**: each heading level and body size rendered live with the actual fonts
- **Component gallery**: buttons (all states), form inputs (default/focus/error), cards, badges
- **Spacing scale**: visual ruler showing the scale values
- **Elevation/shadow scale**: cards showing each elevation level
- **Do's and Don'ts**: rendered as a side-by-side comparison

Use inline CSS only (no external dependencies). Load any custom fonts via Google Fonts or
system font stacks.

---

## Step 5 — Offer next steps

After generating both files and passing the linter:

1. Tell the user where the files were written
2. Show the path to open preview.html in a browser: `open preview.html`
3. Offer these follow-up options:
   - "I can generate a dark-mode variant of the preview"
   - "I can export tokens for design tools:"
     - Tailwind: `npx @google/design.md export --format tailwind DESIGN.md > tailwind.theme.json`
     - DTCG (Design Token Community Group): `npx @google/design.md export --format dtcg DESIGN.md > tokens.json`
   - "I can update any section — just tell me what to change"
   - "I can generate a project-specific component example using this design system"

---

## Design system references

The awesome-design-md collection (<https://github.com/VoltAgent/awesome-design-md>) contains 55+
real-world DESIGN.md files. When a user asks to reference a known brand or aesthetic, consult
`references/design-md-spec.md` for the documented patterns from: Linear, Vercel, Cursor, Claude,
Notion, Figma, Stripe, Supabase, PostHog, Raycast, Sentry, and many others.

Don't copy verbatim — extract the *philosophy* and adapt it to the user's project. The value is
in understanding *why* Linear uses negative letter-spacing or *why* Vercel uses shadow-as-border,
not in reusing their exact values.
