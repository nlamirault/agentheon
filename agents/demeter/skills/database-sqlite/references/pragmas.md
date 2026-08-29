# SQLite PRAGMA Reference

PRAGMAs configure SQLite behavior at the connection level. Most settings reset when the connection closes — they are not
persistent unless explicitly re-applied on every new connection.

## Essential PRAGMAs to Set on Every Connection

```sql
-- Enable foreign key enforcement (OFF by default)
PRAGMA foreign_keys = ON;

-- Enable WAL mode for better concurrency (readers don't block writers)
-- This setting IS persistent (stored in the database file) after first set.
PRAGMA journal_mode = WAL;

-- Reduce fsync frequency (slight durability trade-off for speed)
-- NORMAL: sync on checkpoint only (WAL mode). Safe for most use cases.
PRAGMA synchronous = NORMAL;  -- default is FULL

-- Enable memory-mapped I/O for read-heavy workloads (0 = disabled)
PRAGMA mmap_size = 268435456;  -- 256MB
```

## Performance PRAGMAs

```sql
-- Increase page cache size (default is 2MB = -2000 pages × 1KB)
-- Negative value = size in kibibytes; positive = number of pages
PRAGMA cache_size = -65536;  -- 64MB cache

-- Set page size before creating database (cannot change after)
-- Larger pages are better for large blobs or full-table scans
PRAGMA page_size = 4096;  -- default; 8192 or 16384 for large datasets

-- Temporary file storage: MEMORY is fastest, DEFAULT uses disk
PRAGMA temp_store = MEMORY;

-- Auto-checkpoint threshold (WAL mode only)
-- Checkpoint when WAL reaches this many pages (default 1000)
PRAGMA wal_autocheckpoint = 1000;
```

## Maintenance PRAGMAs

```sql
-- Reclaim free pages (like VACUUM but faster; runs incrementally)
-- Set to 1000 pages per connection to run incrementally
PRAGMA auto_vacuum = INCREMENTAL;
PRAGMA incremental_vacuum(100);  -- reclaim 100 pages

-- Full vacuum (rewrites entire database file — offline operation)
VACUUM;

-- Analyze query planner statistics
PRAGMA optimize;   -- SQLite 3.18+: auto-analyzes tables that need it
ANALYZE;           -- full analyze of all tables

-- Check database integrity
PRAGMA integrity_check;
PRAGMA quick_check;  -- faster, less thorough
```

## Inspection PRAGMAs

```sql
-- List all tables
PRAGMA table_list;

-- Show column info for a table
PRAGMA table_info(users);

-- Show indexes on a table
PRAGMA index_list(users);
PRAGMA index_info(idx_users_email);

-- Show current settings
PRAGMA journal_mode;
PRAGMA foreign_keys;
PRAGMA page_size;
PRAGMA cache_size;

-- Show database file stats
PRAGMA page_count;   -- total pages
PRAGMA freelist_count;  -- unused pages (reclaimed by VACUUM)
PRAGMA database_size;   -- size in pages

-- Show WAL checkpoint stats
PRAGMA wal_checkpoint;
```

## Security PRAGMAs

```sql
-- Encrypt database (requires SQLCipher extension)
-- This is NOT standard SQLite — needs SQLCipher build
PRAGMA key = 'passphrase';

-- Limit size of in-memory temp tables
PRAGMA soft_heap_limit = 67108864;  -- 64MB
```

## WAL Mode Notes

WAL (Write-Ahead Logging) creates two extra files alongside your `.db` file:

- `database.db-wal` — the write-ahead log
- `database.db-shm` — shared memory index

These files are normal — they're part of a live WAL-mode database. They're cleaned up after a checkpoint. If you see
them after your application exits, it means a checkpoint didn't complete (common if connections weren't closed cleanly).
Force a checkpoint manually:

```sql
PRAGMA wal_checkpoint(TRUNCATE);  -- checkpoint and zero the WAL file
```

**Do not delete `-wal` or `-shm` files manually** while any process has the database open — this will corrupt the
database.
