---
name: okf
description: >-
  Author, maintain, and consume Open Knowledge Format (OKF) knowledge bundles —
  portable markdown + YAML frontmatter for human-agent collaboration.
  Use when documenting project knowledge (services, APIs, schemas, metrics, runbooks, decisions),
  updating existing bundles, or consuming knowledge from an `.okf/` directory.
  Trigger on: "document this in OKF", "create an OKF bundle", "update the knowledge bundle",
  "capture this as a concept", or when navigating a codebase with an `.okf` folder.
---

# Open Knowledge Format (OKF)

OKF represents knowledge as a directory of markdown files with YAML frontmatter.
It is designed to be minimal, portable, and easily readable by both humans and AI agents.

## Core Rules

1. **One Concept = One File**: Each concept (e.g., a table, a service, a metric) lives in its own `.md` file. The file path is its ID.
2. **Required Frontmatter**: Every concept file MUST have a YAML frontmatter block with a `type` field.
3. **Reserved Files**:
   - `index.md`: Directory listing for progressive disclosure.
   - `log.md`: Chronological change history (newest first).
4. **Links**: Use standard Markdown links for relationships (e.g., `[Auth Service](/services/auth.md)`).

## Workflow

### 1. Produce (Create or Extend)
- **Identify Source**: Extract knowledge from code, READMEs, or docs.
- **Layout**: Organize by domain (e.g., `services/`, `data/`, `decisions/`).
- **Write**: Use the concept template. Set `type`, `title`, and `description`.
- **Index**: Add entries to the relevant `index.md`.
- **Log**: Append a dated entry to `log.md`.

### 2. Maintain (Update)
- **Sync**: Keep concepts updated as the project evolves.
- **Timestamp**: Update the `timestamp` field in frontmatter.
- **Deprecation**: Mark removed items as `**Deprecation**` in `log.md` instead of deleting them immediately.

### 3. Consume (Read)
- **Entry Point**: Start with the root `index.md`.
- **Follow Links**: Navigate the bundle to gather context for your task.

## Validation
Always validate your bundle before finishing:
```bash
python scripts/okf_validate.py .okf/
```

## Resources
- **Specification**: [references/SPEC.md](references/SPEC.md)
- **Templates**:
  - [templates/concept.md](templates/concept.md)
  - [templates/index.md](templates/index.md)
  - [templates/log.md](templates/log.md)
