namespace Graphify.Cli.Configuration;

/// <summary>
/// Root configuration model for Graphify settings.
/// </summary>
public class GraphifyConfig
{
    public string? Provider { get; set; }
    public string? WorkingFolder { get; set; }
    public string? OutputFolder { get; set; }
    public string? ExportFormats { get; set; }
    public AzureOpenAIConfig AzureOpenAI { get; set; } = new();
    public OllamaConfig Ollama { get; set; } = new();
    public CopilotSdkConfig CopilotSdk { get; set; } = new();
    public Neo4jSettings Neo4j { get; set; } = new();
}

/// <summary>
/// Azure OpenAI provider configuration.
/// </summary>
public class AzureOpenAIConfig
{
    public string? Endpoint { get; set; }
    public string? ApiKey { get; set; }
    public string? DeploymentName { get; set; }
    public string? ModelId { get; set; }
}

/// <summary>
/// Ollama provider configuration with sensible local defaults.
/// </summary>
public class OllamaConfig
{
    public string Endpoint { get; set; } = "http://localhost:11434";
    public string ModelId { get; set; } = "llama3.2";
}

/// <summary>
/// GitHub Copilot SDK provider configuration.
/// Authentication is handled by the GitHub Copilot CLI (user must be logged in).
/// </summary>
public class CopilotSdkConfig
{
    public string ModelId { get; set; } = "gpt-4.1";
}

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
