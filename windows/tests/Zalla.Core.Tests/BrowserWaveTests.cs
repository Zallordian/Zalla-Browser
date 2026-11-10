namespace Zalla.Core.Tests;

public class BrowserWaveTests
{
    [Fact]
    public void SuggestionsPreferBookmarksThenHistoryAndATypedAddress()
    {
        var marks = new List<Bookmark> { new() { Title = "News", Url = "https://example.com/news" } };
        var history = new List<HistoryEntry>
        {
            new() { Title = "Example", Url = "https://example.com/news" },
            new() { Title = "Other", Url = "https://example.org/help" }
        };
        var items = AddressSuggestions.Match("example", marks, history, SearchEngine.Brave);
        Assert.Equal(SuggestionKind.Bookmark, items[0].Kind);
        Assert.Equal(SuggestionKind.History, items[1].Kind);
        Assert.Equal("https://example.org/help", items[1].Url);
        Assert.DoesNotContain(items, item => item.Kind == SuggestionKind.History && item.Url == "https://example.com/news");
        var typed = AddressSuggestions.Match("typed.example/path", marks, history, SearchEngine.Brave);
        Assert.Contains(typed, item => item.Kind == SuggestionKind.Address && item.Url.Contains("typed.example", StringComparison.Ordinal));
        Assert.Empty(AddressSuggestions.Match("  ", marks, history, SearchEngine.Brave));
        Assert.Empty(AddressSuggestions.Match("/burn", marks, history, SearchEngine.Brave));
    }

    [Fact]
    public void SuggestionKeysMoveWithinTheList()
    {
        Assert.Equal(0, AddressSuggestions.Move(-1, 3, 1));
        Assert.Equal(2, AddressSuggestions.Move(-1, 3, -1));
        Assert.Equal(1, AddressSuggestions.Move(0, 3, 1));
        Assert.Equal(2, AddressSuggestions.Move(2, 3, 1));
        Assert.Equal(-1, AddressSuggestions.Move(0, 0, 1));
    }

    [Fact]
    public void StandardShortcutsStayAcceleratorsAndLettersDoNot()
    {
        Assert.Equal(BrowserAction.NewTab, BrowserGestures.Match(true, false, false, BrowserGestures.KeyT, out _));
        Assert.Equal(BrowserAction.ReopenTab, BrowserGestures.Match(true, true, false, BrowserGestures.KeyT, out _));
        Assert.Equal(BrowserAction.CloseTab, BrowserGestures.Match(true, false, false, BrowserGestures.KeyW, out _));
        Assert.Equal(BrowserAction.FocusAddress, BrowserGestures.Match(true, false, false, BrowserGestures.KeyL, out _));
        Assert.Equal(BrowserAction.FocusAddress, BrowserGestures.Match(false, false, true, BrowserGestures.KeyD, out _));
        Assert.Equal(BrowserAction.NextTab, BrowserGestures.Match(true, false, false, BrowserGestures.KeyTab, out _));
        Assert.Equal(BrowserAction.PreviousTab, BrowserGestures.Match(true, true, false, BrowserGestures.KeyTab, out _));
        Assert.Equal(BrowserAction.Find, BrowserGestures.Match(true, false, false, BrowserGestures.KeyF, out _));
        Assert.Equal(BrowserAction.ZoomIn, BrowserGestures.Match(true, true, false, BrowserGestures.KeyOemPlus, out _));
        Assert.Equal(BrowserAction.ZoomOut, BrowserGestures.Match(true, false, false, BrowserGestures.KeyOemMinus, out _));
        Assert.Equal(BrowserAction.ZoomReset, BrowserGestures.Match(true, false, false, BrowserGestures.Key0, out _));
        Assert.Equal(BrowserAction.Reload, BrowserGestures.Match(false, false, false, BrowserGestures.KeyF5, out _));
        Assert.Equal(BrowserAction.FullScreen, BrowserGestures.Match(false, false, false, BrowserGestures.KeyF11, out _));
        Assert.Equal(BrowserAction.Back, BrowserGestures.Match(false, false, true, BrowserGestures.KeyLeft, out _));
        Assert.Equal(BrowserAction.None, BrowserGestures.Match(false, false, false, BrowserGestures.KeyT, out _));
        Assert.Equal(BrowserAction.SelectTab, BrowserGestures.Match(true, false, false, BrowserGestures.Key1, out var number));
        Assert.Equal(1, number);
    }

    [Fact]
    public void NumberKeysPickTabsAndTheLastKeyJumpsToTheEnd()
    {
        Assert.Equal(0, BrowserGestures.TabIndex(4, 1));
        Assert.Equal(2, BrowserGestures.TabIndex(4, 3));
        Assert.Null(BrowserGestures.TabIndex(2, 3));
        Assert.Equal(5, BrowserGestures.TabIndex(6, 9));
        Assert.True(BrowserGestures.ShouldOpenReplacement(1));
        Assert.False(BrowserGestures.ShouldOpenReplacement(2));
    }

    [Fact]
    public void ContextMenusMatchTheClickAndOmitDeveloperTools()
    {
        var page = ContextMenus.Page(canBack: true, canForward: false, hasSelection: true);
        Assert.Contains(page, item => item.Action == "back");
        Assert.DoesNotContain(page, item => item.Action == "forward");
        Assert.Contains(page, item => item.Action == "copy");
        Assert.DoesNotContain(page, item => item.Label.Contains("Inspect", StringComparison.OrdinalIgnoreCase));
        var link = ContextMenus.Link();
        Assert.Equal(["open-link", "open-link-tab", "copy-link"], link.Select(item => item.Action));
        Assert.True(link[^1].SeparatorBefore);
        var tab = ContextMenus.Tab(canCloseOthers: true, hasUrl: true);
        Assert.Contains(tab, item => item.Action == "duplicate");
        Assert.Contains(tab, item => item.Action == "close-others");
        Assert.DoesNotContain(ContextMenus.Tab(false, false), item => item.Action is "close-others" or "copy-url");
    }

    [Fact]
    public void ZoomStepsAndFindScriptsStayInsideThePage()
    {
        Assert.Equal(1.1, PageZoom.In(1));
        Assert.Equal(0.9, PageZoom.Out(1));
        Assert.Equal(1, PageZoom.Reset());
        Assert.Equal("125%", PageZoom.Label(1.25));
        var script = PageFind.CountScript("say \"hi\"");
        Assert.DoesNotContain("say \"hi\"", script);
        Assert.Contains("\\u0022", script);
        Assert.Contains("true", PageFind.JumpScript("a", backwards: true));
    }

    [Fact]
    public void ClosedTabsComeBackNewestFirstAndDownloadsDescribeProgress()
    {
        var pages = new List<ClosedPage>();
        ClosedTabMemory.Push(pages, "One", "https://one.test");
        ClosedTabMemory.Push(pages, "Two", "https://two.test");
        Assert.True(ClosedTabMemory.TryTake(pages, out var page));
        Assert.Equal("https://two.test", page.Url);
        Assert.Equal("Finished", DownloadText.Describe(10, 10, true, "InProgress"));
        Assert.Equal("1 KB of 2 KB", DownloadText.Describe(1024, 2048, false, ""));
    }
}
