# Open Knowledge Format (OKF) Specification v0.1

## 1. Introduction
OKF is a portable, vendor-neutral specification for representing knowledge as a directory of Markdown files with YAML frontmatter.

## 2. Structure
A "bundle" is a directory containing:
- Concept files (`.md` with frontmatter)
- Directory indexes (`index.md`)
- A change log (`log.md`)

## 3. Concepts
A concept is a single unit of knowledge.
- File naming: `concept-name.md` (kebab-case recommended).
- Identity: The path relative to the bundle root (e.g., `/tables/users.md`).

## 4. Frontmatter
Every concept file MUST start with a YAML block.
- `type`: (Required) Category of the concept (e.g., `Table`, `Service`).
- `title`: (Recommended) Human-readable name.
- `description`: (Recommended) Brief summary.
- `resource`: (Optional) Canonical URI (e.g., database URL).
- `tags`: (Optional) List of keywords.
- `timestamp`: (Recommended) Last update in ISO 8601.

## 5. Body
The Markdown body should contain detailed information, schemas, or logic.
- Use standard Markdown headings.
- Cross-link using `[text](path/to/concept.md)`.

## 6. Reserved Files
- `index.md`: Provides a listing of concepts in a directory.
- `log.md`: Chronological history of changes, newest first.

## 7. Versioning
The bundle root `index.md` may include `okf_version: "0.1"` in its frontmatter.
