namespace Zalla.Core;

public enum ChromeLayout
{
    Island,
    Classic
}

public enum DockEdge
{
    None,
    Left,
    Top,
    Right,
    Bottom
}

public sealed class PrivacySettings
{
    public bool BlockTrackers { get; set; } = true;

    public bool BlockCommonAds { get; set; } = true;

    public bool FullAdBlocking { get; set; } = true;

    public bool HideAdSpaces { get; set; } = true;

    public bool CookieBanners { get; set; } = true;

    public bool HttpsOnly { get; set; } = true;

    public bool CleanLinks { get; set; } = true;

    public bool TrimReferrer { get; set; } = true;

    public bool Fingerprinting { get; set; } = true;

    public bool EncryptedDns { get; set; } = true;

    /// <summary>
    /// A proxy the person provides. Off until they add one. Zalla does not ship a server.
    /// </summary>
    public bool OwnProxy { get; set; }

    public string ProxyAddress { get; set; } = "";

    public static PrivacySettings CreateDefaults() => new();

    public bool ShieldOn =>
        BlockTrackers || BlockCommonAds || FullAdBlocking || HideAdSpaces || CookieBanners
        || HttpsOnly || CleanLinks || TrimReferrer || Fingerprinting || EncryptedDns;
}

public sealed class IslandPlacement
{
    public DockEdge Dock { get; set; } = DockEdge.Bottom;

    public double X { get; set; } = 0.5;

    public double Y { get; set; } = 0.9;

    public bool HasMoved { get; set; }
}

public sealed class TabState
{
    public string Id { get; set; } = "";

    public string Title { get; set; } = "New Tab";

    public string Url { get; set; } = "";
}

public sealed class SpaceState
{
    public string ThemeId { get; set; } = ThemeCatalog.WindowsStartThemeId;

    public List<TabState> Tabs { get; set; } = new();

    public int ActiveIndex { get; set; }

    public PrivacySettings Privacy { get; set; } = PrivacySettings.CreateDefaults();

    public int BlockedThisWeek { get; set; }

    public static SpaceState CreateNew()
    {
        return new SpaceState
        {
            Tabs = [new TabState { Id = Guid.NewGuid().ToString("N"), Title = "New Tab" }]
        };
    }
}

public sealed class AppSettings
{
    public ChromeLayout Layout { get; set; } = ChromeLayout.Island;

    public string SearchEngineId { get; set; } = SearchEngine.Brave.Id;

    public string CustomSearchTemplate { get; set; } = "";

    public SpaceKind LastSpace { get; set; } = SpaceKind.Personal;

    public IslandPlacement Island { get; set; } = new();
}
