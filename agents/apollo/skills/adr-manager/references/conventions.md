# ADR Conventions

## Directory Structure

All ADRs must be stored under `docs/adr/` at the repository root:

```text
docs/
└── adr/
    ├── 0001-adopt-postgresql.md
    ├── 0002-use-event-sourcing.md
    └── 0003-migrate-to-kubernetes.md
```

## Filename Format

```text
{number}-{kebab-case-title}.md
```

- `number` — zero-padded, four-digit sequential integer (e.g., `0001`, `0042`)
- `kebab-case-title` — lowercase, words separated by hyphens, derived from the ADR title

Examples:

- `0001-adopt-microservices.md`
- `0012-replace-rabbitmq-with-kafka.md`

## Numbering

- Numbers are assigned sequentially at creation time.
- To find the next number: scan `docs/adr/*.md`, extract the numeric prefix from each filename, take the maximum, and
  add one.
- Numbers are never reused, even if an ADR is rejected or deprecated.

## Immutability

- ADRs are immutable once their status is **Accepted**.
- To revise an accepted decision, create a **new ADR** that supersedes the old one.
- Update the old ADR's `status` frontmatter field to `⌛️ Superseded` and add a "Superseded by ADR-{number}" note in the
  body.

## Status Values

| Status     | Emoji | When to Use                                       |
| ---------- | ----- | ------------------------------------------------- |
| Draft      | 📝    | Work-in-progress, not ready for team review       |
| Proposed   | 🤔    | Under discussion, decision not yet made           |
| Accepted   | ✅    | Decision made and actively in effect              |
| Rejected   | 🚫    | Considered but not adopted                        |
| Superseded | ⌛️    | Replaced by a newer ADR                           |
| Deprecated | 🪦    | No longer relevant; kept for historical reference |

### Valid Transitions

```text
Draft → Proposed
Proposed → Accepted
Proposed → Rejected
Accepted → Superseded
Accepted → Deprecated
```

## Frontmatter Fields

| Field          | Required | Description                                    |
| -------------- | -------- | ---------------------------------------------- |
| `adr`          | Yes      | ADR number (integer)                           |
| `status`       | Yes      | `<emoji> <StatusLabel>` (e.g., `🤔 Proposed`)  |
| `date`         | Yes      | ISO-8601 date of decision (e.g., `2026-02-24`) |
| `deciders`     | Yes      | Usernames or names of decision-makers          |
| `consulted`    | No       | People consulted but not decision-makers       |
| `informed`     | No       | People informed after the decision             |
| `spdx-license` | Yes      | SPDX license identifier (e.g., `Apache-2.0`)   |

## Best Practices

- One ADR per decision — do not bundle multiple decisions in a single ADR.
- Write in plain language understandable by future team members unfamiliar with the context.
- Always fill in the `Context` section — future readers need to understand the problem space, not just the solution.
- List at least two considered options even if one is obviously preferred.
- Link to relevant tickets, RFCs, or discussions in the `References` section.
