using System.Text.Json;

namespace Zalla.Core;

public static class SettingsStore
{
    public static readonly JsonSerializerOptions Json = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true
    };

    public static string SettingsPath(string root) => Path.Combine(root, "settings.json");

    public static string SpacesRoot(string root) => Path.Combine(root, "Spaces");

    public static string SpaceDirectory(string root, SpaceKind space) =>
        Path.Combine(SpacesRoot(root), SpaceNames.Folder(space));

    public static string WebViewDirectory(string root, SpaceKind space) =>
        Path.Combine(SpaceDirectory(root, space), "WebView2");

    public static string SpaceStatePath(string root, SpaceKind space) =>
        Path.Combine(SpaceDirectory(root, space), "state.json");

    public static AppSettings LoadApp(string root)
    {
        return Read(SettingsPath(root), new AppSettings());
    }

    public static void SaveApp(string root, AppSettings settings)
    {
        Directory.CreateDirectory(root);
        Write(SettingsPath(root), settings);
    }

    public static SpaceState LoadSpace(string root, SpaceKind space)
    {
        var state = Read<SpaceState?>(SpaceStatePath(root, space), null);
        if (state is null || state.Tabs.Count == 0)
        {
            state = SpaceState.CreateNew();
        }

        state.Privacy ??= PrivacySettings.CreateDefaults();
        if (string.IsNullOrWhiteSpace(state.ThemeId))
        {
            state.ThemeId = ThemeCatalog.WindowsStartThemeId;
        }

        state.ActiveIndex = Math.Clamp(state.ActiveIndex, 0, state.Tabs.Count - 1);
        return state;
    }

    public static void SaveSpace(string root, SpaceKind space, SpaceState state)
    {
        if (SpaceWipe.WipesOnClose(space))
        {
            return;
        }

        var directory = SpaceDirectory(root, space);
        Directory.CreateDirectory(directory);
        Write(SpaceStatePath(root, space), state);
    }

    static T Read<T>(string path, T fallback)
    {
        try
        {
            if (!File.Exists(path))
            {
                return fallback;
            }

            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<T>(json, Json) ?? fallback;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException or JsonException)
        {
            return fallback;
        }
    }

    static void Write<T>(string path, T value)
    {
        var json = JsonSerializer.Serialize(value, Json);
        var temp = path + ".tmp";
        File.WriteAllText(temp, json);
        File.Move(temp, path, overwrite: true);
    }
}
