namespace Zalla;

static class Copy
{
    public const string SearchPlaceholder = "Search, type a site, or press / for commands";
    public const string CommandPlaceholder = "Type a command";
    public const string IslandHint = "Drag it anywhere, or dock it on an edge";
    public const string NewCard = "New card    Ctrl T";
    public const string ShieldOn = "Shield on";
    public const string ShieldOff = "Shield off";
    public const string ClickToTune = "Click to tune";
    public const string BlockedWeek = "blocked this week";
    public const string Trackers = "Trackers";
    public const string Ads = "Ads";
    public const string CookieBanners = "Cookie banners";
    public const string HttpsOnly = "HTTPS-Only";
    public const string Fingerprinting = "Fingerprinting";
    public const string BurnTooltip = "Burn It All";
    public const string Back = "Back";
    public const string Forward = "Forward";
    public const string Menu = "Zalla menu";
    public const string NewTab = "New tab";
    public const string Settings = "Settings";
    public const string Close = "Close";
    public const string Minimize = "Minimize";
    public const string Maximize = "Maximize";
    public const string Restore = "Restore";
    public const string WebOnly = "Zalla only opens web pages.";
    public const string NoTheme = "No theme named that.";
    public const string NeedAnother = "Open another card to sit side by side.";
    public const string WebViewMissing = "This PC needs the Microsoft Edge WebView2 Runtime before pages can load. Windows 11 usually has it already.";
    public const string GhostNote = "Ghost forgets this Space when you leave it.";
    public const string CloseSplit = "Close split";
    public const string DropToSplit = "Drop to sit side by side";
    public const string LayoutIsland = "Command Island";
    public const string LayoutClassic = "Classic tab strip";
    public const string LayoutHelp = "Command Island keeps the page full screen. Classic puts a tab strip on top.";
    public const string PrivacyNote = "Link cleaning, HTTPS-Only, referrer trimming, and Burn It All work now. Tracker lists, ad lists, cookie banner hiding, fingerprint changes, and encrypted DNS are saved and on. They take effect when those pieces land.";
    public const string ProxyTitle = "Use my own proxy";
    public const string ProxyDetail = "Sends page traffic through a proxy you provide. Zalla does not ship a proxy, and it does not hide your IP on its own. Leave this off until you have an address. Routing through it comes in a later update.";
    public const string About = "Zalla for Windows. Pages load with Microsoft Edge WebView2, which is already on most Windows 11 PCs.";
    public const string Spaces = "SPACES";
    public const string Appearance = "Appearance";
    public const string Privacy = "Privacy";
    public const string Search = "Search";
    public const string AboutTitle = "About";
    public const string BurnFailed = "Zalla could not clear everything. Close the app and open it again.";
    public const string Colors = "Colors";
    public const string Themes = "Themes";
    public const string Pro = "Pro";
    public const string Seasons = "Seasons";
    public const string CustomSearch = "Custom search address, with %s where the words go";

    public static readonly string[] Sayings =
    [
        "Where to next?",
        "Browse quietly.",
        "Private by default.",
        "Start somewhere.",
        "Ready when you are.",
        "Look something up."
    ];

    public static string ThemeOn(string name) => name + " is on.";

    public static string Cleared(string space) => space + " is cleared.";

    public static string DeckCount(int count) => count == 1 ? "DECK  ·  1 TAB" : $"DECK  ·  {count} TABS";
}
