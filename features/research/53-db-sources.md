# Feature #53: Database Sources

## Overview

Enable metabuffer to query and edit database records as if they were text buffers. Users can run SQL queries through the metabuffer prompt system, filter results using matchers, and write edits back as UPDATE statements. When paired with LLM query generation, this becomes a powerful conversational interface for data exploration and manipulation.

## Motivation

- Current sources handle text files, project-wide semantic search, and file metadata. Databases are a missing category.
- Many workflows involve exploring and modifying data: logs, configuration records, schema artifacts, telemetry.
- Manual SQL writing is friction. LLM-generated queries (via prompt directives) could make data exploration as natural as typing a description.
- Writeback as UPDATE/INSERT creates a novel editing model: "find these records, modify them in metabuffer, sync changes back."

## Architecture

### Source Provider Contract

DB sources must implement the same interface as `text.fnl` and `lgrep.fnl`:

```fennel
{:provider-key "db"
 :active? (fn [parsed] ...)
 :hit-prefix (fn [ref] ...)
 :info-path (fn [ref full-path?] ...)
 :info-suffix (fn [session ref mode ...] ...)
 :preview-filetype (fn [ref] ...)
 :preview-lines (fn [session ref height ...] ...)
 :collect-source-set (fn [settings parsed canonical-path] ...)
 :apply-write-ops! (fn [ops] ...)}
```

### DB Source Module Layout

File: `fnl/metabuffer/source/db.fnl`

#### Active Detection

```fennel
(fn M.active? [parsed]
  "Check if any DB directive is present in parsed query."
  (when-let [db-spec (. parsed :db-spec)]
    (and db-spec
         (. db-spec :engine)
         (. db-spec :query))))
```

The parser sets `:db-spec` when directives like `#sql` or natural language `#ask db:...` are detected.

#### Ref Structure

DB hits carry metadata beyond regular file refs:

```lua
{
  kind = "db-row",
  engine = "sqlite",
  db-path = "/path/to/db.sqlite",
  table = "users",
  columns = {"id", "name", "email", "status"},
  primary-key = "id",
  row-id = 42,
  row-values = {id=42, name="alice", email="a@x.com", status="active"},
  lnum = 1,
  text = "42 | alice | a@x.com | active"
}
```

The `text` field is the rendered row (pipe-delimited or customizable). The `row-values` table enables writeback.

#### Collection (Query Execution)

```fennel
(fn M.collect-source-set [settings parsed canonical-path]
  "Execute DB query and return rows as metabuffer content."
  (let [spec (. parsed :db-spec)
        engine (. spec :engine)
        conn (db-connection! settings engine spec)
        results (db-query! conn spec.query)]
    (if (> (# results) 0)
        {:content (mapv format-row results)
         :refs (mapv (fn [row] (ref-for-row engine spec row)) results)}
        nil)))
```

### Connection Management

#### Per-Engine Connection Pools

DB source maintains a connection pool keyed by `{engine db-path}`:

```lua
local connections = {}  -- {engine:db_path => conn}

function db-connection!(settings, engine, spec)
  local key = engine .. ":" .. (spec.db-path or "")
  
  if connections[key] then
    return connections[key]
  end
  
  local conn = engine_connect(engine, spec)
  connections[key] = conn
  return conn
end
```

#### Engine Support

Phase 1: SQLite (file-based, zero-config, safe)
Phase 2: PostgreSQL, MySQL (network, auth required)
Phase 3: Custom engines via Lua hooks

SQLite implementation:

```fennel
(fn sqlite-connect [settings db-path]
  (let [sqlite3 (require :luasqlite3)]
    (when sqlite3
      (sqlite3.open db-path))))

(fn sqlite-query [conn query]
  (let [stmt (conn:prepare query)
        results []]
    (each [row (stmt:nrows)]
      (table.insert results row))
    results))
```

Error handling: wrap with `pcall`, log to debug buffer, return empty set on connection failure.

### Result Formatting

Rows display as human-readable delimited lines. Customization per session:

```lua
{
  id = 1,
  name = "alice",
  email = "alice@example.com"
}
```

Rendered as:
```
1 | alice | alice@example.com
```

Column order is preserved. Null values render as blank. Very long values truncate with ellipsis.

### Writeback Mechanics

When user accepts with `<CR>`, metabuffer collects edit operations and dispatches to `apply-write-ops!`.

#### Operation Types

Each operation targets a single row:

```lua
{
  kind = "db-row-update",
  engine = "sqlite",
  db-path = "/path/to/db.sqlite",
  table = "users",
  primary-key = "id",
  row-id = 42,
  old-values = {id=42, name="alice", email="a@x.com", status="active"},
  new-values = {id=42, name="alice_new", email="a@x.com", status="archived"}
}
```

The engine computes a minimal UPDATE:

```sql
UPDATE users SET name = 'alice_new', status = 'archived' WHERE id = 42
```

#### Transaction Safety

Multiple rows in one session → single transaction:

```fennel
(fn apply-write-ops! [ops]
  (let [grouped (group-ops-by-engine ops)
        result {:wrote false :changed 0}]
    (each [engine ops-for-engine (pairs grouped)]
      (let [conn (get-connection engine)]
        (conn:exec "BEGIN TRANSACTION")
        (try
          (do
            (var changed 0)
            (each [_ op (ipairs ops-for-engine)]
              (let [success (execute-update-op! conn op)]
                (when success
                  (set changed (+ changed 1)))))
            (conn:exec "COMMIT")
            (set (. result :wrote) true)
            (set (. result :changed) (+ (. result :changed) changed)))
          (catch [e]
            (conn:exec "ROLLBACK")
            (log-error (.. "DB writeback failed: " e))
            nil))))
    result))
```

If any row update fails, the entire transaction rolls back.

#### Conflict Handling

When two users edit the same row concurrently:

- Last write wins (simple, pessimistic)
- Optimistic locking via version column (if table has one)
- Manual conflict prompt (future enhancement)

For phase 1, detect row changes via timestamp and warn the user before applying updates.

### Directives & Activation

#### SQL Directive

Explicit SQL query:

```
#sql select * from users where status = 'active'
```

Parsed as:

```lua
{
  db-spec = {
    engine = "sqlite",
    db-path = vim.fn.expand("~/app.db"),  -- resolved from config
    query = "select * from users where status = 'active'"
  }
}
```

#### Natural Language Query (LLM Integration)

User types natural language, LLM translates to SQL:

```
#ask db:"show me inactive users from the past month"
```

Flow:

1. Prompt parser detects `#ask db:` directive
2. Sends description to configured LLM endpoint
3. LLM returns SQL: `SELECT * FROM users WHERE status = 'inactive' AND created_at > date('now', '-1 month')`
4. SQL is injected into parse state
5. Collection proceeds as normal

Configuration:

```lua
require("metabuffer").setup({
  options = {
    db = {
      engine = "sqlite",
      db-path = vim.fn.expand("~/.myapp/db.sqlite"),
      llm_endpoint = "openai",
      llm_prompt_template = "Generate a SQL SELECT query for: {description}. Return only the query, no explanation. Table schema: {schema}"
    }
  }
})
```

### LLM Query Generation Flow

#### Query Generation on `#ask` Directive

When user enters `#ask db:"find users matching pattern"`:

1. **Directive Detection**: Parser recognizes `#ask db:` → sets `:ask-db-description "find users matching pattern"`
2. **Schema Retrieval**: DB source introspects active table schema asynchronously
3. **LLM Call**: Sends schema + description to LLM in background
4. **Result Injection**: When LLM returns SQL, inject into `:db-spec :query`
5. **Async Collection**: Results stream in as normal

#### Multi-Line Refinement

Users can refine queries in the prompt without waiting:

```
#ask db:"users table, filter by region"
region: north america
age: 25-35
```

Each line after the directive acts as a filter hint. Collected into `{:ask-db-hints [...]}` and concatenated into the LLM prompt.

#### Schema Caching

Cache introspection results per database to avoid redundant queries:

```lua
_db_schema_cache = {
  ["~/.myapp/db.sqlite"] = {
    users = {columns = {...}, indexes = {...}},
    logs = {...}
  }
}
```

Invalidate with `#refresh-schema` directive or session restart.

### Query Variations

Beyond simple SELECT, support:

#### Aggregations

```
#sql select status, count(*) from users group by status
```

Results render as `status | count` rows.

#### Joins

```
#sql select u.id, u.name, count(o.id) as order_count 
      from users u 
      left join orders o on u.id = o.user_id 
      group by u.id
```

Rendered similarly.

#### Computed Columns

Use SQL `AS` to name computed output:

```
#sql select id, name, 
            upper(email) as email_upper,
            created_at::date as created_date
      from users
```

Each rendered as a column in the output.

Writeback only works on queries that touch a single table with a clear primary key. Queries with joins or aggregations are read-only (no UPDATE generation).

## UX Flow

### Starting a Session

```
:Meta
#sql select id, name, status from users where status = 'active'
```

Result:
```
[Results buffer]
1 | alice | active
2 | bob | active
3 | charlie | active

[Info float]
Source: db (sqlite)
Table: users
Rows: 3
```

Selecting a row shows full record in info panel and a formatted preview.

### Editing & Writeback

User moves selection to row 2, presses `<CR>` to jump to edit:

```
[Jump to... where?]
```

Metabuffer opens a temp buffer with the row as JSON or key-value format:

```
id: 2
name: bob
status: active
```

User edits:

```
id: 2
name: bob_updated
status: inactive
```

User saves (`:w`). Metabuffer detects changes, registers a write op.

When user accepts in the main results buffer (`<CR>` again), writeback executes the UPDATE.

### LLM-Assisted Query

```
:Meta
#ask db:"get me users from California"
```

Metabuffer shows a loading indicator. In the background:

1. Schema introspection: `pragma table_info(users)`
2. LLM call with schema + description
3. SQL returned: `SELECT * FROM users WHERE state = 'CA'`
4. Results stream in

User sees results appear as the query completes.

### Refinement with History

After first query, user refines in the prompt:

```
[Prompt]
#ask db:"get me users from California"
salary: above 100k
```

Each new line appends to the LLM context. LLM generates refined SQL.

## Security Considerations

### SQL Injection Prevention

1. **No direct user typing into queries**: Queries come from directives or LLM.
2. **Parameterized queries always**: Use bound parameters for any user-derived values.

```fennel
(fn safe-query [conn template params]
  (let [stmt (conn:prepare template)]
    (each [idx val (ipairs (or params []))]
      (stmt:bind idx val))
    (stmt:step-all)))

;; Usage
(safe-query conn
  "SELECT * FROM users WHERE email = ? AND status = ?)"
  ["user@example.com" "active"])
```

### Database Access Control

1. **Read-only transactions by default**: Queries use `BEGIN DEFERRED` or explicit transaction mode.
2. **Explicit write mode**: Only `apply-write-ops!` uses `BEGIN IMMEDIATE` (write transaction).
3. **Audit logging**: Log all writes (user, timestamp, old/new values) to a metatable.

### Credential Handling

1. **No credentials in config**: DB path/connection string interpolated from environment or secure storage.

```lua
require("metabuffer").setup({
  options = {
    db = {
      engine = "sqlite",
      db_path_env = "MY_APP_DB",  -- resolved from $MY_APP_DB
    }
  }
})
```

2. **Network DBs**: Use environment variables for secrets.

### Scope & Validation

1. **Allowlist of tables**: Config specifies which tables are editable.

```lua
options = {
  db = {
    editable_tables = {"logs", "config", "settings"},
    read_only_tables = {"schema", "audit_trail"}
  }
}
```

2. **Column-level permissions**: Certain columns never updated (ID, created_at, audit fields).

### LLM Prompt Injection

When LLM generates SQL from user descriptions:

1. **Never pass user text directly**: Sanitize and validate descriptions.
2. **Schema context only**: Include column names and types, not sample data.
3. **Result validation**: Returned SQL is parsed and validated before execution.

```fennel
(fn validate-llm-sql [sql]
  "Reject queries with dangerous keywords: DROP, TRUNCATE, DELETE."
  (let [upper (string.upper sql)
        dangerous? (or (string.find upper "DROP")
                       (string.find upper "TRUNCATE")
                       (string.find upper "DELETE"))]
    (not dangerous?)))
```

## Implementation Phases

### Phase 1: Basic SQLite Query

**Scope**: Read-only SELECT queries against SQLite databases.

**Deliverables**:
- `fnl/metabuffer/source/db.fnl` implementing provider contract
- `#sql` directive for explicit SQL queries
- Column-delimited row display
- Connection pool management
- Error handling and logging

**Testing**:
- Unit tests for query parsing and result formatting
- Screen tests for interactive query and result browsing
- Connection lifecycle tests

**Timeline**: 2-3 weeks

### Phase 2: Writeback & Transactions

**Scope**: UPDATE operations with row-level changes.

**Deliverables**:
- Temp buffer edit flow for row modification
- `apply-write-ops!` with transaction wrapping
- Conflict detection (timestamp-based)
- Audit logging

**Testing**:
- Screen tests for edit and writeback workflows
- Transaction rollback tests
- Concurrent edit conflict scenarios

**Timeline**: 2 weeks

### Phase 3: LLM Query Generation

**Scope**: Natural language query generation via `#ask db:`.

**Deliverables**:
- LLM endpoint integration (OpenAI, etc.)
- Schema introspection and caching
- Prompt construction with user description + schema
- Async result injection into query state
- Multi-line hint refinement

**Testing**:
- Mock LLM endpoint for deterministic tests
- Schema cache validation
- Prompt construction edge cases

**Timeline**: 2-3 weeks

### Phase 4: Multi-Engine Support

**Scope**: PostgreSQL, MySQL, custom engines.

**Deliverables**:
- Engine abstraction layer with adapter pattern
- PostgreSQL and MySQL connection/query modules
- Plugin hook for custom engines
- Connection string parsing and validation

**Testing**:
- Docker-compose test databases
- Cross-engine integration tests

**Timeline**: 3-4 weeks (lower priority, deferred)

## Integration Points

### Directive System

New directives registered in `fnl/metabuffer/query/directive.fnl`:

```fennel
{:kind "flag"
 :long "sql"
 :arg "{query}"
 :doc "Execute SQL query against configured database."
 :await {:kind "query-source" :source-key "db"}}

{:kind "flag"
 :long "ask"
 :token-key :ask-mode
 :arg "db:{description}"
 :doc "Use LLM to generate SQL from natural language description."}
```

### Source Provider Index

Register DB provider in `fnl/metabuffer/source/init.fnl`:

```fennel
(local db (require :metabuffer.source.db))
(local query-sources [{:key "db" :provider db}
                      {:key "lgrep" :provider lgrep}])
```

### Config Extensions

Add DB options to `fnl/metabuffer/config.fnl`:

```fennel
:db
{:engine "sqlite"
 :db-path (vim.fn.expand "~/.myapp.db")
 :llm-endpoint nil
 :editable-tables []
 :read-only-tables []
 :column-order []
 :row-display-format :pipe-delimited}
```

### Events

New events for DB operations:

- `:db-connected` → connection pool initialized
- `:db-query-started` → collection async begun
- `:db-query-completed` → results available
- `:db-write-committed` → update transaction succeeded
- `:db-write-rolled-back` → update transaction failed

## Known Limitations & Future Work

### Phase 1 Limitations

- SQLite only (no network DBs)
- Read-only (no writeback)
- No LLM integration
- No transaction isolation control

### Future Enhancements

1. **Incremental result streaming**: Large queries stream results progressively instead of loading all at once.
2. **Result caching**: Cache query results in session-local map, allow re-running with different filters.
3. **Schema browser**: `#schema` directive opens a floating panel of tables, columns, indexes.
4. **Query history**: Like prompt history, save successful queries.
5. **Materialized views**: Pre-compute expensive queries as views, query those instead.
6. **Partial writes**: Update only changed columns (column-level delta).
7. **Custom row editors**: Allow users to define Lua functions for rendering/editing rows.
8. **Distributed DBs**: Support queries that fan out across multiple database replicas.

## Testing Strategy

### Unit Tests

`tests/unit/test_db_source.lua`:

- Query parsing (directives, SQL extraction)
- Result formatting (row → line conversion)
- Schema introspection (SQLite PRAGMA parsing)
- LLM prompt construction (description + schema → SQL template)
- Operation generation (diff old/new rows → UPDATE statement)

### Screen Tests

`tests/screen/db/test_screen_db_query.lua`:

- Launch session with `#sql` directive
- Verify results appear and are interactive
- Selection and preview update correctly
- Jump-to-edit flow

`tests/screen/db/test_screen_db_writeback.lua`:

- Edit a row and writeback
- Verify UPDATE executes and results refresh
- Rollback on conflict/error
- Transaction boundaries

`tests/screen/db/test_screen_db_llm_query.lua`:

- `#ask db:` with mock LLM endpoint
- Results stream in async
- Multi-line hints affect query refinement

### Integration Tests

- Multi-threaded concurrent edit scenarios
- Connection pool exhaustion (safety)
- Very large result sets (performance)
- Network failure during writeback (recovery)

## Example User Workflows

### Workflow 1: Log Analysis

```
:Meta
#sql select timestamp, level, message from logs 
     where level = 'error' and timestamp > datetime('now', '-1 day')
```

Results show recent errors. User selects one, previews context. Jumps to edit, marks as `resolved = true`, syncs back.

### Workflow 2: Configuration Management

```
:Meta
#ask db:"show me all production settings that are outdated"
```

LLM generates SQL checking last-modified timestamps. User browses results, edits values, commits changes. Audit trail logs who changed what.

### Workflow 3: Data Exploration

```
:Meta
#ask db:"users grouped by region, show count and average age"
```

LLM translates to GROUP BY query. Results show aggregations. User uses matchers to narrow down regions of interest.

Then refines:

```
region: asia
active: true
```

LLM-assisted WHERE clause generation for these filters.

## Open Questions

1. **Row representation format**: Pipe-delimited vs JSON vs custom? Configurable per session?
2. **Edit buffer format**: How do we present a single row for editing? JSON? Key-value? Vertical layout?
3. **Ordering of results**: By primary key? By query? User-specified sort?
4. **Pagination**: Load all results upfront or stream paginated? Performance implications?
5. **Multi-table joins**: Should we support writeback on joined queries, or keep read-only?
6. **Historical queries**: Do we version rows or just track writes to audit table?
7. **LLM fallback**: If LLM fails, should we show a manual SQL input prompt?

## References

- `fnl/metabuffer/source/init.fnl` — provider interface and registration
- `fnl/metabuffer/source/text.fnl` — simple synchronous provider example
- `fnl/metabuffer/source/lgrep.fnl` — async external-tool provider example
- `fnl/metabuffer/query/directive.fnl` — directive parser and registry
- `fnl/metabuffer/config.fnl` — config merging and defaults
