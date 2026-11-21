namespace Zalla.Core;

public sealed class Bookmark
{
    public string Title { get; set; } = "";

    public string Url { get; set; } = "";
}

public sealed class HistoryEntry
{
    public string Title { get; set; } = "";

    public string Url { get; set; } = "";

    public DateTimeOffset When { get; set; }
}

public static class BrowserLibrary
{
    public const int HistoryCap = 200;

    public static bool IsBookmarked(IEnumerable<Bookmark> items, string? url)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return false;
        }

        return items.Any(item => string.Equals(item.Url, url, StringComparison.OrdinalIgnoreCase));
    }

    public static bool ToggleBookmark(List<Bookmark> items, string? url, string? title)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return false;
        }

        var existing = items.FirstOrDefault(item => string.Equals(item.Url, url, StringComparison.OrdinalIgnoreCase));
        if (existing != null)
        {
            items.Remove(existing);
            return false;
        }

        items.Insert(0, new Bookmark
        {
            Url = url,
            Title = string.IsNullOrWhiteSpace(title) ? url : title.Trim()
        });
        return true;
    }

    public static void Remember(List<HistoryEntry> items, string? url, string? title)
    {
        if (!IsPage(url))
        {
            return;
        }

        items.Insert(0, new HistoryEntry
        {
            Url = url!,
            Title = string.IsNullOrWhiteSpace(title) ? url! : title.Trim(),
            When = DateTimeOffset.Now
        });
        if (items.Count > HistoryCap)
        {
            items.RemoveRange(HistoryCap, items.Count - HistoryCap);
        }
    }

    public static bool IsUnpackedExtension(string? folder)
    {
        if (string.IsNullOrWhiteSpace(folder))
        {
            return false;
        }

        return File.Exists(Path.Combine(folder, "manifest.json"));
    }

    public static bool IsPage(string? url)
    {
        if (string.IsNullOrWhiteSpace(url))
        {
            return false;
        }

        return url.StartsWith("https://", StringComparison.OrdinalIgnoreCase)
            || url.StartsWith("http://", StringComparison.OrdinalIgnoreCase);
    }
}

public static class ChromeMigration
{
    public const int CurrentRevision = 1;

    public static bool Apply(AppSettings settings)
    {
        settings.Bookmarks ??= new List<Bookmark>();
        if (settings.ChromeRevision >= CurrentRevision)
        {
            return false;
        }

        settings.Layout = ChromeLayout.Classic;
        settings.ChromeRevision = CurrentRevision;
        return true;
    }
}
