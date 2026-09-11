<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Scripts Reference

> **Reference** — factual and comprehensive. The canonical source is each
> script's own header comment (`./<script> --help` or `help`). This page
> documents the three operator-facing entry points: `agentheon.sh`,
> `hack/set-model.sh`, and `hack/gateway.sh`.

Agentheon derives every Hermes profile from a single source of truth —
`agents/<slug>/README.md` frontmatter. These scripts read that source and act on
a Hermes home (`$HERMES_HOME`, default `~/.hermes`). All three are pure Bash,
`set -euo pipefail`, colourised (auto-off when stdout is not a TTY or
`NO_COLOR=1`), and expose their header comment via `--help` / `help`.

## `agentheon.sh` — install the pantheon

Installs the whole pantheon into a Hermes Agent home. For every
`agents/*/README.md` it writes a profile under `$HERMES_HOME/profiles/<slug>/`,
seeds shared team context, and rebuilds the routing matrix Zeus uses to dispatch
work. Meant to run on the VPS that hosts Hermes Agent.

### Usage

```bash
./agentheon.sh [install] [--cli|--no-cli] [--dry-run] [--home DIR] \
               --secrets bitwarden --bws-project-id UUID
./agentheon.sh --help
```

A secret source is **required** — the script refuses to run without one.

### What it writes per profile

| File           | Purpose                                                                                                                                         | Regenerated                                  |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `config.yaml`  | The file Hermes reads: `model` (provider/model/reasoning/base_url), `toolsets`, `skills`, `memory`, and the optional `secrets.bitwarden` block. | Every run                                    |
| `profile.yaml` | Portable descriptor (description + required skills) for review/portability. Hermes ignores it.                                                  | Every run                                    |
| `SOUL.md`      | Identity only — who the agent is, how it speaks, what it avoids. Persona frontmatter is rendered to prose voice.                                | Managed block; hand edits outside it survive |
| `AGENTS.md`    | Project operating guide — scope, handoff routes, shared-context pointers, skills, finalization gate, agent body.                                | Managed block; hand edits outside it survive |

It also installs each agent's vendored skills
(`agents/<slug>/skills/*`) into that profile's own skill store
(`$HERMES_HOME/profiles/<slug>/skills/agentheon/`), installs its scheduled tasks
(`agents/<slug>/crons/*.md` → `$HERMES_HOME/crons/<name>.yaml`, see
[crons.md](crons.md)), seeds `team/*.md` into `$HERMES_HOME/team/company/`, and
writes the routing matrix to `$HERMES_HOME/team/company/routing.md`.

### Two install paths, same source

| Path             | Flag                 | hermes CLI | Behaviour                                                                                                      |
| ---------------- | -------------------- | ---------- | -------------------------------------------------------------------------------------------------------------- |
| file-drop        | `--no-cli` (default) | optional   | Writes files directly. If the CLI is present, also registers the profile so it shows in `hermes profile list`. |
| CLI (imperative) | `--cli`              | required   | Delegates to `hack/gen-hermes-profiles.sh`; sets config through `hermes config set`.                           |

Aliases (`aliases:` frontmatter) and cron registration are CLI-only; without the
CLI the file-drop path writes the spec and skips registration with a warning.

### Options

| Option                  | Description                                                                      |
| ----------------------- | -------------------------------------------------------------------------------- |
| `install`               | Install/refresh all profiles (default action).                                   |
| `--no-cli`              | File-drop only; no hermes CLI required (default).                                |
| `--cli`                 | Delegate to `hack/gen-hermes-profiles.sh` (needs the hermes CLI).                |
| `--dry-run`, `-n`       | Show what would happen; write nothing.                                           |
| `--home DIR`            | Hermes home (default `$HERMES_HOME` or `~/.hermes`).                             |
| `--secrets NAME`        | *(required)* Secret source to wire in (`bitwarden`).                             |
| `--bws-project-id UUID` | *(required with bitwarden)* Bitwarden project id; implies `--secrets bitwarden`. |
| `-h`, `--help`          | Show help.                                                                       |

### Environment overrides

Flags take precedence over env.

| Variable            | Default                              | Purpose                                        |
| ------------------- | ------------------------------------ | ---------------------------------------------- |
| `HERMES_HOME`       | `~/.hermes`                          | Profiles root parent.                          |
| `MODEL_OPUS`        | `openrouter/meta/muse-spark-1.3`     | provider/model for agents with `model: opus`.  |
| `MODEL_SONNET`      | `openrouter/meta/muse-spark-1.3`     | provider/model for agents with `model: sonnet`.|
| `MODEL_BASE_URL`    | `https://openrouter.ai/api/v1`       | OpenAI-compatible endpoint (`model.base_url`). |
| `AGENTHEON_SECRETS` | *(unset — required)*                 | Secret source (`bitwarden`).                   |
| `BWS_PROJECT_ID`    | *(unset — required with bitwarden)*  | Bitwarden project id.                          |
| `BWS_SERVER_URL`    | `https://vault.bitwarden.com`        | Bitwarden server URL.                          |
| `BWS_TOKEN_ENV`     | `BWS_ACCESS_TOKEN`                   | Name of the env var holding the access token.  |

### Secrets

Plaintext `.env` is **never** touched (add keys with `hermes -p <name> setup`).
With `--secrets bitwarden`, a `secrets.bitwarden` block is emitted into every
`config.yaml` so provider keys resolve once from a Bitwarden project at runtime
instead of being duplicated per-profile. The access token stays in the shell
(`BWS_ACCESS_TOKEN`) — only the *name* of the env var is written, never the
token itself. See [ADR-0003](../decisions/0003-secret-management.md) and the
[secrets how-to](../how-to/manage-secrets.md).

### Make targets

| Command                | Runs                               |
| ---------------------- | ---------------------------------- |
| `make install`         | `./agentheon.sh install`           |
| `make install-dry-run` | `./agentheon.sh install --dry-run` |

## `hack/set-model.sh` — set the model across all profiles

Sets the `model:` block in `config.yaml` for **every** Hermes profile: the
`default` profile (`$HERMES_HOME/config.yaml`) and every named deity profile
(`$HERMES_HOME/profiles/<slug>/config.yaml`). It writes nested keys via
`hermes config set model.<key>` (not a raw YAML patch), so Hermes owns the
schema. Named profiles are discovered by directory, so a profile with no
`config.yaml` yet gets one created by the first `set`.

Use this to re-point every profile at a new model without re-running the full
`agentheon.sh install` — but note `install` overwrites `config.yaml` from
frontmatter, so a model set here is transient until you fold it into the source.

### Usage

```bash
hack/set-model.sh                 # apply to default + all named profiles
hack/set-model.sh --dry-run       # print what would change, touch nothing
hack/set-model.sh -p zeus         # apply to ONE named profile only
hack/set-model.sh --default-only  # apply to the default profile only
hack/set-model.sh help
```

Requires the `hermes` CLI on `PATH`.

### The model block written

```yaml
model:
  provider: openrouter
  model: meta/muse-spark-1.3
  reasoning_effort: high
  default: meta/muse-spark-1.3
  base_url: https://openrouter.ai/api/v1
```

### Environment overrides

| Variable                 | Default                          |
| ------------------------ | -------------------------------- |
| `MODEL_PROVIDER`         | `openrouter`                     |
| `MODEL_ID`               | `meta/muse-spark-1.3`            |
| `MODEL_REASONING_EFFORT` | `high`                           |
| `MODEL_DEFAULT`          | `meta/muse-spark-1.3`            |
| `MODEL_BASE_URL`         | `https://openrouter.ai/api/v1`   |
| `HERMES_HOME`            | `~/.hermes`                      |
| `NO_COLOR=1`             | disable ANSI colour              |

## `hack/gateway.sh` — manage the multiplex cron gateway

Manages the **single** Hermes messaging gateway that serves every deity. A
gateway is the process that fires a profile's cron jobs and delivers their
output. Rather than one gateway per cron-owning deity, Agentheon runs **one**
gateway on the `default` profile as a *multiplexer*: it ticks and serves every
named profile at once. See
[ADR-0005](../decisions/0005-multiplex-cron-gateway.md).

Each deity is a satellite profile (`gateway.enabled=false`, pinned by
`gen-hermes-profiles.sh`) that shares the default gateway's listener. Hermes
refuses a second per-profile gateway while the multiplexer serves it, so the
default gateway is the only one this script manages.

### Usage

```bash
hack/gateway.sh install       # configure default as multiplexer + install the gateway
hack/gateway.sh list          # list all profiles and gateway status
hack/gateway.sh start         # start the default multiplex gateway
hack/gateway.sh stop          # stop it
hack/gateway.sh restart       # restart it
hack/gateway.sh status        # show its status
hack/gateway.sh help
```

Extra `hermes` flags pass through, e.g.:

```bash
hack/gateway.sh install --start-now
hack/gateway.sh install --force
hack/gateway.sh start --system
```

Requires the `hermes` CLI on `PATH`.

### What `install` does

1. Writes `BWS_ACCESS_TOKEN` (if set) into the default profile's `.env`
   (`$HERMES_HOME/.env`) at mode `600`, preserving other keys. No-op when unset.
2. Sets `gateway.enabled=true` and `gateway.multiplex_profiles=true` on the
   default profile — the other side of the satellites' pinned
   `gateway.enabled=false`.
3. Reports the cron-owning deities the multiplexer will fire (derived from
   `agents/<slug>/crons/*.md`).
4. Runs `hermes gateway install` (with any pass-through flags).

The multiplexer serves **all** named profiles (no allowlist); a profile with no
crons simply has nothing to fire. To restrict it, set
`gateway.multiplex_profile_allowlist` in the default `config.yaml` by hand — it
is a YAML list, which `hermes config set` cannot write.

### Environment

| Variable           | Default     | Purpose                                                              |
| ------------------ | ----------- | -------------------------------------------------------------------- |
| `HERMES_HOME`      | `~/.hermes` | Profiles root parent.                                                |
| `BWS_ACCESS_TOKEN` | *(unset)*   | Bitwarden bootstrap token, written to the default `.env` on install. |
| `NO_COLOR=1`       | —           | Disable ANSI colour.                                                 |

## See also

- [Cron catalog and schedule schema](crons.md) — what the gateway fires.
- [Agent catalog and profile schema](agents.md) — the frontmatter these scripts read.
- [Install the pantheon](../how-to/install-the-pantheon.md) — task-oriented walkthrough.
- Other `hack/` helpers (`gen-hermes-profiles.sh`, `gen-crons.sh`,
  `validate-agents.sh`, `validate-crons.sh`, …) are internal generators/linters,
  wired into the `Makefile`; run `make help` to list them.
