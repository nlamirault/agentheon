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

## 3. Result envelope — specialist → Zeus

Use to return a finished result up to Zeus. A specialist **never** messages a
human directly: it returns this envelope, and Zeus (the sole outbound messenger)
decides whether and how to deliver it. Platform tokens live only on the gateway;
no specialist holds one. See [ADR-0006](../docs/decisions/0006-zeus-as-sole-messenger.md).

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

Rules:

- `To` is **always `zeus`** — a specialist never names a platform as its recipient.
- `Deliver`/`Target` are a *proposal*; Zeus may accept, change, or drop them.
- `Deliver: none` is the default — most results are folded into a larger answer,
  not shipped standalone.
- `From` is attribution the gateway renders ("Tyche → …"), not a second sender
  identity.
