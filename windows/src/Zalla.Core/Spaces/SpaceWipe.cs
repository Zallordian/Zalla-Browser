namespace Zalla.Core;

public enum SpaceKind
{
    Personal,
    Work,
    Ghost
}

public enum WipeResult
{
    Wiped,
    Missing,
    Skipped,
    Refused
}

public static class SpaceNames
{
    public static string Folder(SpaceKind space) => space switch
    {
        SpaceKind.Personal => "Personal",
        SpaceKind.Work => "Work",
        SpaceKind.Ghost => "Ghost",
        _ => "Personal"
    };

    public static string Label(SpaceKind space) => Folder(space);

    public static bool TryParse(string? value, out SpaceKind space)
    {
        if (Enum.TryParse(value, ignoreCase: true, out space))
        {
            return true;
        }

        space = SpaceKind.Personal;
        return false;
    }
}

/// <summary>
/// Ghost is the only Space whose folder is deleted. Personal and Work stay.
/// Deletes are refused unless the target is a single child folder of the Spaces root.
/// </summary>
public static class SpaceWipe
{
    public const string PendingFileName = "pending-wipe.txt";

    public static bool WipesOnClose(SpaceKind space) => space == SpaceKind.Ghost;

    public static WipeResult Wipe(string spacesRoot, SpaceKind space)
    {
        if (!WipesOnClose(space))
        {
            return WipeResult.Skipped;
        }

        return TryDeleteContained(spacesRoot, SpaceNames.Folder(space));
    }

    public static WipeResult TryDeleteContained(string spacesRoot, string folderName)
    {
        if (!IsSafeFolderName(folderName))
        {
            return WipeResult.Refused;
        }

        var root = Path.GetFullPath(spacesRoot);
        var target = Path.GetFullPath(Path.Combine(root, folderName));
        if (!IsInside(root, target))
        {
            return WipeResult.Refused;
        }

        if (!Directory.Exists(target))
        {
            return WipeResult.Missing;
        }

        try
        {
            Directory.Delete(target, recursive: true);
        }
        catch (IOException)
        {
            return WipeResult.Refused;
        }
        catch (UnauthorizedAccessException)
        {
            return WipeResult.Refused;
        }

        return Directory.Exists(target) ? WipeResult.Refused : WipeResult.Wiped;
    }

    public static void RequestWipe(string spacesRoot, SpaceKind space)
    {
        if (!WipesOnClose(space))
        {
            return;
        }

        Directory.CreateDirectory(spacesRoot);
        File.WriteAllText(Path.Combine(spacesRoot, PendingFileName), SpaceNames.Folder(space));
    }

    public static WipeResult ConsumePending(string spacesRoot)
    {
        var marker = Path.Combine(spacesRoot, PendingFileName);
        if (!File.Exists(marker))
        {
            return WipeResult.Skipped;
        }

        var name = File.ReadAllText(marker).Trim();
        if (!string.Equals(name, SpaceNames.Folder(SpaceKind.Ghost), StringComparison.Ordinal))
        {
            File.Delete(marker);
            return WipeResult.Refused;
        }

        var result = TryDeleteContained(spacesRoot, name);
        if (result is WipeResult.Wiped or WipeResult.Missing)
        {
            File.Delete(marker);
        }

        return result;
    }

    public static bool IsInside(string root, string candidate)
    {
        var rootFull = Path.GetFullPath(root);
        var candidateFull = Path.GetFullPath(candidate);
        var relative = Path.GetRelativePath(rootFull, candidateFull);
        if (relative is "." or "")
        {
            return false;
        }

        if (relative.StartsWith("..", StringComparison.Ordinal) || Path.IsPathRooted(relative))
        {
            return false;
        }

        return !relative.Contains(Path.DirectorySeparatorChar, StringComparison.Ordinal)
            && !relative.Contains(Path.AltDirectorySeparatorChar, StringComparison.Ordinal);
    }

    public static bool IsSafeFolderName(string? folderName)
    {
        if (string.IsNullOrWhiteSpace(folderName))
        {
            return false;
        }

        if (folderName is "." or "..")
        {
            return false;
        }

        return folderName.IndexOfAny(['/', '\\', ':', '*', '?', '"', '<', '>', '|']) < 0;
    }
}
