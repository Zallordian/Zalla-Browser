using System.Runtime.InteropServices;
using System.Text;

namespace Zalla;

static class AppLog
{
    public static string Describe(Exception exception)
    {
        var detail = RestrictedText();
        var text = new StringBuilder();
        text.AppendLine(exception.GetType().FullName);
        text.Append("0x").AppendLine(exception.HResult.ToString("X8"));
        text.AppendLine(exception.Message);
        if (!string.IsNullOrWhiteSpace(detail) && exception.Message.IndexOf(detail, StringComparison.Ordinal) < 0)
        {
            text.AppendLine(detail);
        }

        if (!string.IsNullOrWhiteSpace(exception.StackTrace))
        {
            text.AppendLine(exception.StackTrace);
        }

        return text.ToString().Trim();
    }

    public static void Write(Exception exception) => WriteText(Describe(exception));

    public static void WriteText(string text)
    {
        try
        {
            var directory = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Zalla");
            Directory.CreateDirectory(directory);
            File.AppendAllText(Path.Combine(directory, "zalla.log"), DateTimeOffset.Now.ToString("u") + " " + text + Environment.NewLine + Environment.NewLine);
        }
        catch
        {
            // Logging must not take the window down with it.
        }
    }

    static string RestrictedText()
    {
        try
        {
            if (GetRestrictedErrorInfo(out var info) != 0 || info == null)
            {
                return "";
            }

            info.GetErrorDetails(out var description, out _, out var restricted, out _);
            if (!string.IsNullOrWhiteSpace(restricted))
            {
                return restricted;
            }

            return description ?? "";
        }
        catch
        {
            return "";
        }
    }

    [DllImport("api-ms-win-core-winrt-error-l1-1-1.dll")]
    static extern int GetRestrictedErrorInfo(out IRestrictedErrorInfo info);

    [ComImport]
    [Guid("82BA7092-4C88-427D-A7BC-16DD93FEB67E")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IRestrictedErrorInfo
    {
        void GetErrorDetails(
            [MarshalAs(UnmanagedType.BStr)] out string description,
            out int error,
            [MarshalAs(UnmanagedType.BStr)] out string restrictedDescription,
            [MarshalAs(UnmanagedType.BStr)] out string capabilitySid);

        void GetReference([MarshalAs(UnmanagedType.BStr)] out string reference);
    }
}
