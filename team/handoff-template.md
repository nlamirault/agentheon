<!--
SPDX-FileCopyrightText: Copyright (C) Nicolas Lamirault <nicolas.lamirault@gmail.com>
SPDX-License-Identifier: Apache-2.0
-->

# Agentheon — Handoff Template

Every transfer of work between agents uses this format. Consistent handoffs
prevent context loss — the number-one cause of multi-agent failure. Fill every
field; an empty field is a question the receiving agent will have to ask.

## 1. Work handoff

Use for any agent-to-agent work transfer (e.g. Athena → Hephaestus).

```markdown
# Handoff

| Field    | Value                          |
| -------- | ------------------------------ |
| From     | <Agent> (<Domain>)             |
| To       | <Agent> (<Domain>)             |
| Task     | <short task id / title>        |
| Priority | Critical / High / Medium / Low |

## Context

- **Goal**: <what we are ultimately trying to achieve>
- **State so far**: <what is already done — be specific>
- **Relevant files**: <path — what it contains>, ...
- **Dependencies**: <what must be true / done first>
- **Constraints**: <technical, style, security, timeline>

## Deliverable requested

<one specific, measurable deliverable>

## Acceptance criteria

- [ ] <criterion 1 — measurable>
- [ ] <criterion 2 — measurable>

**References**: <specs, plan, prior work>

## Quality expectations

- **Must pass**: <the gate this must clear — see workflow.md>
- **Evidence required**: <what proof of completion looks like>
- **Next hop**: <who receives the output, in what form>
```

## 2. Review verdict — PASS / FAIL

Use when a gate agent (Artemis for tests, Argus for review) reports back.

```markdown
# Verdict: PASS ✅   |   FAIL ❌

| Field    | Value                    |
| -------- | ------------------------ |
| Task     | <task id / title>        |
| Author   | <agent who did the work> |
| Reviewer | <gate agent>             |
| Attempt  | <N> of 3                 |

## Evidence

- <test output / build result / diff / screenshot path>

## Criteria

- [x] <criterion met>
- [ ] <criterion NOT met — this is why it failed>

## Verdict detail

- **PASS** → next hop: <agent>
- **FAIL** → back to <author> with the specific fixes below:
  1. <precise, actionable fix>
  2. ...
- **Attempt 3 FAIL** → escalate to Zeus (reassign / decompose / defer).
```
