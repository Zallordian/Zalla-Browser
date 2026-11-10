namespace Zalla.Core.Tests;

public class BrowserChromeTests
{
    [Fact]
    public void TheToolbarReadsLeftToRightLikeABrowser()
    {
        Assert.Equal("Back", BrowserChrome.Toolbar[0]);
        Assert.Equal("Address", BrowserChrome.Toolbar[3]);
        Assert.Equal("Menu", BrowserChrome.Toolbar[^1]);
        Assert.DoesNotContain("Burn It All", BrowserChrome.Toolbar);
    }

    [Fact]
    public void TheMenuGroupsEverydayItemsAwayFromBurn()
    {
        var labels = BrowserChrome.Menu.Select(item => item.Label).ToList();
        Assert.Equal("New tab", labels[0]);
        Assert.Equal(["Bookmarks", "History", "Downloads"], labels.Skip(1).Take(3));
        var burn = BrowserChrome.Menu[^1];
        Assert.Equal("burn", burn.Action);
        Assert.True(burn.SeparatorBefore);
        Assert.True(BrowserChrome.Menu.Single(item => item.Action == "extensions").SeparatorBefore);
        Assert.True(BrowserChrome.Menu.Single(item => item.Action == "deck").SeparatorBefore);
    }

    [Fact]
    public void TheBrowserBarDoesNotFloatTheShieldOverThePage()
    {
        Assert.False(BrowserChrome.FloatsShield(ChromeLayout.Classic));
        Assert.True(BrowserChrome.FloatsShield(ChromeLayout.Island));
    }

    [Fact]
    public void SettingsOpenOnAppearanceAndKeepPrivacyWithTheOtherGroups()
    {
        Assert.Equal("Appearance", BrowserChrome.SettingsSections[0]);
        Assert.Contains("Privacy", BrowserChrome.SettingsSections);
        Assert.Contains("About", BrowserChrome.SettingsSections);
    }
}
