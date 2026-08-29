---
name: adr-manager
description: "This skill should be used when the user asks to 'create an ADR', 'generate an ADR template', 'list ADRs', 'update an ADR', or 'manage Architectural Decision Records'. It helps in managing the complete lifecycle of ADRs."
license: Apache-2.0
allowed-tools: Read Write Edit Glob
metadata:
  author: nlamirault
  version: "1.0.0"
  service:
  - markdown
  - github
  task: [document, configure]
  persona: [developer, technical-writer]
  workload: [documentation]
---

# ADR Manager Skill

This skill provides comprehensive tools and guidance for managing Architectural Decision Records (ADRs) within your
project. It supports the entire lifecycle of an ADR, from creation and templating to listing and updating existing ADRs.

## Purpose

The primary purpose of this skill is to streamline the process of documenting significant architectural and technical
decisions with proper context, rationale, and consequences. It ensures consistency in ADR structure and facilitates easy
access and modification.

## Conventions

ADRs follow strict conventions to ensure consistency and traceability. See `references/conventions.md` for the full
reference.

Key rules:

- All ADRs live in `docs/adr/` at the repository root.
- Filenames follow the pattern `{0000}-{kebab-case-title}.md` (e.g., `0001-adopt-postgresql.md`).
- Numbers are sequential and zero-padded to four digits.
- One ADR per decision — ADRs are immutable once accepted; use "Superseded" status with a reference to the new ADR for
  changes.

## When to Use This Skill

Use this skill whenever you need to:

- Document a new architectural or significant technical decision.
- Generate a standard ADR Markdown template to start a new record.
- View a list of existing ADRs in the project.
- Modify or update the content or status of an existing ADR.

## How to Use This Skill

### Listing ADRs

Use `Glob` to scan `docs/adr/*.md` and present a table of existing ADRs with their number, title, and status (read from
frontmatter).

Example: "List all ADRs."

### Creating a New ADR

1. Use `Glob` on `docs/adr/*.md` to find the highest existing ADR number.
2. Increment by one and zero-pad to four digits.
3. Convert the title to kebab-case for the filename.
4. Instantiate `references/adr-template.md`, filling in `adr`, `date` (today's date), and the title.
5. Write the file to `docs/adr/{number}-{kebab-title}.md` using the `Write` tool.

Example: "Create a new ADR titled 'Decision to Adopt Microservices'."

### Updating an Existing ADR

1. Locate the target ADR file using `Glob` or `Read`.
2. Apply the requested changes using the `Edit` tool.
3. When superseding an ADR, also update the old ADR's status to `⌛️ Superseded` and add a "Superseded by" note
   referencing the new ADR number.

Example: "Update ADR 001 with the new status 'Accepted'."

### Generating a Standalone Template

Return the contents of `references/adr-template.md` for the user to fill out manually.

Example: "Generate a new ADR template."

## Status Lifecycle

| Status     | Emoji | Meaning                                 |
| ---------- | ----- | --------------------------------------- |
| Draft      | 📝    | Work-in-progress, not ready for review  |
| Proposed   | 🤔    | Under discussion, not yet decided       |
| Accepted   | ✅    | Decision made and in effect             |
| Rejected   | 🚫    | Evaluated but not adopted               |
| Superseded | ⌛️    | Replaced by a newer ADR                 |
| Deprecated | 🪦    | No longer relevant, kept for history    |

Valid transitions: Draft → Proposed, Proposed → Accepted, Proposed → Rejected, Accepted → Superseded, Accepted → Deprecated.

## Additional Resources

- `references/adr-template.md` — Standard ADR Markdown template
- `references/conventions.md` — Naming, numbering, directory structure, and lifecycle rules
