namespace Zalla.Core.Tests;

public class BrowserLibraryTests
{
    [Fact]
    public void BookmarkToggleAddsAndRemovesTheSameAddress()
    {
        var items = new List<Bookmark>();
        Assert.True(BrowserLibrary.ToggleBookmark(items, "https://Example.com/a", "Example"));
        Assert.True(BrowserLibrary.IsBookmarked(items, "https://example.com/a"));
        Assert.False(BrowserLibrary.ToggleBookmark(items, "https://example.com/a", "Example"));
        Assert.Empty(items);
        Assert.False(BrowserLibrary.ToggleBookmark(items, "  ", "x"));
    }

    [Fact]
    public void HistoryKeepsPagesAndDropsTheOldestPastTheCap()
    {
        var items = new List<HistoryEntry>();
        BrowserLibrary.Remember(items, "about:blank", "Blank");
        Assert.Empty(items);
        for (var i = 0; i < BrowserLibrary.HistoryCap + 5; i++)
        {
            BrowserLibrary.Remember(items, "https://example.com/" + i, "Page " + i);
        }

        Assert.Equal(BrowserLibrary.HistoryCap, items.Count);
        Assert.Equal("https://example.com/" + (BrowserLibrary.HistoryCap + 4), items[0].Url);
    }

    [Fact]
    public void UnpackedExtensionNeedsAManifestBesideTheFolder()
    {
        var root = Path.Combine(Path.GetTempPath(), "zalla-ext-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        Assert.False(BrowserLibrary.IsUnpackedExtension(root));
        File.WriteAllText(Path.Combine(root, "manifest.json"), "{}");
        Assert.True(BrowserLibrary.IsUnpackedExtension(root));
        Assert.False(BrowserLibrary.IsUnpackedExtension(null));
    }

    [Fact]
    public void SavedIslandLayoutMovesToTheBrowserBarOnce()
    {
        var settings = new AppSettings { Layout = ChromeLayout.Island, ChromeRevision = 0 };
        Assert.True(ChromeMigration.Apply(settings));
        Assert.Equal(ChromeLayout.Classic, settings.Layout);
        Assert.Equal(ChromeMigration.CurrentRevision, settings.ChromeRevision);
        settings.Layout = ChromeLayout.Island;
        Assert.False(ChromeMigration.Apply(settings));
        Assert.Equal(ChromeLayout.Island, settings.Layout);
    }
}
