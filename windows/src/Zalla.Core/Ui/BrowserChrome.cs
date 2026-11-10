namespace Zalla.Core;

public sealed record ChromeCommand(string Label, string Shortcut, string Action, bool SeparatorBefore);

public static class BrowserChrome
{
    public static IReadOnlyList<string> Toolbar { get; } =
    [
        "Back",
        "Forward",
        "Reload",
        "Address",
        "Bookmark",
        "Shield",
        "Menu"
    ];

    public static IReadOnlyList<ChromeCommand> Menu { get; } =
    [
        new("New tab", "Ctrl+T", "new-tab", false),
        new("Bookmarks", "", "bookmarks", false),
        new("History", "Ctrl+H", "history", false),
        new("Downloads", "", "downloads", false),
        new("Extensions", "", "extensions", true),
        new("Settings", "", "settings", false),
        new("Floating cards", "", "deck", true),
        new("Burn It All", "", "burn", true)
    ];

    public static IReadOnlyList<string> SettingsSections { get; } =
    [
        "Appearance",
        "Search",
        "Privacy",
        "About"
    ];

    public static bool FloatsShield(ChromeLayout layout) => layout == ChromeLayout.Island;
}
