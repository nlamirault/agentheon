---
name: "database-postgresql"
description: "Use this skill when working with PostgreSQL — writing queries, designing schemas, debugging slow queries, using advanced features like JSONB, CTEs, window functions, partitioning, or setting up replication. Trigger when the user mentions 'postgres', 'pg', 'psql', RDS PostgreSQL, or any PostgreSQL-specific concept."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - postgresql
  task: [configure, debug, audit]
  persona: [developer, data-engineer]
  workload: [data]
---

# PostgreSQL / Best Practices

## Guiding Principles (Extends Generic SQL)

- **Leverage Data Types:** Utilize PostgreSQL's rich data types (e.g., `JSONB`, `ARRAY`, `UUID`, `INET`, geometric
  types, range types) where appropriate.
- **Indexing:**
  - Use standard B-tree indexes for most cases.
  - Consider specialized index types: `GIN` (for `JSONB`, `ARRAY`, full-text), `GiST` (geometric, full-text), `BRIN`
    (for large, physically ordered tables).
  - Use partial indexes (`CREATE INDEX ... WHERE ...`) for subsets of data.
  - Use expression indexes (`CREATE INDEX ... ON ... (lower(column))`) for case-insensitive or function-based lookups.
- **Window Functions:** Use powerful window functions (`OVER (...)`) for complex analytical queries, avoiding self-joins
  or complex subqueries where possible.
- **Common Table Expressions (CTEs):** Use `WITH` clauses (CTEs) to break down complex queries into logical, readable
  steps. Use `WITH RECURSIVE` for hierarchical or graph traversal.
- **Transactions:** Understand transaction isolation levels (`READ COMMITTED` default). Use advisory locks
  (`pg_advisory_lock`) for application-level locking if needed.
- **Stored Procedures/Functions (PL/pgSQL):** Use functions (`CREATE FUNCTION ... LANGUAGE plpgsql`) for encapsulating
  reusable logic on the database server. Be mindful of performance implications.
- **Partitioning:** Use declarative partitioning for very large tables based on ranges or lists to improve manageability
  and query performance.
- **JSONB Operations:** Utilize efficient `JSONB` operators (`@>`, `?`, `->`, `->>`) for querying JSON data.
- **EXPLAIN ANALYZE:** Use `EXPLAIN ANALYZE` extensively to understand query plans and identify performance bottlenecks.
- **Vacuuming & Statistics:** Understand the importance of `VACUUM` (especially autovacuum) and `ANALYZE` for
  maintaining performance and accurate query planning.

## Reference Files

For deeper topics, read the relevant reference file:

### Query Patterns

@references/query-patterns.md Index usage, covering indexes, partial indexes, JSONB queries, window functions, CTEs
(materialized/not), upsert patterns, and bulk operations.

### Performance

@references/performance.md EXPLAIN analysis, key configuration parameters (shared_buffers, work_mem), PgBouncer
connection pooling, autovacuum tuning, index bloat, lock monitoring, and table partitioning.

## Gotchas

- **`VACUUM FULL` locks the table exclusively for its entire duration.** It's meant for reclaiming disk space after
  massive deletes, but it prevents all reads and writes. Use `pg_repack` on production tables to reclaim space without
  blocking.
- **`SERIAL` is legacy — prefer `GENERATED ALWAYS AS IDENTITY`.** `SERIAL` creates a sequence with implicit ownership
  that can get out of sync with the column. `GENERATED ALWAYS AS IDENTITY` (SQL standard) is cleaner and doesn't have
  the same pitfalls.
- **`TRUNCATE` does not fire row-level triggers; `DELETE` does.** If you have triggers for audit logging or cascading
  cleanup, `TRUNCATE` will silently skip them.
- **`EXPLAIN` without `ANALYZE` does not execute the query.** The plan it shows uses estimated row counts which can be
  wildly inaccurate. Always use `EXPLAIN (ANALYZE, BUFFERS)` to see actual runtime behavior.
- **Unlogged tables lose all data on a crash or unclean shutdown.** They're faster because they skip WAL, but they're
  truncated on recovery. Never use them for anything that can't be trivially rebuilt.
- **`pg_dump` without `--no-owner` ties the dump to the original role name.** Restoring on a different host with a
  different superuser role will fail with `role does not exist` errors.
- **Connection limits are shared with superuser reserved connections.** If `max_connections = 100` and a connection
  storm fills all 100, superusers can't connect to investigate. Always set `max_connections` with headroom and use a
  connection pooler (PgBouncer) in production.
