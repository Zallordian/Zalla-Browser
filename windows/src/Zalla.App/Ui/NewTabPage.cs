namespace Zalla;

sealed class NewTabPage : Grid
{
    readonly StackPanel _center;
    readonly TextBlock _saying;

    public NewTabPage(string saying, Action<string> open)
    {
        Background = Paint.Brush(Paint.White, 1);
        _center = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Spacing = 8
        };
        Children.Add(_center);

        var logo = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center
        };
        logo.Children.Add(new TextBlock
        {
            Text = "Zalla",
            FontSize = 76,
            FontWeight = Windows.UI.Text.FontWeights.ExtraBold,
            Foreground = Paint.Brush(Paint.White)
        });
        logo.Children.Add(new TextBlock
        {
            Text = ".",
            FontSize = 76,
            FontWeight = Windows.UI.Text.FontWeights.ExtraBold,
            Foreground = Paint.Brush("E33B4F")
        });
        _center.Children.Add(logo);

        _saying = new TextBlock
        {
            Text = saying,
            FontSize = 16,
            Opacity = 0.7,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 0, 0, 36)
        };
        _center.Children.Add(_saying);

        var shortcuts = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            Spacing = 28
        };
        foreach (var (name, url, color) in Links)
        {
            shortcuts.Children.Add(Shortcut(name, color, () => open(url)));
        }

        _center.Children.Add(shortcuts);

        PointerPressed += (_, e) =>
        {
            if (!HitTestHelper.IsInteractive(e.OriginalSource as DependencyObject))
            {
                WindowDrag.Requested?.Invoke();
            }
        };
    }

    public void SetSideInset(double left, double right)
    {
        _center.Margin = new Thickness(left, 0, right, 40);
    }

    public void SetBrand(Color brand)
    {
        if (_center.Children[0] is StackPanel logo && logo.Children.Count > 1 && logo.Children[1] is TextBlock dot)
        {
            dot.Foreground = Paint.Brush(brand);
        }
    }

    static Button Shortcut(string name, string color, Action open)
    {
        var tile = new Grid { Width = 80, Height = 80 };
        tile.Children.Add(new Ellipse
        {
            Fill = Paint.Brush(Paint.White, 20),
            Stroke = Paint.Brush(Paint.White, 36),
            StrokeThickness = 1
        });
        var inner = new Grid { Width = 42, Height = 42, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center };
        inner.Children.Add(new Ellipse { Fill = Paint.Brush(color) });
        inner.Children.Add(new TextBlock
        {
            Text = name[..1],
            FontSize = 20,
            FontWeight = Windows.UI.Text.FontWeights.Bold,
            Foreground = Paint.Brush(Paint.White),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        });
        tile.Children.Add(inner);

        var stack = new StackPanel { Spacing = 8, HorizontalAlignment = HorizontalAlignment.Center };
        stack.Children.Add(tile);
        stack.Children.Add(new TextBlock
        {
            Text = name,
            FontSize = 13,
            HorizontalAlignment = HorizontalAlignment.Center,
            Foreground = Paint.Brush(Paint.White)
        });

        var button = Paint.Flat(stack);
        button.Click += (_, _) => open();
        AutomationProperties.SetName(button, name);
        return button;
    }

    static readonly (string Name, string Url, string Color)[] Links =
    [
        ("YouTube", "https://www.youtube.com", "FF0033"),
        ("Wikipedia", "https://www.wikipedia.org", "888888"),
        ("GitHub", "https://github.com", "333333"),
        ("Reddit", "https://www.reddit.com", "FF4500"),
        ("News", "https://news.google.com", "3AA0FF"),
        ("Mail", "https://mail.google.com", "7C5CFF")
    ];
}

static class HitTestHelper
{
    public static bool IsInteractive(DependencyObject? node)
    {
        while (node is not null)
        {
            if (node is Button or TextBox or ToggleSwitch or ComboBox or RadioButton or Slider)
            {
                return true;
            }

            node = VisualTreeHelper.GetParent(node);
        }

        return false;
    }
}

static class WindowDrag
{
    public static Action? Requested { get; set; }
}
