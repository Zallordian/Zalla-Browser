using Microsoft.UI.Xaml.Shapes;

namespace Zalla;

sealed class ShieldCard : Grid
{
    readonly Border _card = new();
    readonly Ellipse _orb = new() { Width = 46, Height = 46 };
    readonly TextBlock _title = new() { FontWeight = FontWeights.Bold, FontSize = 15 };
    readonly TextBlock _tune = new() { Text = Copy.ClickToTune, FontSize = 12, Opacity = 0.7 };
    readonly TextBlock _lines = new() { FontSize = 12, Opacity = 0.88, Margin = new Thickness(0, 12, 0, 0) };
    readonly TextBlock _countLabel = new() { Text = ShieldPresentation.NotCounting, FontSize = 12, Opacity = 0.65, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 10, 0, 0) };
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

    public void Update(PrivacySettings privacy, bool compact)
    {
        var active = privacy.HttpsOnly || privacy.CleanLinks;
        _title.Text = ShieldPresentation.Title;
        _tune.Text = Copy.ClickToTune;
        _card.Background = Paint.Brush(active ? "0A1E16" : "1A1C20", 170);
        _card.BorderBrush = Paint.Brush(active ? "6EE7A8" : "FFFFFF", active ? (byte)90 : (byte)40);
        _orb.Fill = new RadialGradientBrush
        {
            GradientStops =
            {
                new GradientStop { Color = Paint.Hex(active ? "6EE7A8" : "8A9098"), Offset = 0 },
                new GradientStop { Color = Paint.Hex(active ? "14402B" : "2A2E33"), Offset = 1 }
            }
        };
        _lines.Text = string.Join("\n", ShieldPresentation.Lines(privacy.HttpsOnly).Select(line => ShieldPresentation.Format(line.Name, line.State)))
            + "\n" + ShieldPresentation.Detail(privacy.HttpsOnly, privacy.CleanLinks);
        _lines.TextWrapping = TextWrapping.Wrap;
        _details.Visibility = compact ? Visibility.Collapsed : Visibility.Visible;
        Width = compact ? 180 : 230;
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
        _details.Children.Add(_countLabel);
        root.Children.Add(_details);
        return root;
    }

}
