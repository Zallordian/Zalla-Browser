namespace Zalla.Core;

public sealed class ThemeDocument
{
    public int Version { get; set; }

    public string Note { get; set; } = "";

    public List<string> ExportedFrom { get; set; } = new();

    public List<ThemeRecord> Themes { get; set; } = new();

    public List<SeasonWindowRecord> SeasonalWindows { get; set; } = new();

    public List<BackgroundRecord> NewTabBackgrounds { get; set; } = new();

    public List<ThemePackRecord> ThemePacks { get; set; } = new();
}

public sealed class ThemeRecord
{
    public string Id { get; set; } = "";

    public string Name { get; set; } = "";

    public string Group { get; set; } = "";

    public bool RequiresUnlock { get; set; }

    public bool Seasonal { get; set; }

    public bool UsesGradientAccent { get; set; } = true;

    public string PrimaryHex { get; set; } = "";

    public ThemeColors Colors { get; set; } = new();

    public string Icon { get; set; } = "";
}

public sealed class ThemeColors
{
    public string Primary { get; set; } = "";

    public string Bright { get; set; } = "";

    public string Deep { get; set; } = "";

    public string Highlight { get; set; } = "";

    public string GradientEnd { get; set; } = "";
}

public sealed class SeasonWindowRecord
{
    public string Id { get; set; } = "";

    public string Kind { get; set; } = "";

    public string? Rule { get; set; }

    public SeasonDateRecord? Start { get; set; }

    public SeasonDateRecord? End { get; set; }

    public int? StartOffsetDays { get; set; }

    public int? EndOffsetDays { get; set; }
}

public sealed class SeasonDateRecord
{
    public int Month { get; set; }

    public int Day { get; set; }

    public int YearOffset { get; set; }

    public string? DayMeaning { get; set; }
}

public sealed class BackgroundRecord
{
    public string Id { get; set; } = "";

    public string Name { get; set; } = "";

    public List<string> Colors { get; set; } = new();

    public string Style { get; set; } = "";

    public bool IsDark { get; set; }

    public string? Pack { get; set; }

    public string Decor { get; set; } = "none";

    public bool RequiresUnlock { get; set; }
}

public sealed class ThemePackRecord
{
    public string Id { get; set; } = "";

    public string Name { get; set; } = "";

    public string Tagline { get; set; } = "";

    public string ThemeId { get; set; } = "";

    public string Icon { get; set; } = "";

    public string BackgroundPresetId { get; set; } = "";

    public string Transition { get; set; } = "";

    public string SymbolName { get; set; } = "";
}

public static class ThemeHex
{
    public static bool IsRgb(string? value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length != 6)
        {
            return false;
        }

        foreach (var ch in value)
        {
            var ok = ch is >= '0' and <= '9' or >= 'a' and <= 'f' or >= 'A' and <= 'F';
            if (!ok)
            {
                return false;
            }
        }

        return true;
    }
}
