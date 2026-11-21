namespace Zalla.Core;

/// <summary>
/// A page view captures its size and display scale on first creation.
/// Wait until it is in the window and has a real layout, or the site is sized wrong.
/// </summary>
public static class PageViewport
{
    public const double MinimumDip = 2;

    public static bool Ready(bool hasWindowRoot, double width, double height)
    {
        return hasWindowRoot && width >= MinimumDip && height >= MinimumDip;
    }
}
