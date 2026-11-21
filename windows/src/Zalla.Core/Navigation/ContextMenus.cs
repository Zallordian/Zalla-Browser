namespace Zalla.Core;

public static class ContextMenus
{
    public static IReadOnlyList<ChromeCommand> Page(bool canBack, bool canForward, bool hasSelection)
    {
        var items = new List<ChromeCommand>();
        if (canBack)
        {
            items.Add(new ChromeCommand("Back", "Alt+Left", "back", false));
        }

        if (canForward)
        {
            items.Add(new ChromeCommand("Forward", "Alt+Right", "forward", false));
        }

        items.Add(new ChromeCommand("Reload", "Ctrl+R", "reload", false));
        if (hasSelection)
        {
            items.Add(new ChromeCommand("Copy", "", "copy", true));
        }

        items.Add(new ChromeCommand("Select all", "", "select-all", !hasSelection));
        return items;
    }

    public static IReadOnlyList<ChromeCommand> Link()
    {
        return
        [
            new("Open link", "", "open-link", false),
            new("Open link in new tab", "", "open-link-tab", false),
            new("Copy link", "", "copy-link", true)
        ];
    }

    public static IReadOnlyList<ChromeCommand> Tab(bool canCloseOthers, bool hasUrl)
    {
        var items = new List<ChromeCommand>
        {
            new("New tab", "Ctrl+T", "new-tab", false),
            new("Close tab", "Ctrl+W", "close-tab", false)
        };
        if (canCloseOthers)
        {
            items.Add(new ChromeCommand("Close other tabs", "", "close-others", false));
        }

        items.Add(new ChromeCommand("Duplicate tab", "", "duplicate", true));
        if (hasUrl)
        {
            items.Add(new ChromeCommand("Copy URL", "", "copy-url", false));
        }

        return items;
    }
}
