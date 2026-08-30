# Builder Protocol (Claude Code Adaptation)

The builder is the **execution role** in AI-DLC. It reads a skill's sub-skill instructions
and validation spec, then produces artifacts. In Claude Code's single-agent model, the
orchestrator switches to builder mode by loading this protocol alongside the active skill.

---

## 1. Inputs

The orchestrator provides per invocation:

- Active skill: `sub-skills/<skill-name>.md`
- Active validation spec: `validation-specs/<skill-name>.md`
- Input file paths
- Current step: `clarification` | `planning` | `execution` | `fix`
- Answered question file path (step: `execution`)
- Approved plan file path (step: `execution`)
- Validation report path (step: `fix`)

The builder is stateless. Each invocation is independent. All state is in files on disk.

---

## 2. Protocol Per Step

### Clarification

1. Read `validation-specs/<skill>.md` **before** assessing — it defines the quality target
2. Read all input files
3. Assess whether clarifying questions are needed

**If `human-clarification: true` and questions needed:**
- Write questions to `<output-dir>/<skill>-questions.md` using A/B/C/D format (D=Other)
- Leave `[Answer]:` blank
- Update state: `clarification:pending → clarification:awaiting-human`
- Stop; return to orchestrator

**If `human-clarification: false`:**
- Write questions with recommended answers pre-filled; record rationale per answer
- Advance state through full clarification path in one pass:
  `pending → awaiting-human → answered → complete`
- Continue to planning (or execution if `plan-creation: false`)

**If no clarification needed:**
- Advance clarification to `complete`; continue

### Planning

Skip entirely when `plan-creation: false` — state goes from `clarification:complete` directly
to `execution:pending`.

1. Produce a plan file with checkboxes covering all artifacts to generate
2. Update state: `planning:pending → planning:awaiting-human`
3. Stop; orchestrator presents plan to human for approval

### Execution

1. Execute the approved plan; generate all artifacts per the sub-skill's **Output** section
2. Mark each plan checkbox `[x]` immediately as it completes — **never batch**
3. **Do NOT self-validate** — that is the validator's job
4. Update state Artifacts column with bare filenames (e.g. `requirements.md`, not full path)
5. Update state: `execution:pending → execution:complete`

### Fix (after validation fail)

1. Read the validation report
2. Read current artifacts
3. Fix every issue identified; rewrite affected artifacts
4. Update state: `execution:pending → execution:complete` (attempt counter already incremented)

---

## 3. Rules

1. **Read validation-spec before assessing clarification** — it informs what questions to ask
   and what standards to build toward
2. **Scope-by-phase** — never ask about or design for concerns belonging to a later skill:
   - Inception skills (`requirements-analysis`, `user-stories`, `application-design`):
     no tech stack, frameworks, databases, protocols, infrastructure, or deployment
   - `application-design`: logical behaviour only — no language, framework, database,
     protocol, broker, or vendor specifics
   - `functional-design`: technology-agnostic domain/business logic only
3. **Gap handling** — if input artifacts leave a capability unaddressed, raise a follow-up
   question. Never silently add functionality not documented upstream.
4. **Brownfield context** — accept context from codekb, RE artifacts, or direct codebase
   analysis. The skill file does not restate this.
5. **No direct human interaction** — all human communication routes through orchestrator
   approval gates defined in SKILL.md

---

## 4. State Write Responsibilities

| Step | Transition |
|---|---|
| Clarification (human-clar: true) | `clarification:pending → clarification:awaiting-human` |
| Clarification (human-clar: true) | `clarification:answered → clarification:complete` |
| Clarification (human-clar: false) | Full path `pending → awaiting-human → answered → complete` |
| Planning | `planning:pending → planning:awaiting-human` |
| Execution | `execution:pending → execution:complete` |

Does NOT write: `awaiting-human → answered/approved/rejected` — those are orchestrator's job,
except in `human-clarification: false` mode where the builder fills its own answers.
