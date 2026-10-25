namespace Zalla;

static class AppLog
{
    public static void Write(Exception exception)
    {
        try
        {
            var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Zalla");
            Directory.CreateDirectory(directory);
            File.AppendAllText(Path.Combine(directory, "zalla.log"), DateTimeOffset.Now.ToString("u") + " " + exception + Environment.NewLine + Environment.NewLine);
        }
        catch
        {
            // Logging must not take the window down with it.
        }
    }
}
