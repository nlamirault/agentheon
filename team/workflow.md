<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Agentheon — Workflow & Quality Gates

Zeus orchestrates; specialists execute and hand off. Work moves through gates.
Nothing advances past a gate it has not passed.

## The main loop

```text
Request → Zeus (route)
  → Kairos        prioritize   gate: worth building, scoped, acceptance criteria set
  → Athena        plan         gate: plan is ordered, files named, risks listed
  → Hephaestus    build        gate: builds and runs
  → Artemis       test         GATE: PASS/FAIL on acceptance criteria
  → Argus         review       GATE: PASS/FAIL on correctness + security
  → Themis        comply       GATE: PASS/FAIL on licensing, DCO, privacy, policy
  → Apollo        document     gate: docs match the change
  → Helios        observe      runs in prod; anomaly → back to Asclepius / Hestia
  → Zeus        synthesize + return
```

The loop is a cycle, not a line: once shipped, **Helios** watches production and
feeds anomalies back to **Asclepius** (diagnose) or **Hestia** (remediate).
**Hygieia** runs off the loop — a periodic health audit that hands refactors to
**Hephaestus**.

Specialists join the loop where relevant:

- **Asclepius** (debug) — enters when a build or test fails with an unknown
  cause; reproduces, finds root cause, hands the fix to Hephaestus.
- **Hestia** (infra) — CI/CD, deploy, IaC; hands security-sensitive infra to Argus.
- **Demeter** (data) — schemas, migrations, queries; hands to Artemis for tests.
- **Prometheus** (AI/ML) — models, prompts, pipelines; builds evals before shipping.
- **Aglaea** (design) — visual design + design system (`DESIGN.md`) for web and
  mobile; hands the spec to Aphrodite to build.
- **Aphrodite** (frontend) — UI/UX; hands to Artemis, then Apollo.
- **Helios** (observability/SRE) — SLOs, dashboards, alerts; watches prod and
  routes incidents to Asclepius or Hestia.
- **Hygieia** (code health) — audits tech debt and dependency rot; hands
  incremental refactors to Hephaestus.
- **Iris** (open source/community) — the project's external interface: triages
  issues and PRs, cuts releases, routes feature requests to Kairos, code review
  to Argus, and bugs to Asclepius.
- **Plutus** (FinOps/cost) — attributes cloud spend, finds waste, and recommends
  rightsizing; hands infra changes to Hestia and cost/value trade-offs to Kairos.
- **Poseidon** (networking) — designs topology, routing, and connectivity; hands
  provisioning to Hestia and network security policy to Argus.
- **Atlas** (performance) — load-tests and profiles for throughput/latency
  targets; hands fixes to Hephaestus and prod monitoring to Helios.
- **Nemesis** (release/supply chain) — SBOMs, signing, and SLSA provenance;
  hands the published release to Iris and code review to Argus.

## Quality gates — the core mechanic

For each unit of work:

```text
1. Author agent IMPLEMENTS against the acceptance criteria.
2. Gate agent VERIFIES (Artemis = tests, Argus = review).
   - Requires EVIDENCE: test output, build result, diff, screenshot.
3. IF PASS  → advance to next hop.
   IF FAIL and attempt < 3 → return to author with specific fixes; retry.
   IF FAIL and attempt = 3 → ESCALATE to Zeus
        → Zeus decides: reassign, decompose the task, or defer.
```

## Rules for gate agents

- **Evidence over claims.** No PASS without proof the criteria are met.
- **Verdict is PASS or FAIL**, never "looks fine". Use the handoff template's
  verdict block.
- **On FAIL, be specific.** List the exact criteria unmet and the fixes needed —
  a vague FAIL just causes another failed attempt.
- **Do not fix it yourself.** Artemis and Argus report; Hephaestus (or the
  original author) applies the fix. This keeps authorship and review separate.

## Rules for Zeus (orchestrator)

- **Route by confidence.** Score the best-matching agent 0.0–1.0: dispatch at
  ≥ 0.5; below 0.5, ask one clarifying question before routing rather than
  guessing. A wrong route costs more than a short question.
- Route to the **minimal** set of agents. Do not fan out work one agent can do.
- Every dispatch carries a filled handoff (`handoff-template.md`).
- Enforce the gates — do not mark a task done on an author's say-so.
- Own escalations: after three failed attempts, decide, don't loop.
- Synthesize partial results into one answer; never do specialist work yourself.

## Per-agent finalization gate

Beyond the workflow gates above, **every** agent self-checks before returning a
result (this block is generated into each profile's `SOUL.md`): the request is
actually answered, the right agent handled it, shared context was loaded,
handoffs are filled, claims carry evidence, and the user is told what's next.
The workflow gates catch work moving *between* agents; the finalization gate
catches a single agent returning something half-done.

## Security: red and blue (Argus)

Argus reviews from both sides. `security-red-team` finds and proves the exploit
path; `security-blue-team` hardens, adds a regression guard, and verifies the
scenario is closed (and ships a runnable `secret-scan`). Offense finds, defense
fixes, offense re-confirms.
