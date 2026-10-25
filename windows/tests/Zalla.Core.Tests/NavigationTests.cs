namespace Zalla.Core.Tests;

public class NavigationTests
{
    [Fact]
    public void AddressesBecomeWebOrSearch()
    {
        var web = AddressResolver.Resolve("example.com", SearchEngine.Brave);
        Assert.Equal(AddressKind.Web, web.Kind);
        Assert.Equal("https://example.com/", web.Url);

        var secure = AddressResolver.Resolve("https://example.com/a", SearchEngine.Brave);
        Assert.Equal("https://example.com/a", secure.Url);

        var local = AddressResolver.Resolve("localhost:8080", SearchEngine.Brave);
        Assert.StartsWith("https://localhost:8080", local.Url, StringComparison.Ordinal);

        var search = AddressResolver.Resolve("cold wind", SearchEngine.Brave);
        Assert.Equal(AddressKind.Search, search.Kind);
        Assert.Equal("https://search.brave.com/search?q=cold%20wind", search.Url);

        Assert.Equal(AddressKind.Rejected, AddressResolver.Resolve("javascript:alert(1)", SearchEngine.Brave).Kind);
        Assert.Equal(AddressKind.Rejected, AddressResolver.Resolve("file:///tmp/a", SearchEngine.Brave).Kind);
        Assert.Equal(AddressKind.Empty, AddressResolver.Resolve("  ", SearchEngine.Brave).Kind);
    }

    [Fact]
    public void StartpageUsesQueryAndCustomFallsBack()
    {
        var url = AddressResolver.Resolve("news", SearchEngine.Startpage);
        Assert.Contains("startpage.com/sp/search?query=news", url.Url, StringComparison.Ordinal);

        var custom = AddressResolver.Resolve("dogs", SearchEngine.Custom, "https://search.example/find?q=%s");
        Assert.Equal("https://search.example/find?q=dogs", custom.Url);

        var broken = AddressResolver.Resolve("dogs", SearchEngine.Custom, "not a template");
        Assert.StartsWith("https://search.brave.com/search?q=dogs", broken.Url, StringComparison.Ordinal);
    }

    [Fact]
    public void TrackingParametersAreRemoved()
    {
        Assert.True(TrackingCleaner.TryClean("https://example.com/a?utm_source=x&id=1&fbclid=abc", out var cleaned));
        Assert.Equal("https://example.com/a?id=1", cleaned);
        Assert.False(TrackingCleaner.TryClean("https://example.com/a?id=1", out _));
        Assert.True(TrackingCleaner.IsTracking("utm_campaign"));
        Assert.False(TrackingCleaner.IsTracking("q"));
    }

    [Fact]
    public void HttpUpgradesOnlyPlainHttp()
    {
        Assert.Equal("https://example.com/a", HttpsUpgrade.ToHttps("http://example.com/a"));
        Assert.Null(HttpsUpgrade.ToHttps("https://example.com"));
        Assert.Null(HttpsUpgrade.ToHttps("example.com"));
    }

    [Fact]
    public void PrivacyDefaultsAreOnExceptTheProxy()
    {
        var privacy = PrivacySettings.CreateDefaults();
        Assert.True(privacy.BlockTrackers);
        Assert.True(privacy.BlockCommonAds);
        Assert.True(privacy.FullAdBlocking);
        Assert.True(privacy.HideAdSpaces);
        Assert.True(privacy.CookieBanners);
        Assert.True(privacy.HttpsOnly);
        Assert.True(privacy.CleanLinks);
        Assert.True(privacy.TrimReferrer);
        Assert.True(privacy.Fingerprinting);
        Assert.True(privacy.EncryptedDns);
        Assert.False(privacy.OwnProxy);
        Assert.True(privacy.ShieldOn);

        privacy.BlockTrackers = false;
        privacy.BlockCommonAds = false;
        privacy.FullAdBlocking = false;
        privacy.HideAdSpaces = false;
        privacy.CookieBanners = false;
        privacy.HttpsOnly = false;
        privacy.CleanLinks = false;
        privacy.TrimReferrer = false;
        privacy.Fingerprinting = false;
        privacy.EncryptedDns = false;
        Assert.False(privacy.ShieldOn);
    }
}
