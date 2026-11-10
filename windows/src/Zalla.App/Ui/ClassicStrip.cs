namespace Zalla;

sealed class ClassicStrip : Grid
{
    readonly StackPanel _tabs = new() { Orientation = Orientation.Horizontal, Spacing = 4 };
    readonly ScrollViewer _scroll;
    string _signature = "";

    public ClassicStrip()
    {
        Height = 44;
        Background = Paint.Brush("070B12");
        Padding = new Thickness(10, 6, 148, 0);
        ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        SpacesHost = new Grid { VerticalAlignment = VerticalAlignment.Center, Margin = new Thickness(0, 0, 12, 0) };
        Children.Add(SpacesHost);

        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        _scroll = new ScrollViewer
        {
            HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden,
            VerticalScrollBarVisibility = ScrollBarVisibility.Disabled,
            Content = _tabs
        };
        row.Children.Add(_scroll);
        var add = new Button
        {
            Content = ChromeIcons.Plus(),
            Width = 32,
            Height = 32,
            Padding = new Thickness(0),
            CornerRadius = new CornerRadius(8),
            BorderThickness = new Thickness(0),
            Background = Paint.Brush(Paint.White, 0),
            VerticalAlignment = VerticalAlignment.Center
        };
        Paint.TryTheme(add, "ButtonBackground", Paint.Brush(Paint.White, 0));
        Paint.TryTheme(add, "ButtonBackgroundPointerOver", Paint.Brush(Paint.White, 28));
        Paint.TryTheme(add, "ButtonBackgroundPressed", Paint.Brush(Paint.White, 48));
        add.Click += (_, _) => NewTab?.Invoke();
        AutomationProperties.SetName(add, Copy.NewTab);
        ToolTipService.SetToolTip(add, Copy.NewTab + " (Ctrl+T)");
        row.Children.Add(add);
        Grid.SetColumn(row, 1);
        Children.Add(row);
    }

    public Grid SpacesHost { get; }

    public event Action<string>? Selected;
    public event Action<string>? Closed;
    public event Action? NewTab;

    public void Bind(IReadOnlyList<DeckCard> cards, Color accent)
    {
        var signature = accent.A + "." + accent.R + "." + accent.G + "." + accent.B + "\n" + string.Join("\n", cards.Select(card => card.Id + "\u001f" + card.Title + "\u001f" + card.Active + "\u001f" + card.ColorHex));
        if (signature == _signature)
        {
            return;
        }

        _signature = signature;
        _tabs.Children.Clear();
        foreach (var card in cards)
        {
            var tab = new Grid
            {
                MinWidth = 132,
                MaxWidth = 220,
                Height = 32
            };
            var chrome = new Border
            {
                Background = card.Active ? Paint.Brush("121A26") : Paint.Brush(Paint.White, 0),
                CornerRadius = new CornerRadius(8, 8, 0, 0),
                Child = tab
            };
            if (card.Active)
            {
                chrome.BorderBrush = Paint.Brush(accent);
                chrome.BorderThickness = new Thickness(0, 0, 0, 2);
            }
            tab.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            tab.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            tab.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            var dot = new Border
            {
                Width = 10,
                Height = 10,
                CornerRadius = new CornerRadius(3),
                Background = Paint.Brush(card.ColorHex),
                Margin = new Thickness(8, 0, 6, 0),
                VerticalAlignment = VerticalAlignment.Center
            };
            tab.Children.Add(dot);
            var title = new TextBlock
            {
                Text = card.Title,
                FontSize = 13,
                FontWeight = card.Active ? FontWeights.SemiBold : FontWeights.Normal,
                VerticalAlignment = VerticalAlignment.Center,
                TextTrimming = TextTrimming.CharacterEllipsis
            };
            Grid.SetColumn(title, 1);
            tab.Children.Add(title);
            var close = Paint.Flat(new TextBlock { Text = "\u00D7", FontSize = 14 }, 22);
            close.Margin = new Thickness(0, 0, 4, 0);
            var id = card.Id;
            close.Click += (_, _) => Closed?.Invoke(id);
            AutomationProperties.SetName(close, Copy.Close);
            Grid.SetColumn(close, 2);
            tab.Children.Add(close);
            chrome.PointerPressed += (_, e) =>
            {
                if (!HitTestHelper.IsInteractive(e.OriginalSource as DependencyObject))
                {
                    Selected?.Invoke(id);
                }
            };
            _tabs.Children.Add(chrome);
        }
    }
}
