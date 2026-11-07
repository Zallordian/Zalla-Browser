namespace Zalla.Core;

/// <summary>
/// WinUI can leave Parent null after Children.Add, until the window is shown.
/// A second Add of that same element throws 0x800F1000.
/// </summary>
public static class ElementPlacement
{
    public readonly record struct Plan(bool DetachFromOther, bool Add);

    public static Plan Decide(bool targetContains, bool reportedParentIsTarget, bool listedInOtherPanel)
    {
        if (targetContains || reportedParentIsTarget)
        {
            return new Plan(false, false);
        }

        return new Plan(listedInOtherPanel, true);
    }
}
