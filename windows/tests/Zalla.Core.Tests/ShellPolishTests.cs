namespace Zalla.Core.Tests;

public class ShellPolishTests
{
    [Theory]
    [InlineData(DragSurface.Page)]
    [InlineData(DragSurface.Control)]
    [InlineData(DragSurface.IslandChrome)]
    [InlineData(DragSurface.None)]
    public void OrdinaryClicksDoNotMoveTheWindow(DragSurface surface)
    {
        Assert.False(DragPolicy.MoveWindow(surface, leftButtonDown: true));
        Assert.False(DragPolicy.MoveWindow(surface, leftButtonDown: false));
    }

    [Fact]
    public void OnlyTheTitleStripMovesTheWindowAndOnlyWhileHeld()
    {
        Assert.True(DragPolicy.MoveWindow(DragSurface.TitleStrip, leftButtonDown: true));
        Assert.False(DragPolicy.MoveWindow(DragSurface.TitleStrip, leftButtonDown: false));
        Assert.False(DragPolicy.KeepDragging(leftButtonDown: false));
    }

    [Fact]
    public void TheIslandMovesInsideTheWindowAndAControlDoesNot()
    {
        Assert.True(DragPolicy.MoveIsland(DragSurface.IslandChrome, leftButtonDown: true));
        Assert.False(DragPolicy.MoveIsland(DragSurface.Control, leftButtonDown: true));
        Assert.False(DragPolicy.MoveIsland(DragSurface.Page, leftButtonDown: true));
        Assert.False(DragPolicy.MoveIsland(DragSurface.TitleStrip, leftButtonDown: true));
    }

    [Fact]
    public void CaptionMarksAreShapesWithNames()
    {
        Assert.False(CaptionMark.UsesIconFont);
        Assert.Equal("Minimize", CaptionMark.AccessibleName(CaptionKind.Minimize));
        Assert.Equal("Maximize", CaptionMark.AccessibleName(CaptionKind.Maximize));
        Assert.Equal("Restore", CaptionMark.AccessibleName(CaptionKind.Restore));
        Assert.Equal("Close", CaptionMark.AccessibleName(CaptionKind.Close));
        Assert.Equal(2, CaptionMark.Parts(CaptionKind.Close).Count);
        Assert.Equal(2, CaptionMark.Parts(CaptionKind.Restore).Count);
        Assert.DoesNotContain(CaptionMark.Parts(CaptionKind.Minimize), part => part.Contains("\\u", StringComparison.Ordinal));
    }

    [Fact]
    public void LaunchMarksStayInOrder()
    {
        var clock = new LaunchClock();
        clock.Mark("tree");
        clock.Mark("shown");
        Assert.Equal(2, clock.Count);
        Assert.StartsWith("tree ", clock.Line(), StringComparison.Ordinal);
        Assert.Contains(", shown ", clock.Line(), StringComparison.Ordinal);
    }
}
