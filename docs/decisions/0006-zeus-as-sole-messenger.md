---
adr: 0006
status: 🚧 Proposed
deciders: Nicolas Lamirault
consulted:
informed:
date: 2026-09-28
spdx-license: Apache-2.0
---

# ADR-0006: Zeus as the Sole Outbound Messenger

## Context

Every deity is a fully independent Hermes profile that loads only its own
`profiles/<slug>/.env` ([ADR-0003](0003-secret-management.md)). Outbound delivery
to a human — Slack, Telegram, email — is a **gateway** function: a cron carries a
`deliver:` channel ([`team/crons.md`](../../team/crons.md),
[`docs/reference/crons.md`](../reference/crons.md)) and the gateway process ships
it. [ADR-0005](0005-multiplex-cron-gateway.md) already consolidated that to **one
multiplex gateway on the `default` profile**, which owns the host listener and
the platform tokens; satellite profiles set `gateway.enabled: false`.

Two forces exposed a gap:

- **A crash.** After [#65](https://github.com/nlamirault/agentheon/pull/65)
  symlinked every profile's `.env` to one shared `.shared-secrets.env`, that
  shared file carried `SLACK_BOT_TOKEN`. Every profile then *also* configured the
  Slack platform, and Hermes' `_guard_named_profile_under_multiplexer`
  (ADR-0005) refused to start:

    > Profile 'default (env SLACK_BOT_TOKEN)' and 'tyche (env SLACK_BOT_TOKEN)' both
    > configure slack with the same credential — refusing to start the duplicate
    > (one credential cannot be consumed twice).

    Slack Socket Mode and the Telegram `getUpdates` long-poll both allow exactly
    **one** live consumer per bot token; the guard enforces at config time what the
    platforms enforce at runtime.

- **A missing policy.** Nothing stated *who* may address a human. If any deity
  can hold a platform token and post directly, the pantheon speaks with many
  uncoordinated voices, every specialist profile becomes a place a platform
  secret can leak, and the single-consumer limit is violated by construction.

Zeus is already the single entrypoint that routes work and **synthesizes partial
results into one coherent answer** ([ADR-0001](0001-zeus-as-sole-orchestrator.md);
`agents/zeus/README.md`). Zeus's toolset is deliberately `orchestration` + `files`
only — **no hermes-cli / shell** — so Zeus is structurally incapable of calling a
platform API itself. Delivery is, and must remain, the gateway's job.

The decision: who is allowed to send a message to a human, and how does a
specialist's result reach that sender?

## Considered Options

1. **Single outbound messenger — specialists return an envelope to Zeus; the
   ADR-0005 gateway (sole token holder) transmits Zeus's message.** Platform
   tokens live only on the gateway profile; no specialist profile configures a
   platform. Zeus authors/aggregates the user-facing message; the gateway ships
   it.
2. **Every deity messages directly.** Each profile that needs to notify a human
   holds its own platform token and delivers its own output.
3. **Distinct bot token per deity.** Give each deity its own Slack app / Telegram
   bot so there is no shared credential to collide on.

## Pros and Cons

### 1. Single outbound messenger (chosen)

**Pros:**

- ✅ Fixes the crash by construction: exactly one profile configures each
  platform, so the one-credential-one-consumer guard can never trip.
- ✅ One voice to a human — Zeus synthesizes, which is already its stated job
  (ADR-0001); attribution is carried in the envelope's `from`, not by a second
  bot identity.
- ✅ Smallest secret blast radius: no specialist profile holds a platform token,
  so a leaked deity `.env` exposes provider keys only, never the messaging bot.
- ✅ Layers cleanly on ADR-0005 — the gateway is already the sole token holder and
  transmitter; this ADR only forbids anyone *else* from configuring a platform.
- ✅ Ships today; no new Slack/Telegram apps, no upstream Hermes change.

**Cons:**

- ❌ Zeus + the gateway are a single point of delivery for all outbound messages
  (already true of the gateway under ADR-0005; this ADR does not add the SPOF, it
  names it).
- ❌ All human-facing messages wear one bot identity; per-deity voice survives
  only as envelope attribution, not as a distinct sender.

### 2. Every deity messages directly

**Pros:**

- ✅ No aggregation hop; a deity's result reaches the human immediately.

**Cons:**

- ❌ This is exactly the crashed state: N profiles sharing one token trip the
  guard, and even with distinct tokens the pantheon speaks in N uncoordinated
  voices.
- ❌ Every specialist profile becomes a place a platform secret can leak.

### 3. Distinct bot token per deity

**Pros:**

- ✅ No credential collision; each deity keeps its own visible identity.

**Cons:**

- ❌ One Slack app + one Telegram bot to create, invite, and rotate **per deity**
  (28 and counting) — operational weight with no routing benefit.
- ❌ Contradicts ADR-0001/0005: delivery scatters back across the roster instead
  of staying with one gateway.
- ❌ Kept as the escape hatch *if and only if* a deity ever needs its own visible
  identity on a channel; not the default.

## Decision

We adopt **Option 1 — Zeus is the sole outbound messenger.**

**Roles.** Two actors, together "the messenger"; no third party may address a
human:

- **Zeus — the author.** Zeus (and only Zeus) composes the user-facing message,
  synthesizing specialist results ([ADR-0001](0001-zeus-as-sole-orchestrator.md)).
  Zeus holds no token and runs no shell — it produces the message *content and
  destination*, nothing more.
- **The gateway — the transmitter.** The ADR-0005 multiplex gateway on `default`
  is the sole holder of every platform token and the only process that calls a
  platform API.

**Specialists never message a human.** A deity receives its request (from Zeus, a
cron, or a user), does the work, and returns a **result envelope** up the handoff
chain to Zeus. It never configures a platform and never holds a platform token.

**Credentials.** Every platform secret — `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`,
`SLACK_ALLOWED_USERS`, `SLACK_HOME_CHANNEL`, `SLACK_HOME_CHANNEL_NAME`,
`TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`, `TELEGRAM_HOME_CHANNEL` — is
resolvable **only** by the gateway (`default`) profile; no satellite may resolve
any of them. Hermes activates a platform for **any profile whose env resolves
that platform's token** (the crash names it: `default (env SLACK_BOT_TOKEN)` and
`tyche (env SLACK_BOT_TOKEN)`), so scoping is about *reachability*, not intent.
Two secret paths, same rule:

- **Plaintext.** `.shared-secrets.env` is symlinked into every satellite, so it
  keeps **provider/LLM keys only**; platform secrets live in the default
  profile's own `$HERMES_HOME/.env`, which no satellite loads.
- **Bitwarden (ADR-0003).** Secrets Manager injects a **whole project** into a
  profile (no per-key allowlist), so a shared project holding a platform token
  leaks it to every deity — the same crash. Split into **two projects**: a
  *providers* project (`BWS_PROJECT_ID`, LLM keys) injected into every deity by
  `agentheon.sh`, and a *platform* project (`BWS_GATEWAY_PROJECT_ID`, the eight
  Slack/Telegram vars) wired into the default profile alone by
  `hack/gateway.sh`. The two project ids must differ (both scripts refuse
  otherwise); Bitwarden machine-account grants can further restrict the platform
  project to the gateway host's access token.

This scoping alone clears the startup crash.

**The result envelope.** A new section 3 of
[`team/handoff-template.md`](../../team/handoff-template.md). A specialist returns
this to Zeus; Zeus decides `to`/`target` (or overrides them) and hands the
composed message to the gateway for delivery:

```markdown
# Result envelope

| Field    | Value                                                   |
| -------- | ------------------------------------------------------- |
| From     | <deity slug> (<Domain>)      # attribution only         |
| To       | zeus                         # always Zeus              |
| Task     | <task id / title>                                       |
| Status   | done / blocked / failed                                 |
| Deliver  | slack / telegram / email / stdout / none                |
| Target   | <channel / chat id / address>  # proposed; Zeus decides |
| Priority | Critical / High / Medium / Low                          |

## Result

<the human-facing summary Zeus may forward verbatim or fold into a larger answer>

## Evidence

- <test output / build result / diff / path>

## References

- <specs, plan, prior work>
```

Rules on the envelope:

- `To` is **always `zeus`**. A specialist never names a platform as its
  recipient; `Deliver`/`Target` are a *proposal* Zeus may accept, change, or drop.
- `Deliver: none` is the default — most results are consumed by Zeus and folded
  into a larger answer, not shipped standalone.
- `From` is attribution the gateway renders (e.g. "Tyche → …"); it is **not** a
  second sender identity.

**Transport (specialist → Zeus).** Reuse the existing handoff path — the envelope
is returned the same way a `handoff-template.md` block is today
(`MODE=filedrop` drop or `MODE=cli` return; `agentheon.sh:115`). No new bus.

**Crons.** A cron's `deliver:` channel is unchanged and remains valid: the
gateway supplies the token, so a cron notification never required the token in the
deity profile. Cron delivery is the one sanctioned path where the gateway ships a
deity's output without a Zeus authoring hop — it is a fixed system notification,
not a synthesized answer. Ad-hoc (non-cron) human messages always go through Zeus.

We accept the delivery SPOF (already carried by the ADR-0005 gateway) and the
single visible bot identity, because they buy one coordinated voice, the smallest
possible secret blast radius, and a configuration the credential guard can never
crash.

## Consequences

### Positive

- ✅ The startup crash is impossible: one profile per platform.
- ✅ Platform secrets exist in exactly one profile; specialist `.env` leaks cannot
  expose the messaging bot.
- ✅ One coherent voice to humans, with per-deity attribution preserved in-message.
- ✅ Pure layer on ADR-0005; no new services, apps, or upstream dependency.

### Negative

- ❌ Zeus + gateway are the single delivery path for all ad-hoc outbound messages.
- ❌ Per-deity *visible* identity is given up unless Option 3 is adopted for a
  specific channel later.

### Neutral

- ↔️ `.shared-secrets.env` narrows to provider/LLM keys, and the Bitwarden
  providers project holds no platform secret; `hack/validate-secrets.sh` asserts
  no platform token is reachable by the shared file or any satellite `.env`.
- ↔️ Bitwarden gains a second project: `agentheon.sh` takes the providers project,
  `hack/gateway.sh` takes the platform project (`BWS_GATEWAY_PROJECT_ID`); the two
  ids must differ.
- ↔️ The result envelope extends `handoff-template.md`; no new transport is
  introduced.

## References

- [ADR-0001: Zeus as the Sole Orchestrator](0001-zeus-as-sole-orchestrator.md) —
  Zeus routes and synthesizes; specialists execute
- [ADR-0003: Manage Provider API Keys with an External Secret Source](0003-secret-management.md)
  — per-profile secret scoping
- [ADR-0005: One Multiplex Gateway on the Default Profile](0005-multiplex-cron-gateway.md)
  — the gateway that holds platform tokens and transmits
- [`agentheon.sh`](../../agentheon.sh) — emits the providers-project block into
  every deity; validates `BWS_GATEWAY_PROJECT_ID` differs from `BWS_PROJECT_ID`
- [`hack/gateway.sh`](../../hack/gateway.sh) — wires the platform project into the
  default profile only
- [`hack/validate-secrets.sh`](../../hack/validate-secrets.sh) — asserts platform
  tokens are scoped to the default profile
- [`team/handoff-template.md`](../../team/handoff-template.md) — gains the result
  envelope (section 3)
- [`agents/zeus/README.md`](../../agents/zeus/README.md) — routing-only,
  `orchestration` + `files` toolset (no shell)
- [#65](https://github.com/nlamirault/agentheon/pull/65) — the shared-secrets
  symlink that leaked `SLACK_BOT_TOKEN` into every profile
