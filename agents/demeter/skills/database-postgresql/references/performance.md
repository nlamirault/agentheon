# PostgreSQL Performance

## Query Analysis Workflow

Always use `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` to diagnose slow queries:

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT ...;
```

Key things to look for in the plan:

| Signal | What It Means |
|--------|---------------|
| `Seq Scan` on large table | Missing index, or planner chose not to use one — check filter selectivity |
| High `rows=X` estimate vs. actual rows | Stale statistics — run `ANALYZE table_name` |
| `Hash Join` with large `Batches` > 1 | `work_mem` too low, spilling to disk |
| `Sort` with `Sort Method: external merge` | Disk sort due to low `work_mem` |
| High `Buffers: shared hit/read` ratio < 80% | Low `shared_buffers` or infrequently cached data |
| `Nested Loop` on large outer table | Missing index on inner table's join column |

## Key Configuration Parameters

These are the most impactful parameters. All require PostgreSQL restart unless noted.

```sql
-- shared_buffers: PostgreSQL's buffer pool (no restart needed in some setups)
-- Rule of thumb: 25% of total RAM
shared_buffers = '4GB'

-- work_mem: per-sort/per-hash operation (set per session for heavy analytic queries)
-- Too low = disk sorts. Too high = OOM under concurrent load. Start at 64MB.
work_mem = '64MB'
-- SET work_mem = '256MB'; -- for a specific heavy analytics session

-- effective_cache_size: tells the planner how much RAM is available for caching
-- (OS page cache + shared_buffers). Affects index vs. seq scan decisions.
effective_cache_size = '12GB'

-- max_parallel_workers_per_gather: parallelism for seq scans, sorts, joins
max_parallel_workers_per_gather = 4
```

## Connection Pooling

PostgreSQL connections are expensive (~10MB RAM each). **Do not connect directly from application pods in production** —
use PgBouncer or pgpool-II.

PgBouncer configuration for transaction-mode pooling (most efficient):

```ini
[databases]
mydb = host=postgres-primary port=5432 dbname=mydb

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 20
server_idle_timeout = 600
```

**Transaction-mode caveat**: prepared statements don't work across pool connections in transaction mode. Use
`pg_prepared_statements_max = 0` in the app's connection string or use statement-mode pooling if prepared statements are
required.

## Autovacuum Tuning

Default autovacuum settings are conservative for small tables. For large, high-churn tables:

```sql
-- Per-table autovacuum tuning
ALTER TABLE orders SET (
  autovacuum_vacuum_scale_factor = 0.01,    -- trigger at 1% of table size (not default 20%)
  autovacuum_analyze_scale_factor = 0.005,  -- analyze at 0.5%
  autovacuum_vacuum_cost_delay = 2           -- less throttling for large tables
);
```

Check autovacuum health:

```sql
SELECT schemaname, tablename, n_dead_tup, n_live_tup,
  last_autovacuum, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC;
```

## Index Bloat

Indexes accumulate bloat after many updates/deletes. Check:

```sql
SELECT schemaname, tablename, indexname,
  pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC
LIMIT 20;
```

Rebuild without locking (pg 12+):

```sql
REINDEX INDEX CONCURRENTLY idx_orders_user_id;
```

## Lock Monitoring

```sql
-- Find blocked queries and what's blocking them
SELECT blocked.pid, blocked.query, blocking.pid AS blocking_pid, blocking.query AS blocking_query
FROM pg_stat_activity AS blocked
JOIN pg_stat_activity AS blocking ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE blocked.wait_event_type = 'Lock';

-- Find long-running queries
SELECT pid, now() - query_start AS duration, state, query
FROM pg_stat_activity
WHERE state != 'idle' AND query_start < now() - interval '5 minutes'
ORDER BY duration DESC;
```

## Table Partitioning

Use declarative partitioning for tables that grow without bound (logs, events, time-series):

```sql
CREATE TABLE events (
  id          bigserial,
  created_at  timestamptz NOT NULL DEFAULT now(),
  user_id     bigint,
  event_type  text
) PARTITION BY RANGE (created_at);

CREATE TABLE events_2024_01 PARTITION OF events
  FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Drop old partitions instantly (no DELETE needed, no VACUUM needed)
DROP TABLE events_2023_01;  -- instant, no lock on parent
```

Create partitions in advance — inserting into a range with no matching partition fails. Automate partition creation with
`pg_partman`.
