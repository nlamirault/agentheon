<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Manage provider API keys with Bitwarden

Every deity is an independent Hermes profile that loads **only its own** `.env`
(the root `~/.hermes/.env` belongs to the default profile alone). So a provider
key set the naive way has to be repeated in **all 21 profiles** — 21 places to
edit, 21 places to rotate. And `agentheon.sh` rewrites each `config.yaml` on
every run, so configuring a profile by hand does not survive a regenerate.

This guide wires **Bitwarden Secrets Manager** in as a single source of truth:
each provider key lives once in a vault, and `agentheon.sh` teaches every profile
to pull it at runtime. Adding a provider afterwards is one secret in the vault —
zero repo changes. The rationale and the alternatives considered are in
[ADR-0003](../decisions/0003-secret-management.md).

> Prerequisites: the pantheon installed (see
> [Install the pantheon](install-the-pantheon.md)), a Bitwarden account with
> **Secrets Manager** enabled, and the ability to create a machine account.

## How it fits together

A secret source has two pieces, and they live in **different places** on purpose:

| Piece           | Value                              | Lives in                                                    | Why there                                                                    |
| --------------- | ---------------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Bootstrap token | `BWS_ACCESS_TOKEN`                 | your **shell** (one file, sourced from the rc)              | inherited by every profile; never committed; not overwritten by regeneration |
| Source config   | `secrets.bitwarden` block          | each profile's `config.yaml`, **emitted by `agentheon.sh`** | it is config, not a secret — the generator keeps all 21 identical            |
| Provider keys   | `XAI_API_KEY`, `OPENAI_API_KEY`, … | the Bitwarden **project**, one secret each                  | matched **by name** at runtime                                               |

The Bitwarden backend maps **each secret's name straight to an env-var name**: a
secret called `XAI_API_KEY` in the project becomes `XAI_API_KEY` in the process.
There is no per-key mapping to maintain.

## 1. Create the project and machine account

In Bitwarden Secrets Manager:

1. Create a **project** (e.g. `agentheon`). Note its **project id** (a UUID).
2. Create a **machine account**, grant it read access to that project, and
   create an **access token**. Copy the token now — it is shown once.

## 2. Put the access token in your shell

The token is the one bootstrap secret. Keep it in a single shell-sourced file so
every profile inherits it, and **never** commit it:

```bash
# ~/.hermes/shared-secrets.env   (chmod 600)
export BWS_ACCESS_TOKEN="0.xxxxxxxx..."
```

Source it from your shell rc so every `hermes` invocation sees it:

```bash
echo '[ -f ~/.hermes/shared-secrets.env ] && source ~/.hermes/shared-secrets.env' >> ~/.zshenv
source ~/.hermes/shared-secrets.env
```

## 3. Add provider keys as named secrets

In the Bitwarden project, add one secret **per provider key**, where the secret's
**name is the env-var name** Hermes expects:

| Secret name (in Bitwarden) | Value      |
| -------------------------- | ---------- |
| `XAI_API_KEY`              | `xai-…`    |
| `OPENAI_API_KEY`           | `sk-…`     |
| `ANTHROPIC_API_KEY`        | `sk-ant-…` |

## 4. Generate profiles with the source enabled

Run the installer with the Bitwarden backend switched on:

```bash
AGENTHEON_SECRETS=bitwarden \
  BWS_PROJECT_ID="<your-project-uuid>" \
  ./agentheon.sh
```

This appends an identical `secrets.bitwarden` block to **every** profile's
`config.yaml`:

```yaml
secrets:
  bitwarden:
    enabled: true
    access_token_env: BWS_ACCESS_TOKEN
    project_id: <your-project-uuid>
    server_url: https://vault.bitwarden.com
    cache_ttl_seconds: 300
    override_existing: true
```

Only the **name** of the token env var lands in the file — never the token value.

> EU or self-hosted Bitwarden? Set `BWS_SERVER_URL` (e.g.
> `https://vault.bitwarden.eu`). Using a different env var for the token? Set
> `BWS_TOKEN_ENV`. Both are generator env vars.

## 5. Verify

```bash
# every profile carries the block:
grep -l bitwarden $HERMES_HOME/profiles/*/config.yaml | wc -l   # → 21

# the token VALUE is nowhere in config (only the env-var name):
grep -r BWS_ACCESS_TOKEN $HERMES_HOME/profiles/*/config.yaml    # → access_token_env: BWS_ACCESS_TOKEN

# resolve now and run:
hermes -p athena chat
```

On start, Hermes runs `bws secret list <project_id>`, injects each named secret
into the environment (cached for `cache_ttl_seconds`), and the agent has its
keys. On a Bitwarden outage it falls back to whatever `.env` already held.

## Adding a provider later (the payoff)

Adding X.AI — or any provider — is now **one step, no repo change**:

1. Add a secret named `XAI_API_KEY` to the Bitwarden project.

That is all. Because matching is by name and the config block is identical for
every deity, no profile edit and no `agentheon.sh` change is needed. (Re-running
`agentheon.sh` stays safe — it regenerates the same block.)

## Rotating a key

Edit the secret's value in the Bitwarden project. Every profile picks up the new
value on its next start (or after `cache_ttl_seconds`). One edit, all 21.

## Security notes

- `BWS_ACCESS_TOKEN` is the only plaintext secret, and it lives in your shell,
  not in the repo. Keep `~/.hermes/shared-secrets.env` at `chmod 600` and
  gitignored.
- `project_id` and `server_url` are **not** secrets (they are pointers); the
  generator takes them from env so nothing personal is hardcoded in the repo.
- `override_existing: true` means a value from Bitwarden wins over a stale one in
  `.env`. A plaintext key in a profile's `.env` is no longer needed — remove it.

## Troubleshooting

- **The `secrets:` block vanished after a run.** You configured a profile by hand
  with `hermes -p <slug> secrets bitwarden setup`; `agentheon.sh` overwrites
  `config.yaml` on every run and wiped it. Always enable the source through the
  generator (step 4) so it is regenerated, not hand-written.
- **Keys don't resolve.** Check `BWS_ACCESS_TOKEN` is exported in the shell that
  launched `hermes` (`echo ${BWS_ACCESS_TOKEN:+set}`), and that the secret name
  in Bitwarden matches the env-var name exactly.

## Alternative: no secret manager

If you would rather not run a manager, a single shell-sourced file is still a
valid one-place source (at the cost of plaintext on disk): put every provider key
in `~/.hermes/shared-secrets.env` and source it from your rc. Shell-exported
provider keys are inherited by every profile. This is option 2 in
[ADR-0003](../decisions/0003-secret-management.md); Bitwarden is preferred for
central rotation and no keys on disk.

## Related

- [ADR-0003: Manage provider API keys with an external secret source](../decisions/0003-secret-management.md)
- [Install the pantheon into Hermes Agent](install-the-pantheon.md)
- [Connect a knowledge vault](connect-a-knowledge-vault.md)
