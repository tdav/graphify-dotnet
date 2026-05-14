using System.Diagnostics;
using System.Text;
using Graphify.Graph;
using Graphify.Models;
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
            async tx =>
            {
                var cursor = await tx.RunAsync($"MATCH (n:{wipeLabel}) DETACH DELETE n").ConfigureAwait(false);
                await cursor.ConsumeAsync().ConfigureAwait(false);
                return 0;
            }).ConfigureAwait(false);

        // Idempotent uniqueness constraint
        await session.ExecuteWriteAsync(
            async tx =>
            {
                var cursor = await tx.RunAsync(
                    $"CREATE CONSTRAINT graphify_node_id IF NOT EXISTS " +
                    $"FOR (n:{wipeLabel}) REQUIRE n.id IS UNIQUE"
                ).ConfigureAwait(false);
                await cursor.ConsumeAsync().ConfigureAwait(false);
                return 0;
            }).ConfigureAwait(false);

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
                    async tx =>
                    {
                        var cursor = await tx.RunAsync(cypher, new { batch = payload }).ConfigureAwait(false);
                        await cursor.ConsumeAsync().ConfigureAwait(false);
                        return 0;
                    }).ConfigureAwait(false);
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
                    async tx =>
                    {
                        var cursor = await tx.RunAsync(cypher, new { batch = payload }).ConfigureAwait(false);
                        await cursor.ConsumeAsync().ConfigureAwait(false);
                        return 0;
                    }).ConfigureAwait(false);
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
        if (result.Length > 0 && char.IsDigit(result[0]))
        {
            result = "_" + result;
        }
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
