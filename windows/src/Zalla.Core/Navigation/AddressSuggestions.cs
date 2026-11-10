namespace Zalla.Core;

public enum SuggestionKind
{
    Bookmark,
    History,
    Address
}

public sealed record AddressSuggestion(SuggestionKind Kind, string Title, string Url);

public static class AddressSuggestions
{
    public const int Limit = 8;

    public static IReadOnlyList<AddressSuggestion> Match(
        string? query,
        IEnumerable<Bookmark> bookmarks,
        IEnumerable<HistoryEntry> history,
        SearchEngine engine,
        string? customTemplate = null)
    {
        var text = query?.Trim() ?? "";
        if (text.Length == 0 || text.StartsWith('/'))
        {
            return [];
        }

        var needle = text.ToLowerInvariant();
        var results = new List<AddressSuggestion>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        void Add(SuggestionKind kind, string title, string url)
        {
            if (results.Count >= Limit || string.IsNullOrWhiteSpace(url) || !seen.Add(url))
            {
                return;
            }

            results.Add(new AddressSuggestion(kind, string.IsNullOrWhiteSpace(title) ? url : title.Trim(), url));
        }

        foreach (var mark in bookmarks.Where(mark => Hits(mark.Title, mark.Url, needle)))
        {
            Add(SuggestionKind.Bookmark, mark.Title, mark.Url);
        }

        foreach (var entry in history.Where(entry => Hits(entry.Title, entry.Url, needle)))
        {
            Add(SuggestionKind.History, entry.Title, entry.Url);
        }

        var resolved = AddressResolver.Resolve(text, engine, customTemplate);
        if (resolved.Kind == AddressKind.Web)
        {
            Add(SuggestionKind.Address, resolved.Url, resolved.Url);
        }

        return results;
    }

    public static int Move(int current, int count, int delta)
    {
        if (count <= 0 || delta == 0)
        {
            return -1;
        }

        if (current < 0)
        {
            return delta > 0 ? 0 : count - 1;
        }

        var next = current + delta;
        if (next < 0)
        {
            return 0;
        }

        return next >= count ? count - 1 : next;
    }

    static bool Hits(string? title, string? url, string needle)
    {
        return (title ?? "").Contains(needle, StringComparison.OrdinalIgnoreCase)
            || (url ?? "").Contains(needle, StringComparison.OrdinalIgnoreCase);
    }
}
