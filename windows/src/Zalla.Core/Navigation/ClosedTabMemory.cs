namespace Zalla.Core;

public readonly record struct ClosedPage(string Title, string Url);

public static class ClosedTabMemory
{
    public const int Cap = 25;

    public static void Push(List<ClosedPage> pages, string? title, string? url)
    {
        pages.Insert(0, new ClosedPage(title?.Trim() ?? "", url?.Trim() ?? ""));
        if (pages.Count > Cap)
        {
            pages.RemoveRange(Cap, pages.Count - Cap);
        }
    }

    public static bool TryTake(List<ClosedPage> pages, out ClosedPage page)
    {
        if (pages.Count == 0)
        {
            page = default;
            return false;
        }

        page = pages[0];
        pages.RemoveAt(0);
        return true;
    }
}
