---
adr: 0002
status: ✅ Accepted
deciders: Nicolas Lamirault
consulted:
informed:
date: 2026-08-28
spdx-license: Apache-2.0
---

# ADR-0002: Deploy the Website on Cloudflare Workers

## Context

Agentheon ships a small Astro website (`web/`) that presents the pantheon: a
landing page and one rendered page per agent profile. Until now it was wired for
**GitHub Pages** as a project page (`site: nlamirault.github.io`,
`base: /agentheon`), which serves the build from a repository subpath.

Two forces push us to reconsider the host:

- **A custom domain.** The site should live at `agentheon.lamirault.xyz`, at the
  domain root — not under a `/agentheon` subpath. A project-page base path
  complicates every asset URL and rules out a clean apex.
- **Agent-native content.** Agentheon's product *is* agent profiles. A site
  about agents should be readable *by* agents: an agent fetching a page should
  be able to get clean Markdown instead of scraping HTML. Static hosting cannot
  do content negotiation; it returns whatever file sits on disk.

The sibling project [Pilotariak](https://github.com/Pilotariak/website) already
solved the same problem with a Cloudflare Worker that sits in front of static
assets and converts HTML to Markdown at the edge when a request carries
`Accept: text/markdown`, and serves `/.well-known/` discovery documents with
machine-readable headers. We want the same capability here.

The decision: where and how do we host the website?

## Considered Options

1. **Cloudflare Workers + static assets** — a Worker serves the built `dist/`
   as static assets and adds edge logic (Markdown content negotiation,
   `/.well-known/` headers). Custom domain at the apex.
2. **GitHub Pages (status quo)** — commit-driven static hosting from a
   repository subpath, no edge compute.
3. **Netlify / Vercel** — managed static hosting with serverless functions.

## Pros and Cons

### 1. Cloudflare Workers + static assets

**Pros:**

- ✅ Edge compute lets the same URL serve HTML to browsers and Markdown to
  agents (`Accept: text/markdown`), so the site is agent-native by design.
- ✅ Custom domain at the apex; no subpath base to thread through asset URLs.
- ✅ `/.well-known/` agent-discovery documents served with correct content
   types and cache headers.
- ✅ Mirrors the Pilotariak deployment, so one mental model and one `worker.js`
   pattern covers both projects.

**Cons:**

- ❌ Introduces a Cloudflare account dependency and a `wrangler` toolchain.
- ❌ The Worker is code that must be maintained and reasoned about, not just
   files on disk.

### 2. GitHub Pages (status quo)

**Pros:**

- ✅ Zero extra infrastructure; already configured.
- ✅ Deploys straight from the repository with no external account.

**Cons:**

- ❌ Static only — no content negotiation, so no first-class Markdown for agents.
- ❌ Project pages live under a `/agentheon` subpath; a clean apex needs extra
   custom-domain plumbing and still no edge logic.

### 3. Netlify / Vercel

**Pros:**

- ✅ Managed static hosting with serverless functions and custom domains.

**Cons:**

- ❌ Another vendor to standardise on, diverging from Pilotariak's Cloudflare
   model with no offsetting benefit.
- ❌ Edge/function ergonomics for HTML→Markdown rewriting are weaker than
   Cloudflare's `HTMLRewriter`.

## Decision

We will use **Option 1 — Cloudflare Workers serving static assets**, matching
the Pilotariak model.

Concretely:

- `web/wrangler.jsonc` declares a Worker (`agentheon-web`) whose `assets`
  binding serves the Astro build in `web/dist`.
- `web/worker.js` performs Markdown content negotiation: on
  `Accept: text/markdown` it fetches the underlying HTML asset, strips
  non-content elements with `HTMLRewriter`, converts the remainder to Markdown,
  and returns it as `text/markdown` with a token-count header. All other
  requests pass through to the static asset unchanged. Requests under
  `/.well-known/` are served with consistent, machine-readable headers.
- `web/astro.config.mjs` sets `site: https://agentheon.lamirault.xyz` and drops
  the GitHub Pages `base`, so the site is served at the domain root.
- Agent-discovery documents (`robots.txt`, `llms.txt`, `_headers`, and
  `/.well-known/{ai.txt,ai.json,security.txt,agent-card.json}`) live in
  `web/public/` and ship as static assets.

We accept the Cloudflare account and `wrangler` dependency because edge content
negotiation is the feature that makes an agent site legible to agents, and
reusing Pilotariak's proven Worker keeps the cost of that capability near zero.

### Workers Builds configuration

Deployment runs through **Workers Builds** (the git-connected CI), which clones
the repository and runs the build and deploy commands from a configured working
directory. Because the Worker config lives in the `web/` subdirectory rather
than the repository root, the **Root directory** must be set to `web`; otherwise
`wrangler deploy` runs at the repo root, finds no `wrangler.jsonc`, and fails
with *"Missing entry-point to Worker script or to assets directory."*

Configure the Worker under **Workers & Pages → Settings → Builds**:

| Setting        | Value                 | Why                                                        |
| -------------- | --------------------- | ---------------------------------------------------------- |
| Root directory | `web`                 | So `wrangler` resolves `web/wrangler.jsonc` and `web/dist` |
| Build command  | `pnpm run build`      | Runs `astro build` (pnpm detected from `pnpm-lock.yaml`)   |
| Deploy command | `npx wrangler deploy` | Publishes the Worker and its static assets                 |

Local deploys use the same two steps via `make web-deploy` (which runs
`web-build` then `wrangler deploy` with `--dir web`); Workers Builds is the
equivalent for commit-driven releases.

## Consequences

### Positive

- ✅ The same page URL serves HTML to humans and clean Markdown to agents.
- ✅ Website lives at `agentheon.lamirault.xyz` at the apex, no subpath.
- ✅ Standard agent-discovery surface under `/.well-known/`.
- ✅ Deployment mirrors Pilotariak — one Worker pattern across projects.

### Negative

- ❌ Deployment now depends on a Cloudflare account and the `wrangler` CLI.
- ❌ `worker.js` is edge code that must be maintained alongside the site.

### Neutral

- ↔️ GitHub Pages is no longer the deployment target; the `base` path is
   removed and asset URLs resolve from the domain root.
- ↔️ Releases are cut with `wrangler deploy` (via `make web-deploy`) rather than
   a Pages build step.

## References

- [Pilotariak website](https://github.com/Pilotariak/website) — the Worker
  pattern this ADR adopts
- [`web/wrangler.jsonc`](../../web/wrangler.jsonc) — Worker + static-assets config
- [`web/worker.js`](../../web/worker.js) — edge Markdown content negotiation
- [Cloudflare Workers static assets](https://developers.cloudflare.com/workers/static-assets/)
