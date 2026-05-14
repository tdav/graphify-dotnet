namespace Graphify.Export;

/// <summary>
/// Connection settings for the live Neo4j publisher.
/// </summary>
/// <param name="Uri">Bolt URI, e.g. <c>bolt://localhost:7687</c>.</param>
/// <param name="User">Neo4j auth user name.</param>
/// <param name="Password">Neo4j auth password.</param>
/// <param name="Database">Target database name (default <c>neo4j</c>).</param>
/// <param name="WipeLabel">Label used to scope the pre-write wipe (default <c>Graphify</c>).</param>
public sealed record Neo4jConnectionOptions(
    string Uri,
    string User,
    string Password,
    string Database = "neo4j",
    string WipeLabel = "Graphify");
