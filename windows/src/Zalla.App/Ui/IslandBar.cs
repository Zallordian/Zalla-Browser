namespace Zalla;

sealed class IslandBar : Grid
{
    readonly Border _shell = new();
    readonly Button _back;
    readonly Button _forward;
    readonly Button _reload;
    readonly TextBlock _reloadLabel;
    readonly Button _bookmark;
    readonly TextBlock _bookmarkLabel;
    readonly TextBox _input = new();
    readonly Button _burn;
    string _address = "";

    public IslandBar()
    {
        Height = 70;
        VerticalAlignment = VerticalAlignment.Center;
        _shell.BorderThickness = new Thickness(1);
        _shell.BorderBrush = Paint.Brush(Paint.White, 40);
        _shell.CornerRadius = new CornerRadius(35);
        _shell.Padding = new Thickness(12, 0, 12, 0);
        Children.Add(_shell);

        var row = new Grid { VerticalAlignment = VerticalAlignment.Center };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        _shell.Child = row;

        var z = TextButton(Copy.Menu, () => { });
        var menu = new MenuFlyout { Placement = FlyoutPlacementMode.Bottom };
        menu.Items.Add(Item(Copy.NewTab, () => NewTab?.Invoke()));
        menu.Items.Add(Item(Copy.Bookmarks, () => Bookmarks?.Invoke()));
        menu.Items.Add(Item(Copy.History, () => History?.Invoke()));
        menu.Items.Add(Item(Copy.Downloads, () => Downloads?.Invoke()));
        menu.Items.Add(Item(Copy.Extensions, () => Extensions?.Invoke()));
        menu.Items.Add(Item(Copy.Cards, () => Deck?.Invoke()));
        menu.Items.Add(Item(Copy.Settings, () => Settings?.Invoke()));
        menu.Items.Add(Item(Copy.BurnTooltip, () => Burn?.Invoke()));
        z.Flyout = menu;
        AutomationProperties.SetName(z, Copy.Menu);
        row.Children.Add(z);

        _back = TextButton(Copy.Back, () => Back?.Invoke());
        _back.Margin = new Thickness(8, 0, 0, 0);
        Grid.SetColumn(_back, 1);
        row.Children.Add(_back);

        _forward = TextButton(Copy.Forward, () => Forward?.Invoke());
        _forward.Margin = new Thickness(6, 0, 0, 0);
        Grid.SetColumn(_forward, 2);
        row.Children.Add(_forward);

        _reloadLabel = new TextBlock { Text = Copy.Reload, FontSize = 15, Foreground = Paint.Brush(Paint.White) };
        _reload = TextButton(Copy.Reload, () => ReloadOrStop?.Invoke());
        _reload.Content = _reloadLabel;
        _reload.Margin = new Thickness(6, 0, 8, 0);
        Grid.SetColumn(_reload, 3);
        row.Children.Add(_reload);

        _input.PlaceholderText = Copy.SearchPlaceholder;
        _input.BorderThickness = new Thickness(0);
        _input.Background = Paint.Brush(Paint.Black, 90);
        _input.Foreground = Paint.Brush(Paint.White);
        _input.CornerRadius = new CornerRadius(8);
        _input.Height = 44;
        _input.MinWidth = 240;
        _input.Padding = new Thickness(14, 8, 14, 8);
        _input.FontSize = 16;
        _input.VerticalAlignment = VerticalAlignment.Center;
        _input.RequestedTheme = ElementTheme.Dark;
        _input.KeyDown += OnKey;
        Grid.SetColumn(_input, 4);
        row.Children.Add(_input);

        _bookmarkLabel = new TextBlock { Text = Copy.Bookmark, FontSize = 15, Foreground = Paint.Brush(Paint.White) };
        _bookmark = TextButton(Copy.Bookmark, () => Bookmark?.Invoke());
        _bookmark.Content = _bookmarkLabel;
        _bookmark.Margin = new Thickness(8, 0, 0, 0);
        Grid.SetColumn(_bookmark, 5);
        row.Children.Add(_bookmark);

        _burn = TextButton(Copy.BurnTooltip, () => Burn?.Invoke());
        if (_burn.Content is TextBlock flame)
        {
            flame.FontFamily = new FontFamily("Segoe UI Emoji");
        }
        _burn.Margin = new Thickness(8, 0, 0, 0);
        AutomationProperties.SetName(_burn, Copy.BurnTooltip);
        ToolTipService.SetToolTip(_burn, Copy.BurnTooltip);
        Grid.SetColumn(_burn, 6);
        row.Children.Add(_burn);

        SetHistory(false, false);
    }

    public TextBox Input => _input;

    public bool CommandMode { get; private set; }

    public event Action? Back;
    public event Action? Forward;
    public event Action? ReloadOrStop;
    public event Action? Bookmark;
    public event Action? Burn;
    public event Action? NewTab;
    public event Action? Settings;
    public event Action? Bookmarks;
    public event Action? History;
    public event Action? Downloads;
    public event Action? Extensions;
    public event Action? Deck;
    public event Action<string, bool>? Submit;

    public void UsePill(bool pill)
    {
        _shell.CornerRadius = new CornerRadius(pill ? 20 : 0);
        Height = 64;
        Margin = new Thickness(0);
        _shell.Padding = new Thickness(pill ? 12 : 8, 0, 12, 0);
    }

    public void SetLoading(bool loading)
    {
        _reloadLabel.Text = loading ? Copy.Stop : Copy.Reload;
        AutomationProperties.SetName(_reload, _reloadLabel.Text);
        ToolTipService.SetToolTip(_reload, _reloadLabel.Text);
    }

    public void SetBookmarked(bool marked)
    {
        _bookmarkLabel.Text = marked ? Copy.Bookmarked : Copy.Bookmark;
        AutomationProperties.SetName(_bookmark, _bookmarkLabel.Text);
        ToolTipService.SetToolTip(_bookmark, _bookmarkLabel.Text);
    }

    public void SetAddress(string url)
    {
        _address = url;
        if (CommandMode || _input.FocusState != FocusState.Unfocused)
        {
            return;
        }

        _input.Text = url;
    }

    public void SetHistory(bool canBack, bool canForward)
    {
        _back.Opacity = canBack ? 1 : 0.35;
        _forward.Opacity = canForward ? 1 : 0.35;
        _back.IsEnabled = canBack;
        _forward.IsEnabled = canForward;
    }

    public void FocusCommand(bool command)
    {
        CommandMode = command;
        _input.PlaceholderText = command ? Copy.CommandPlaceholder : Copy.SearchPlaceholder;
        if (command)
        {
            _input.Text = "";
        }
        else
        {
            _input.Text = _address;
        }

        _input.Focus(FocusState.Programmatic);
        _input.SelectAll();
    }

    public void LeaveCommand()
    {
        CommandMode = false;
        _input.PlaceholderText = Copy.SearchPlaceholder;
        _input.Text = _address;
    }

    public void ApplyChrome(Color fill, Color burnTop, Color burnBottom)
    {
        _shell.Background = Paint.Brush(fill);
        Paint.FillButton(_burn, new LinearGradientBrush
        {
            StartPoint = new Point(0.5, 0),
            EndPoint = new Point(0.5, 1),
            GradientStops =
            {
                new GradientStop { Color = burnTop, Offset = 0 },
                new GradientStop { Color = burnBottom, Offset = 1 }
            }
        }, Paint.Brush(Paint.White));
    }

    public void ApplyBrand(Color brand)
    {
        if (_shell.Child is Grid row && row.Children[0] is Button z)
        {
            Paint.FillButton(z, Paint.Brush(brand), Paint.Brush(Paint.White));
        }
    }

    void OnKey(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key == Windows.System.VirtualKey.Enter)
        {
            Submit?.Invoke(_input.Text, CommandMode);
            e.Handled = true;
        }
        else if (e.Key == Windows.System.VirtualKey.Escape)
        {
            LeaveCommand();
            e.Handled = true;
        }
    }

    static MenuFlyoutItem Item(string text, Action action)
    {
        var item = new MenuFlyoutItem { Text = text };
        item.Click += (_, _) => action();
        return item;
    }

    static Button LetterButton(string text)
    {
        var label = new TextBlock
        {
            Text = text,
            FontSize = 20,
            FontWeight = FontWeights.Bold,
            Foreground = Paint.Brush(Paint.White),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        var button = Paint.Flat(label, 46);
        button.Foreground = Paint.Brush(Paint.White);
        return button;
    }

    static Button TextButton(string name, Action action)
    {
        var label = new TextBlock
        {
            Text = name,
            FontSize = 15,
            Foreground = Paint.Brush(Paint.White),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        var button = new Button
        {
            Content = label,
            Height = 40,
            MinWidth = 72,
            Padding = new Thickness(12, 0, 12, 0),
            Margin = new Thickness(0),
            CornerRadius = new CornerRadius(8),
            BorderThickness = new Thickness(1)
        };
        var rest = Paint.Brush("101820", 230);
        var hover = Paint.Brush("243044");
        Paint.FillButton(button, rest, Paint.Brush(Paint.White));
        button.Resources["ButtonBackgroundPointerOver"] = hover;
        button.Resources["ButtonBackgroundPressed"] = Paint.Brush("0A1018");
        button.Resources["ButtonBorderBrush"] = Paint.Brush(Paint.White, 80);
        button.Resources["ButtonBorderBrushPointerOver"] = Paint.Brush(Paint.White, 160);
        button.Click += (_, _) => action();
        AutomationProperties.SetName(button, name);
        ToolTipService.SetToolTip(button, name);
        return button;
    }
}
