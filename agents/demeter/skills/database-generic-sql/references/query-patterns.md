# Generic SQL Query Patterns

## NULL Handling

NULL represents unknown, not empty or zero. This causes non-obvious behavior:

```sql
-- NOT IN with NULLs is always empty
-- ❌ If any user_id in the subquery is NULL, this returns 0 rows
SELECT * FROM orders WHERE user_id NOT IN (SELECT id FROM banned_users);

-- ✅ Use NOT EXISTS — handles NULLs correctly
SELECT * FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM banned_users b WHERE b.id = o.user_id);

-- NULL comparisons are never TRUE/FALSE — always use IS NULL / IS NOT NULL
-- ❌ This always returns empty
WHERE column = NULL
-- ✅
WHERE column IS NULL

-- COALESCE returns first non-NULL value
SELECT COALESCE(nickname, first_name, 'Anonymous') AS display_name FROM users;

-- NULLIF returns NULL if the two values are equal (useful to avoid division by zero)
SELECT total_revenue / NULLIF(total_orders, 0) AS avg_order_value FROM stats;
```

## Aggregation Patterns

```sql
-- COUNT(*) counts all rows; COUNT(column) excludes NULLs
SELECT COUNT(*) AS total, COUNT(email) AS with_email FROM users;

-- Conditional aggregation (pivot-like)
SELECT
  COUNT(*) FILTER (WHERE status = 'active') AS active,    -- PostgreSQL/SQLite syntax
  COUNT(CASE WHEN status = 'active' THEN 1 END) AS active -- ANSI SQL syntax
FROM users;

-- GROUP BY with HAVING (filter on aggregate, not WHERE)
SELECT user_id, COUNT(*) AS order_count
FROM orders
GROUP BY user_id
HAVING COUNT(*) >= 5;  -- only users with 5+ orders

-- Running total (window function — SQL 2003 standard)
SELECT date, amount,
  SUM(amount) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative
FROM daily_sales;
```

## JOIN Patterns

```sql
-- INNER JOIN: only rows with matches in both tables
SELECT o.id, u.email FROM orders o
INNER JOIN users u ON u.id = o.user_id;

-- LEFT JOIN: all rows from left table, NULL for unmatched right
SELECT u.email, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
GROUP BY u.id, u.email;

-- Anti-join: rows in left table with NO match in right table
-- Method 1: LEFT JOIN + IS NULL (widely supported)
SELECT u.* FROM users u
LEFT JOIN orders o ON o.user_id = u.id
WHERE o.id IS NULL;

-- Method 2: NOT EXISTS (often more readable intent)
SELECT * FROM users u
WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

-- Self-join: find records related to other records in same table
SELECT e.name, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.id;
```

## Pagination

```sql
-- Offset pagination (simple but slow for large offsets)
SELECT * FROM products ORDER BY id LIMIT 20 OFFSET 100;

-- Keyset/cursor pagination (fast at any offset)
-- "Give me the next 20 products after id=1234"
SELECT * FROM products
WHERE id > :last_seen_id  -- or: WHERE (created_at, id) > (:last_seen_date, :last_seen_id)
ORDER BY id
LIMIT 20;
```

Keyset pagination is always preferred for large tables — `OFFSET 100000` requires scanning 100,000 rows to discard them.

## Date/Time Patterns

```sql
-- Always store in UTC, convert at display time
INSERT INTO events (created_at) VALUES (NOW() AT TIME ZONE 'UTC');  -- PostgreSQL
INSERT INTO events (created_at) VALUES (datetime('now'));            -- SQLite

-- Truncate to a period for grouping (PostgreSQL)
SELECT DATE_TRUNC('day', created_at) AS day, COUNT(*) FROM events GROUP BY 1;

-- Truncate for grouping (standard SQL)
SELECT CAST(created_at AS DATE) AS day, COUNT(*) FROM events GROUP BY 1;

-- Date arithmetic (standard SQL)
WHERE created_at >= CURRENT_DATE - INTERVAL '30' DAY
-- PostgreSQL shorthand:
WHERE created_at >= NOW() - INTERVAL '30 days'
-- SQLite:
WHERE created_at >= datetime('now', '-30 days')
```

## Avoiding Common Performance Mistakes

```sql
-- ❌ Function on indexed column defeats the index
WHERE YEAR(created_at) = 2024
-- ✅ Range query uses the index
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'

-- ❌ OR conditions can prevent index use (database-dependent)
WHERE status = 'active' OR status = 'pending'
-- ✅ IN is often optimized better
WHERE status IN ('active', 'pending')

-- ❌ Implicit type conversion for string-stored numbers
WHERE user_id = 123  -- user_id is VARCHAR
-- ✅ Explicit cast
WHERE user_id = CAST(123 AS VARCHAR)

-- ❌ SELECT * in production queries
SELECT * FROM users WHERE ...
-- ✅ Name only what you need
SELECT id, email, created_at FROM users WHERE ...
```
