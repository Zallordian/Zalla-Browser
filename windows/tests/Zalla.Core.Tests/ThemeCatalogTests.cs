using System.Text.Json;

namespace Zalla.Core.Tests;

public class ThemeCatalogTests
{
    static readonly string FilePath = Path.Combine(AppContext.BaseDirectory, "themes.json");

    [Fact]
    public void EmbeddedFileMatchesSharedJson()
    {
        var embedded = ThemeCatalog.LoadEmbedded();
        var fromDisk = ThemeCatalog.Load(FilePath);
        Assert.Equal(fromDisk.Themes.Select(theme => theme.Id), embedded.Themes.Select(theme => theme.Id));
        Assert.Equal(34, embedded.Themes.Count);
    }

    [Fact]
    public void LakeSuperiorMatchesIosColors()
    {
        var theme = ThemeCatalog.LoadEmbedded().Require("lakeSuperior");
        Assert.Equal("Lake Superior", theme.Name);
        Assert.Equal("pro", theme.Group);
        Assert.True(theme.RequiresUnlock);
        Assert.False(theme.Seasonal);
        Assert.True(theme.UsesGradientAccent);
        Assert.Equal("4A6F8F", theme.PrimaryHex);
        Assert.Equal("4A6F8F", theme.Colors.Primary);
        Assert.Equal("6B8FAF", theme.Colors.Bright);
        Assert.Equal("2B4560", theme.Colors.Deep);
        Assert.Equal("FF7A2F", theme.Colors.Highlight);
        Assert.Equal("7F95A8", theme.Colors.GradientEnd);
        Assert.Equal("LakeSuperior", theme.Icon);
        Assert.Equal("lakeSuperior", ThemeCatalog.WindowsStartThemeId);
    }

    [Fact]
    public void EveryThemeHasUniqueIdAndRealColors()
    {
        var catalog = ThemeCatalog.LoadEmbedded();
        Assert.Equal(catalog.Themes.Count, catalog.Themes.Select(theme => theme.Id).Distinct(StringComparer.Ordinal).Count());
        Assert.Equal(catalog.Themes.Count, catalog.Themes.Select(theme => theme.Name).Distinct(StringComparer.Ordinal).Count());

        foreach (var theme in catalog.Themes)
        {
            Assert.True(ThemeHex.IsRgb(theme.PrimaryHex), theme.Id);
            Assert.Equal(theme.PrimaryHex, theme.Colors.Primary, StringComparer.OrdinalIgnoreCase);
            Assert.True(ThemeHex.IsRgb(theme.Colors.Bright), theme.Id);
            Assert.True(ThemeHex.IsRgb(theme.Colors.Deep), theme.Id);
            Assert.True(ThemeHex.IsRgb(theme.Colors.Highlight), theme.Id);
            Assert.True(ThemeHex.IsRgb(theme.Colors.GradientEnd), theme.Id);
            Assert.False(string.IsNullOrWhiteSpace(theme.Icon));
        }

        var oled = catalog.Require("oledVoid");
        Assert.False(oled.UsesGradientAccent);
        Assert.Equal(33, catalog.Themes.Count(theme => theme.UsesGradientAccent));
    }

    [Fact]
    public void UnlockAndSeasonalFlagsMatchIos()
    {
        var catalog = ThemeCatalog.LoadEmbedded();
        var unlock = catalog.Themes.Where(theme => theme.RequiresUnlock).Select(theme => theme.Id).ToArray();
        Assert.Equal(
            new[]
            {
                "jungle", "volcano", "deepOcean", "arcade", "neonCity", "arctic", "cherryBlossom",
                "northwoods", "lakeSuperior", "midnightEmber", "aurora", "oledVoid"
            },
            unlock);

        var seasonal = catalog.Themes.Where(theme => theme.Seasonal).Select(theme => theme.Id).ToArray();
        Assert.Equal(
            new[]
            {
                "newYear", "winter", "valentines", "stPatricks", "easter", "spring",
                "memorialDay", "summer", "fourthOfJuly", "halloween", "harvest", "christmas"
            },
            seasonal);
        Assert.Equal(seasonal, catalog.Document.SeasonalWindows.Select(window => window.Id));
    }

    [Fact]
    public void ChristmasAndNewYearWindowsMatchSwift()
    {
        var windows = ThemeCatalog.LoadEmbedded().Document.SeasonalWindows;
        var christmas = windows.Single(window => window.Id == "christmas");
        Assert.Equal("fixed", christmas.Kind);
        Assert.Equal(12, christmas.Start!.Month);
        Assert.Equal(1, christmas.Start.Day);
        Assert.Equal(26, christmas.End!.Day);

        var newYear = windows.Single(window => window.Id == "newYear");
        Assert.Equal(-1, newYear.Start!.YearOffset);
        Assert.Equal(12, newYear.Start.Month);
        Assert.Equal(26, newYear.Start.Day);
        Assert.Equal(0, newYear.End!.YearOffset);
        Assert.Equal(1, newYear.End.Month);
        Assert.Equal(7, newYear.End.Day);

        var easter = windows.Single(window => window.Id == "easter");
        Assert.Equal("westernEaster", easter.Rule);
        Assert.Equal(-14, easter.StartOffsetDays);
        Assert.Equal(1, easter.EndOffsetDays);
    }

    [Fact]
    public void NamesResolveWithoutSpacesOrCase()
    {
        var catalog = ThemeCatalog.LoadEmbedded();
        Assert.Equal("lakeSuperior", catalog.Match("Lake Superior")!.Id);
        Assert.Equal("lakeSuperior", catalog.Match("lakesuperior")!.Id);
        Assert.Equal("lakeSuperior", catalog.Match("lake")!.Id);
        Assert.Equal("oledVoid", catalog.Match("OLED Void")!.Id);
        Assert.Equal("zallaRed", catalog.Match("Zalla Red")!.Id);
        Assert.Null(catalog.Match("no such theme"));
        Assert.Null(catalog.Match("a"));
    }

    [Fact]
    public void BackgroundsAndPacksCameAlong()
    {
        var document = ThemeCatalog.LoadEmbedded().Document;
        Assert.Equal(41, document.NewTabBackgrounds.Count);
        Assert.Contains(document.NewTabBackgrounds, background => background.Id == "nebula" && background.Decor == "stars" && background.RequiresUnlock);
        Assert.Contains(document.NewTabBackgrounds, background => background.Id == "crimson" && background.Pack is null && !background.RequiresUnlock);
        Assert.Equal(8, document.ThemePacks.Count);
        Assert.Contains(document.ThemePacks, pack => pack.ThemeId == "space" && pack.BackgroundPresetId == "nebula");

        using var stream = File.OpenRead(FilePath);
        using var json = JsonDocument.Parse(stream);
        Assert.Equal(1, json.RootElement.GetProperty("version").GetInt32());
        Assert.True(json.RootElement.GetProperty("exportedFrom").GetArrayLength() >= 4);
    }
}
