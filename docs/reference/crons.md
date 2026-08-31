<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Cron Catalog and Schedule Schema

> **Reference** — factual and comprehensive. The canonical source is each
> `agents/<slug>/crons/*.md` file; the generated matrix lives in
> [`team/crons.md`](../../team/crons.md), and this page documents the schema.

## What a cron is

A cron is a scheduled, unattended Hermes run: a prompt executed on a cron
schedule by one owning deity, its output delivered to one channel. Crons are the
scheduled counterpart to the agents — where an agent answers on demand, a cron
fires on a clock. Each cron lives beside the deity that owns it, under that
agent's `crons/` directory, so ownership is structural — the parent profile is
the owner, never a frontmatter field.

## Cron catalog

| Cron            | Schedule     | Agent | Skill          | Deliver  |
| --------------- | ------------ | ----- | -------------- | -------- |
| `weekly-digest` | `0 18 * * 0` | Iris  | `git-workflow` | telegram |

## Cron frontmatter schema

Every `agents/<slug>/crons/<name>.md` opens with YAML frontmatter, then a
Markdown body that is the prompt Hermes runs:

| Field      | Type   | Description                                                  |
| ---------- | ------ | ------------------------------------------------------------ |
| `name`     | string | Cron id; must match the filename (`<name>.md`).              |
| `schedule` | string | A 5-field cron expression (`min hour dom mon dow`).          |
| `skill`    | string | The skill Hermes loads for the run.                          |
| `deliver`  | enum   | Delivery channel: `telegram`, `slack`, `email`, or `stdout`. |
| `summary`  | string | One-line description used in the generated matrix.           |
| `owners`   | list   | *(optional)* GitHub owners the prompt operates over.         |

The **owning agent is the directory** the cron lives under
(`agents/<slug>/crons/`) — there is no `agent:` field. The body below the
frontmatter is the verbatim prompt — the steps, output format, and any "quiet
week" fallback the run should follow.

## Tooling

| Command                   | What it does                                             |
| ------------------------- | -------------------------------------------------------- |
| `make crons-validate`     | Lint every `agents/*/crons/*.md` against this schema.    |
| `make crons-matrix`       | Regenerate `team/crons.md` from the frontmatter.         |
| `make crons-matrix-check` | Fail if `team/crons.md` is stale (CI + pre-commit gate). |
| `make crons-check`        | Validate + schedule-sync in one shot.                    |

## Installation

`./agentheon.sh install` writes each cron to `$HERMES_HOME/crons/<name>.yaml`
(a portable, self-contained spec — schedule, owner, skill, channel, and prompt).
When the `hermes` CLI is present it also registers the job with the runtime as
its owning agent via `hermes -p <slug> cron create`; without the CLI the spec is
written and registration is skipped with a warning (the same policy as profile
aliases).
