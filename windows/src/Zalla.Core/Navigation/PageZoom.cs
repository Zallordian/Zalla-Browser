namespace Zalla.Core;

public static class PageZoom
{
    static readonly double[] Steps = [0.25, 0.33, 0.5, 0.67, 0.75, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4, 5];

    public static double In(double current) => Neighbor(current, 1);

    public static double Out(double current) => Neighbor(current, -1);

    public static double Reset() => 1;

    public static string Label(double factor) => Math.Round(factor * 100).ToString(System.Globalization.CultureInfo.InvariantCulture) + "%";

    static double Neighbor(double current, int direction)
    {
        var index = 0;
        var best = double.MaxValue;
        for (var i = 0; i < Steps.Length; i++)
        {
            var gap = Math.Abs(Steps[i] - current);
            if (gap < best)
            {
                best = gap;
                index = i;
            }
        }

        var next = Math.Clamp(index + direction, 0, Steps.Length - 1);
        return Steps[next];
    }
}
