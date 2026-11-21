namespace Zalla.Core;

public readonly record struct ScreenRect(int X, int Y, int Width, int Height)
{
    public int Right => X + Width;

    public int Bottom => Y + Height;
}

/// <summary>
/// Ordinary maximize uses the monitor work area, so the taskbar stays visible.
/// Full screen uses the whole monitor and is a separate action.
/// </summary>
public static class WindowFrame
{
    public static ScreenRect Maximize(ScreenRect workArea) => workArea;

    public static ScreenRect FullScreen(ScreenRect monitorBounds) => monitorBounds;

    public static bool CoversTaskbar(ScreenRect frame, ScreenRect workArea)
    {
        return frame.X < workArea.X
            || frame.Y < workArea.Y
            || frame.Right > workArea.Right
            || frame.Bottom > workArea.Bottom;
    }
}
