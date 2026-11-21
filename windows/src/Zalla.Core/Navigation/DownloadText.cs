namespace Zalla.Core;

public static class DownloadText
{
    public static string Describe(long received, long total, bool finished, string? state)
    {
        if (finished)
        {
            return "Finished";
        }

        if (total > 0)
        {
            return Size(received) + " of " + Size(total);
        }

        if (received > 0)
        {
            return Size(received);
        }

        return string.IsNullOrWhiteSpace(state) ? "Starting" : state.Trim();
    }

    public static string Size(long bytes)
    {
        if (bytes < 1024)
        {
            return bytes + " B";
        }

        var value = bytes / 1024d;
        var unit = "KB";
        if (value >= 1024)
        {
            value /= 1024;
            unit = "MB";
        }

        if (value >= 1024)
        {
            value /= 1024;
            unit = "GB";
        }

        return value.ToString("0.#", System.Globalization.CultureInfo.InvariantCulture) + " " + unit;
    }
}
