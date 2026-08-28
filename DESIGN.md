---
# Agentheon Design System — machine-readable design tokens
# Dark-native, classical-editorial, gold-on-obsidian. A Greek pantheon of software agents.

colors:
  # Brand primary alias (Hermes gold)
  primary: "{colors.gold}"

  # Backgrounds — obsidian, receding
  background: "#0a0a0b"
  surface: "#141416"
  surfaceElevated: "#1c1c20"

  # Border / divider
  border: "#2a2a30"
  borderStrong: "#3a3a42"

  # Text hierarchy
  textPrimary: "#e8e8ea"
  textSecondary: "#9a9aa2"
  textMuted: "#6c6c76"
  textOnGold: "#17130a"

  # Brand — Hermes gold
  gold: "#d4a533"
  goldBright: "#e8c063"
  goldGlow: "rgba(212, 165, 51, 0.10)"

  # Semantic (tuned to deity palette)
  success: "#6fae8e"
  warning: "#f2c14e"
  error: "#c8563d"
  info: "#5b7fa6"

  # Interactive states
  hoverOverlay: "rgba(232, 232, 234, 0.04)"
  focusRing: "#d4a533"

typography:
  display:
    fontFamily: "'Cormorant Garamond', Georgia, 'Times New Roman', serif"
    fontSize: "80px"
    fontWeight: 500
    lineHeight: 1.05
    letterSpacing: "-0.01em"
  h1:
    fontFamily: "'Cormorant Garamond', Georgia, serif"
    fontSize: "48px"
    fontWeight: 500
    lineHeight: 1.1
    letterSpacing: "-0.01em"
  h2:
    fontFamily: "'Cormorant Garamond', Georgia, serif"
    fontSize: "38px"
    fontWeight: 500
    lineHeight: 1.15
    letterSpacing: "0em"
  h3:
    fontFamily: "'Cormorant Garamond', Georgia, serif"
    fontSize: "30px"
    fontWeight: 500
    lineHeight: 1.2
    letterSpacing: "0em"
  lede:
    fontFamily: "Inter, ui-sans-serif, system-ui, sans-serif"
    fontSize: "19px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0em"
  body:
    fontFamily: "Inter, ui-sans-serif, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.6
    letterSpacing: "0em"
  bodySmall:
    fontFamily: "Inter, ui-sans-serif, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0em"
  eyebrow:
    fontFamily: "'JetBrains Mono', ui-monospace, 'SF Mono', Menlo, monospace"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "0.18em"
  label:
    fontFamily: "'JetBrains Mono', ui-monospace, 'SF Mono', Menlo, monospace"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "0.12em"
  code:
    fontFamily: "'JetBrains Mono', ui-monospace, 'SF Mono', Menlo, monospace"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0em"
  caption:
    fontFamily: "Inter, ui-sans-serif, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "0em"

spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  "2xl": "48px"
  "3xl": "64px"
  "4xl": "96px"

rounded:
  sm: "5px"
  md: "8px"
  lg: "10px"
  xl: "12px"
  "2xl": "14px"
  full: "999px"

components:
  button:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.textOnGold}"
    typography: "{typography.bodySmall}"
    rounded: "{rounded.md}"
    padding: "11px 22px"
  buttonGhost:
    backgroundColor: "{colors.background}"
    textColor: "{colors.textPrimary}"
    typography: "{typography.bodySmall}"
    rounded: "{rounded.md}"
    padding: "11px 22px"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.textPrimary}"
    typography: "{typography.body}"
    rounded: "{rounded.xl}"
    padding: "24px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.textPrimary}"
    typography: "{typography.bodySmall}"
    rounded: "{rounded.md}"
    padding: "10px 12px"
  pill:
    backgroundColor: "{colors.surfaceElevated}"
    textColor: "{colors.textSecondary}"
    typography: "{typography.label}"
    rounded: "{rounded.full}"
    padding: "3px 9px"
  codeBlock:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.textPrimary}"
    typography: "{typography.code}"
    rounded: "{rounded.lg}"
    padding: "14px 18px"
---

# Agentheon Design System

Agentheon is a pantheon of Greek-deity software-engineering agents. The identity is
**classical, but not costume** — obsidian surfaces, a single Hermes-gold accent, and an
editorial serif that evokes carved stone and manuscript, paired with a precise monospace
that signals the tooling underneath the myth.

## Visual Theme & Atmosphere

The interface should feel like a **darkened temple hall lit by a single gold flame**. Deep
near-black backgrounds recede so content and the gold accent carry all the weight. There is
one hero moment per page — a soft gold aura behind the title — and everything else is quiet.

Three type voices tell the story: a **serif display** (`Cormorant Garamond`) for the
mythological, editorial register of headings; **Inter** for calm, legible body and UI; and
**JetBrains Mono** for anything mechanical — commands, roles, tags, version numbers. The
tension between carved-serif headline and monospace label *is* the brand: myth over
machinery.

Restraint is the rule. Gold is precious — it marks brand, interaction, and the active deity,
nothing else. Depth comes from stepping background colors (obsidian → surface → elevated),
almost never from drop shadows. Motion is subtle: a 3px lift and a border warming to gold on
hover, ~180ms.

## Colors

Backgrounds recede in three obsidian steps; each step up = one level of elevation.

- `#0a0a0b` — **background**, the app canvas (true near-black)
- `#141416` — **surface**, cards, panels, code blocks
- `#1c1c20` — **surfaceElevated**, glyph tiles, pills, hover fills

Borders and dividers:

- `#2a2a30` — **border**, default hairline on every surface
- `#3a3a42` — **borderStrong**, emphasis dividers

Text hierarchy — never pure white, to soften contrast on obsidian:

- `#e8e8ea` — **textPrimary**, headings and body
- `#9a9aa2` — **textSecondary**, ledes, descriptions, metadata
- `#6c6c76` — **textMuted**, disabled, faint captions
- `#17130a` — **textOnGold**, dark ink used *only* on gold fills

Brand — Hermes gold, the caduceus flame:

- `#d4a533` — **gold**, brand + all primary interaction (buttons, links, focus, active deity)
- `#e8c063` — **goldBright**, hover / links-in-prose
- `rgba(212,165,51,0.10)` — **goldGlow**, the hero aura only

Semantic roles (drawn from the deity palette so they never clash):

- `#6fae8e` — **success** (Artemis sage)
- `#f2c14e` — **warning** (Helios sun)
- `#c8563d` — **error** (Hestia flame)
- `#5b7fa6` — **info** (Themis steel)

### Deity accent colors

Each of the 17 deities carries one accent, applied as a per-card `--agent` CSS variable
(card border warms to it on hover, role text uses it). These are **content colors**, never
chrome — do not repurpose them for UI.

| Deity      | Accent    | Emoji | Domain                        |
| ---------- | --------- | ----- | ----------------------------- |
| Zeus       | `#d4a533` | ⚡    | Routing & Coordination        |
| Athena     | `#8fb0c8` | 🦉    | Architecture & Planning       |
| Hephaestus | `#c8734a` | 🔨    | Implementation                |
| Artemis    | `#6fae8e` | 🏹    | Testing & QA                  |
| Argus      | `#a98fc8` | 👁     | Security & Review             |
| Demeter    | `#97a24e` | 🌾    | Data & Database Engineering   |
| Helios     | `#f2c14e` | ☀️    | Observability & SRE           |
| Apollo     | `#d9c25a` | 📜    | Documentation & Knowledge     |
| Aphrodite  | `#d18aa6` | 🪞    | Frontend & UX                 |
| Aglaea     | `#c9a227` | 🎨    | Design & Design Systems       |
| Asclepius  | `#479aa6` | ⚕     | Debugging & Incident Response |
| Hestia     | `#b8543d` | 🔥    | DevOps & Infrastructure       |
| Hygieia    | `#6bbf8a` | 🧼    | Code Health & Refactoring     |
| Iris       | `#3fb0c9` | 📬    | Open Source & Community       |
| Kairos     | `#e07b39` | ⏳    | Product & Prioritization      |
| Prometheus | `#7c6bc0` | 🧠    | AI & ML Engineering           |
| Themis     | `#5b7fa6` | ⚖️    | Compliance & Governance       |

## Typography

Three families, each with one job:

- **Display / headings** — `Cormorant Garamond`, weight 500, italic reserved for a single
  gold-highlighted word in the hero. Serif carries the mythological voice.
- **Body / UI** — `Inter`, weight 400 body / 600 buttons + brand. Calm and legible.
- **Mono** — `JetBrains Mono`, for commands, eyebrows, roles, pills, code, versions.

Scale (rendered live in `preview.html`):

| Role         | Family         | Size          | Weight | Tracking         | Line-height |
| ------------ | -------------- | ------------- | ------ | ---------------- | ----------- |
| Display      | Cormorant      | clamp 45–80px | 500    | -0.01em          | 1.05        |
| H1           | Cormorant      | 48px          | 500    | -0.01em          | 1.1         |
| H2           | Cormorant      | 38px          | 500    | 0                | 1.15        |
| H3           | Cormorant      | 30px          | 500    | 0                | 1.2         |
| Lede         | Inter          | 19px          | 400    | 0                | 1.5         |
| Body         | Inter          | 16px          | 400    | 0                | 1.6         |
| Body sm      | Inter          | 14px          | 400    | 0                | 1.5         |
| Eyebrow      | JetBrains Mono | 13px          | 500    | 0.18em uppercase | 1.4         |
| Label / role | JetBrains Mono | 12px          | 500    | 0.12em uppercase | 1.4         |
| Code         | JetBrains Mono | 14px          | 400    | 0                | 1.5         |

Rules: serif headings only — never set a headline in Inter. Eyebrows and roles are always
uppercase mono with wide tracking. Body copy stays at 1.6 line-height for long-form comfort.

## Layout

Spacing scale is **base-4**. Never use odd values (no 6px, 10px, 14px for gaps).

`4 / 8 / 16 / 24 / 32 / 48 / 64 / 96px`

- **xs 4** — icon padding, tight inline
- **sm 8** — icon + label gap, inside components
- **md 16** — standard component padding
- **lg 24** — card padding, section gaps within a panel
- **xl 32** — between subsections
- **2xl 48** — page section rhythm
- **3xl 64** — hero top/bottom
- **4xl 96** — hero-scale breathing room

Structure:

- **Content max-width**: 1080px, centered with auto margins (`.wrap`)
- **Reading column** (agent detail, prose): 760px
- **Side padding**: 24px, applied at the container
- **Grid**: agent cards on `repeat(auto-fill, minmax(280px, 1fr))`, 20px gutter

## Elevation & Depth

**Background-shift is the primary elevation system**, not shadows. A surface reads as
"higher" by being a lighter obsidian step, paired with a hairline border.

- **Level 0 — canvas**: `#0a0a0b`, no border
- **Level 1 — surface**: `#141416` + `1px #2a2a30` (cards, panels, code)
- **Level 2 — elevated**: `#1c1c20` + `1px #2a2a30` (glyph tiles, pills, hover fills)
- **Overlay** (modals, if introduced): `#1c1c20` + `0 8px 24px rgba(0,0,0,0.55)`

The **one gradient** in the system is the hero aura: a fixed radial gold glow
(`goldGlow → transparent 70%`), 900×600, behind the title. Use it once per page, never
decoratively elsewhere.

z-index scale: `0` content · `1` `.wrap` above aura · `10` sticky nav · `30` modal · `40`
toast · `50` tooltip.

## Shapes

Corner radii climb with element size; pills are fully round.

- **sm 5px** — inline code
- **md 8px** — buttons, inputs, small glyph tiles
- **lg 10px** — install / command block, large glyph tiles
- **xl 12px** — cards
- **2xl 14px** — app icon / favicon container
- **full 999px** — pills, tags, badges

Form language: rectangular with softly eased corners. Nothing is a circle except the
glyph-free pill ends. No radius above 14px on rectangular surfaces — larger reads as
"consumer app" and breaks the carved-stone restraint.

## Components

### Buttons

**Primary** — the gold call to action:

- Background `#d4a533` / text `#17130a` (dark ink) / radius 8px
- Inter 15px / weight 600
- Padding 11px 22px
- Hover: background `#e8c063`
- Active: background `#c99a2b`
- Focus: outline 2px `#d4a533`, offset 2px
- Disabled: opacity 0.4, `cursor: not-allowed`

**Ghost** — secondary:

- Transparent background / text `#e8e8ea` / border `1px #2a2a30` / radius 8px
- Hover: border-color `#d4a533` (no fill)
- Active: background `rgba(232,232,234,0.04)`

### Cards (agent tile)

- Background `#141416` / border `1px #2a2a30` / radius 12px / padding 24px
- Hover: border warms to the deity accent (`--agent`), lift `translateY(-3px)`,
  transition `border-color .18s, transform .18s`
- Contains: glyph tile (44px, radius 10px, `#1c1c20`), name (Inter 600), role
  (mono uppercase in accent), tagline (secondary), pill row

### Inputs

- Height ~40px / background `#141416` / border `1px #2a2a30` / radius 8px / padding 10px 12px
- Inter 15px, text `#e8e8ea`, placeholder `#6c6c76`
- Focus: border `#d4a533`, no glow
- Error: border `#c8563d`, helper text `#c8563d`
- Disabled: opacity 0.4

### Pills / tags

- Background `#1c1c20` / border `1px #2a2a30` / radius 999px / padding 3px 9px
- JetBrains Mono 12px, text `#9a9aa2`

### Command / install block

- Background `#141416` / border `1px #2a2a30` / radius 10px / padding 14px 18px
- JetBrains Mono 14px; the `$` sigil in gold, `user-select: none`

### Links

- In prose: `#e8c063`, underline on hover
- In nav: `#9a9aa2` → `#e8e8ea` on hover, no underline

## Do's and Don'ts

✓ **DO** reserve gold (`#d4a533`) for brand, interactive elements, and the active deity —
scarcity is what makes it read as precious.
✓ **DO** set every heading in `Cormorant Garamond` — the serif is the mythological voice.
✓ **DO** use `JetBrains Mono`, uppercase with wide tracking, for eyebrows, roles, and tags.
✓ **DO** create depth by stepping the background (`#0a0a0b → #141416 → #1c1c20`) plus a
hairline border.
✓ **DO** keep the gold aura to one instance per page, behind the hero only.
✓ **DO** use deity accent colors for content (card hover, role text) exclusively.

✗ **DON'T** use pure white `#ffffff` for text — always `#e8e8ea`.
✗ **DON'T** set headlines in Inter or body in Cormorant — the two voices never trade jobs.
✗ **DON'T** add a second accent color to chrome; deity colors are content, not UI.
✗ **DON'T** lean on drop shadows for elevation — shift the background instead (overlay is the
one exception).
✗ **DON'T** exceed 14px radius on rectangular surfaces — it breaks the carved restraint.
✗ **DON'T** use odd spacing values — stay on the base-4 scale.

## Responsive Behavior

Breakpoints:

- Mobile: `< 640px`
- Tablet: `640px – 1024px`
- Desktop: `> 1024px`

Mobile adaptations:

- Hero display scales via `clamp(2.8rem, 7vw, 5rem)` — no manual override needed
- Agent grid collapses to one column (min 280px track handles it automatically)
- Nav links may collapse; keep brand + primary CTA visible
- Section padding drops one step (2xl → xl)
- Touch targets ≥ 44×44px; drop hover-only affordances (the -3px lift, border warm)

Tablet:

- Grid holds 2 columns; reading column stays ≤ 760px
- Side padding 24px throughout

## Agent Prompt Guide

Copy-paste references for AI agents building UI in this system:

**Colors** — background `#0a0a0b`, surface `#141416`, elevated `#1c1c20`, border `#2a2a30`,
text-primary `#e8e8ea`, text-secondary `#9a9aa2`, brand-gold `#d4a533`, gold-hover `#e8c063`,
success `#6fae8e`, warning `#f2c14e`, error `#c8563d`, info `#5b7fa6`.

**Typography** — headings `Cormorant Garamond` 500; body `Inter` 400/600; mono `JetBrains
Mono`. Sizes 12/14/16/19/30/38/48/80. Eyebrows: mono, uppercase, tracking 0.18em.

**Spacing** — base-4: 4/8/16/24/32/48/64/96px. **Radii** — 5/8/10/12/14/999.

**Example prompts:**

1. "Build a deity card: background `#141416`, border `1px #2a2a30`, radius 12px, padding 24px.
   44px glyph tile (`#1c1c20`, radius 10px) holding the emoji, name in Inter 600, role in
   JetBrains Mono 12px uppercase using the deity accent, tagline in `#9a9aa2`. On hover, warm
   the border to the accent and lift `translateY(-3px)`."

2. "Style a primary button: background `#d4a533`, text `#17130a`, radius 8px, padding
   11px 22px, Inter 15px weight 600; hover background `#e8c063`; focus outline 2px `#d4a533`
   offset 2px."

3. "Create a hero: eyebrow in gold JetBrains Mono uppercase tracking 0.18em, title in
   Cormorant Garamond `clamp(2.8rem,7vw,5rem)` with one italic word in `#e8c063`, lede in
   `#9a9aa2` 19px, then a gold primary + ghost CTA. Place a single fixed radial gold aura
   (`rgba(212,165,51,0.10)` → transparent 70%) behind the title."

4. "Style an install block: background `#141416`, border `1px #2a2a30`, radius 10px, padding
   14px 18px, JetBrains Mono 14px, `$` sigil in `#d4a533` and non-selectable."
