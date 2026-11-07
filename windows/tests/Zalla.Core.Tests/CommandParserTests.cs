namespace Zalla.Core.Tests;

public class CommandParserTests
{
    [Theory]
    [InlineData("/burn")]
    [InlineData("burn")]
    [InlineData("  Burn It All ")]
    [InlineData("/burn-it-all")]
    public void Burn(string text)
    {
        var parsed = CommandParser.Parse(text);
        Assert.Equal(CommandKind.Burn, parsed.Kind);
    }

    [Theory]
    [InlineData("/reader")]
    [InlineData("reader mode")]
    public void ReaderIsAPlaceholder(string text)
    {
        var parsed = CommandParser.Parse(text);
        Assert.Equal(CommandKind.Reader, parsed.Kind);
        Assert.Equal(CommandParser.ReaderNote, parsed.Note);
        Assert.DoesNotContain("—", parsed.Note, StringComparison.Ordinal);
        Assert.DoesNotContain("–", parsed.Note, StringComparison.Ordinal);
    }

    [Fact]
    public void ThemeCarriesTheName()
    {
        var parsed = CommandParser.Parse("/theme Lake Superior");
        Assert.Equal(CommandKind.Theme, parsed.Kind);
        Assert.Equal("Lake Superior", parsed.Argument);

        var missing = CommandParser.Parse("theme");
        Assert.Equal(CommandKind.Theme, missing.Kind);
        Assert.Equal("", missing.Argument);
        Assert.Equal(CommandParser.ThemeNeedsName, missing.Note);
    }

    [Theory]
    [InlineData("/new tab")]
    [InlineData("newtab")]
    [InlineData("New card")]
    public void NewTab(string text)
    {
        Assert.Equal(CommandKind.NewTab, CommandParser.Parse(text).Kind);
    }

    [Theory]
    [InlineData("/close tab")]
    [InlineData("closetab")]
    [InlineData("close")]
    public void CloseTab(string text)
    {
        Assert.Equal(CommandKind.CloseTab, CommandParser.Parse(text).Kind);
    }

    [Fact]
    public void UnknownAndEmpty()
    {
        Assert.Equal(CommandKind.Empty, CommandParser.Parse("   ").Kind);
        Assert.Equal(CommandKind.Empty, CommandParser.Parse("/").Kind);
        var unknown = CommandParser.Parse("/hello");
        Assert.Equal(CommandKind.Unknown, unknown.Kind);
        Assert.Equal(CommandParser.UnknownNote, unknown.Note);
    }

    [Fact]
    public void SlashOrCommandModeChoosesTheRoute()
    {
        var burn = InputRouter.Decide("/burn", commandMode: false);
        Assert.Equal(InputRoute.Command, burn.Route);
        Assert.Equal(CommandKind.Burn, burn.Command.Kind);

        var typed = InputRouter.Decide("burn", commandMode: false);
        Assert.Equal(InputRoute.Navigate, typed.Route);

        var fromPalette = InputRouter.Decide("theme aurora", commandMode: true);
        Assert.Equal(InputRoute.Command, fromPalette.Route);
        Assert.Equal(CommandKind.Theme, fromPalette.Command.Kind);
        Assert.Equal("aurora", fromPalette.Command.Argument);

        var urlInPalette = InputRouter.Decide("https://example.com", commandMode: true);
        Assert.Equal(InputRoute.Navigate, urlInPalette.Route);

        var search = InputRouter.Decide("cold wind", commandMode: false);
        Assert.Equal(InputRoute.Navigate, search.Route);
    }
}
