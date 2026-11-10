namespace Zalla;

public partial class App : Application
{
    Window? _window;

    public App()
    {
        InitializeComponent();
        UnhandledException += (_, args) => AppLog.Write(args.Exception);
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            _window = new ShellWindow();
            _window.Activate();
        }
        catch (Exception ex)
        {
            var details = AppLog.Describe(ex);
            AppLog.WriteText(details);
            var note = details.Contains("WebView2", StringComparison.OrdinalIgnoreCase)
                ? Environment.NewLine + Environment.NewLine + Copy.WebViewMissing
                : "";
            var fallback = new Window { Title = "Zalla" };
            var body = new TextBlock
            {
                Text = Copy.OpenFailed + Environment.NewLine + Environment.NewLine + details + note + Environment.NewLine + Environment.NewLine + Copy.LogHint,
                TextWrapping = TextWrapping.Wrap,
                FontSize = 14,
                Foreground = Paint.Brush(Paint.White),
                IsTextSelectionEnabled = true
            };
            fallback.Content = new ScrollViewer
            {
                Background = Paint.Brush("111111"),
                Padding = new Thickness(24),
                Content = body
            };
            fallback.Activate();
            _window = fallback;
        }
    }
}
