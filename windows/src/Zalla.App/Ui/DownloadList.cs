namespace Zalla;

sealed class DownloadList : Grid
{
    readonly StackPanel _rows = new() { Spacing = 8 };
    readonly Action<string> _open;
    readonly Action<string> _reveal;

    public DownloadList(Action<string> open, Action<string> reveal, Action close)
    {
        _open = open;
        _reveal = reveal;
        Background = Paint.Brush(Paint.Black, 140);
        var card = new Border
        {
            Width = 720,
            MaxHeight = 640,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            CornerRadius = new CornerRadius(16),
            Padding = new Thickness(20),
            Background = Paint.Brush("0E1E34", 245),
            BorderBrush = Paint.Brush(Paint.White, 50),
            BorderThickness = new Thickness(1),
            RequestedTheme = ElementTheme.Dark
        };
        var stack = new StackPanel { Spacing = 10 };
        var header = new Grid();
        header.Children.Add(new TextBlock { Text = Copy.Downloads, FontSize = 26, FontWeight = FontWeights.Bold, Foreground = Paint.Brush(Paint.White) });
        var closeButton = CaptionButtons.Create(CaptionKind.Close, close);
        closeButton.HorizontalAlignment = HorizontalAlignment.Right;
        header.Children.Add(closeButton);
        stack.Children.Add(header);
        stack.Children.Add(new TextBlock
        {
            Text = "Files this window has started saving. The usual save prompt still appears.",
            FontSize = 15,
            Foreground = Paint.Brush(Paint.White),
            TextWrapping = TextWrapping.Wrap
        });
        stack.Children.Add(new ScrollViewer { MaxHeight = 460, Content = _rows });
        card.Child = stack;
        Children.Add(card);
    }

    public void Update(IReadOnlyList<DownloadNote> items)
    {
        _rows.Children.Clear();
        if (items.Count == 0)
        {
            _rows.Children.Add(new TextBlock { Text = "No downloads yet.", FontSize = 15, Foreground = Paint.Brush(Paint.White), Opacity = 0.8 });
            return;
        }

        foreach (var item in items)
        {
            var row = new Grid { Margin = new Thickness(0, 0, 0, 4) };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            var words = new StackPanel();
            words.Children.Add(new TextBlock { Text = item.Name, FontSize = 15, Foreground = Paint.Brush(Paint.White), TextTrimming = TextTrimming.CharacterEllipsis });
            words.Children.Add(new TextBlock
            {
                Text = DownloadText.Describe(item.Received, item.Total, item.Finished, item.State),
                FontSize = 13,
                Opacity = 0.75,
                Foreground = Paint.Brush(Paint.White)
            });
            row.Children.Add(words);
            if (item.Finished && !string.IsNullOrWhiteSpace(item.Path))
            {
                var path = item.Path;
                var open = ActionButton("Open", () => _open(path));
                Grid.SetColumn(open, 1);
                row.Children.Add(open);
                var reveal = ActionButton("Show in folder", () => _reveal(path));
                reveal.Margin = new Thickness(8, 0, 0, 0);
                Grid.SetColumn(reveal, 2);
                row.Children.Add(reveal);
            }

            _rows.Children.Add(row);
        }
    }

    static Button ActionButton(string label, Action action)
    {
        var button = new Button { Content = label, Height = 32, Padding = new Thickness(12, 0, 12, 0), FontSize = 13 };
        Paint.FillButton(button, Paint.Brush(Paint.White, 24), Paint.Brush(Paint.White));
        button.Click += (_, _) => action();
        AutomationProperties.SetName(button, label);
        return button;
    }
}
