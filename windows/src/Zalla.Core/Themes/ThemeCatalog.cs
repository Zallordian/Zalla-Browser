using System.Reflection;
using System.Text.Json;

namespace Zalla.Core;

public sealed class ThemeCatalog
{
    public const string WindowsStartThemeId = "lakeSuperior";

    static readonly JsonSerializerOptions Json = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true
    };

    readonly Dictionary<string, ThemeRecord> _byCompact = new(StringComparer.Ordinal);

    ThemeCatalog(ThemeDocument document)
    {
        Document = document;
        foreach (var theme in document.Themes)
        {
            _byCompact[Compact(theme.Id)] = theme;
            _byCompact[Compact(theme.Name)] = theme;
        }
    }

    public ThemeDocument Document { get; }

    public IReadOnlyList<ThemeRecord> Themes => Document.Themes;

    public static ThemeCatalog Load(Stream utf8)
    {
        var document = JsonSerializer.Deserialize<ThemeDocument>(utf8, Json)
            ?? throw new InvalidDataException("Theme file was empty.");
        if (document.Themes.Count == 0)
        {
            throw new InvalidDataException("Theme file has no themes.");
        }

        return new ThemeCatalog(document);
    }

    public static ThemeCatalog Load(string path)
    {
        using var stream = File.OpenRead(path);
        return Load(stream);
    }

    public static ThemeCatalog LoadEmbedded(Assembly? assembly = null)
    {
        assembly ??= typeof(ThemeCatalog).Assembly;
        var name = assembly.GetManifestResourceNames().Single(resource => resource.EndsWith("themes.json", StringComparison.OrdinalIgnoreCase));
        using var stream = assembly.GetManifestResourceStream(name)
            ?? throw new InvalidDataException("Embedded themes.json is missing.");
        return Load(stream);
    }

    public ThemeRecord? ById(string id)
    {
        return Document.Themes.FirstOrDefault(theme => string.Equals(theme.Id, id, StringComparison.OrdinalIgnoreCase));
    }

    public ThemeRecord Require(string id)
    {
        return ById(id) ?? ById(WindowsStartThemeId)
            ?? throw new InvalidDataException("Starting theme is missing from themes.json.");
    }

    /// <summary>
    /// Exact name or id, then a unique prefix. "lake" finds Lake Superior. "a" does not guess.
    /// </summary>
    public ThemeRecord? Match(string query)
    {
        var key = Compact(query);
        if (key.Length == 0)
        {
            return null;
        }

        if (_byCompact.TryGetValue(key, out var exact))
        {
            return exact;
        }

        var prefix = Document.Themes.Where(theme =>
            Compact(theme.Id).StartsWith(key, StringComparison.Ordinal)
            || Compact(theme.Name).StartsWith(key, StringComparison.Ordinal)).ToList();
        return prefix.Count == 1 ? prefix[0] : null;
    }

    public static string Compact(string value)
    {
        var chars = value.Where(char.IsLetterOrDigit).Select(char.ToLowerInvariant).ToArray();
        return new string(chars);
    }
}
