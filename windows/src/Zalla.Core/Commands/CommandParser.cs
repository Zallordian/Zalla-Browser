namespace Zalla.Core;

public enum CommandKind
{
    Empty,
    Burn,
    Reader,
    Theme,
    NewTab,
    CloseTab,
    Unknown
}

public readonly record struct ParsedCommand(CommandKind Kind, string Argument, string Note)
{
    public static ParsedCommand Empty { get; } = new(CommandKind.Empty, "", "");

    public bool Handled => Kind is not CommandKind.Empty and not CommandKind.Unknown;
}

public static class CommandParser
{
    public const string ReaderNote = "Reader is coming in a later update.";
    public const string ThemeNeedsName = "Name a theme, like theme Lake Superior.";
    public const string UnknownNote = "Zalla does not know that command.";

    public static ParsedCommand Parse(string text)
    {
        var raw = text.Trim();
        if (raw.StartsWith('/'))
        {
            raw = raw[1..].TrimStart();
        }

        if (raw.Length == 0)
        {
            return ParsedCommand.Empty;
        }

        var compact = ThemeCatalog.Compact(raw);
        if (compact is "burn" or "burnit" or "burnitall" or "burnall")
        {
            return new ParsedCommand(CommandKind.Burn, "", "");
        }

        if (compact is "reader" or "readermode" or "readingmode")
        {
            return new ParsedCommand(CommandKind.Reader, "", ReaderNote);
        }

        if (compact is "newtab" or "new" or "opencard" or "newcard")
        {
            return new ParsedCommand(CommandKind.NewTab, "", "");
        }

        if (compact is "closetab" or "close" or "closethistab" or "closecard")
        {
            return new ParsedCommand(CommandKind.CloseTab, "", "");
        }

        if (compact.StartsWith("theme", StringComparison.Ordinal))
        {
            var arg = raw.Length >= 5 && raw[..5].Equals("theme", StringComparison.OrdinalIgnoreCase)
                ? raw[5..].Trim()
                : "";
            if (arg.Length == 0)
            {
                return new ParsedCommand(CommandKind.Theme, "", ThemeNeedsName);
            }

            return new ParsedCommand(CommandKind.Theme, arg, "");
        }

        return new ParsedCommand(CommandKind.Unknown, raw, UnknownNote);
    }
}
