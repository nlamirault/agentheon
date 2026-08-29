# State Schema

Single source of truth for `intent-state.md` format and the state machine it tracks.

## File Format

```markdown
# Intent State

intent: <intent-name>
created: <ISO-8601-timestamp>
updated: <ISO-8601-timestamp>

## Workflow Progress

| Skill | Step | Status | Attempt | Artifacts |
|---|---|---|---|---|
| <skill-name> | <step> | <status> | <n> | <comma-separated bare filenames or —> |
```

## Rules

### 1. One row per skill

Each skill has exactly one row. When updating state, find the existing row and replace in place.
Do NOT add a new row — duplicate rows break parsing.

### 2. State key

- Inception skills: skill name only (e.g., `requirements-analysis`)
- Construction skills (per-unit): `<skill-name>:<unit-name>` (e.g., `functional-design:auth-service`)
- Scoped skills: `<skill-name>:<scope-name>` (e.g., `reverse-engineering:payments-api`)

### 3. Artifacts column

Bare filenames only — no full paths (e.g., `requirements.md` not `inception/requirements-analysis/requirements.md`).

Paths resolve relative to:
- inception: `inception/<skill>/`
- inception (scoped): `inception/<skill>/<scope>/`
- construction: `construction/<unit>/<skill>/`

Comma-separated, or `—` if none.

### 4. Write responsibilities

| Actor | Writes |
|---|---|
| Orchestrator | clarification, planning, execution, validation states |
| Orchestrator | `awaiting-human → answered/approved/rejected`, `— → complete` |

---

## Valid States

| Step | Status | Meaning |
|---|---|---|
| — | not-started | Skill has not begun |
| clarification | pending | Questions need to be generated |
| clarification | awaiting-human | Questions written, waiting for answers |
| clarification | answered | Human answered; reviewing for ambiguity |
| clarification | follow-up | Ambiguous answers; follow-up questions generated |
| clarification | complete | Answers clear; ready to plan |
| planning | pending | Plan needs to be created |
| planning | awaiting-human | Plan written; waiting for approval |
| planning | revision-requested | Human requested changes |
| planning | approved | Plan approved; ready to execute |
| execution | pending | Artifacts need to be generated |
| execution | complete | Artifacts written |
| validation | pending | Validation needed |
| validation | pass | All checks passed |
| validation | fail | One or more checks failed |
| verification | awaiting-human | Artifacts presented for human review |
| verification | approved | Human approved |
| verification | rejected | Human rejected; needs rework |
| — | halting | Retries exhausted; escalated to human |
| — | complete | Skill finished |

## Valid Transitions

Full path (all flags `true`):

```
— : not-started                → clarification : pending

clarification : pending         → clarification : awaiting-human
clarification : awaiting-human  → clarification : answered
clarification : answered        → clarification : follow-up  (ambiguous answers)
clarification : answered        → clarification : complete
clarification : follow-up       → clarification : awaiting-human
clarification : complete        → planning : pending           (plan-creation: true)
clarification : complete        → execution : pending          (plan-creation: false)

planning : pending              → planning : awaiting-human
planning : awaiting-human       → planning : approved
planning : awaiting-human       → planning : revision-requested
planning : revision-requested   → planning : awaiting-human
planning : approved             → execution : pending

execution : pending             → execution : complete
execution : complete            → validation : pending

validation : pending            → validation : pass
validation : pending            → validation : fail
validation : pass               → verification : awaiting-human  (artefact-verification: true)
validation : pass               → — : complete                   (artefact-verification: false)
validation : fail               → execution : pending            (retries left)
validation : fail               → — : halting                    (no retries)

verification : awaiting-human   → verification : approved
verification : awaiting-human   → verification : rejected
verification : approved         → — : complete
verification : rejected         → execution : pending           (increment attempt)
```

## Attempt Counter

- Starts at 1; increments on validation fail + retry and on verification rejected
- Never decreases
- Default maximum: 3
- Reached + validation fail → `halting`
