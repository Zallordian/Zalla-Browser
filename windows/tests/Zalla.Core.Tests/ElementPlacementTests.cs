namespace Zalla.Core.Tests;

public class ElementPlacementTests
{
    [Fact]
    public void LoadingASpaceDoesNotAddTheSameTabTwice()
    {
        var first = ElementPlacement.Decide(targetContains: false, reportedParentIsTarget: false, listedInOtherPanel: false);
        Assert.True(first.Add);
        Assert.False(first.DetachFromOther);

        // AddTab puts the card in the stack. LayoutHosts runs next, and WinUI still reports Parent as null.
        var second = ElementPlacement.Decide(targetContains: true, reportedParentIsTarget: false, listedInOtherPanel: false);
        Assert.False(second.Add);
        Assert.False(second.DetachFromOther);
    }

    [Fact]
    public void MovingACardDetachesItWhenTheOldParentIsNotReported()
    {
        var plan = ElementPlacement.Decide(targetContains: false, reportedParentIsTarget: false, listedInOtherPanel: true);
        Assert.True(plan.DetachFromOther);
        Assert.True(plan.Add);
    }

    [Fact]
    public void AReportedParentIsLeftAlone()
    {
        var plan = ElementPlacement.Decide(targetContains: false, reportedParentIsTarget: true, listedInOtherPanel: false);
        Assert.False(plan.Add);
    }
}
