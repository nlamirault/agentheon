<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Agentheon — Workflow & Quality Gates

Hermes orchestrates; specialists execute and hand off. Work moves through gates.
Nothing advances past a gate it has not passed.

## The main loop

```text
Request → Hermes (route)
  → Kairos        prioritize   gate: worth building, scoped, acceptance criteria set
  → Athena        plan         gate: plan is ordered, files named, risks listed
  → Hephaestus    build        gate: builds and runs
  → Artemis       test         GATE: PASS/FAIL on acceptance criteria
  → Argus         review       GATE: PASS/FAIL on correctness + security
  → Themis        comply       GATE: PASS/FAIL on licensing, DCO, privacy, policy
  → Apollo        document     gate: docs match the change
  → Helios        observe      runs in prod; anomaly → back to Asclepius / Hestia
  → Hermes        synthesize + return
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

## Quality gates — the core mechanic

For each unit of work:

```text
1. Author agent IMPLEMENTS against the acceptance criteria.
2. Gate agent VERIFIES (Artemis = tests, Argus = review).
   - Requires EVIDENCE: test output, build result, diff, screenshot.
3. IF PASS  → advance to next hop.
   IF FAIL and attempt < 3 → return to author with specific fixes; retry.
   IF FAIL and attempt = 3 → ESCALATE to Hermes
        → Hermes decides: reassign, decompose the task, or defer.
```

## Rules for gate agents

- **Evidence over claims.** No PASS without proof the criteria are met.
- **Verdict is PASS or FAIL**, never "looks fine". Use the handoff template's
  verdict block.
- **On FAIL, be specific.** List the exact criteria unmet and the fixes needed —
  a vague FAIL just causes another failed attempt.
- **Do not fix it yourself.** Artemis and Argus report; Hephaestus (or the
  original author) applies the fix. This keeps authorship and review separate.

## Rules for Hermes (orchestrator)

- Route to the **minimal** set of agents. Do not fan out work one agent can do.
- Every dispatch carries a filled handoff (`handoff-template.md`).
- Enforce the gates — do not mark a task done on an author's say-so.
- Own escalations: after three failed attempts, decide, don't loop.
- Synthesize partial results into one answer; never do specialist work yourself.
