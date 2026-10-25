namespace Zalla.Core;

public enum AddressKind
{
    Empty,
    Web,
    Search,
    Rejected
}

public readonly record struct ResolvedAddress(AddressKind Kind, string Url)
{
    public static ResolvedAddress Empty { get; } = new(AddressKind.Empty, "");
}

public sealed class SearchEngine
{
    SearchEngine(string id, string label, string endpoint, string parameter)
    {
        Id = id;
        Label = label;
        Endpoint = endpoint;
        Parameter = parameter;
    }

    public string Id { get; }

    public string Label { get; }

    public string Endpoint { get; }

    public string Parameter { get; }

    public static SearchEngine Google { get; } = new("Google", "Google", "https://www.google.com/search", "q");
    public static SearchEngine Bing { get; } = new("Bing", "Bing", "https://www.bing.com/search", "q");
    public static SearchEngine DuckDuckGo { get; } = new("DuckDuckGo", "DuckDuckGo", "https://duckduckgo.com/", "q");
    public static SearchEngine Brave { get; } = new("Brave Search", "Brave Search", "https://search.brave.com/search", "q");
    public static SearchEngine Startpage { get; } = new("Startpage", "Startpage", "https://www.startpage.com/sp/search", "query");
    public static SearchEngine Ecosia { get; } = new("Ecosia", "Ecosia", "https://www.ecosia.org/search", "q");
    public static SearchEngine Kagi { get; } = new("Kagi", "Kagi", "https://kagi.com/search", "q");
    public static SearchEngine Custom { get; } = new("Custom URL", "Custom URL", "", "q");

    public static IReadOnlyList<SearchEngine> All { get; } =
    [
        Google, Bing, DuckDuckGo, Brave, Startpage, Ecosia, Kagi, Custom
    ];

    public static SearchEngine Default { get; } = Brave;

    public static SearchEngine Find(string? id)
    {
        return All.FirstOrDefault(engine => string.Equals(engine.Id, id, StringComparison.OrdinalIgnoreCase)) ?? Default;
    }
}

public static class AddressResolver
{
    public static bool LooksNavigable(string text)
    {
        var trimmed = text.Trim();
        if (trimmed.Length == 0 || trimmed.Any(char.IsWhiteSpace))
        {
            return false;
        }

        if (HasWebScheme(trimmed) || IsRejectedScheme(trimmed))
        {
            return true;
        }

        return LooksLikeHost(trimmed);
    }

    public static ResolvedAddress Resolve(string input, SearchEngine engine, string? customTemplate = null)
    {
        var text = input.Trim();
        if (text.Length == 0)
        {
            return ResolvedAddress.Empty;
        }

        if (IsRejectedScheme(text))
        {
            return new ResolvedAddress(AddressKind.Rejected, "");
        }

        if (HasWebScheme(text) && Uri.TryCreate(text, UriKind.Absolute, out var absolute) && HasHost(absolute))
        {
            return new ResolvedAddress(AddressKind.Web, absolute.AbsoluteUri);
        }

        if (LooksLikeHost(text))
        {
            var candidate = text.StartsWith("//", StringComparison.Ordinal) ? "https:" + text : "https://" + text;
            if (Uri.TryCreate(candidate, UriKind.Absolute, out var hostUrl) && HasHost(hostUrl) && hostUrl.UserInfo.Length == 0)
            {
                return new ResolvedAddress(AddressKind.Web, hostUrl.AbsoluteUri);
            }
        }

        var search = SearchUrl(text, engine, customTemplate);
        return search is null
            ? new ResolvedAddress(AddressKind.Rejected, "")
            : new ResolvedAddress(AddressKind.Search, search);
    }

    public static string? SearchUrl(string query, SearchEngine engine, string? customTemplate)
    {
        var trimmed = query.Trim();
        if (trimmed.Length == 0)
        {
            return null;
        }

        if (engine.Id == SearchEngine.Custom.Id)
        {
            var custom = CustomUrl(customTemplate, trimmed);
            return custom ?? SearchUrl(trimmed, SearchEngine.Default, null);
        }

        var encoded = Uri.EscapeDataString(trimmed);
        var separator = engine.Endpoint.Contains('?', StringComparison.Ordinal) ? "&" : "?";
        return engine.Endpoint + separator + engine.Parameter + "=" + encoded;
    }

    public static string? CustomUrl(string? template, string query)
    {
        if (string.IsNullOrWhiteSpace(template) || !template.Contains("%s", StringComparison.Ordinal))
        {
            return null;
        }

        var encoded = Uri.EscapeDataString(query);
        var built = template.Replace("%s", encoded, StringComparison.Ordinal);
        if (!Uri.TryCreate(built, UriKind.Absolute, out var url) || !HasWebScheme(built) || !HasHost(url))
        {
            return null;
        }

        return url.AbsoluteUri;
    }

    static bool LooksLikeHost(string text)
    {
        if (text.Contains("://", StringComparison.Ordinal) || text.Any(char.IsWhiteSpace))
        {
            return false;
        }

        var lower = text.ToLowerInvariant();
        if (lower.StartsWith("localhost", StringComparison.Ordinal) || lower.StartsWith("127.0.0.1", StringComparison.Ordinal))
        {
            return true;
        }

        return text.Contains('.', StringComparison.Ordinal);
    }

    static bool HasWebScheme(string text)
    {
        return text.StartsWith("https://", StringComparison.OrdinalIgnoreCase)
            || text.StartsWith("http://", StringComparison.OrdinalIgnoreCase);
    }

    static bool IsRejectedScheme(string text)
    {
        var lower = text.ToLowerInvariant();
        return lower.StartsWith("javascript:", StringComparison.Ordinal)
            || lower.StartsWith("data:", StringComparison.Ordinal)
            || lower.StartsWith("file:", StringComparison.Ordinal)
            || lower.StartsWith("about:", StringComparison.Ordinal);
    }

    static bool HasHost(Uri url)
    {
        return !string.IsNullOrEmpty(url.Host) && url.UserInfo.Length == 0;
    }
}
