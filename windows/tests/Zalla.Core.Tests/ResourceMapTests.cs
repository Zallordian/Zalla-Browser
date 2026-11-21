namespace Zalla.Core.Tests;

public class ResourceMapTests
{
    [Fact]
    public void AMissingKeyIsCreatedFromAFreshBrush()
    {
        var map = new Dictionary<string, object>();
        var rest = new object();
        Assert.True(ResourceMap.TryPut(map, "ButtonBackground", rest));
        Assert.Same(rest, map["ButtonBackground"]);
        Assert.False(ResourceMap.TryPut(map, "ButtonBackgroundPointerOver", rest));
        Assert.False(map.ContainsKey("ButtonBackgroundPointerOver"));
    }

    [Fact]
    public void HoverColorReplacesOnlyWhenTheBrushIsNotShared()
    {
        var map = new Dictionary<string, object>();
        var rest = new object();
        var hover = new object();
        Assert.True(ResourceMap.TryPut(map, "ButtonBackground", rest));
        Assert.True(ResourceMap.TryPut(map, "ButtonBackgroundPointerOver", hover));
        Assert.Same(rest, map["ButtonBackground"]);
        Assert.Same(hover, map["ButtonBackgroundPointerOver"]);
        Assert.False(ResourceMap.TryPut(map, "", hover));
        Assert.False(ResourceMap.TryPut(map, "ButtonBackgroundPressed", null));
    }
}
