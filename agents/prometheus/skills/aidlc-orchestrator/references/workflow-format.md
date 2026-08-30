# Workflow File Format

`workflow.md` in the intent directory. One skill invocation per line.

## Syntax

```
<skill-name> <input-file-1> [<input-file-2> ...]
```

### --unit flag (construction per-unit skills)

```
<skill-name> --unit <unit-name> <input-file-1> [...]
```

- Artifacts write to `construction/<unit-name>/<skill-name>/`
- State key becomes `<skill-name>:<unit-name>`

### --scope flag (same skill, multiple instances)

```
<skill-name> --scope <scope-name> <input-file-1> [...]
```

- Artifacts write to `inception/<skill-name>/<scope-name>/`
- State key becomes `<skill-name>:<scope-name>`
- `--scope` is mandatory for `reverse-engineering` even with a single repo

### --phase flag (non-inception, non-unit skills)

```
<skill-name> --phase <phase-name> <input-file-1> [...]
```

- Artifacts write to `<phase-name>/<skill-name>/`
- Use for `operations` skills

`--unit`, `--scope`, and `--phase` are mutually exclusive. `--unit` implies construction.

## Bootstrap Skills Not in workflow.md

`intent-bootstrap` and `workflow-composition` run via the orchestrator's bootstrap pre-loop
and are never present in `workflow.md`:

- `intent-bootstrap` creates `workflow.md` with a single `workflow-composition` stub line
- `workflow-composition` rewrites `workflow.md` with chosen downstream skills

By the time the standard skill loop starts, only downstream skills appear in `workflow.md`.

## Format Rules

- Lines starting with `#` are comments
- Empty lines are ignored
- No markdown tables, no extra formatting
- File must be named `workflow.md`

## Example

```
# Inception phase
reverse-engineering --scope payments-api org-ai-kb/aidlc-docs/intent-001-payment-service/intent.md
requirements-analysis org-ai-kb/aidlc-docs/intent-001-payment-service/intent.md
user-stories org-ai-kb/aidlc-docs/intent-001-payment-service/inception/requirements-analysis/requirements.md
application-design org-ai-kb/aidlc-docs/intent-001-payment-service/inception/requirements-analysis/requirements.md org-ai-kb/aidlc-docs/intent-001-payment-service/inception/user-stories/stories.md

# Construction phase
functional-design --unit payment-processor org-ai-kb/aidlc-docs/intent-001-payment-service/inception/units-generation/units-of-work.md
nfr-assessment --unit payment-processor org-ai-kb/aidlc-docs/intent-001-payment-service/construction/payment-processor/functional-design/business-logic-model.md
nfr-design --unit payment-processor org-ai-kb/aidlc-docs/intent-001-payment-service/construction/payment-processor/nfr-assessment/nfr-requirements.md
code-generation --unit payment-processor org-ai-kb/aidlc-docs/intent-001-payment-service/construction/payment-processor/functional-design/business-logic-model.md
build-and-test --phase construction org-ai-kb/aidlc-docs/intent-001-payment-service/intent.md
```
