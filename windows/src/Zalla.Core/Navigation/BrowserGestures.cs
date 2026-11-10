namespace Zalla.Core;

public enum BrowserAction
{
    None,
    NewTab,
    CloseTab,
    FocusAddress,
    NextTab,
    PreviousTab,
    ReopenTab,
    SelectTab,
    Reload,
    FullScreen,
    Back,
    Forward,
    Bookmark,
    History,
    Find,
    ZoomIn,
    ZoomOut,
    ZoomReset,
    Command
}

public static class BrowserGestures
{
    public const int KeyTab = 0x09;
    public const int KeyLeft = 0x25;
    public const int KeyRight = 0x27;
    public const int Key0 = 0x30;
    public const int Key1 = 0x31;
    public const int Key9 = 0x39;
    public const int KeyD = 0x44;
    public const int KeyF = 0x46;
    public const int KeyH = 0x48;
    public const int KeyK = 0x4B;
    public const int KeyL = 0x4C;
    public const int KeyR = 0x52;
    public const int KeyT = 0x54;
    public const int KeyW = 0x57;
    public const int KeyF5 = 0x74;
    public const int KeyF11 = 0x7A;
    public const int KeyAdd = 0x6B;
    public const int KeySubtract = 0x6D;
    public const int KeyOemPlus = 0xBB;
    public const int KeyOemMinus = 0xBD;

    public static BrowserAction Match(bool control, bool shift, bool alt, int key, out int tabNumber)
    {
        tabNumber = 0;
        if (key == KeyF11)
        {
            return BrowserAction.FullScreen;
        }

        if (key == KeyF5 || (control && !shift && !alt && key == KeyR))
        {
            return BrowserAction.Reload;
        }

        if (alt && !control && key == KeyLeft)
        {
            return BrowserAction.Back;
        }

        if (alt && !control && key == KeyRight)
        {
            return BrowserAction.Forward;
        }

        if (alt && !control && !shift && key == KeyD)
        {
            return BrowserAction.FocusAddress;
        }

        if (!control || alt)
        {
            return BrowserAction.None;
        }

        if (key == KeyT)
        {
            return shift ? BrowserAction.ReopenTab : BrowserAction.NewTab;
        }

        if (!shift && key == KeyW)
        {
            return BrowserAction.CloseTab;
        }

        if (!shift && (key == KeyL || key == KeyK))
        {
            return key == KeyK ? BrowserAction.Command : BrowserAction.FocusAddress;
        }

        if (key == KeyTab)
        {
            return shift ? BrowserAction.PreviousTab : BrowserAction.NextTab;
        }

        if (!shift && key == KeyD)
        {
            return BrowserAction.Bookmark;
        }

        if (!shift && key == KeyH)
        {
            return BrowserAction.History;
        }

        if (!shift && key == KeyF)
        {
            return BrowserAction.Find;
        }

        if (key == KeyOemPlus || key == KeyAdd)
        {
            return BrowserAction.ZoomIn;
        }

        if (!shift && (key == KeyOemMinus || key == KeySubtract))
        {
            return BrowserAction.ZoomOut;
        }

        if (!shift && key == Key0)
        {
            return BrowserAction.ZoomReset;
        }

        if (!shift && key >= Key1 && key <= Key9)
        {
            tabNumber = key - Key0;
            return BrowserAction.SelectTab;
        }

        return BrowserAction.None;
    }

    public static int? TabIndex(int count, int number)
    {
        if (count <= 0 || number < 1 || number > 9)
        {
            return null;
        }

        if (number == 9)
        {
            return count - 1;
        }

        var index = number - 1;
        return index < count ? index : null;
    }

    public static bool ShouldOpenReplacement(int tabsBeforeClose) => tabsBeforeClose <= 1;
}
