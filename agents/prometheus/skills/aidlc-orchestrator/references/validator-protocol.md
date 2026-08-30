# Validator Protocol (Claude Code Adaptation)

The validator is the **verification role** in AI-DLC. It checks artifacts against the skill's
`validation-specs/<skill>.md` and produces a structured report. In Claude Code's single-agent
model, the orchestrator switches to validator mode by loading this protocol alongside the
active skill's validation spec.

---

## 1. Inputs

The orchestrator provides:

- Active validation spec: `validation-specs/<skill-name>.md`
- Artifact paths (from execution step)
- Upstream artifact paths (listed in validation-spec Inputs section)
- Answered question file path
- Skill output directory path

---

## 2. Protocol

1. Read `validation-specs/<skill>.md` including its "Inputs" section
2. Read all artifacts at the provided paths
3. Read all upstream artifacts listed in the spec
4. Read the answered question file
5. Run `scripts/process-checker.sh <intent-dir> <skill> [--unit <name>|--scope <name>]`
   Capture output and exit code. A non-zero exit code means `fail` regardless of other findings.
6. Validate all three dimensions:
   - **Spec compliance** — check every rule in `validation-specs/<skill>.md`
   - **Script results** — fold the exit code from step 5 into findings
   - **Clarification consistency** — artifacts match the answered questions
   - **Completeness** — gaps the spec may not anticipate (missing coverage, unstated
     assumptions, logical inconsistencies)
7. Write validation report to `<skill-output-dir>/validation-report.md`
8. Update state: `validation:pending → validation:pass` or `validation:pending → validation:fail`

---

## 3. Validation Report Format

### Human-Readable Section

```markdown
## Validation Report: <skill-name> [unit: <unit> | scope: <scope>]

**Status:** PASS | FAIL

### Rules Checked

- Rule 1: PASS — [brief confirmation]
- Rule 2: FAIL — [artifact, section, issue description]
  Recommendation: [how to fix]
...

### Scripts

- process-checker.sh: exit 0 — PASS | exit 1 — FAIL
  Output: [any output from script]

### Completeness Findings

[Any gaps not caught by explicit rules]
```

### Machine-Readable Block

Append at the very end — exact format, no markdown, no extra whitespace:

```
---PROCESS-CHECK-DATA---
STATUS: PASS
TOOLS: process-checker.sh
RULES: 1,2,3,4,5
---END-PROCESS-CHECK-DATA---
```

- `STATUS`: exactly `PASS` or `FAIL` (uppercase)
- `TOOLS`: comma-separated script filenames run, or `none`
- `RULES`: comma-separated rule numbers from validation-spec that were checked

---

## 4. Rules

1. **Never fix artifacts** — validate and report only; recommendations go in the report
2. **All rules must be checked** — no skipping, even for skills with many rules
3. **Do not carry context from previous validation runs** — each run is independent
4. **A script failure is a hard fail** — script exit code ≠ 0 overrides human-readable findings

---

## 5. State Write Responsibilities

| Outcome | Transition |
|---|---|
| All checks pass | `validation:pending → validation:pass` |
| Any check fails | `validation:pending → validation:fail` |

Does NOT write any other state transitions.
