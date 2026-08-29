---
name: "database-sqlite"
description: "Use this skill when working with SQLite — embedded databases, mobile app storage, local development databases, test fixtures, or migrating from SQLite to another engine. Trigger when the user mentions SQLite, a .db or .sqlite file, serverless/embedded databases, or asks about WAL mode, PRAGMA settings, or FTS."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - sqlite
  task: [configure, debug]
  persona: [developer, data-engineer]
  workload: [data]
---

# SQLite / Best Practices

## Guiding Principles (Extends Generic SQL)

- **Simplicity:** Leverage SQLite's simplicity. It's serverless, file-based, and transactional.
- **Typelessness (Type Affinity):** Understand SQLite's type affinity. Columns accept most data types, but prefer
  declared types (`INTEGER`, `REAL`, `TEXT`, `BLOB`, `NUMERIC`) for clarity and potential affinity behavior. Use
  `STRICT` tables (SQLite 3.37.0+) to enforce data types.
- **Primary Keys:** Prefer `INTEGER PRIMARY KEY` (typically auto-incrementing, alias for `rowid`) for simple unique row
  identifiers unless a natural key exists.
- **Indexing:** Create indexes (`CREATE INDEX`) on columns used in `WHERE` clauses and `ORDER BY` for performance.
  SQLite automatically indexes primary keys and `UNIQUE` constraints.
- **Transactions:** Use transactions (`BEGIN`, `COMMIT`, `ROLLBACK`) explicitly, especially for multiple writes, to
  ensure atomicity and improve performance (reduces disk I/O per statement).
- **WAL Mode:** Consider enabling Write-Ahead Logging (`PRAGMA journal_mode=WAL;`) for better concurrency (readers don't
  block writers, writers don't block readers).
- **Prepared Statements:** Use prepared statements (parameter binding `?`) in application code to prevent SQL injection
  and improve performance (avoids re-parsing SQL).
- **PRAGMA Statements:** Use `PRAGMA` commands to configure SQLite behavior (e.g., `journal_mode`, `synchronous`,
  `foreign_keys`, `optimize`).
- **Foreign Keys:** Enable foreign key constraints (`PRAGMA foreign_keys = ON;`) per connection if needed, as they are
  off by default.
- **Full-Text Search (FTS):** Utilize built-in FTS extensions (FTS3/4, FTS5) for efficient text searching by creating
  virtual tables.
- **Generated Columns:** Use generated columns (`GENERATED ALWAYS AS ... STORED/VIRTUAL`) for derived data (SQLite
  3.31.0+).

## Reference Files

### PRAGMA Reference

@references/pragmas.md All essential PRAGMAs with explanations: foreign keys, WAL mode, cache size, synchronous level,
auto_vacuum, maintenance commands, and WAL file behavior.

## Gotchas

- **`AUTOINCREMENT` is almost never what you want.** It prevents rowid reuse after deletions but adds overhead and a
  separate `sqlite_sequence` table lookup on every insert. The plain `INTEGER PRIMARY KEY` alias for `rowid`
  auto-increments without this overhead and is sufficient for 99% of use cases.
- **SQLite locks the entire database file on writes.** Concurrent writers will receive `SQLITE_BUSY` or wait until a
  timeout. WAL mode improves this (readers don't block writers and vice versa), but it does not enable true concurrent
  writes.
- **`PRAGMA foreign_keys = ON` must be set on every connection, every time.** Foreign key enforcement is off by default
  and resets when the connection closes. An ORM or connection pool that doesn't set this pragma will silently allow
  orphaned records.
- **Never use `REAL` for monetary values.** IEEE 754 floating point cannot represent most decimal fractions exactly.
  Store currency as `INTEGER` (e.g., cents) or `TEXT` (with a decimal string) instead.
- **WAL files persist on disk when a reader holds an open connection during shutdown.** The `-wal` and `-shm` files are
  not cleaned up until a checkpoint completes. Applications that don't close connections gracefully will leave these
  files behind, and other tools that open the database directly may see stale state.
- **Date and time have no native type in SQLite.** Using `TEXT`, `INTEGER`, or `REAL` for dates is all valid, but mixing
  conventions within a schema causes silent comparison bugs. Standardize on ISO 8601 `TEXT` or Unix epoch `INTEGER` and
  document the choice.
