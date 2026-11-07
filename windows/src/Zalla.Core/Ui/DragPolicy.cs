namespace Zalla.Core;

public enum DragSurface
{
    None,
    TitleStrip,
    IslandChrome,
    Page,
    Control
}

/// <summary>
/// Window movement is only the title strip. The command island moves inside the window.
/// A page, a button, or a released button must not keep a drag going.
/// </summary>
public static class DragPolicy
{
    public static bool MoveWindow(DragSurface surface, bool leftButtonDown)
        => leftButtonDown && surface == DragSurface.TitleStrip;

    public static bool MoveIsland(DragSurface surface, bool leftButtonDown)
        => leftButtonDown && surface == DragSurface.IslandChrome;

    public static bool KeepDragging(bool leftButtonDown) => leftButtonDown;
}
