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
