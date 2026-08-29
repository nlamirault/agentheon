---
name: "database-generic-sql"
description: "Use this skill when writing, reviewing, or optimizing SQL queries, database schemas, indexes, or data models — regardless of the database engine. Trigger when the user writes any SQL, asks about query performance, schema design, joins, transactions, or normalization — even if they don't ask for 'best practices'."
license: Apache-2.0
metadata:
  author: nlamirault
  version: "1.1.0"
  service:
  - sql
  task: [configure, debug, audit]
  persona: [developer, data-engineer]
  workload: [data]
---

# Generic SQL Best Practices

## Readability & Formatting

- Use consistent casing for keywords (UPPERCASE often preferred: `SELECT`, `FROM`, `WHERE`).
- Use consistent casing for identifiers (lowercase `snake_case` often preferred: `user_id`, `order_details`).
- Indent clauses (`FROM`, `WHERE`, `GROUP BY`, `ORDER BY`) for clarity.
- Use comments (`--` or `/* ... */`) to explain complex logic.

## Explicit Column Listing

- Avoid `SELECT *`. Explicitly list the columns needed to improve clarity, performance, and resilience to schema
  changes.

## Meaningful Aliases

- Use clear and concise aliases for tables (`FROM users u`) and columns (`SELECT count(*) AS total_users`).

## WHERE Clause Effectiveness

- Place filtering conditions in the `WHERE` clause, not in `JOIN ON` clauses where possible (unless it's outer join
  logic).
- Ensure `WHERE` clauses can leverage indexes where appropriate (Sargable queries).

## JOINs

- Prefer ANSI standard `JOIN` syntax (`INNER JOIN`, `LEFT JOIN`) over older comma-based syntax.
- Be explicit with `INNER JOIN` vs. `OUTER JOIN` (`LEFT`, `RIGHT`, `FULL`).

## Data Types

Use the most appropriate and specific data types for columns (e.g., `INT` vs `VARCHAR` for numbers, `DATE`/`TIMESTAMP`
vs `VARCHAR` for dates).

## Indexing

- Understand and create appropriate indexes (e.g., on foreign keys, columns frequently used in `WHERE`, `JOIN`,
  `ORDER BY`) to optimize query performance. Avoid over-indexing.

## Normalization

- Understand database normalization principles (1NF, 2NF, 3NF) and apply them appropriately to avoid data redundancy and
  anomalies. Denormalize cautiously for performance reasons when necessary.

## Transaction Management

- Use transactions (`BEGIN`, `COMMIT`, `ROLLBACK`) to ensure atomicity for operations involving multiple DML statements.

## Avoid Vendor Lock-in

- Stick to standard SQL functions and syntax where possible if portability is a concern. If using vendor-specific
  features, be aware of the trade-offs.

## Security

- Use parameterized queries or prepared statements in application code to prevent SQL injection.
- Grant least privilege to database users.

## Reference Files

### Query Patterns

@references/query-patterns.md NULL handling, aggregation patterns, JOIN types (including anti-joins), keyset pagination,
date/time patterns, and common performance anti-patterns with indexed columns.

## Gotchas

- **`NOT IN` with a subquery that returns any NULLs always returns an empty set.**
  `WHERE id NOT IN (SELECT user_id FROM ...)` silently returns no rows if `user_id` can be NULL. Use `NOT EXISTS`
  instead, which handles NULLs correctly.
- **`BETWEEN` is inclusive on both ends.** `WHERE created_at BETWEEN '2024-01-01' AND '2024-01-31'` includes records at
  exactly `2024-01-31 00:00:00`. For date ranges, use `>= start AND < next_day` to avoid off-by-one errors.
- **Implicit type coercions in `WHERE` clauses silently bypass indexes.** `WHERE id = '123'` on an integer `id` column
  forces a cast on every row, making a full table scan even with a perfect index. Ensure parameter types match column
  types.
- **`UPDATE` or `DELETE` without a `WHERE` clause affects every row.** There is no undo in most contexts. Always write
  and test the `SELECT` version of the condition first, then convert to `UPDATE`/`DELETE`.
- **Storing timestamps in local time zones causes bugs around DST transitions.** Always store in UTC, convert to the
  user's timezone only at display time.
- **`GROUP BY` with non-aggregate columns behaves differently across vendors.** MySQL historically allowed selecting
  non-aggregated columns not in `GROUP BY` (returning arbitrary values). PostgreSQL and SQLite reject this. Write
  queries that are explicit about which columns are grouped.

## Restrictions

- You have no power or authority to make any database changes, or install globally available scripts/apps
