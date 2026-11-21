namespace Zalla.Core;

public static class ShieldPresentation
{
    public const string Title = "Shield preview";

    public const string NotCounting = "Not counting blocks yet.";

    public static string Detail(bool httpsOnly, bool cleanLinks)
    {
        if (httpsOnly && cleanLinks)
        {
            return "HTTPS-Only and link cleaning are on. Tracker and ad blocking are not active yet.";
        }

        if (httpsOnly)
        {
            return "HTTPS-Only is on. Tracker and ad blocking are not active yet.";
        }

        if (cleanLinks)
        {
            return "Link cleaning is on. Tracker and ad blocking are not active yet.";
        }

        return "Tracker and ad blocking are not active yet.";
    }

    public static IReadOnlyList<(string Name, string State)> Lines(bool httpsOnly)
    {
        return
        [
            ("HTTPS-Only", httpsOnly ? "on" : "off"),
            ("Trackers", "preview"),
            ("Ads", "preview"),
            ("Cookie banners", "preview"),
            ("Fingerprinting", "preview")
        ];
    }

    public static string Format(string name, string state) => name + "  " + state;
}
