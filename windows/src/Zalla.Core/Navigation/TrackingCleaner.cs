namespace Zalla.Core;

/// <summary>
/// Same tracking parameter names the iOS app strips.
/// </summary>
public static class TrackingCleaner
{
    static readonly HashSet<string> Exact = new(StringComparer.OrdinalIgnoreCase)
    {
        "fbclid", "gclid", "gclsrc", "dclid", "gbraid", "wbraid", "msclkid", "yclid", "twclid", "ttclid",
        "igshid", "mc_eid", "mc_cid", "_hsenc", "_hsmi", "hsctatracking", "mkt_tok", "vero_id", "vero_conv",
        "oly_enc_id", "oly_anon_id", "s_cid", "rb_clickid", "_openstat", "ref_src"
    };

    public static bool IsTracking(string name)
    {
        return name.StartsWith("utm_", StringComparison.OrdinalIgnoreCase) || Exact.Contains(name);
    }

    public static bool TryClean(string url, out string cleaned)
    {
        cleaned = url;
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || string.IsNullOrEmpty(uri.Query) || uri.Query == "?")
        {
            return false;
        }

        var kept = new List<string>();
        var changed = false;
        foreach (var part in uri.Query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var name = part.Split('=', 2)[0];
            var decoded = Uri.UnescapeDataString(name.Replace("+", " ", StringComparison.Ordinal));
            if (IsTracking(decoded))
            {
                changed = true;
                continue;
            }

            kept.Add(part);
        }

        if (!changed)
        {
            return false;
        }

        var path = uri.GetLeftPart(UriPartial.Path);
        var query = kept.Count == 0 ? "" : "?" + string.Join("&", kept);
        cleaned = path + query + uri.Fragment;
        return true;
    }
}

public static class HttpsUpgrade
{
    public static string? ToHttps(string url)
    {
        if (!url.StartsWith("http://", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return "https://" + url["http://".Length..];
    }
}
