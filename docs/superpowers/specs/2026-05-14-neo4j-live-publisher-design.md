# Neo4j Live Publisher — Design

**Date:** 2026-05-14
**Status:** Approved, ready for implementation plan
**Owner:** tdavron@gmail.com

## Goal

Enable `graphify run <path> --format neo4j` to push the knowledge graph directly into a live remote Neo4j instance (`bolt://192.168.0.211:7687`) in addition to producing the existing `graph.cypher` file. Reproducible test target: `samples/mini-library/`.

## Scope

In scope:

- New `Neo4jLivePublisher` that opens a Bolt session and writes the graph using parameterized `UNWIND` batches.
- Add `Graphify:Neo4j` config section (env + appsettings) — no new CLI flags.
- Wire the publisher into the existing `case "neo4j":` branch in `PipelineRunner.RunAsync` so the file is always written and live push runs when connection settings are present.
- Thread the new connection options through both `run` and `watch` command wiring in `Program.cs`.
- Create `samples/mini-library/` — small C# project (~8 files) for reproducible end-to-end runs.

Out of scope (YAGNI for v1):

- CLI flags for Neo4j connection (use env vars or `appsettings.local.json`).
- Retry/backoff on transient errors.
- Integration tests with Testcontainers.
- Cluster routing (`neo4j+s://`, multi-instance, replication-aware sessions).
- Schema evolution between runs (constraints other than node-id uniqueness).

## Decisions (user-confirmed)

| # | Question | Decision |
|---|---|---|
| 1 | File vs live push for `--format neo4j` | Both — write `graph.cypher` AND push to DB |
| 2 | Config source | Env vars + appsettings (no CLI flags) |
| 3 | Behavior on existing data | Wipe before insert |
| 4 | Wipe scope | Label-scoped: every Graphify node carries `:Graphify`; wipe deletes only that label |
| 5 | Sample folder | Create `samples/mini-library/` from scratch |
| 6 | Tests | None — no test changes in this change |

## Architecture

```
PipelineRunner
  ├─> Neo4jExporter            ──> graphify-out/graph.cypher  (always)
  └─> Neo4jLivePublisher       ──> bolt://...                  (only if config present)
```

### New components

- **`src/Graphify/Export/Neo4jLivePublisher.cs`** — `public sealed class`. Not an `IGraphExporter` (does not write to a file path). Public surface:
  ```csharp
  public Task<PublishStats> PublishAsync(
      KnowledgeGraph graph,
      Neo4jConnectionOptions options,
      CancellationToken cancellationToken = default);
  ```
- **`src/Graphify/Export/Neo4jConnectionOptions.cs`** — record:
  ```csharp
  public sealed record Neo4jConnectionOptions(
      string Uri,
      string User,
      string Password,
      string Database = "neo4j",
      string WipeLabel = "Graphify");
  ```
- **`src/Graphify/Export/PublishStats.cs`** — record `(int NodesWritten, int EdgesWritten, TimeSpan Elapsed)`.
- **`src/Graphify.Cli/Configuration/GraphifyConfig.cs`** — add `Neo4jSettings Neo4j { get; set; } = new();` and a nested `Neo4jSettings` POCO mirroring `Neo4jConnectionOptions` (nullable strings for `Uri`/`User`/`Password`; defaults for `Database` and `WipeLabel`).

### Dependency

- Add `Neo4j.Driver` 5.x (NuGet) to `src/Graphify/Graphify.csproj`. Verify the specific package version supports `net10.0` (loads via `netstandard2.0` if no `net8.0`/`net10.0` TFM is published — pin the latest stable that exposes the `IAsyncSession` / `ExecuteWriteAsync` surface used below).

### Existing components touched

- **`src/Graphify.Cli/PipelineRunner.cs`** — add ctor parameter `Neo4jConnectionOptions? neo4jOptions = null` (optional with default `null` to preserve all existing test constructions). Store on field. In `case "neo4j":` after the file export, if `neo4jOptions is not null`, instantiate `Neo4jLivePublisher` and call `PublishAsync`.
- **`src/Graphify.Cli/Program.cs`** — read `graphifyConfig.Neo4j`; if `Uri` is non-empty build a `Neo4jConnectionOptions` and pass it into BOTH `PipelineRunner` constructions (one in the `run` command action, one in the `watch` command action). If `Uri` is empty/null, pass `null`.

### Not touched (intentional)

- `Neo4jExporter.cs` — keep as-is; private static sanitization helpers remain there. Avoids breaking existing `Neo4jExporterTests` per user constraint.
- `WatchMode` internals — it consumes a `PipelineRunner` injected from `Program.cs`, so no changes needed inside.

## Configuration

### appsettings.json (defaults)

```json
{
  "Graphify": {
    "Neo4j": {
      "Uri": null,
      "User": null,
      "Password": null,
      "Database": "neo4j",
      "WipeLabel": "Graphify"
    }
  }
}
```

### appsettings.local.json (user-managed; gitignored)

```json
{
  "Graphify": {
    "Neo4j": {
      "Uri": "bolt://192.168.0.211:7687",
      "User": "neo4j",
      "Password": "<password>"
    }
  }
}
```

Confirmed: `.gitignore` line 24 contains `appsettings.local.json` — the password file is excluded from git.

### Environment variables (override appsettings)

```
GRAPHIFY__Neo4j__Uri=bolt://192.168.0.211:7687
GRAPHIFY__Neo4j__User=neo4j
GRAPHIFY__Neo4j__Password=<password>
```

Resolution uses the existing `ConfigurationFactory.Build()` chain (env → user-secrets → appsettings.local.json → appsettings.json). No new providers needed.

### Resolution semantics

- If `Uri` resolves to null or whitespace → publisher is not invoked; log:
  `Neo4j connection not configured (set GRAPHIFY__Neo4j__Uri), skipping live publish`
- If `Uri` is set but `User` or `Password` is missing → fail fast with an error log; file export still succeeds because it ran first.

### Logging hygiene

- Verbose output prints `Uri` and `User`. Never prints `Password`.
- Error messages mentioning auth must not echo the password.

## Cypher strategy (live push only)

Live push uses parameterized `UNWIND` batches. The file path keeps the existing per-statement Cypher (already shipped, unchanged).

### Step 1 — Connectivity check

```csharp
await driver.VerifyConnectivityAsync(cancellationToken);
```

Fail fast if the URI is unreachable or auth fails.

### Step 2 — Wipe (label-scoped)

```cypher
MATCH (n:Graphify) DETACH DELETE n
```

Runs in its own write transaction. `DETACH` removes incident edges in the same operation.

### Step 3 — Constraint (idempotent)

```cypher
CREATE CONSTRAINT graphify_node_id IF NOT EXISTS
FOR (n:Graphify) REQUIRE n.id IS UNIQUE
```

Safe to re-run. Guarantees `id` lookups during edge writes use the index.

### Step 4 — Nodes (batched, grouped by type)

Group `graph.GetNodes()` by sanitized `Type`. For each group emit batches of 500. Each batch payload is a list of flat maps:

```csharp
new Dictionary<string, object?>
{
    ["id"]        = node.Id,
    ["label"]     = node.Label,
    ["community"] = node.Community,            // nullable
    // metadata keys merged at root level, sanitized property names
    ["filePath"]  = "src/Foo.cs",
    // ...
}
```

Cypher template per group (the type label is interpolated server-side once per group, not per row — safe because it comes from `SanitizeNodeType` which restricts to `[A-Za-z][A-Za-z0-9_]*`):

```cypher
UNWIND $batch AS row
CREATE (n:Graphify:Class)
SET n = row
```

Using `SET n = row` (not an inline property map) is required because `node.Metadata` carries arbitrary, per-node-varying keys — an inline `{id: row.id, label: row.label, ...}` map cannot express that.

Property keys are sanitized identically to the existing file-path (`SanitizePropertyName`). String values are passed as native parameters — no Cypher escaping needed (no injection risk).

### Step 5 — Edges (batched, grouped by relationship)

Group `graph.GetEdges()` by sanitized `Relationship`. For each group emit batches of 500. Payload:

```csharp
new Dictionary<string, object?>
{
    ["source"]     = edge.Source.Id,
    ["target"]     = edge.Target.Id,
    ["weight"]     = edge.Weight,
    ["confidence"] = edge.Confidence.ToString().ToUpperInvariant(),
}
```

Cypher template per group:

```cypher
UNWIND $batch AS row
MATCH (a:Graphify {id: row.source}), (b:Graphify {id: row.target})
CREATE (a)-[r:CALLS]->(b)
SET r.weight = row.weight, r.confidence = row.confidence
```

(`CALLS` replaced per group with the sanitized relationship type, same identifier-restriction guarantee as labels.)

### Sanitization

Publisher carries its own copy of `SanitizeNodeType`, `SanitizeRelationshipType`, `SanitizePropertyName` — duplication of ~50 lines vs `Neo4jExporter`. Acceptable for v1; consolidates only if a third consumer appears.

### Progress / logging

```
[6/6] Exporting results...
      Exported Neo4j Cypher: graphify-out/graph.cypher
      Publishing to Neo4j: bolt://192.168.0.211:7687 (user: neo4j) ...
      Wiped existing :Graphify nodes
      Published: 1234 nodes, 5678 edges (3.2s)
```

Stats come from `PublishStats` returned by `PublishAsync`.

## Data flow

```csharp
case "neo4j":
    // 1. File export (unchanged)
    var neo4jExporter = new Neo4jExporter();
    var cypherPath = Path.Combine(outputDir, "graph.cypher");
    await neo4jExporter.ExportAsync(graph, cypherPath, cancellationToken);
    await WriteLineAsync($"      Exported Neo4j Cypher: {cypherPath}");

    // 2. Live push (new)
    if (this.neo4jOptions is not null)
    {
        await WriteLineAsync($"      Publishing to Neo4j: {this.neo4jOptions.Uri} (user: {this.neo4jOptions.User}) ...");
        var publisher = new Neo4jLivePublisher();
        var stats = await publisher.PublishAsync(graph, this.neo4jOptions, cancellationToken);
        await WriteLineAsync(
            $"      Published: {stats.NodesWritten} nodes, {stats.EdgesWritten} edges ({stats.Elapsed.TotalSeconds:F1}s)");
    }
    else
    {
        await WriteLineAsync(
            "      Neo4j connection not configured (set GRAPHIFY__Neo4j__Uri), skipping live publish");
    }
    break;
```

Inside `Neo4jLivePublisher.PublishAsync`:

1. `using` `IDriver` (one driver instance per call).
2. `using` `IAsyncSession` configured for `options.Database`.
3. `VerifyConnectivityAsync`.
4. Wipe transaction.
5. Constraint transaction.
6. Node batches (one transaction per batch).
7. Edge batches (one transaction per batch).
8. Return `PublishStats`.

All async calls receive `cancellationToken`.

## Error handling

The existing `try/catch` around `foreach (var format in formats)` in `PipelineRunner` catches publisher errors and logs them. The file export already succeeded in Step 1, so a network failure doesn't lose work. Categories:

| Cause | Driver exception | Reaction |
|---|---|---|
| URI unreachable / DNS / refused | `ServiceUnavailableException` | Log `Error: Neo4j unreachable at <uri>: <msg>`. Continue with remaining formats. |
| Auth fail | `AuthenticationException` | Log `Error: Neo4j auth failed for user <user>`. Password not echoed. |
| Cypher rejected | `ClientException` | Log `Error: Cypher rejected: <msg>`. In verbose: first 200 chars of payload key set (not values). |
| User cancellation | `OperationCanceledException` | Rethrown; the outer pipeline `try/catch` already handles it (prints `Pipeline cancelled by user`). |

Idempotency: wipe + create-constraint are safe on every run. A partial-failure re-run wipes everything and starts over. No partial-state recovery code.

No retry policy in v1.

## Sample folder

`samples/mini-library/` — small C# project for repro. Standalone (not part of the solution). ~8 files:

```
samples/mini-library/
├── MiniLibrary.csproj            (net10.0, no references)
├── Models/
│   ├── Book.cs                   (record Book(Id, Title, Author))
│   └── Reader.cs                 (record Reader(Id, Name))
├── Services/
│   ├── ILibraryService.cs
│   └── LibraryService.cs         (BorrowBook → calls IInventory.Reserve)
├── Infrastructure/
│   ├── IInventory.cs
│   └── InMemoryInventory.cs      (implements IInventory)
└── Program.cs                    (Main wires LibraryService)
```

Yields multiple node types (`Class`, `Interface`, `Method`) and edge types (`CALLS`, `IMPLEMENTS`, `REFERENCES`) — enough surface for the end-to-end test:

```bash
dotnet run --project src/Graphify.Cli -- run samples/mini-library --format neo4j
```

## Verification (manual, no automated tests)

1. Set env vars (`GRAPHIFY__Neo4j__Uri`, `GRAPHIFY__Neo4j__User`, `GRAPHIFY__Neo4j__Password`).
2. Run `dotnet run --project src/Graphify.Cli -- run samples/mini-library --format neo4j --verbose`.
3. Confirm `graphify-out/graph.cypher` exists.
4. Confirm CLI log line `Published: N nodes, M edges (Xs)`.
5. From `cypher-shell`/Neo4j Browser:
   - `MATCH (n:Graphify) RETURN count(n);` — matches `N`.
   - `MATCH ()-[r]-(:Graphify) RETURN count(distinct r);` — matches `M`.
6. Re-run the same command. Counts should be identical (wipe-then-write).
7. With `GRAPHIFY__Neo4j__Uri` unset, run again. Confirm skip log line and unchanged DB (no wipe).

## Open risks

- `Neo4j.Driver` 5.x package compatibility with `net10.0` must be verified at implementation time; pick the latest stable that loads cleanly. Fallback: 5.15+ (the LTS line currently widely shipped).
- `Neo4j.Driver` adds a transitive dependency on `System.Reactive` (older 5.x versions). Acceptable for a CLI tool but flag in impl plan if a smaller surface is preferred (`Neo4j.Driver` exposes both async and Rx; async is what we use).

## References

- `src/Graphify/Export/Neo4jExporter.cs` — existing file exporter, kept intact.
- `src/Graphify.Cli/PipelineRunner.cs:253-258` — `case "neo4j":` branch to extend.
- `src/Graphify.Cli/Program.cs:177` (run), `Program.cs:206` (watch) — both `PipelineRunner` construction sites needing the new options.
- `src/Graphify.Cli/Configuration/GraphifyConfig.cs` — POCO to extend with `Neo4jSettings`.
- `.gitignore:24` — `appsettings.local.json` already excluded.
