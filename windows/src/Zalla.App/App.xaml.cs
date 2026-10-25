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
            AppLog.Write(ex);
            var fallback = new Window { Title = "Zalla" };
            fallback.Content = new TextBlock
            {
                Text = "Zalla could not open. " + ex.Message,
                Margin = new Thickness(24),
                TextWrapping = TextWrapping.Wrap,
                FontSize = 16
            };
            fallback.Activate();
            _window = fallback;
        }
    }
}
