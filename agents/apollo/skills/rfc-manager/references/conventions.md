# RFC Conventions

## Directory Structure

All RFCs must be stored under `docs/rfc/` at the repository root:

```text
docs/
└── rfc/
    ├── 001-api-gateway-redesign.md
    ├── 002-event-sourcing-adoption.md
    └── 003-replace-rabbitmq-with-kafka.md
```

## Filename Format

```text
{number}-{kebab-case-title}.md
```

- `number` — zero-padded, three-digit sequential integer (e.g., `001`, `042`)
- `kebab-case-title` — lowercase, words separated by hyphens, derived from the RFC title

Examples:

- `001-api-gateway-redesign.md`
- `012-migrate-auth-to-oauth2.md`

## Numbering

- Numbers are assigned sequentially at creation time.
- To find the next number: scan `docs/rfc/*.md`, extract the numeric prefix from each filename, take the maximum, and
  add one.
- Numbers are never reused, even if an RFC is rejected or obsolete.

## Status Values

| Status      | Emoji | When to Use                                      |
| ----------- | ----- | ------------------------------------------------ |
| Draft       | 📝    | Initial proposal, still being written or refined |
| In Review   | 👀    | Open for team discussion and feedback            |
| Approved    | ✅    | Decision made; ready for implementation          |
| Implemented | 🚀    | Fully delivered; outcomes section filled in      |
| Rejected    | 🚫    | Evaluated but not adopted                        |
| Obsolete    | 🪦    | Superseded or no longer relevant                 |

### Valid Transitions

```text
Draft → In Review
In Review → Approved
In Review → Rejected
Approved → Implemented
Approved → Obsolete
any active state → Obsolete
```

## Frontmatter Fields

| Field          | Required | Description                                  |
| -------------- | -------- | -------------------------------------------- |
| `rfc`          | Yes      | RFC number (integer)                         |
| `title`        | Yes      | Short descriptive title                      |
| `status`       | Yes      | `<emoji> <StatusLabel>` (e.g., `📝 Draft`)   |
| `date`         | Yes      | ISO-8601 creation date (e.g., `2026-02-24`)  |
| `authors`      | Yes      | Usernames or names of the proposal authors   |
| `consulted`    | No       | People consulted during drafting             |
| `informed`     | No       | People to notify once the RFC is decided     |
| `spdx-license` | Yes      | SPDX license identifier (e.g., `Apache-2.0`) |

## RFC vs ADR

RFCs and ADRs serve different purposes and should not be confused:

|                  | RFC                                      | ADR                                  |
| ---------------- | ---------------------------------------- | ------------------------------------ |
| **Purpose**      | Propose and discuss a significant change | Record a decision that has been made |
| **When written** | Before the decision, to gather input     | After the decision, to document it   |
| **Audience**     | Broad team discussion                    | Future readers needing context       |
| **Lifecycle**    | Draft → In Review → Approved/Rejected    | Proposed → Accepted/Rejected         |
| **Directory**    | `docs/rfc/`                              | `docs/adr/`                          |

An RFC often precedes and motivates an ADR: once an RFC is Approved, an ADR can be written to record the resulting
architectural decision.

## Best Practices

- One RFC per proposal — do not bundle unrelated changes.
- Keep the Summary section short enough to read in under a minute.
- Fill in the Motivation section before soliciting review — reviewers need to understand the problem before evaluating
  the solution.
- Always document alternatives considered, even if they were quickly dismissed.
- Fill in the Outcomes section once the RFC reaches Implemented or Rejected status.
- Link to the resulting ADR (if any) in the References section.
