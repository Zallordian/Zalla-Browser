namespace Zalla.Core.Tests;

public class WindowChromeTests
{
    static readonly ScreenRect Monitor = new(0, 0, 1920, 1080);
    static readonly ScreenRect Work = new(0, 0, 1920, 1040);

    [Fact]
    public void MaximizeStaysAboveTheTaskbar()
    {
        var frame = WindowFrame.Maximize(Work);
        Assert.Equal(Work, frame);
        Assert.False(WindowFrame.CoversTaskbar(frame, Work));
    }

    [Fact]
    public void FullScreenIsSeparateAndCoversTheTaskbar()
    {
        var frame = WindowFrame.FullScreen(Monitor);
        Assert.Equal(Monitor, frame);
        Assert.NotEqual(WindowFrame.Maximize(Work), frame);
        Assert.True(WindowFrame.CoversTaskbar(frame, Work));
    }

    [Fact]
    public void APageWaitsForARealLayoutBeforeItIsCreated()
    {
        Assert.False(PageViewport.Ready(hasWindowRoot: false, width: 1200, height: 800));
        Assert.False(PageViewport.Ready(hasWindowRoot: true, width: 0, height: 800));
        Assert.True(PageViewport.Ready(hasWindowRoot: true, width: 1200, height: 800));
    }

    [Fact]
    public void TheShieldDoesNotClaimBlocksThatAreNotRunning()
    {
        Assert.NotEqual("Shield on", ShieldPresentation.Title);
        var lines = ShieldPresentation.Lines(httpsOnly: true).Select(line => ShieldPresentation.Format(line.Name, line.State)).ToList();
        Assert.Contains("HTTPS-Only  on", lines);
        Assert.Contains("Trackers  preview", lines);
        Assert.Contains("Ads  preview", lines);
        Assert.DoesNotContain(lines, line => line.StartsWith("Trackers", StringComparison.Ordinal) && line.EndsWith("on", StringComparison.Ordinal));
        Assert.Contains("not active yet", ShieldPresentation.Detail(true, true), StringComparison.Ordinal);
        Assert.DoesNotContain("blocked", ShieldPresentation.NotCounting, StringComparison.OrdinalIgnoreCase);
    }
}
