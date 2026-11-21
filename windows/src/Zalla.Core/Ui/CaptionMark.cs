namespace Zalla.Core;

public enum CaptionKind
{
    Minimize,
    Maximize,
    Restore,
    Close
}

/// <summary>
/// Caption controls are drawn shapes. They do not depend on a private-use icon font.
/// </summary>
public static class CaptionMark
{
    public static bool UsesIconFont => false;

    public static string AccessibleName(CaptionKind kind) => kind switch
    {
        CaptionKind.Minimize => "Minimize",
        CaptionKind.Maximize => "Maximize",
        CaptionKind.Restore => "Restore",
        CaptionKind.Close => "Close",
        _ => "Window"
    };

    public static IReadOnlyList<string> Parts(CaptionKind kind) => kind switch
    {
        CaptionKind.Minimize => ["bar"],
        CaptionKind.Maximize => ["square"],
        CaptionKind.Restore => ["square", "square"],
        CaptionKind.Close => ["diagonal", "diagonal"],
        _ => []
    };
}
