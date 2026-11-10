namespace Zalla.Core;

public enum InputRoute
{
    None,
    Navigate,
    Command
}

public readonly record struct InputDecision(InputRoute Route, string Text, ParsedCommand Command)
{
    public static InputDecision None { get; } = new(InputRoute.None, "", ParsedCommand.Empty);
}

/// <summary>
/// The address field is a search box until it is opened as a command bar.
/// A leading slash is always a command. Ctrl K sets command mode.
/// </summary>
public static class InputRouter
{
    public static InputDecision Decide(string text, bool commandMode)
    {
        var trimmed = text.Trim();
        if (trimmed.Length == 0)
        {
            return InputDecision.None;
        }

        var slash = trimmed.StartsWith('/');
        if (commandMode || slash)
        {
            var parsed = CommandParser.Parse(trimmed);
            if (parsed.Kind == CommandKind.Empty)
            {
                return InputDecision.None;
            }

            if (parsed.Kind != CommandKind.Unknown)
            {
                return new InputDecision(InputRoute.Command, trimmed, parsed);
            }

            if (commandMode && !slash && AddressResolver.LooksNavigable(trimmed))
            {
                return new InputDecision(InputRoute.Navigate, trimmed, ParsedCommand.Empty);
            }

            return new InputDecision(InputRoute.Command, trimmed, parsed);
        }

        return new InputDecision(InputRoute.Navigate, trimmed, ParsedCommand.Empty);
    }
}
