<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# How to Install the Pantheon into Hermes Agent

> **How-to** — task-oriented. This guide gets every Agentheon deity installed as
> a runnable [Hermes Agent](https://hermes-agent.nousresearch.com) profile. If
> you only want to understand the agents first, start with the
> [getting-started tutorial](../tutorials/getting-started.md).

## Goal

Run `agentheon.sh` to turn `agents/*.md` into Hermes profiles under
`$HERMES_HOME/profiles/`, seed the shared team context, and rebuild the routing
matrix — on a VPS that hosts Hermes Agent, or on your own machine.

## What it produces

`agentheon.sh` derives everything from a single source of truth — the
frontmatter in each `agents/*.md`. For every agent it writes:

| File                           | Purpose                                                                                      |
| ------------------------------ | -------------------------------------------------------------------------------------------- |
| `profiles/<name>/config.yaml`  | The file Hermes reads: model, toolsets, memory. **Regenerated every run — never hand-edit.** |
| `profiles/<name>/profile.yaml` | Portable descriptor (description + required skills) for review/portability.                  |
| `profiles/<name>/SOUL.md`      | Persona, scope, handoff routes, and the agent body — inside a managed block.                 |

It also seeds shared context into `$HERMES_HOME/team/company/`
(`company.md`, `workflow.md`, `handoff-template.md`) and regenerates
`routing.md`, the matrix Hermes uses to dispatch work.

## Prerequisites

- The Agentheon repository cloned locally.
- Bash 4+ (the script uses associative arrays).
- **Optional:** the `hermes` CLI on `PATH`. Not required — without it, files are
  written directly; with it, each profile is also registered so it appears in
  `hermes profile list`.

## Steps

### 1. Preview first (recommended)

See exactly what would be written, changing nothing:

```bash
make install-dry-run
# or
./agentheon.sh install --dry-run
```

### 2. Install

```bash
make install
# or
./agentheon.sh install
```

This installs into `$HERMES_HOME` (default `~/.hermes`). Secrets (`.env`) are
**never** touched.

### 3. Add API keys and run an agent

Profiles are installed but have no credentials yet. Add them per profile:

```bash
hermes -p athena setup    # add API keys (.env)
hermes -p athena chat     # run the agent
hermes profile list       # see them all
```

## Choosing an install mode

| Mode                | Command                       | Needs `hermes` CLI | Behavior                                                                         |
| ------------------- | ----------------------------- | ------------------ | -------------------------------------------------------------------------------- |
| File-drop (default) | `./agentheon.sh` `[--no-cli]` | No                 | Writes files directly; also registers profiles if the CLI is present.            |
| CLI                 | `./agentheon.sh --cli`        | Yes                | Delegates to `hack/gen-hermes-profiles.sh`; sets config via `hermes config set`. |

Use file-drop unless you specifically need the imperative CLI path.

## Options

```text
install        Install/refresh all profiles (default action).
--no-cli       File-drop only; no hermes CLI required (default).
--cli          Delegate to hack/gen-hermes-profiles.sh (needs hermes CLI).
--dry-run, -n  Show what would happen; write nothing.
--home DIR     Hermes home (default: $HERMES_HOME or ~/.hermes).
-h, --help     Show help.
```

## Environment overrides

| Env var           | Default                   | Purpose                                        |
| ----------------- | ------------------------- | ---------------------------------------------- |
| `HERMES_HOME`     | `~/.hermes`               | Profiles root parent.                          |
| `MODEL_OPUS`      | `anthropic/claude-opus`   | Concrete `provider/model` for `model: opus`.   |
| `MODEL_SONNET`    | `anthropic/claude-sonnet` | Concrete `provider/model` for `model: sonnet`. |
| `HERMES_RESERVED` | `hermes-agent`            | Replacement for the reserved name `hermes`.    |

Example — install into a custom home with a pinned model id:

```bash
MODEL_OPUS=anthropic/claude-opus-4 \
  ./agentheon.sh install --home /srv/hermes
```

## Re-running is safe

`agentheon.sh` is idempotent. Re-run it any time you edit an agent or pull new
changes:

- `config.yaml` and `profile.yaml` are regenerated from frontmatter every run.
- In `SOUL.md`, only the `AGENTHEON:BEGIN … END` managed block is overwritten.
  Anything you hand-write **outside** that block survives regeneration.

## Verify it worked

```bash
ls $HERMES_HOME/profiles/                 # one directory per agent
cat $HERMES_HOME/team/company/routing.md  # the regenerated routing matrix
hermes profile list                       # (if the CLI is installed)
```

You should see one profile directory per `agents/*.md`, and `routing.md`
listing every agent with its domain, model, and handoffs.

## Related

- [Add a new agent to the pantheon](add-a-new-agent.md)
- [Agent catalog and profile schema](../reference/agents.md)
- [Pantheon architecture](../explanation/architecture.md)
