namespace Zalla.Core;

public sealed class LaunchClock
{
    readonly long _start = Environment.TickCount64;
    readonly List<string> _marks = new();

    public void Mark(string name)
    {
        _marks.Add(name + " " + (Environment.TickCount64 - _start));
    }

    public string Line() => string.Join(", ", _marks);

    public int Count => _marks.Count;
}
