# PostgreSQL Query Patterns

## Index Usage Patterns

### When Indexes Are Ignored (and Why)

An index exists but the query doesn't use it — common causes:

```sql
-- ❌ Wrapping the column in a function defeats B-tree index
WHERE lower(email) = 'user@example.com'
-- ✅ Use an expression index instead
CREATE INDEX idx_users_email_lower ON users (lower(email));

-- ❌ Leading wildcard prevents B-tree prefix scan
WHERE name LIKE '%smith'
-- ✅ Use pg_trgm extension + GIN index for arbitrary substring search
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_users_name_trgm ON users USING gin (name gin_trgm_ops);

-- ❌ Implicit type cast between VARCHAR column and integer literal
WHERE user_id = 123  -- user_id is VARCHAR
-- ✅ Match the literal type to the column type
WHERE user_id = '123'
```

### Covering Indexes (Index-Only Scans)

Include all columns the query needs directly in the index to avoid heap access:

```sql
-- Query: SELECT email, created_at FROM users WHERE status = 'active' ORDER BY created_at
CREATE INDEX idx_users_active ON users (status, created_at) INCLUDE (email);
-- The INCLUDE columns aren't part of the sort key but are stored in the index leaf pages
```

### Partial Indexes

Index only a subset of rows to keep the index small and fast:

```sql
-- Only index unprocessed jobs (usually a small fraction of the table)
CREATE INDEX idx_jobs_pending ON jobs (created_at) WHERE status = 'pending';

-- Index non-deleted records only
CREATE INDEX idx_users_active ON users (email) WHERE deleted_at IS NULL;
```

## JSONB Query Patterns

```sql
-- Check if a key exists
WHERE data ? 'config_key'

-- Check if object contains a sub-object
WHERE data @> '{"role": "admin"}'::jsonb

-- Extract and filter on a nested value (uses GIN index if present)
WHERE data ->> 'status' = 'active'

-- Array containment
WHERE tags @> '["urgent"]'::jsonb

-- Index for arbitrary key existence and containment queries
CREATE INDEX idx_data_gin ON events USING gin (data);

-- Index for a specific frequently-queried path (more selective)
CREATE INDEX idx_data_status ON events ((data->>'status'));
```

## Window Functions for Common Analytical Patterns

```sql
-- Latest record per group (no subquery needed)
SELECT DISTINCT ON (user_id) user_id, event_type, created_at
FROM events
ORDER BY user_id, created_at DESC;

-- Or with window function (works in subquery, CTE, or view)
SELECT * FROM (
  SELECT *, row_number() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
  FROM events
) t WHERE rn = 1;

-- Running total
SELECT date, amount, sum(amount) OVER (ORDER BY date) AS cumulative
FROM daily_revenue;

-- Percentage of total
SELECT category, revenue,
  revenue / sum(revenue) OVER () * 100 AS pct_of_total
FROM category_revenue;

-- Lag/lead for period-over-period comparison
SELECT date, revenue,
  lag(revenue, 7) OVER (ORDER BY date) AS revenue_7d_ago,
  revenue - lag(revenue, 7) OVER (ORDER BY date) AS delta_7d
FROM daily_revenue;
```

## CTEs: Materialized vs. Not

Since PostgreSQL 12, CTEs are **not materialized by default** (the planner can inline them). For recursive CTEs or when
you want to force materialization as an optimization fence:

```sql
-- Force materialization (useful to prevent re-evaluation of expensive subquery)
WITH expensive_subquery AS MATERIALIZED (
  SELECT ... FROM large_table WHERE ...
)
SELECT * FROM expensive_subquery JOIN ...;

-- Recursive CTE for hierarchical data
WITH RECURSIVE subordinates AS (
  SELECT id, manager_id, name FROM employees WHERE id = :root_id
  UNION ALL
  SELECT e.id, e.manager_id, e.name
  FROM employees e
  JOIN subordinates s ON e.manager_id = s.id
)
SELECT * FROM subordinates;
```

## Upsert Patterns

```sql
-- Insert or update (upsert) on conflict
INSERT INTO user_stats (user_id, login_count, last_login)
VALUES ($1, 1, now())
ON CONFLICT (user_id) DO UPDATE
  SET login_count = user_stats.login_count + 1,
      last_login = now();

-- Insert if not exists, do nothing on conflict
INSERT INTO tags (name) VALUES ($1)
ON CONFLICT (name) DO NOTHING
RETURNING id;
```

## Bulk Operations

```sql
-- Bulk insert with COPY (fastest for large datasets)
COPY users (name, email, created_at) FROM '/path/to/file.csv' CSV HEADER;

-- Or from application: use COPY with stdin (psycopg2 copy_from / asyncpg copy_records_to_table)

-- Bulk update via JOIN
UPDATE orders o
SET status = 'shipped', shipped_at = now()
FROM (VALUES (1, 'order-001'), (2, 'order-002')) AS updates(id, order_ref)
WHERE o.id = updates.id;

-- Delete with returning (for audit log)
DELETE FROM sessions WHERE expires_at < now()
RETURNING user_id, session_token, created_at;
```
