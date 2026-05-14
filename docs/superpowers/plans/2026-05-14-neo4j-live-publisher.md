# Neo4j Live Publisher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `graphify run <path> --format neo4j` push the knowledge graph into a live Neo4j instance (configured via env vars or `appsettings.local.json`) while still writing the existing `graph.cypher` file.

**Architecture:** Add a `Neo4jLivePublisher` (uses `Neo4j.Driver` 5.x, parameterized `UNWIND` batches, label-scoped wipe with `:Graphify`). Wire it into the existing `case "neo4j":` branch in `PipelineRunner` so the file path is unchanged; the live push runs only when `Graphify:Neo4j:Uri` resolves. Add a small `samples/mini-library/` project for reproducible end-to-end runs.

**Tech Stack:** .NET 10, C#, `Neo4j.Driver` 5.x, `Microsoft.Extensions.Configuration`, existing `System.CommandLine` CLI in `Graphify.Cli`.

**Constraint from user:** No new tests, no changes to existing tests. Verification is manual (build + run + Cypher checks against Neo4j).

**Reference spec:** `docs/superpowers/specs/2026-05-14-neo4j-live-publisher-design.md`

---

## File Structure

**Create:**
- `src/Graphify/Export/Neo4jConnectionOptions.cs` — record carrying Bolt URI/user/password/db/wipe-label.
- `src/Graphify/Export/PublishStats.cs` — record returned by `PublishAsync`.
- `src/Graphify/Export/Neo4jLivePublisher.cs` — driver lifecycle, wipe, constraint, batched UNWIND inserts.
- `samples/mini-library/MiniLibrary.csproj` — `net10.0` console project, no references.
- `samples/mini-library/Models/Book.cs`
- `samples/mini-library/Models/Reader.cs`
- `samples/mini-library/Services/ILibraryService.cs`
- `samples/mini-library/Services/LibraryService.cs`
- `samples/mini-library/Infrastructure/IInventory.cs`
- `samples/mini-library/Infrastructure/InMemoryInventory.cs`
- `samples/mini-library/Program.cs`

**Modify:**
- `src/Graphify/Graphify.csproj` — add `Neo4j.Driver` PackageReference.
- `src/Graphify.Cli/Configuration/GraphifyConfig.cs` — add `Neo4jSettings` POCO + property.
- `src/Graphify.Cli/appsettings.json` — add `Graphify:Neo4j` defaults.
- `src/Graphify.Cli/PipelineRunner.cs` — add optional ctor param `Neo4jConnectionOptions? neo4jOptions = null`, extend `case "neo4j":` branch.
- `src/Graphify.Cli/Program.cs` — build `Neo4jConnectionOptions` from resolved config; pass into both `run` and `watch` command's `PipelineRunner` construction.

---

### Task 1: Add `Neo4j.Driver` package and create option types

**Files:**
- Modify: `src/Graphify/Graphify.csproj`
- Create: `src/Graphify/Export/Neo4jConnectionOptions.cs`
- Create: `src/Graphify/Export/PublishStats.cs`

- [ ] **Step 1: Add `Neo4j.Driver` PackageReference**

Find the existing `<ItemGroup>` that holds `PackageReference` entries in `src/Graphify/Graphify.csproj` (it sits with the other dependencies like `Microsoft.Extensions.AI`, `QuikGraph`, `TreeSitter.Bindings`). Add one line:

```xml
<PackageReference Include="Neo4j.Driver" Version="5.27.0" />
```

(`5.27.0` is the latest stable as of 2026-05; if a newer 5.x patch is available locally pin to that. Do not jump to 6.x without re-validating the `IAsyncSession` / `ExecuteWriteAsync` surface used in Task 2.)

- [ ] **Step 2: Restore packages and verify the project still builds**

Run: `dotnet restore src/Graphify/Graphify.csproj`
Then: `dotnet build src/Graphify/Graphify.csproj`
Expected: `Build succeeded.` with zero warnings caused by the new package (transitive `System.Reactive` is normal and not an error).

- [ ] **Step 3: Create `Neo4jConnectionOptions.cs`**

Write the file at `src/Graphify/Export/Neo4jConnectionOptions.cs`:

```csharp
namespace Graphify.Export;

/// <summary>
/// Connection settings for the live Neo4j publisher.
/// </summary>
public sealed record Neo4jConnectionOptions(
    string Uri,
    string User,
    string Password,
    string Database = "neo4j",
    string WipeLabel = "Graphify");
```

- [ ] **Step 4: Create `PublishStats.cs`**

Write the file at `src/Graphify/Export/PublishStats.cs`:

```csharp
namespace Graphify.Export;

/// <summary>
/// Outcome of a Neo4j live publish operation.
/// </summary>
public sealed record PublishStats(int NodesWritten, int EdgesWritten, TimeSpan Elapsed);
```

- [ ] **Step 5: Build to verify both types compile**

Run: `dotnet build src/Graphify/Graphify.csproj`
Expected: `Build succeeded.`

- [ ] **Step 6: Commit**

```bash
git add src/Graphify/Graphify.csproj src/Graphify/Export/Neo4jConnectionOptions.cs src/Graphify/Export/PublishStats.cs
git commit -m "feat(neo4j): add Neo4j.Driver package and connection/stats records"
```

---

### Task 2: Implement `Neo4jLivePublisher`

**Files:**
- Create: `src/Graphify/Export/Neo4jLivePublisher.cs`

- [ ] **Step 1: Create `Neo4jLivePublisher.cs`**

Write the file at `src/Graphify/Export/Neo4jLivePublisher.cs`:

```csharp
using System.Diagnostics;
using System.Text;
using Graphify.Graph;
using Neo4j.Driver;

namespace Graphify.Export;

/// <summary>
/// Publishes a knowledge graph into a live Neo4j instance using parameterized UNWIND batches.
/// Label-scoped wipe (deletes only nodes carrying the configured wipe label) followed by
/// constraint creation and batched node + edge inserts.
/// </summary>
public sealed class Neo4jLivePublisher
{
    private const int BatchSize = 500;

    public async Task<PublishStats> PublishAsync(
        KnowledgeGraph graph,
        Neo4jConnectionOptions options,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(graph);
        ArgumentNullException.ThrowIfNull(options);

        var stopwatch = Stopwatch.StartNew();
        var wipeLabel = SanitizeIdentifier(options.WipeLabel, fallback: "Graphify");

        await using var driver = GraphDatabase.Driver(
            options.Uri,
            AuthTokens.Basic(options.User, options.Password));

        await driver.VerifyConnectivityAsync().ConfigureAwait(false);

        await using var session = driver.AsyncSession(b => b.WithDatabase(options.Database));

        // Wipe label-scoped
        await session.ExecuteWriteAsync(
            tx => tx.RunAsync($"MATCH (n:{wipeLabel}) DETACH DELETE n").ContinueWith(_ => 0, cancellationToken),
            cancellationToken: cancellationToken).ConfigureAwait(false);

        // Idempotent uniqueness constraint
        await session.ExecuteWriteAsync(
            tx => tx.RunAsync(
                $"CREATE CONSTRAINT graphify_node_id IF NOT EXISTS " +
                $"FOR (n:{wipeLabel}) REQUIRE n.id IS UNIQUE"
            ).ContinueWith(_ => 0, cancellationToken),
            cancellationToken: cancellationToken).ConfigureAwait(false);

        // Nodes — grouped by sanitized type, batched
        var nodesWritten = 0;
        var nodeGroups = graph.GetNodes().GroupBy(n => SanitizeIdentifier(n.Type, fallback: "Node"));
        foreach (var group in nodeGroups)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var typeLabel = group.Key;
            var cypher =
                $"UNWIND $batch AS row " +
                $"CREATE (n:{wipeLabel}:{typeLabel}) " +
                $"SET n = row";

            foreach (var batch in Chunk(group, BatchSize))
            {
                var payload = batch.Select(BuildNodeRow).ToList();
                await session.ExecuteWriteAsync(
                    tx => tx.RunAsync(cypher, new { batch = payload })
                        .ContinueWith(_ => 0, cancellationToken),
                    cancellationToken: cancellationToken).ConfigureAwait(false);
                nodesWritten += payload.Count;
            }
        }

        // Edges — grouped by sanitized relationship, batched
        var edgesWritten = 0;
        var edgeGroups = graph.GetEdges()
            .GroupBy(e => SanitizeRelationshipType(e.Relationship ?? "RELATED_TO"));
        foreach (var group in edgeGroups)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var relType = group.Key;
            var cypher =
                $"UNWIND $batch AS row " +
                $"MATCH (a:{wipeLabel} {{id: row.source}}), (b:{wipeLabel} {{id: row.target}}) " +
                $"CREATE (a)-[r:{relType}]->(b) " +
                $"SET r.weight = row.weight, r.confidence = row.confidence";

            foreach (var batch in Chunk(group, BatchSize))
            {
                var payload = batch.Select(e => new Dictionary<string, object?>
                {
                    ["source"] = e.Source.Id,
                    ["target"] = e.Target.Id,
                    ["weight"] = e.Weight,
                    ["confidence"] = e.Confidence.ToString().ToUpperInvariant(),
                }).ToList();

                await session.ExecuteWriteAsync(
                    tx => tx.RunAsync(cypher, new { batch = payload })
                        .ContinueWith(_ => 0, cancellationToken),
                    cancellationToken: cancellationToken).ConfigureAwait(false);
                edgesWritten += payload.Count;
            }
        }

        stopwatch.Stop();
        return new PublishStats(nodesWritten, edgesWritten, stopwatch.Elapsed);
    }

    private static Dictionary<string, object?> BuildNodeRow(GraphNode node)
    {
        var row = new Dictionary<string, object?>
        {
            ["id"] = node.Id,
            ["label"] = node.Label ?? node.Id,
        };

        if (node.Community.HasValue)
        {
            row["community"] = node.Community.Value;
        }

        if (node.Metadata != null)
        {
            foreach (var (key, value) in node.Metadata)
            {
                if (string.IsNullOrWhiteSpace(value) || key == "label" || key == "id" || key == "community")
                {
                    continue;
                }

                var safeKey = SanitizePropertyName(key);
                if (!row.ContainsKey(safeKey))
                {
                    row[safeKey] = value;
                }
            }
        }

        return row;
    }

    private static IEnumerable<List<T>> Chunk<T>(IEnumerable<T> source, int size)
    {
        var buffer = new List<T>(size);
        foreach (var item in source)
        {
            buffer.Add(item);
            if (buffer.Count == size)
            {
                yield return buffer;
                buffer = new List<T>(size);
            }
        }

        if (buffer.Count > 0)
        {
            yield return buffer;
        }
    }

    // Identifier sanitizers — duplicate of Neo4jExporter helpers (kept private there for test stability).
    private static string SanitizeIdentifier(string? value, string fallback)
    {
        if (string.IsNullOrWhiteSpace(value)) return fallback;
        var sb = new StringBuilder();
        var first = true;
        foreach (var c in value)
        {
            if (char.IsLetter(c))
            {
                sb.Append(c);
                first = false;
            }
            else if (!first && char.IsDigit(c))
            {
                sb.Append(c);
            }
            else if (!first && c == '_')
            {
                sb.Append(c);
            }
            else if (!first)
            {
                sb.Append('_');
            }
        }

        var result = sb.ToString();
        return string.IsNullOrEmpty(result) ? fallback : result;
    }

    private static string SanitizeRelationshipType(string relationship)
    {
        if (string.IsNullOrWhiteSpace(relationship)) return "RELATED_TO";
        var sb = new StringBuilder();
        foreach (var c in relationship)
        {
            sb.Append(char.IsLetterOrDigit(c) ? char.ToUpperInvariant(c) : '_');
        }

        var result = sb.ToString();
        while (result.Contains("__")) result = result.Replace("__", "_");
        result = result.Trim('_');
        return string.IsNullOrEmpty(result) ? "RELATED_TO" : result;
    }

    private static string SanitizePropertyName(string name)
    {
        if (string.IsNullOrWhiteSpace(name)) return "property";
        var sb = new StringBuilder();
        var first = true;
        foreach (var c in name)
        {
            if (char.IsLetter(c))
            {
                sb.Append(first ? char.ToLowerInvariant(c) : c);
                first = false;
            }
            else if (!first && char.IsDigit(c))
            {
                sb.Append(c);
            }
            else if (!first && c == '_')
            {
                sb.Append(c);
            }
            else if (!first)
            {
                sb.Append('_');
            }
        }

        var result = sb.ToString();
        return string.IsNullOrEmpty(result) ? "property" : result;
    }
}
```

Notes for the implementer:
- `GraphNode` and the `KnowledgeGraph.GetNodes()` / `GetEdges()` methods already exist in `src/Graphify/Graph/`. Inspect them if any property reference does not compile (e.g., `node.Metadata` is a `Dictionary<string,string>?`).
- The `.ContinueWith(_ => 0, ct)` shim returns a typed `Task<int>` so `ExecuteWriteAsync` is satisfied; the count itself is discarded — we sum batch sizes ourselves.

- [ ] **Step 2: Build the project**

Run: `dotnet build src/Graphify/Graphify.csproj`
Expected: `Build succeeded.` If compile errors mention property names (`GraphNode.Type`, `GraphEdge.Relationship`, etc.) inspect `src/Graphify/Graph/GraphNode.cs` and `GraphEdge.cs` and adjust references — these are the only domain types this file touches.

- [ ] **Step 3: Commit**

```bash
git add src/Graphify/Export/Neo4jLivePublisher.cs
git commit -m "feat(neo4j): add Neo4jLivePublisher with UNWIND batching"
```

---

### Task 3: Extend `GraphifyConfig` with `Neo4jSettings` and add appsettings defaults

**Files:**
- Modify: `src/Graphify.Cli/Configuration/GraphifyConfig.cs`
- Modify: `src/Graphify.Cli/appsettings.json`

- [ ] **Step 1: Add `Neo4jSettings` POCO and property in `GraphifyConfig.cs`**

In `src/Graphify.Cli/Configuration/GraphifyConfig.cs`, add `using` if not present (the file currently has none — the new types don't need any new imports). Add a property to `GraphifyConfig` and a new class at the bottom of the file.

Inside the `GraphifyConfig` class (after the `CopilotSdk` property), append:

```csharp
    public Neo4jSettings Neo4j { get; set; } = new();
```

Append a new class at the end of the file:

```csharp
/// <summary>
/// Live Neo4j connection configuration.
/// Uri/User/Password must be set (env or appsettings.local.json) to enable live publish.
/// </summary>
public class Neo4jSettings
{
    public string? Uri { get; set; }
    public string? User { get; set; }
    public string? Password { get; set; }
    public string Database { get; set; } = "neo4j";
    public string WipeLabel { get; set; } = "Graphify";
}
```

- [ ] **Step 2: Add Neo4j defaults to `appsettings.json`**

Open `src/Graphify.Cli/appsettings.json` and replace the contents with:

```json
{
  "Graphify": {
    "Ollama": {
      "Endpoint": "http://localhost:11434",
      "ModelId": "llama3.2"
    },
    "CopilotSdk": {
      "ModelId": "gpt-4.1"
    },
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

- [ ] **Step 3: Verify build**

Run: `dotnet build src/Graphify.Cli/Graphify.Cli.csproj`
Expected: `Build succeeded.`

- [ ] **Step 4: Commit**

```bash
git add src/Graphify.Cli/Configuration/GraphifyConfig.cs src/Graphify.Cli/appsettings.json
git commit -m "feat(neo4j): add Neo4j config section to GraphifyConfig"
```

---

### Task 4: Wire `PipelineRunner` to use the publisher

**Files:**
- Modify: `src/Graphify.Cli/PipelineRunner.cs`

- [ ] **Step 1: Add optional ctor parameter and field**

Open `src/Graphify.Cli/PipelineRunner.cs`. Add this `using` near the top with the other usings:

```csharp
using Graphify.Export;
```

(`Graphify.Export` is already used implicitly via the type names in the `switch` — adding the using makes the new `Neo4jConnectionOptions` reference unambiguous.)

Replace the existing field block (currently three fields) and constructor with:

```csharp
    private readonly TextWriter _output;
    private readonly bool _verbose;
    private readonly IChatClient? _chatClient;
    private readonly Neo4jConnectionOptions? _neo4jOptions;

    public PipelineRunner(
        TextWriter output,
        bool verbose = false,
        IChatClient? chatClient = null,
        Neo4jConnectionOptions? neo4jOptions = null)
    {
        _output = output ?? throw new ArgumentNullException(nameof(output));
        _verbose = verbose;
        _chatClient = chatClient;
        _neo4jOptions = neo4jOptions;
    }
```

The new parameter has a default of `null`, so every existing `new PipelineRunner(...)` call site keeps compiling (this is why no test changes are required).

- [ ] **Step 2: Extend the `case "neo4j":` branch**

In the export `switch` (around `PipelineRunner.cs:253-258`), replace the existing `case "neo4j":` block with:

```csharp
                        case "neo4j":
                            var neo4jExporter = new Neo4jExporter();
                            var cypherPath = Path.Combine(outputDir, "graph.cypher");
                            await neo4jExporter.ExportAsync(graph, cypherPath, cancellationToken);
                            await WriteLineAsync($"      Exported Neo4j Cypher: {cypherPath}");

                            if (_neo4jOptions is not null)
                            {
                                await WriteLineAsync(
                                    $"      Publishing to Neo4j: {_neo4jOptions.Uri} (user: {_neo4jOptions.User}) ...");
                                try
                                {
                                    var publisher = new Neo4jLivePublisher();
                                    var stats = await publisher.PublishAsync(graph, _neo4jOptions, cancellationToken);
                                    await WriteLineAsync(
                                        $"      Published: {stats.NodesWritten} nodes, {stats.EdgesWritten} edges " +
                                        $"({stats.Elapsed.TotalSeconds:F1}s)");
                                }
                                catch (Neo4j.Driver.AuthenticationException)
                                {
                                    await WriteLineAsync(
                                        $"      Error: Neo4j auth failed for user {_neo4jOptions.User}");
                                }
                                catch (Neo4j.Driver.ServiceUnavailableException ex)
                                {
                                    await WriteLineAsync(
                                        $"      Error: Neo4j unreachable at {_neo4jOptions.Uri}: {ex.Message}");
                                }
                                catch (Neo4j.Driver.ClientException ex)
                                {
                                    await WriteLineAsync($"      Error: Cypher rejected: {ex.Message}");
                                }
                            }
                            else
                            {
                                await WriteLineAsync(
                                    "      Neo4j connection not configured (set GRAPHIFY__Neo4j__Uri), skipping live publish");
                            }
                            break;
```

Notes:
- The outer `try`/`catch (Exception ex)` already wrapping `foreach (var format in formats)` (around `PipelineRunner.cs:294-298`) still catches anything we don't explicitly handle here — file export already succeeded so the pipeline continues with other formats.
- The password is never written to `_output`. Only `Uri` and `User` appear.

- [ ] **Step 3: Build to verify**

Run: `dotnet build src/Graphify.Cli/Graphify.Cli.csproj`
Expected: `Build succeeded.` Existing test projects keep compiling because of the default `null` parameter.

- [ ] **Step 4: Commit**

```bash
git add src/Graphify.Cli/PipelineRunner.cs
git commit -m "feat(neo4j): wire Neo4jLivePublisher into PipelineRunner"
```

---

### Task 5: Build `Neo4jConnectionOptions` in `Program.cs` and pass into both `run` and `watch`

**Files:**
- Modify: `src/Graphify.Cli/Program.cs`

- [ ] **Step 1: Add helper that resolves connection options**

Open `src/Graphify.Cli/Program.cs`. Near the top of the file, add a `using` if not present:

```csharp
using Graphify.Export;
```

In the helper section (next to `ResolveProviderAsync`), add a new local static method **above** the `// ── run command ──` divider:

```csharp
static Neo4jConnectionOptions? BuildNeo4jOptions()
{
    var configuration = ConfigurationFactory.Build();
    var graphifyConfig = new GraphifyConfig();
    configuration.GetSection("Graphify").Bind(graphifyConfig);

    var settings = graphifyConfig.Neo4j;
    if (string.IsNullOrWhiteSpace(settings.Uri))
    {
        return null;
    }

    if (string.IsNullOrWhiteSpace(settings.User) || string.IsNullOrWhiteSpace(settings.Password))
    {
        Console.WriteLine(
            $"⚠ Neo4j Uri is set ({settings.Uri}) but User/Password are missing. Live publish will be skipped.");
        return null;
    }

    return new Neo4jConnectionOptions(
        Uri: settings.Uri,
        User: settings.User,
        Password: settings.Password,
        Database: settings.Database,
        WipeLabel: settings.WipeLabel);
}
```

- [ ] **Step 2: Pass `Neo4jConnectionOptions?` into the `run` command's runner**

Locate the `runCommand.SetAction(async (parseResult, cancellationToken) => { ... });` block (around `Program.cs:142-180`). Find the line:

```csharp
    var runner = new Graphify.Cli.PipelineRunner(Console.Out, verbose, chatClient);
```

Replace it with:

```csharp
    var neo4jOptions = BuildNeo4jOptions();
    var runner = new Graphify.Cli.PipelineRunner(Console.Out, verbose, chatClient, neo4jOptions);
```

- [ ] **Step 3: Pass `Neo4jConnectionOptions?` into the `watch` command's runner**

In the `watchCommand.SetAction(async (parseResult, cancellationToken) => { ... });` block (around `Program.cs:194-220`), find the line:

```csharp
    var runner = new Graphify.Cli.PipelineRunner(Console.Out, verbose, chatClient);
```

Replace with:

```csharp
    var neo4jOptions = BuildNeo4jOptions();
    var runner = new Graphify.Cli.PipelineRunner(Console.Out, verbose, chatClient, neo4jOptions);
```

(`WatchMode` continues to consume this injected runner unchanged — no edits needed there.)

- [ ] **Step 4: Build the full solution**

Run: `dotnet build graphify-dotnet.slnx`
Expected: `Build succeeded.` All test projects keep compiling thanks to the default-null parameter on `PipelineRunner`.

- [ ] **Step 5: Commit**

```bash
git add src/Graphify.Cli/Program.cs
git commit -m "feat(neo4j): wire Neo4jConnectionOptions into run and watch CLI commands"
```

---

### Task 6: Create `samples/mini-library/`

**Files (all created):**
- `samples/mini-library/MiniLibrary.csproj`
- `samples/mini-library/Models/Book.cs`
- `samples/mini-library/Models/Reader.cs`
- `samples/mini-library/Services/ILibraryService.cs`
- `samples/mini-library/Services/LibraryService.cs`
- `samples/mini-library/Infrastructure/IInventory.cs`
- `samples/mini-library/Infrastructure/InMemoryInventory.cs`
- `samples/mini-library/Program.cs`

- [ ] **Step 1: Create the csproj**

Write `samples/mini-library/MiniLibrary.csproj`:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>MiniLibrary</RootNamespace>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
</Project>
```

(Standalone, not registered in `graphify-dotnet.slnx` — graphify reads files via the detector, not via solution wiring.)

- [ ] **Step 2: Create `Models/Book.cs`**

```csharp
namespace MiniLibrary.Models;

public sealed record Book(string Id, string Title, string Author);
```

- [ ] **Step 3: Create `Models/Reader.cs`**

```csharp
namespace MiniLibrary.Models;

public sealed record Reader(string Id, string Name);
```

- [ ] **Step 4: Create `Infrastructure/IInventory.cs`**

```csharp
using MiniLibrary.Models;

namespace MiniLibrary.Infrastructure;

public interface IInventory
{
    bool Reserve(Book book, Reader reader);
    void Release(Book book);
    IReadOnlyCollection<Book> AvailableBooks();
}
```

- [ ] **Step 5: Create `Infrastructure/InMemoryInventory.cs`**

```csharp
using MiniLibrary.Models;

namespace MiniLibrary.Infrastructure;

public sealed class InMemoryInventory : IInventory
{
    private readonly Dictionary<string, Book> books = new();
    private readonly Dictionary<string, Reader> reservations = new();

    public InMemoryInventory(IEnumerable<Book> seed)
    {
        foreach (var book in seed)
        {
            this.books[book.Id] = book;
        }
    }

    public bool Reserve(Book book, Reader reader)
    {
        if (!this.books.ContainsKey(book.Id) || this.reservations.ContainsKey(book.Id))
        {
            return false;
        }

        this.reservations[book.Id] = reader;
        return true;
    }

    public void Release(Book book)
    {
        this.reservations.Remove(book.Id);
    }

    public IReadOnlyCollection<Book> AvailableBooks()
    {
        return this.books.Values
            .Where(b => !this.reservations.ContainsKey(b.Id))
            .ToList();
    }
}
```

- [ ] **Step 6: Create `Services/ILibraryService.cs`**

```csharp
using MiniLibrary.Models;

namespace MiniLibrary.Services;

public interface ILibraryService
{
    bool BorrowBook(string bookId, Reader reader);
    void ReturnBook(string bookId);
}
```

- [ ] **Step 7: Create `Services/LibraryService.cs`**

```csharp
using MiniLibrary.Infrastructure;
using MiniLibrary.Models;

namespace MiniLibrary.Services;

public sealed class LibraryService : ILibraryService
{
    private readonly IInventory inventory;

    public LibraryService(IInventory inventory)
    {
        this.inventory = inventory;
    }

    public bool BorrowBook(string bookId, Reader reader)
    {
        var book = this.inventory.AvailableBooks().FirstOrDefault(b => b.Id == bookId);
        if (book is null)
        {
            return false;
        }

        return this.inventory.Reserve(book, reader);
    }

    public void ReturnBook(string bookId)
    {
        var book = new Book(bookId, Title: string.Empty, Author: string.Empty);
        this.inventory.Release(book);
    }
}
```

- [ ] **Step 8: Create `Program.cs`**

```csharp
using MiniLibrary.Infrastructure;
using MiniLibrary.Models;
using MiniLibrary.Services;

var seed = new[]
{
    new Book("b1", "The Pragmatic Programmer", "Hunt & Thomas"),
    new Book("b2", "Code Complete", "McConnell"),
    new Book("b3", "Refactoring", "Fowler"),
};

IInventory inventory = new InMemoryInventory(seed);
ILibraryService library = new LibraryService(inventory);

var alice = new Reader("r1", "Alice");
var bob = new Reader("r2", "Bob");

Console.WriteLine($"Alice borrows b1: {library.BorrowBook("b1", alice)}");
Console.WriteLine($"Bob borrows b1: {library.BorrowBook("b1", bob)}");
Console.WriteLine($"Bob borrows b2: {library.BorrowBook("b2", bob)}");
library.ReturnBook("b1");
Console.WriteLine($"Bob borrows b1 after Alice returned: {library.BorrowBook("b1", bob)}");
```

- [ ] **Step 9: Verify the sample itself compiles**

Run: `dotnet build samples/mini-library/MiniLibrary.csproj`
Expected: `Build succeeded.`

- [ ] **Step 10: Commit**

```bash
git add samples/mini-library
git commit -m "feat(samples): add mini-library sample for neo4j repro"
```

---

### Task 7: End-to-end manual verification

This task has no code changes. It exercises the wired path against the user's Neo4j instance.

- [ ] **Step 1: Set env vars (PowerShell, current session only)**

```powershell
$env:GRAPHIFY__Neo4j__Uri = "bolt://192.168.0.211:7687"
$env:GRAPHIFY__Neo4j__User = "neo4j"
$env:GRAPHIFY__Neo4j__Password = "<password>"
```

(The user-provided password from the task brief goes here. Do NOT commit it. Do NOT paste it into `appsettings.json`; if persistence is wanted use `appsettings.local.json` which `.gitignore` already excludes.)

- [ ] **Step 2: Run the full pipeline against the sample**

Run: `dotnet run --project src/Graphify.Cli -- run samples/mini-library --format neo4j --verbose`

Expected console output near the bottom:

```
[6/6] Exporting results...
      Exported Neo4j Cypher: graphify-out/graph.cypher
      Publishing to Neo4j: bolt://192.168.0.211:7687 (user: neo4j) ...
      Published: <N> nodes, <M> edges (<X.Y>s)
```

If the line `Neo4j connection not configured (set GRAPHIFY__Neo4j__Uri), skipping live publish` appears instead, the env vars did not propagate — re-check Step 1.

- [ ] **Step 3: Confirm the file landed on disk**

Run: `Test-Path graphify-out/graph.cypher`
Expected: `True`.

- [ ] **Step 4: Confirm node count in Neo4j**

From cypher-shell or Neo4j Browser at `bolt://192.168.0.211:7687`:

```cypher
MATCH (n:Graphify) RETURN count(n) AS nodes;
```

Expected: matches the `<N>` from Step 2 output.

- [ ] **Step 5: Confirm edge count in Neo4j**

```cypher
MATCH (:Graphify)-[r]->(:Graphify) RETURN count(r) AS edges;
```

Expected: matches the `<M>` from Step 2 output.

- [ ] **Step 6: Confirm idempotency (re-run is wipe-then-write)**

Run the same command again:

```
dotnet run --project src/Graphify.Cli -- run samples/mini-library --format neo4j --verbose
```

Then re-check the `count(n)` and `count(r)` queries — they must return the same numbers as before (no duplication).

- [ ] **Step 7: Confirm skip behavior with no env config**

```powershell
Remove-Item Env:GRAPHIFY__Neo4j__Uri
Remove-Item Env:GRAPHIFY__Neo4j__User
Remove-Item Env:GRAPHIFY__Neo4j__Password
dotnet run --project src/Graphify.Cli -- run samples/mini-library --format neo4j
```

Expected the log line:
```
Neo4j connection not configured (set GRAPHIFY__Neo4j__Uri), skipping live publish
```

The DB on `192.168.0.211` should still hold the previous run's data (the skip path does not wipe).

- [ ] **Step 8: (Optional) Smoke-test the wired `watch` command**

```powershell
$env:GRAPHIFY__Neo4j__Uri = "bolt://192.168.0.211:7687"
$env:GRAPHIFY__Neo4j__User = "neo4j"
$env:GRAPHIFY__Neo4j__Password = "<password>"
dotnet run --project src/Graphify.Cli -- watch samples/mini-library --format neo4j
```

Expected: same `Publishing to Neo4j: ...` log on initial pipeline. Touch a file under `samples/mini-library/` — confirm the watch re-runs and publishes again. Stop with Ctrl-C.

- [ ] **Step 9: Final commit (none — verification only)**

No code changes in this task. If notes need to be captured, do it outside the repo or in a follow-up commit.

---

## Self-Review

**Spec coverage check (sections in `docs/superpowers/specs/2026-05-14-neo4j-live-publisher-design.md`):**

- Goal / scope — covered by Tasks 1–7 in total.
- Architecture (Neo4jLivePublisher, Neo4jConnectionOptions, PublishStats, GraphifyConfig.Neo4j) — Tasks 1 (option types), 2 (publisher), 3 (config), 4 (PipelineRunner ctor + branch).
- Configuration (appsettings, env, gitignore note) — Task 3 covers `appsettings.json`. `appsettings.local.json` is user-managed at runtime (Task 7 Step 1). `.gitignore` was confirmed during brainstorming.
- Cypher strategy (wipe, constraint, UNWIND-with-`SET n = row`, batched edges) — Task 2 implementation.
- Data flow (PipelineRunner case branch, run + watch) — Tasks 4 and 5.
- Error handling — covered by the try/catch block in Task 4 Step 2 and the outer try/catch already in `PipelineRunner` (untouched).
- Sample folder — Task 6.
- Verification — Task 7.

**Placeholder scan:** No "TBD", "TODO", "fill in", or "similar to" markers. All code blocks are concrete. The `<password>` token in Task 7 is intentional and explicitly called out.

**Type consistency:**
- `Neo4jConnectionOptions(Uri, User, Password, Database, WipeLabel)` — same property names in Tasks 1, 4, 5, and `BuildNeo4jOptions` in Task 5.
- `PublishStats(NodesWritten, EdgesWritten, Elapsed)` — same fields in Task 2 (creation) and Task 4 (consumption).
- `Neo4jSettings` POCO (`Uri`, `User`, `Password`, `Database`, `WipeLabel`) in Task 3 mirrors the record's parameter names — `BuildNeo4jOptions` in Task 5 maps each by name.
- `Neo4jLivePublisher.PublishAsync(graph, options, ct)` — same signature used in Task 4.

**Existing-test stability:**
- All `new PipelineRunner(...)` call sites in `src/tests/` use 1, 2, or 3 positional args. The added parameter is positional after `chatClient` with `= null` default → every existing call site keeps compiling without edits.
- `Neo4jExporter.cs` is untouched → existing `Neo4jExporterTests` keep passing.

No further fixes needed.
