---
name: "aidlc-orchestrator"
description: "AI-Driven Development Life Cycle (AI DLC) v2 — structured multi-phase methodology where AI and humans co-create software through adaptive workflows composed per intent. Orchestrates intent bootstrap, workflow composition, and a catalogue of 13 specialized skills (inception, construction). Activates when the user says 'start a project', 'build a feature', 'implement X', 'use AIDLC', 'let's follow AI DLC', or begins any non-trivial development task where structured planning helps. Also triggers for 'Using AI-DLC, ...' prefix. Proactively triggers when architectural decisions are being made and should be captured as ADRs."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "2.0.0"
  service:
  - ai
  - agent
  task: [configure, build, review]
  persona: [developer, ml-engineer]
  workload: [ai]
---

# AI-Driven Development Life Cycle (AI DLC)

AI DLC positions AI as a central collaborator. AI proposes; humans validate and approve before
execution proceeds. Each intent gets an adaptive workflow composed from a skill catalogue —
no two intents run the same fixed pipeline.

> Based on [AWS AI-DLC methodology](https://aws.amazon.com/blogs/devops/ai-driven-development-life-cycle/)
> and [awslabs/aidlc-workflows v2](https://github.com/awslabs/aidlc-workflows/tree/v2).

## Core Principles

- **AI proposes, humans approve** — never advance to the next step without explicit confirmation
- **Adaptive workflow** — compose from catalogue per intent; skip aggressively when not needed
- **Intent isolation** — each intent lives in `org-ai-kb/aidlc-docs/intent-<nnn>-<slug>/` outside the project
- **Complete audit trail** — every interaction appended to `audit/intent-audit.md`
- **State machine** — track progress in `state/intent-state.md`; sessions resume at last step
- **Content first, code second** — documentation artifacts precede implementation
- **Decisions as records** — every architectural decision captured automatically as an ADR

## Terminology

| AI DLC Term | Traditional Equivalent |
| ----------- | ---------------------- |
| Bolt | Sprint (hours/days, not weeks) |
| Unit of Work | Epic/feature slice |
| Intent | Feature request or task |

---

## Welcome Banner

Display when starting a fresh intent:

```
AI-DLC Workflow 2.0

Humans codify the judgement.
AI orchestrates and self-verifies — deterministically.
```

---

## Step 0: Rules Detection

Check for installed awslabs AI-DLC rules (in priority order):

```bash
.aidlc/aidlc-rules/aws-aidlc-rule-details/
.aidlc-rule-details/
.kiro/aws-aidlc-rule-details/
.amazonq/aws-aidlc-rule-details/
```

- **Rules found**: Load `common/process-overview.md`, `common/session-continuity.md`,
  `common/content-validation.md`, `common/question-format.md`. Those rules take precedence.
- **No rules found**: Follow this skill.

## Step 1: State Check

Check for any `org-ai-kb/aidlc-docs/intent-*/state/intent-state.md`:

- **Found**: List in-progress intents. Ask: "Resume intent [slug] from [last step], or start a new intent?"
- **Not found**: Greenfield session. Proceed to bootstrap.

---

## Bootstrap Pre-Loop (runs once per intent, before workflow.md exists)

1. Load `../aidlc-intent-bootstrap/SKILL.md`. Execute it (no plan, no human clarification).
   This creates `org-ai-kb/aidlc-docs/intent-<nnn>-<slug>/` with all skeleton files.

2. Load `../aidlc-workflow-composition/SKILL.md`. Execute it.
   Present composed workflow to human for approval before proceeding.
   Human approval rewrites `workflow.md` from stub to the full downstream skill list.

---

## Standard Skill Loop

Once `workflow.md` exists and workflow-composition is approved, drive every remaining skill.
Load `references/builder-protocol.md` for execution steps, `references/validator-protocol.md`
for the validation step, and `../aidlc-<skill>/validation-spec.md` for per-skill rules.

```
for each skill in workflow.md:

  [BUILDER MODE — load references/builder-protocol.md + ../aidlc-<skill>/SKILL.md + ../aidlc-<skill>/validation-spec.md]

  1. Clarification step:
     - Read ../aidlc-<skill>/validation-spec.md first (informs what to ask)
     - Generate clarification questions to <output-dir>/<skill>-questions.md
     - If human-clarification: present questions, wait for answers
     - If not: auto-answer with recommended answers, record rationale
     - Update intent-state.md: clarification → complete

  2. Planning step (if plan-creation: true):
     - Produce plan artifact with checkboxes
     - Present plan for human approval
     - Update intent-state.md: planning → approved

  3. Execution step:
     - Generate artifacts per ../aidlc-<skill>/SKILL.md Output section
     - Mark each plan checkbox [x] immediately — never batch
     - Update intent-state.md: execution → complete

  [VALIDATOR MODE — load references/validator-protocol.md + ../aidlc-<skill>/validation-spec.md]

  4. Validation step:
     - Run: scripts/process-checker.sh <intent-dir> <skill> [--unit X|--scope X]
     - Check every rule in ../aidlc-<skill>/validation-spec.md against produced artifacts
     - Write validation-report.md to skill output dir
     - On PASS: update intent-state.md: validation → pass
     - On FAIL and retries left: re-enter builder execution step (increment attempt)
     - On FAIL and no retries: halt, present report to human
     - Update intent-state.md: validation → fail / halting

  [ORCHESTRATOR]

  5. Artefact verification (if artefact-verification: true):
     - Present artifacts to human for review
     - On reject: re-enter execution step (increment attempt counter)
     - On approve: update intent-state.md: — → complete

  6. ADR Decision Capture if ../aidlc-<skill>/SKILL.md specifies it

  → proceed to next skill
```

**For per-unit skills** (construction phase): run the full loop for unit N before starting unit N+1.
**For scoped skills** (reverse-engineering): run once per `--scope` in `workflow.md`.

---

## State and Audit

**State machine**: `state/intent-state.md` — update after every step.
Format and valid transitions: `references/state-schema.md`
Template: `assets/aidlc-state-template.md`

**Audit log**: `audit/intent-audit.md` — append-only. Read first, then append.
Entry format: `assets/audit-entry-template.md`
Record: every user input verbatim, every AI-generated artifact summary, every approval.

---

## ADR Decision Capture

Fires automatically after approval of: Application Design, Functional Design, NFR Assessment,
NFR Design, Infrastructure Design. Creates one ADR per significant architectural decision.
ADRs land in `docs/adr/` (workspace root, not inside `org-ai-kb/`).

Full taxonomy and format: `references/adr-integration.md`

---

## References

| Reference | Content |
|---|---|
| `CATALOGUE.md` | All skills with phase, flags, composition rules |
| `../aidlc-<skill>/SKILL.md` | Detailed instructions per skill |
| `../aidlc-<skill>/validation-spec.md` | Per-skill validation rules and upstream inputs |
| `references/builder-protocol.md` | Builder execution steps, scope-by-phase rules |
| `references/validator-protocol.md` | Validator protocol, report format |
| `scripts/process-checker.sh` | Artifact existence checker (exit 0=PASS, 1=FAIL) |
| `references/state-schema.md` | State machine format, valid states, transitions |
| `references/workflow-format.md` | `workflow.md` syntax, `--unit`, `--scope`, `--phase` flags |
| `references/phases.md` | Stage tables per phase with conditions and key outputs |
| `references/artifacts.md` | Complete artifact listing with directory layout |
| `references/adr-integration.md` | ADR capture taxonomy, format, index |

---

## Anti-Patterns

- **Skipping approval gates** — always wait for explicit "yes" / "continue" / "looks good"
- **Overwriting audit.md** — always append, never overwrite
- **Code in org-ai-kb/** — application code in workspace root only; `org-ai-kb/` contains AI-DLC artifacts exclusively
- **Batching checkbox updates** — mark `[x]` immediately, not at end of generation
- **Summarizing user input** — audit log must capture complete raw input verbatim
- **Silent architectural decisions** — never complete Application Design, NFR Assessment, NFR Design,
  or Infrastructure Design without running ADR Decision Capture
- **Fixed pipeline** — compose per intent from CATALOGUE.md; do not assume all stages always run
- **Advancing on fail** — on validation fail, re-execute; never proceed with a failed step
