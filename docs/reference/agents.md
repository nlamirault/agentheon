<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Agent Catalog and Profile Schema

> **Reference** — factual and comprehensive. The canonical source is each
> `agents/*/README.md` file; this page mirrors it for quick lookup.

## Agent catalog

Each agent is one Greek deity. The pantheon is **two-tier**: Zeus (the sole
entrypoint) routes to an **executive** who owns a domain, and each executive
delegates down to its **specialists**, who own one domain each and do the work.

### Orchestrator & executives

| Agent    | Tier         | Title          | Domain                    | Model  |
| -------- | ------------ | -------------- | ------------------------- | ------ |
| Zeus     | orchestrator | The King       | Routing & Coordination    | opus   |
| Gaia     | executive    | The Foundation | Vision & Company Strategy | opus   |
| Hyperion | executive    | The Overseer   | Technology Strategy       | opus   |
| Hera     | executive    | The Sovereign  | Operations & Delivery     | opus   |
| Hades    | executive    | The Treasurer  | Finance & Capital         | opus   |
| Peitho   | executive    | The Persuader  | Marketing & Growth        | sonnet |
| Tyche    | executive    | The Fortune    | Revenue & Sales           | sonnet |

### Specialists

Each specialist is delegated to by the executive that owns its domain.

| Agent      | Title           | Domain                         | Model  | Executive     |
| ---------- | --------------- | ------------------------------ | ------ | ------------- |
| Kairos     | The Opportune   | Product & Prioritization       | opus   | Gaia / Tyche  |
| Athena     | The Strategist  | Architecture & Planning        | opus   | Hyperion      |
| Hephaestus | The Builder     | Implementation                 | sonnet | Hyperion      |
| Artemis    | The Hunter      | Testing & QA                   | sonnet | Hyperion      |
| Argus      | The Watcher     | Security & Review              | opus   | Hyperion      |
| Asclepius  | The Healer      | Debugging & Incident Response  | opus   | Hyperion      |
| Themis     | The Arbiter     | Compliance & Governance        | sonnet | Hera          |
| Prometheus | The Forethinker | AI & ML Engineering            | opus   | Hyperion      |
| Demeter    | The Cultivator  | Data & Database Engineering    | sonnet | Hyperion      |
| Helios     | The All-Seeing  | Observability & SRE            | sonnet | Hera          |
| Hestia     | The Keeper      | DevOps & Infrastructure        | sonnet | Hyperion      |
| Hygieia    | The Purifier    | Code Health & Refactoring      | sonnet | Hyperion      |
| Aphrodite  | The Aesthete    | Frontend & UX                  | sonnet | Peitho        |
| Aglaea     | The Adornment   | Design & Design Systems        | sonnet | Peitho        |
| Apollo     | The Chronicler  | Documentation & Knowledge      | sonnet | Hera          |
| Iris       | The Messenger   | Open Source & Community        | sonnet | Hera          |
| Plutus     | The Provider    | FinOps & Cost Engineering      | sonnet | Hades         |
| Poseidon   | The Navigator   | Networking & Connectivity      | sonnet | Hyperion      |
| Atlas      | The Bearer      | Performance Engineering        | sonnet | Hyperion      |
| Nemesis    | The Enforcer    | Release & Supply Chain         | sonnet | Hera          |
| Daedalus   | The Artificer   | Developer Experience & Tooling | sonnet | Hyperion      |

## Profile frontmatter schema

Every `agents/<name>/README.md` opens with YAML frontmatter:

| Field       | Type   | Description                                                                   |
| ----------- | ------ | ----------------------------------------------------------------------------- |
| `name`      | string | Deity display name (e.g. `Athena`).                                           |
| `title`     | string | Epithet / role (e.g. `The Strategist`).                                       |
| `domain`    | string | The single domain this agent owns.                                            |
| `tier`      | enum   | `orchestrator` / `executive` / `specialist` (optional; default `specialist`). |
| `emoji`     | string | Glyph used in the showcase and profile.                                       |
| `color`     | hex    | Accent color for the showcase card.                                           |
| `model`     | enum   | `opus` or `sonnet` — mapped to a concrete id at gen time.                     |
| `tools`     | list   | Tools the agent may use (e.g. `Read`, `Grep`, `Task`).                        |
| `tagline`   | string | The deity's myth mapped to the domain.                                        |
| `order`     | int    | Sort order in the showcase.                                                   |
| `reasoning` | enum   | `high` / `medium` / `low`.                                                    |
| `tone`      | string | How the agent communicates.                                                   |
| `handoffs`  | list   | Agents this one may route work to (routing edges).                            |
| `does`      | list   | Concrete in-scope capabilities.                                               |
| `does_not`  | list   | Explicit out-of-scope boundaries.                                             |
| `skills`    | list   | Named skills the agent draws on.                                              |

## Team files

| File                       | Purpose                                               |
| -------------------------- | ----------------------------------------------------- |
| `team/company.md`          | Shared team context: who we are, conventions.         |
| `team/workflow.md`         | The plan→build→test→review loop and quality gates.    |
| `team/handoff-template.md` | Format for handing work to another agent.             |
| `team/routing.md`          | Generated routing matrix (domain → agent + handoffs). |

## Profile generator

`hack/gen-hermes-profiles.sh` turns each `agents/*/README.md` into a Hermes profile.

| Env var           | Default                   | Purpose                                 |
| ----------------- | ------------------------- | --------------------------------------- |
| `HERMES_HOME`     | `~/.hermes`               | Profiles root parent.                   |
| `MODEL_OPUS`      | `anthropic/claude-opus`   | Concrete id for `model: opus`.          |
| `MODEL_SONNET`    | `anthropic/claude-sonnet` | Concrete id for `model: sonnet`.        |

Outputs: `$HERMES_HOME/profiles/<name>/SOUL.md` (managed block + preserved
custom additions) and `$HERMES_HOME/team/company/` (seeded shared context and
regenerated `routing.md`).

## Engineering conventions

- **Conventional Commits** with a scope: `feat(zeus): ...`.
- **DCO sign-off** on every commit: `git commit -s`.
- **SPDX license headers** on every file (enforced by hawkeye pre-commit).
- Pre-commit hooks must pass: whitespace, shebang/exec, secrets, license.
