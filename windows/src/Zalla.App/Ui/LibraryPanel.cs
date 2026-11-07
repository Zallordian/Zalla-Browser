namespace Zalla;

sealed class DownloadNote
{
    public string Name { get; set; } = "Download";

    public string State { get; set; } = "";
}

sealed class LibraryPanel : Grid
{
    public LibraryPanel(string title, string note, IReadOnlyList<(string Label, string? Url)> rows, string empty, Action<string> open, Action? extra, string? extraLabel, Action close)
    {
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
            BorderThickness = new Thickness(1)
        };
        var stack = new StackPanel { Spacing = 10 };
        var header = new Grid();
        header.Children.Add(new TextBlock { Text = title, FontSize = 26, FontWeight = FontWeights.Bold, Foreground = Paint.Brush(Paint.White) });
        var closeButton = CaptionButtons.Create(CaptionKind.Close, close);
        closeButton.HorizontalAlignment = HorizontalAlignment.Right;
        header.Children.Add(closeButton);
        stack.Children.Add(header);
        if (!string.IsNullOrWhiteSpace(note))
        {
            stack.Children.Add(new TextBlock { Text = note, FontSize = 15, Foreground = Paint.Brush(Paint.White), TextWrapping = TextWrapping.Wrap });
        }

        if (extra != null && extraLabel != null)
        {
            var action = new Button { Content = extraLabel, Height = 40, Padding = new Thickness(14, 0, 14, 0), FontSize = 15 };
            Paint.FillButton(action, Paint.Brush("E33B4F"), Paint.Brush(Paint.White));
            action.Click += (_, _) => extra();
            AutomationProperties.SetName(action, extraLabel);
            stack.Children.Add(action);
        }

        var list = new StackPanel { Spacing = 6 };
        if (rows.Count == 0)
        {
            list.Children.Add(new TextBlock { Text = empty, FontSize = 15, Foreground = Paint.Brush(Paint.White), Opacity = 0.8 });
        }

        foreach (var row in rows)
        {
            var button = new Button
            {
                Content = row.Label,
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Left,
                Height = 40,
                FontSize = 15
            };
            Paint.FillButton(button, Paint.Brush(Paint.White, 20), Paint.Brush(Paint.White));
            var url = row.Url;
            if (!string.IsNullOrWhiteSpace(url))
            {
                button.Click += (_, _) => open(url);
            }

            AutomationProperties.SetName(button, row.Label);
            list.Children.Add(button);
        }

        stack.Children.Add(new ScrollViewer { MaxHeight = 420, Content = list });
        card.Child = stack;
        Children.Add(card);
    }
}
