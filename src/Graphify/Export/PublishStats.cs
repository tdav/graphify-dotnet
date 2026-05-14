namespace Graphify.Export;

/// <summary>
/// Outcome of a Neo4j live publish operation.
/// </summary>
public sealed record PublishStats(int NodesWritten, int EdgesWritten, TimeSpan Elapsed);
