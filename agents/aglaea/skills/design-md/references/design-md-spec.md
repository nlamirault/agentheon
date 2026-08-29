# DESIGN.md Specification

## Overview

DESIGN.md is a plain-text design system document for AI agents. It lives in the project root and
provides concrete, machine-readable design specifications so AI coding agents can generate
consistent, pixel-perfect UI without guesswork.

**Source**: <https://stitch.withgoogle.com/docs/design-md/overview>
**Examples**: <https://github.com/VoltAgent/awesome-design-md> (55+ real-world files)

---

## The 9 Sections

### 1. Visual Theme & Atmosphere

The design's soul — the mood, philosophy, and aesthetic direction. This section answers "what does
this product *feel* like?" so AI agents can make consistent decisions about components not
explicitly covered elsewhere.

**What good looks like:**

```markdown
## Visual Theme & Atmosphere

Linear is built for speed and focus. The interface disappears — dark backgrounds recede, content
surfaces with intentional contrast. Nothing competes for attention that doesn't deserve it.
Density serves clarity: comfortable information display without visual noise. Every interaction
should feel instant and precise.
```

**What bad looks like:**

```markdown
## Visual Theme

Clean and professional design.
```

---

### 2. Color Palette & Roles

Every color with its hex value and its semantic purpose. AI agents use roles, not raw colors —
"use the error color" not "use #ff0000".

**Required roles:**

- Background (primary, secondary, tertiary)
- Surface / elevated surface
- Text (primary, secondary, muted/disabled)
- Border / divider
- Brand / primary accent
- Interactive states (hover, active, focus)
- Semantic: success, warning, error, info

**Real example (Linear):**

```markdown
## Color Palette & Roles

Base backgrounds:

- `#08090a` — app canvas (darkest, true background)
- `#0f1011` — primary surface (cards, panels)
- `#16181a` — elevated surface (modals, dropdowns)
- `#1d1f21` — hover states, subtle highlights

Text hierarchy:

- `#e8e8e8` — primary text (headings, labels)
- `#9b9b9b` — secondary text (descriptions, metadata)
- `#5c5c5c` — muted/disabled text

Brand:

- `#5e6ad2` — brand primary (buttons, links, focus rings)
- `#7170ff` — brand hover state

Semantic:

- `#2cbe4e` — success
- `#f0a429` — warning
- `#e11c48` — error
```

**Real example (Vercel):**

```markdown
## Color Palette & Roles

Light mode:

- `#ffffff` — background primary
- `#fafafa` — background secondary
- `#000000` — text primary
- `#666666` — text secondary

Workflow accents (Vercel-specific semantic roles):

- `#ff5b4f` — Ship (production deployments)
- `#de1d8d` — Preview (preview deployments)
- `#0a72ef` — Develop (local development)
```

---

### 3. Typography Rules

Font families, size scale, weights, line heights. All values. No vague descriptions.

**What to include:**

- Primary typeface (UI, headings)
- Secondary typeface (body copy, if different)
- Monospace typeface (code)
- Size scale (with semantic names: display, h1–h6, body-lg, body, body-sm, caption)
- Weight system (with semantic names)
- Letter-spacing rules (especially important for display sizes)
- Line height per size

**Real example (Cursor):**

```markdown
## Typography Rules

Typefaces:

- `CursorGothic` — primary display and UI (loaded via @font-face)
- `jjannon` — editorial body copy, long-form text (serif)
- `berkleyMono` — code, terminals, monospaced contexts

Size scale:

- Display: 48px / weight 700 / tracking -0.03em / line-height 1.1
- H1: 36px / weight 600 / tracking -0.025em / line-height 1.15
- H2: 28px / weight 600 / tracking -0.02em / line-height 1.2
- H3: 22px / weight 500 / tracking -0.015em / line-height 1.25
- Body LG: 17px / weight 400 / tracking 0 / line-height 1.65
- Body: 15px / weight 400 / tracking 0 / line-height 1.6
- Caption: 12px / weight 400 / tracking 0.01em / line-height 1.4

Weight semantics:

- 400 — reading (body copy, descriptions)
- 500 — emphasis (subheadings, labels)
- 700 — display (headlines, hero text)
```

**Real example (Linear):**

```markdown
## Typography Rules

Primary: `Inter Variable` — loaded with variable font features
Monospace: `Berkeley Mono` — for code and inline snippets

Weight system (three tiers):

- 400 — long-form reading (paragraphs, descriptions)
- 510 — UI elements (buttons, nav, labels, metadata)
- 590 — emphasis (subheadings, active states)

Letter-spacing: aggressive negative tracking at larger sizes

- 32px+: -0.04em
- 20–31px: -0.02em
- Below 20px: 0

All UI text: font-variant-numeric: tabular-nums (consistent number widths in tables/lists)
```

---

### 4. Component Stylings

The most important section for AI agents generating UI. Each component needs all states.

**Components to cover at minimum:**

- Buttons (primary, secondary, ghost/outline, destructive)
  - States: default, hover, active/pressed, disabled, loading, focus
- Text inputs / form fields
  - States: default, focus, error, disabled, with prefix/suffix
- Cards / panels
- Badges / chips / tags
- Navigation items (active vs inactive)
- Links (inline, standalone)

**Example (button pattern):**

```markdown
## Component Stylings

### Buttons

Primary button:

- Background: `#5e6ad2` / Text: `#ffffff` / Border-radius: 6px
- Font: 14px / weight 510 / letter-spacing: -0.01em
- Padding: 8px 16px
- Hover: background `#6571e0`, subtle scale(1.01)
- Active: background `#4f5bc0`, scale(0.99)
- Disabled: opacity 0.4, cursor: not-allowed
- Focus: outline 2px `#5e6ad2` offset 2px

Secondary button:

- Background: transparent / Border: 1px solid `rgba(255,255,255,0.1)`
- Text: `#e8e8e8`
- Hover: background `rgba(255,255,255,0.04)`

Destructive button:

- Same as primary but background `#e11c48`
```

---

### 5. Layout Principles

Spacing system and grid rules. AI agents use these to avoid arbitrary pixel values.

```markdown
## Layout Principles

Spacing scale (base-4 system):
4px / 8px / 12px / 16px / 24px / 32px / 48px / 64px / 96px / 128px

Always use multiples of 4. Never use odd values like 6px or 10px.

Semantic spacing:

- xs: 4px — icon padding, tight inline spacing
- sm: 8px — within components (icon + label gap)
- md: 16px — standard component padding
- lg: 24px — section gaps within a panel
- xl: 32px — between major sections
- 2xl: 48px — page-level section spacing
- 3xl: 64px — hero sections, large breakpoints

Grid:

- Container max-width: 1280px, centered with auto margins
- Columns: 12-column grid, 24px gutters
- Side padding: 16px (mobile), 32px (tablet), 64px (desktop)
```

---

### 6. Depth & Elevation

How surfaces stack. Prevents flat-feeling UIs and establishes visual hierarchy.

**Real example (Vercel's shadow-as-border philosophy):**

```markdown
## Depth & Elevation

Border philosophy: Vercel uses shadow-as-border rather than border properties:
`box-shadow: 0px 0px 0px 1px rgba(0,0,0,0.08)` — creates borders that adapt to context

Elevation scale:

- Level 0 (flat): no shadow, no border — background elements
- Level 1 (resting): `box-shadow: 0 1px 2px rgba(0,0,0,0.05), 0 0 0 1px rgba(0,0,0,0.08)` — cards
- Level 2 (raised): `box-shadow: 0 4px 8px rgba(0,0,0,0.1), 0 0 0 1px rgba(0,0,0,0.08)` — dropdowns
- Level 3 (overlay): `box-shadow: 0 8px 24px rgba(0,0,0,0.15), 0 0 0 1px rgba(0,0,0,0.08)` — modals

z-index scale:

- 0: content
- 10: sticky headers
- 20: dropdowns
- 30: modals / dialogs
- 40: toasts / notifications
- 50: tooltips
```

---

### 7. Do's and Don'ts

Design guardrails. Prevent the most common AI design mistakes for this specific system.

```markdown
## Do's and Don'ts

✓ DO use `#5e6ad2` for all interactive elements (buttons, links, focus rings) — consistency creates
  a clear visual language for what's clickable
✓ DO use semi-transparent borders (`rgba(255,255,255,0.08)`) rather than solid colors — they adapt
  to background variations automatically
✓ DO use Berkeley Mono for ALL code, terminal output, and version numbers — it reinforces the
  developer-first identity

✗ DON'T use white (#ffffff) for text — always use `#e8e8e8` to prevent harsh contrast on dark
  backgrounds
✗ DON'T add more than 2 accent colors per page — the single-accent philosophy is intentional
✗ DON'T use border-radius > 8px — rounded corners above 8px feel too "consumer app" for this tool
✗ DON'T use box shadows for depth — use background color shifts instead (darker bg = lower, lighter = higher)
```

---

### 8. Responsive Behavior

Breakpoints and adaptation rules.

```markdown
## Responsive Behavior

Breakpoints:

- Mobile: < 640px
- Tablet: 640px – 1024px
- Desktop: > 1024px
- Wide: > 1280px

Mobile adaptations:

- Navigation collapses to bottom tab bar (5 items max)
- Cards go full-width (remove horizontal margins)
- Font sizes scale down: H1 → 28px, Body → 14px
- Spacing scale reduces: use one step smaller (xl → lg, lg → md)
- Touch targets: minimum 44×44px for all interactive elements
- Remove hover states — they don't apply to touch

Tablet:

- Sidebar navigation (if present) collapses to icon-only (48px wide)
- Two-column layouts become single-column below 768px
```

---

### 9. Agent Prompt Guide

The most AI-specific section. Copy-paste prompts that reference this design system exactly.

```markdown
## Agent Prompt Guide

Use these references when instructing AI agents to build UI with this design system:

**Colors:** background `#08090a`, surface `#0f1011`, elevated `#16181a`, text-primary `#e8e8e8`,
text-secondary `#9b9b9b`, brand `#5e6ad2`, success `#2cbe4e`, error `#e11c48`

**Typography:** Inter Variable, size scale 12/14/16/20/24/32/48, weight scale 400/510/590

**Spacing:** base-4 system: 4/8/12/16/24/32/48/64px

**Example prompts:**

1. "Build a data table component matching our design system: dark background `#0f1011`, text
   `#e8e8e8`, row hover `rgba(255,255,255,0.03)`, borders `rgba(255,255,255,0.06)`, font Inter 14px
   weight 400"

2. "Create a modal dialog: surface color `#16181a`, 8px border-radius, shadow `0 8px 24px
   rgba(0,0,0,0.4)`, close button in top-right, padding 24px, max-width 560px"

3. "Style this form with our input spec: height 36px, border `1px solid rgba(255,255,255,0.1)`,
   background `rgba(255,255,255,0.04)`, focus border `#5e6ad2`, font Inter 14px, padding 0 12px"
```

---

## Known Design Systems Reference

When a user asks to reference a known design system, use these patterns as inspiration (not copy):

| System | Signature traits |
|--------|-----------------|
| **Linear** | Dark-native, Inter Variable, single indigo accent #5e6ad2, negative letter-spacing, base-4 spacing |
| **Vercel** | Light/dark dual, Geist Sans, shadow-as-border, extreme negative tracking at display, workflow accent colors |
| **Cursor** | Warm off-white #f2f1ed, three-font system (CursorGothic + jjannon serif + berkleyMono), orange accent #f54e00 |
| **Claude** | Warm terracotta palette, editorial feel, Tiempos/Söhne, accessible contrast ratios |
| **Notion** | Clean neutral, system fonts, minimal shadow, content-first |
| **Stripe** | Deep purple brand, Camphor/Saans, precise micro-typography, generous whitespace |
| **Supabase** | Dark with green brand (#3ecf8e), developer-focused density |
| **PostHog** | Bold, high-contrast, hedgehog energy, bright accent colors |
| **Raycast** | macOS-native feel, SF Pro, blur/vibrancy surfaces |
| **Figma** | Canvas-centric, neutral grays, property-panel density, icon-first |
| **GitHub** | System fonts, accessible AA/AAA, Primer design system, conservative shadows |

Full collection: <https://github.com/VoltAgent/awesome-design-md>
