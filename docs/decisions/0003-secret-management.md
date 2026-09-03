---
adr: 0003
status: ✅ Accepted
deciders: Nicolas Lamirault
consulted:
informed:
date: 2026-09-03
spdx-license: Apache-2.0
---

# ADR-0003: Manage Provider API Keys with an External Secret Source

## Context

Agentheon derives one Hermes profile per deity from `agents/*/README.md` and
installs each under `$HERMES_HOME/profiles/<slug>/` (see
[ADR-0001](0001-zeus-as-sole-orchestrator.md) for the roster). Each profile is a
**fully independent `HERMES_HOME`** with its own `config.yaml`, `.env`, memory,
sessions, and skills. `agentheon.sh` regenerates `config.yaml` on every run;
secrets in `.env` are deliberately never touched.

That independence creates a secrets-duplication problem. Verified against the
Hermes runtime (`hermes_cli/env_loader.py`, `hermes_cli/profiles.py`):

- Running `hermes -p <slug>` sets `HERMES_HOME` to
  `~/.hermes/profiles/<slug>` and loads **only that profile's** `.env`.
- The root `~/.hermes/.env` belongs to the **default profile alone** — named
  profiles never load it. It is *not* a shared layer.
- A provider key is therefore per-profile. Adding X.AI means creating the key,
  then repeating `XAI_API_KEY` in the `.env` of **every** deity — 21 edits for
  one credential, and 21 places a rotation must reach.

Two things soften this but do not solve it:

- **Shell exports are inherited.** A key `export`ed in the shell reaches every
  profile's `os.environ`, and provider keys are *not* scrubbed at startup (only
  a small set of behavioral ACP routing keys are). One shell-sourced file is a
  valid single source — but it stores every key in plaintext on disk.
- **`config.yaml` is regenerated.** Anything written into a profile's
  `config.yaml` by hand (e.g. `hermes -p <slug> secrets bitwarden setup`) is
  **overwritten on the next `./agentheon.sh` run**. Manual per-profile config is
  not durable in this repo.

We want: one credential lives in one place; adding a provider is a one-line
change; rotation touches one location; no plaintext provider keys on disk; and
the mechanism survives profile regeneration.

The decision: how do Agentheon profiles obtain provider API keys?

## Considered Options

1. **External secret source — Bitwarden Secrets Manager**, wired into the
   `config.yaml` generator. Hermes pulls keys from a Bitwarden project at
   process startup; the generator emits an identical `secrets.bitwarden` block
   for all 21 profiles.
2. **Shared shell-sourced env file** (`~/.hermes/shared-secrets.env` sourced
   from the shell rc). One file, inherited by every profile.
3. **Status quo — per-profile `.env`.** Repeat every key in every profile.

## Pros and Cons

### 1. Bitwarden Secrets Manager via the generator

Hermes' Bitwarden backend (`agent/secret_sources/bitwarden.py`) needs only a
`project_id` plus an access token; it runs `bws secret list <project_id>` and
maps **each secret's name directly to an env-var name** (`XAI_API_KEY` in the
vault becomes `XAI_API_KEY` in the process). There is no per-key mapping in
`config.yaml`.

**Pros:**

- ✅ Single source of truth: the credential lives once in the Bitwarden project.
- ✅ Adding a provider = add one secret named `XAI_API_KEY` in the vault. **Zero
  code and zero config change** — matching is by name, and the config block is
  identical for every deity.
- ✅ No plaintext provider keys on disk; only the bootstrap access token exists,
  and it lives in the shell env, not in the repo.
- ✅ Rotation touches one vault entry; every profile picks it up on next start.
- ✅ Survives regeneration: the generator emits the same `secrets.bitwarden`
  block on every run, so `./agentheon.sh` reinforces the pattern instead of
  wiping it.
- ✅ An in-process cache (`cache_ttl_seconds`) keeps back-to-back `hermes`
  invocations from hammering the API.

**Cons:**

- ❌ Introduces a Bitwarden Secrets Manager dependency and the pinned `bws`
  binary (auto-downloaded and checksum-verified by Hermes on first use).
- ❌ One bootstrap secret (`BWS_ACCESS_TOKEN`) must still be provisioned out of
  band, per machine.
- ❌ Startup does a network fetch when the cache is cold; an outage falls back to
  whatever `.env` already held.

### 2. Shared shell-sourced env file

**Pros:**

- ✅ Single source for all profiles; trivial, no external dependency.
- ✅ Survives regeneration (lives outside `config.yaml`).

**Cons:**

- ❌ Every provider key sits in plaintext in a file on disk.
- ❌ Rotation is a manual file edit; no audit, no central revocation.

### 3. Status quo — per-profile `.env`

**Pros:**

- ✅ No new moving parts.

**Cons:**

- ❌ The problem this ADR exists to fix: N-way duplication, N-way rotation,
  plaintext everywhere.

## Decision

We will adopt **Option 1 — Bitwarden Secrets Manager, wired into the
`config.yaml` generator**, with the bootstrap token supplied through the shell.

The design splits cleanly along the two scopes the runtime enforces:

| Piece           | Value                                                                                                      | Lives in                                                                   | Why there                                                                                  |
| --------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| Bootstrap token | `BWS_ACCESS_TOKEN`                                                                                         | Shell env (e.g. `~/.hermes/shared-secrets.env`, sourced from the shell rc) | Inherited by every profile; never committed; not overwritten by regeneration               |
| Source config   | `secrets.bitwarden` block (`enabled`, `project_id`, `access_token_env`, `server_url`, `cache_ttl_seconds`) | Each profile's `config.yaml`, emitted by `agentheon.sh`                    | Config, not a secret — belongs with the other generated config; identical for all profiles |
| Provider keys   | `XAI_API_KEY`, `OPENAI_API_KEY`, …                                                                         | The Bitwarden project, one secret per key                                  | Matched by name at runtime; adding a provider is a one-line vault change                   |

Concretely:

- `agentheon.sh` gains an opt-in switch (a generator env var, off by default) that
  appends a `secrets.bitwarden` block to the `config.yaml` heredoc (the block
  written around `agentheon.sh:465`). `project_id` and `server_url` come from
  generator env vars so no personal identifiers are hardcoded in the repo.
- The bootstrap token is documented as a shell export, not written to any
  profile `.env` and never committed.
- Profiles are regenerated with `./agentheon.sh`; every deity gets the same
  Bitwarden wiring, and the vault is the single source of truth for keys.

We accept the Bitwarden dependency and the one bootstrap secret because they buy
one-place storage, one-line provider onboarding, one-place rotation, and
no plaintext provider keys on disk — and because, unlike manual
`hermes secrets` configuration, the generator makes the pattern durable across
the regeneration that defines how Agentheon profiles are built.

## Consequences

### Positive

- ✅ A provider key lives once, in the vault; rotation is a single edit.
- ✅ Adding a provider (e.g. X.AI) is one new secret in the project — no repo change.
- ✅ No plaintext provider keys on disk; only the bootstrap token, held in the shell.
- ✅ The pattern is regenerated by `agentheon.sh`, so it cannot silently drift or
  be wiped by a normal install run.

### Negative

- ❌ New runtime dependency: Bitwarden Secrets Manager plus the `bws` binary.
- ❌ One bootstrap secret (`BWS_ACCESS_TOKEN`) must be provisioned per machine,
  out of band.
- ❌ Cold-cache startup performs a network fetch; a Bitwarden outage degrades to
  whatever `.env` already contained.

### Neutral

- ↔️ The `.env`-based flow still works for anyone who does not enable the source;
  the switch is opt-in and off by default.
- ↔️ 1Password is an equally supported Hermes backend; this ADR standardizes on
  Bitwarden for Agentheon but the generator switch can grow a 1Password mode
  without changing this decision's shape.

## References

- [ADR-0001: Zeus as Sole Orchestrator](0001-zeus-as-sole-orchestrator.md) — the
  per-deity profile model this ADR secures
- [`agentheon.sh`](../../agentheon.sh) — the `config.yaml` generator this ADR
  extends (secrets block appended near the `config.yaml` heredoc)
- Hermes Agent — external secret sources (Bitwarden / 1Password):
  <https://hermes-agent.nousresearch.com/docs/user-guide/secrets/>
- Bitwarden Secrets Manager: <https://bitwarden.com/products/secrets-manager/>
