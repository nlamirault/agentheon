---
name: rfc-manager
description: This skill should be used when the user asks to "create an RFC", "generate an RFC template", "list RFCs", "update an RFC", or "manage Request for Comments".
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

# RFC Manager Skill

This skill provides comprehensive tools and guidance for managing Requests for Comments (RFCs) within your project. It
supports the entire lifecycle of an RFC, from creation and templating to listing and updating existing RFCs.

## Purpose

The primary purpose of this skill is to streamline the process of proposing, discussing, and documenting significant
technical decisions and changes through RFCs. It ensures consistency in RFC structure and facilitates easy access and
modification.

## Conventions

RFCs follow strict conventions to ensure consistency and traceability. See `references/conventions.md` for the full
reference.

Key rules:

- All RFCs live in `docs/rfc/` at the repository root.
- Filenames follow the pattern `{000}-{kebab-case-title}.md` (e.g., `001-api-gateway-redesign.md`).
- Numbers are sequential and zero-padded to three digits.
- One RFC per proposal — an RFC captures a single change or decision requiring broader discussion.

## When to Use This Skill

Use this skill whenever you need to:

- Propose a new technical change or decision that requires broader discussion.
- Generate a standard RFC Markdown template to start a new proposal.
- View a list of existing RFCs in the project.
- Modify or update the content or status of an existing RFC.

## How to Use This Skill

### Listing RFCs

Use `Glob` to scan `docs/rfc/*.md` and present a table of existing RFCs with their number, title, and status (read from
frontmatter).

Example: "List all RFCs."

### Creating a New RFC

1. Use `Glob` on `docs/rfc/*.md` to find the highest existing RFC number.
2. Increment by one and zero-pad to three digits.
3. Convert the title to kebab-case for the filename.
4. Instantiate `references/rfc-template.md`, filling in `rfc`, `date` (today's date), and the title.
5. Write the file to `docs/rfc/{number}-{kebab-title}.md` using the `Write` tool.

Example: "Create a new RFC titled 'Proposed API Gateway Changes'."

### Updating an Existing RFC

1. Locate the target RFC file using `Glob` or `Read`.
2. Apply the requested changes using the `Edit` tool.
3. When marking an RFC as `🚀 Implemented`, fill in the `## Outcomes` section with links to the resulting tickets or
   pull requests.
4. When marking as `🪦 Obsolete`, add a note explaining what superseded it.

Example: "Update RFC 001 with the new status 'Approved'."

### Generating a Standalone Template

Return the contents of `references/rfc-template.md` for the user to fill out manually.

Example: "Generate a new RFC template."

## Status Lifecycle

| Status      | Emoji | Meaning                               |
| ----------- | ----- | ------------------------------------- |
| Draft       | 📝    | Initial proposal, still being written |
| In Review   | 👀    | Open for team discussion and feedback |
| Approved    | ✅    | Accepted and ready for implementation |
| Implemented | 🚀    | Fully delivered; outcomes recorded    |
| Rejected    | 🚫    | Evaluated but not adopted             |
| Obsolete    | 🪦    | Superseded or no longer relevant      |

Valid transitions: Draft → In Review → Approved → Implemented, In Review → Rejected, any active state → Obsolete.

## Additional Resources

- `references/rfc-template.md` — Standard RFC Markdown template
- `references/conventions.md` — Naming, numbering, directory structure, and lifecycle rules
