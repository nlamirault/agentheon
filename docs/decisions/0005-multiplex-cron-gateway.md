---
adr: 0005
status: ✅ Accepted
deciders: Nicolas Lamirault
consulted:
informed:
date: 2026-09-08
spdx-license: Apache-2.0
---

# ADR-0005: One Multiplex Gateway on the Default Profile Serves Every Deity's Crons

## Context

Agentheon derives one Hermes profile per deity and installs each under
`$HERMES_HOME/profiles/<slug>/` (see
[ADR-0001](0001-zeus-as-sole-orchestrator.md)). Scheduled tasks are co-located
with the deity that owns them — `agents/<slug>/crons/*.md` — and
`agentheon.sh` registers each with `hermes -p <slug> cron create` so a cron
runs as its owning deity, with that profile's model, skills, credentials, and
memory.

A Hermes **gateway** is the inbound/outbound messaging service. Crucially, it is
also the process that **fires a profile's cron jobs and delivers their output**.
Verified against the runtime: `hermes gateway` is per-profile, and
`hermes gateway list` reports "all profiles and their gateway status". So the
naive model — one gateway per deity that owns a cron — means a separate
long-running service (plus its own `.env` with `BWS_ACCESS_TOKEN`, plus its own
platform wiring) for **each** cron-owning deity. Six crons across five deities
(iris, apollo, artemis, argus, nemesis) implies five gateway services running
just to deliver a handful of daily and weekly messages. `hack/gateway.sh` exists
only to loop that fleet — a smell.

This coupling made "gateway count" scale with "deity count", which in turn made
the deity roster feel too large to operate. The two are not actually linked, and
this ADR breaks the link.

### What we verified in the runtime

Two upstream mechanisms were checked directly against the installed Hermes
Agent **v0.21.1** (`2026.9.7`):

- **Per-cron profile execution is not available.** `hermes cron create` exposes
  `--skill`, `--model`, `--provider`, `--reasoning-effort`, `--deliver` — but
  **no `--profile`/`--agent`** flag. NousResearch/hermes-agent#28124
  ("feat(cron): add per-job profile support") is marked merged but has **not
  shipped**: the flag is absent from the v0.21.1 CLI and from the v2026.9.7 tag
  source (zero `profile` references in the cron CLI, `cronjob_tools.py`, or
  `cron/jobs.py`). We cannot rely on it today.
- **A profile multiplexer exists and is the intended answer.** The gateway on the
  `default` profile can run as a *profile multiplexer*: a single gateway that
  serves several profile homes at once, firing each satellite profile's cron
  jobs and serving its platforms. Confirmed in the installed source:
  - `gateway/channel_directory.py` — "a multiplexed gateway serves several
    profile homes from one".
  - `hermes_cli/gateway.py` — `named_profile_served_by_running_multiplexer()`:
    "a satellite profile has no `gateway.pid`; the multiplexer fires its jobs and
    serves its platforms".
  - `hermes_cli/gateway.py` — `_guard_named_profile_under_multiplexer()`
    **refuses** to start a second per-profile gateway when the multiplexer
    already serves that profile (two pollers on one token / port fights).
  - `gateway/config.py` — the toggles: `gateway.multiplex_profiles` (bool) and
    `gateway.multiplex_profile_allowlist` (optional list; unset = serve all
    named profiles).
  - `gateway/config_env.py` — a satellite profile pins `gateway.enabled: false`
    to share the default profile's listener; only the default profile owns host
    TCP ports.

The decision: how does Agentheon host the gateway(s) that fire and deliver its
per-deity crons?

## Considered Options

1. **One multiplex gateway on the `default` profile.** Enable
   `gateway.multiplex_profiles` on `default`; run a single gateway that ticks and
   serves every deity profile. Crons stay registered per deity, exactly as today.
2. **Status quo — one gateway per cron-owning deity.** `hack/gateway.sh` installs
   and supervises a separate gateway service for each deity that owns a cron.
3. **Consolidate all crons under one profile (e.g. Zeus)** and reproduce each
   deity's behavior per job via `--skill` + `--model`/`--provider`.
4. **Wait for per-cron `--profile` (#28124)** and register every cron under one
   profile with `--profile <slug>`.

## Pros and Cons

### 1. One multiplex gateway on `default` (chosen)

**Pros:**

- ✅ One gateway process for the whole pantheon, regardless of deity count —
  gateway count is decoupled from roster size.
- ✅ Crons keep running **as their real owning deity**: full profile identity,
  credentials, vendored skills, model, and memory. No behavior is faked.
- ✅ Zero change to the co-located cron design (ADR-0001 / issue #36) and no
  change to Zeus, which stays routing-only.
- ✅ Ships today in v0.21.1; no dependency on unreleased upstream work.
- ✅ Upstream actively steers toward this: it refuses redundant per-profile
  gateways while the multiplexer runs.

**Cons:**

- ❌ Secret scoping under multiplex needs care: the gateway is one process, and
  `gateway/authz_mixin.py` notes "under multiplex only the default profile's list
  reaches the env (first-writer-wins)". Each satellite's provider keys must be
  reachable at run time — validated by a smoke test (below), and already the
  shape ADR-0003 targets (Bitwarden fetch per profile scope).
- ❌ The `default` profile becomes load-bearing (it hosts the listener and owns
  the platform tokens), where before it was incidental.

### 2. Status quo — one gateway per deity

**Pros:**

- ✅ No new concepts; strong isolation (each gateway is one profile).

**Cons:**

- ❌ N long-running services, N `.env` files, N platform configs for a handful of
  messages — the operational weight this ADR exists to remove.
- ❌ Makes the roster feel un-scalable: every new cron-owning deity is another
  service to supervise.

### 3. Consolidate crons under one profile (skill/model borrow)

**Pros:**

- ✅ One gateway; uses only shipped flags.

**Cons:**

- ❌ **Fundamentally broken here.** Skills are vendored **per profile and
  private** (`agentheon.sh` copies each into `<pdir>/skills/`, deliberately *not*
  the shared store). A cron under Zeus with `--skill git-workflow` resolves
  against Zeus's store, which does not contain it. Copying skills into the host
  profile violates both the vendoring model and the routing-only Zeus decision.
- ❌ Even if skills were shared, the cron would run with the host's credentials
  and system prompt, not the deity's — losing the identity the pantheon exists to
  provide.

### 4. Wait for per-cron `--profile` (#28124)

**Pros:**

- ✅ Would be the cleanest expression: one profile hosts the schedule, each job
  names its execution profile.

**Cons:**

- ❌ Not shipped in v0.21.1 or the latest tag; unschedulable.
- ❌ Even once released it solves *scheduling ownership*, not *gateway count* —
  the multiplexer is still what makes one gateway serve many profiles. This
  option is complementary, not a substitute.

## Decision

We will adopt **Option 1 — a single multiplex gateway on the `default`
profile**. Crons remain registered per deity (`hermes -p <slug> cron create`);
the `default` gateway multiplexes their execution and delivery.

Concretely:

- The `default` profile sets `gateway.multiplex_profiles: true`. Optionally,
  `gateway.multiplex_profile_allowlist` is derived from the deities that own
  crons (scan `agents/*/crons/*.md`); unset means serve all named profiles, which
  is harmless (a profile with no crons fires nothing).
- Each deity profile sets `gateway.enabled: false` so it shares the default
  listener and never tries to bind its own — emitted by
  `hack/gen-hermes-profiles.sh` in the per-profile loop.
- `hack/gateway.sh` is reworked from a per-profile loop into a single-gateway
  manager: `install` writes the bootstrap token to the **default** `.env`, sets
  the multiplex config, and installs one gateway; `start`/`stop`/`restart`/
  `status` operate the default gateway; `list` is unchanged.
- Delivery platforms (Slack) are configured once, on `default`. Per-cron
  `--deliver` is unchanged.
- Provider secrets stay per-profile (ADR-0003): the multiplex changes only
  **where the gateway runs**, not how each deity obtains its keys. This
  interaction is validated before rollout.

We accept the `default` profile becoming load-bearing and the multiplex
secret-scoping caveat because they buy a single gateway for the entire pantheon,
running today, with every cron still executing as its true deity.

## Consequences

### Positive

- ✅ One gateway to install, supervise, and reason about — independent of how many
  deities exist.
- ✅ Crons keep their owning deity's identity, credentials, skills, model, and
  memory.
- ✅ "Too many deities" is no longer a gateway problem; trimming the roster
  becomes a purely editorial choice, not an operational necessity.
- ✅ No unreleased-feature dependency; the design is complete on v0.21.1.

### Negative

- ❌ The `default` profile is now critical infrastructure (listener + platform
  tokens); its gateway is a single point of delivery for all crons.
- ❌ Multiplex secret scoping must be verified so each deity's cron sees its own
  provider keys — a required smoke test, not an assumption.

### Neutral

- ↔️ When #28124 ships, per-cron `--profile` can layer on top (schedule ownership
  moves to one profile) without changing this decision — the multiplexer remains
  what makes one gateway serve many.
- ↔️ `hack/gateway.sh` keeps the same command surface (`install`/`start`/`stop`/
  `restart`/`status`/`list`); only its per-profile fan-out is removed.

## References

- [ADR-0001: Zeus as Sole Orchestrator](0001-zeus-as-sole-orchestrator.md) — the
  per-deity profile model these crons run under
- [ADR-0003: Manage Provider API Keys with an External Secret Source](0003-secret-management.md)
  — the per-profile secret scoping the multiplex must preserve
- [`hack/gateway.sh`](../../hack/gateway.sh) — reworked from per-profile loop to
  single multiplex gateway manager
- [`hack/gen-hermes-profiles.sh`](../../hack/gen-hermes-profiles.sh) — emits
  `gateway.enabled: false` on satellite profiles
- Hermes Agent v0.21.1 (`2026.9.7`) — profile multiplexer:
  `gateway/config.py` (`multiplex_profiles`, `multiplex_profile_allowlist`),
  `hermes_cli/gateway.py` (`named_profile_served_by_running_multiplexer`)
- NousResearch/hermes-agent#28124 — per-cron `--profile` (merged upstream, not
  yet in a shipped release as of v0.21.1)
