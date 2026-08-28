<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# How to Add a New Agent to the Pantheon

> **How-to** — task-oriented. This guide assumes you understand the
> plan → build → test → review loop. If not, start with the
> [getting-started tutorial](../tutorials/getting-started.md).

## Goal

Add a new Greek-deity agent to `agents/`, wire it into the routing graph, and
regenerate the Hermes profiles.

## Steps

### 1. Create the profile file

Add `agents/<name>.md` (lowercase deity name). Start with the SPDX header, then
the frontmatter. Copy the shape from an existing profile such as
[`agents/athena.md`](../../agents/athena.md):

```yaml
---
name: <Deity>
title: The <Role>
domain: <One domain — e.g. "Observability & Metrics">
emoji: "🦉"
color: "#8fb0c8"
model: opus            # or sonnet
tools: [Read, Grep, Glob]
tagline: <One line — the deity's myth mapped to the domain>
order: <N>
reasoning: high        # or medium / low
tone: <How this agent speaks>
handoffs: [hephaestus, argus]   # who it can route work to
does:
  - <Concrete capability>
does_not:
  - <Explicit boundary — defer X to Y>
skills:
  - <skill-name>
---
```

### 2. Keep the agent inside one domain

Each agent owns exactly one domain. If the new agent overlaps an existing one,
narrow the boundary in `does` / `does_not` rather than duplicating scope.

### 3. Wire the handoffs

Set `handoffs` to the agents this one legitimately routes to. These edges become
the routing matrix (`team/routing.md`) that Hermes reads. Every handoff must
travel with the [handoff template](../../team/handoff-template.md).

### 4. Regenerate the profiles

```bash
./hack/gen-hermes-profiles.sh
```

This creates `$HERMES_HOME/profiles/<name>`, writes the SOUL.md managed block,
seeds shared context into `$HERMES_HOME/team/company/`, and rebuilds
`routing.md` from every agent's frontmatter.

### 5. Verify and commit

```bash
pre-commit run --all-files    # license, secrets, whitespace, shebang
git add agents/<name>.md
git commit -s -m "feat(<name>): add <Deity> for <domain>"
```

Commit must use Conventional Commits with a scope and be DCO-signed (`-s`).

## Verify it worked

- `team/routing.md` (after regeneration) lists the new agent with its handoffs.
- `pre-commit run --all-files` passes — SPDX header and DCO are present.

## Related

- [Agent catalog and profile schema](../reference/agents.md)
- [Pantheon architecture](../explanation/architecture.md)
