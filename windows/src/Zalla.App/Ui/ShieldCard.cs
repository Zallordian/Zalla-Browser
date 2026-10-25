namespace Zalla;

sealed class ShieldCard : Grid
{
    readonly Border _card = new();
    readonly Ellipse _orb = new() { Width = 46, Height = 46 };
    readonly TextBlock _title = new() { FontWeight = Windows.UI.Text.FontWeights.Bold, FontSize = 15 };
    readonly TextBlock _tune = new() { Text = Copy.ClickToTune, FontSize = 12, Opacity = 0.7 };
    readonly TextBlock _lines = new() { FontSize = 12, Opacity = 0.88, Margin = new Thickness(0, 12, 0, 0) };
    readonly TextBlock _count = new() { FontSize = 30, FontWeight = Windows.UI.Text.FontWeights.ExtraBold, Margin = new Thickness(0, 8, 0, 0) };
    readonly TextBlock _countLabel = new() { Text = Copy.BlockedWeek, FontSize = 12, Opacity = 0.65 };
    readonly StackPanel _details = new();

    public ShieldCard()
    {
        Width = 210;
        _card.Padding = new Thickness(16);
        _card.CornerRadius = new CornerRadius(22);
        _card.BorderThickness = new Thickness(1);
        _card.Child = Build();
        Children.Add(_card);
        _card.PointerPressed += (_, e) =>
        {
            OpenSettings?.Invoke();
            e.Handled = true;
        };
    }

    public event Action? OpenSettings;

    public void Update(PrivacySettings privacy, int blocked, bool compact)
    {
        var on = privacy.ShieldOn;
        _title.Text = on ? Copy.ShieldOn : Copy.ShieldOff;
        _card.Background = Paint.Brush(on ? "0A1E16" : "1A1C20", 170);
        _card.BorderBrush = Paint.Brush(on ? "6EE7A8" : "FFFFFF", on ? (byte)90 : (byte)40);
        _orb.Fill = new RadialGradientBrush
        {
            GradientStops =
            {
                new GradientStop { Color = Paint.Hex(on ? "6EE7A8" : "8A9098"), Offset = 0 },
                new GradientStop { Color = Paint.Hex(on ? "14402B" : "2A2E33"), Offset = 1 }
            }
        };
        _lines.Text = string.Join("\n", new[]
        {
            Line(Copy.Trackers, privacy.BlockTrackers),
            Line(Copy.Ads, privacy.BlockCommonAds),
            Line(Copy.CookieBanners, privacy.CookieBanners),
            Line(Copy.HttpsOnly, privacy.HttpsOnly),
            Line(Copy.Fingerprinting, privacy.Fingerprinting)
        });
        _count.Text = blocked.ToString("N0");
        _details.Visibility = compact ? Visibility.Collapsed : Visibility.Visible;
        Width = compact ? 180 : 210;
    }

    StackPanel Build()
    {
        var root = new StackPanel();
        var header = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12 };
        header.Children.Add(_orb);
        var words = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        words.Children.Add(_title);
        words.Children.Add(_tune);
        header.Children.Add(words);
        root.Children.Add(header);
        _details.Children.Add(_lines);
        _details.Children.Add(_count);
        _details.Children.Add(_countLabel);
        root.Children.Add(_details);
        return root;
    }

    static string Line(string name, bool on) => name + (on ? "  \u25CF" : "  \u25CB");
}
