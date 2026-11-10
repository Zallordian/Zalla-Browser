using System.Text.Json;

namespace Zalla.Core;

public static class PageFind
{
    public static string CountScript(string? term)
    {
        var query = JsonSerializer.Serialize(term ?? "");
        return "(() => { const q = " + query + "; if (!q) return 0; const text = document.body ? document.body.innerText : ''; const hay = text.toLowerCase(); const needle = q.toLowerCase(); let n = 0, i = 0; while (needle.length && (i = hay.indexOf(needle, i)) !== -1) { n++; i += needle.length; } return n; })()";
    }

    public static string JumpScript(string? term, bool backwards)
    {
        var query = JsonSerializer.Serialize(term ?? "");
        return "window.find(" + query + ", false, " + (backwards ? "true" : "false") + ", true, false, false, false)";
    }

    public static string ClearScript() => "(() => { const s = window.getSelection(); if (s) s.removeAllRanges(); return true; })()";

    public static string CopyScript() => "document.execCommand('copy')";

    public static string SelectAllScript() => "document.execCommand('selectAll')";
}
