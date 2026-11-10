namespace Zalla;

sealed class IslandBar : Grid
{
    readonly Border _shell = new();
    readonly Button _back;
    readonly Button _forward;
    readonly Button _reload;
    readonly Button _bookmark;
    readonly Button _shield;
    readonly TextBox _input = new();
    readonly TextBlock _shieldTitle = new() { FontSize = 16, FontWeight = FontWeights.SemiBold, Foreground = Paint.Brush(Paint.White) };
    readonly TextBlock _shieldLines = new() { FontSize = 13, TextWrapping = TextWrapping.Wrap, Foreground = Paint.Brush(Paint.White) };
    readonly TextBlock _shieldDetail = new() { FontSize = 13, TextWrapping = TextWrapping.Wrap, Opacity = 0.84, Margin = new Thickness(0, 8, 0, 0), Foreground = Paint.Brush(Paint.White) };
    string _address = "";
    string _shieldKey = "";

    public IslandBar()
    {
        Height = 52;
        VerticalAlignment = VerticalAlignment.Center;
        _shell.BorderThickness = new Thickness(0, 0, 0, 1);
        _shell.BorderBrush = Paint.Brush(Paint.White, 28);
        _shell.Padding = new Thickness(8, 0, 8, 0);
        Children.Add(_shell);

        var row = new Grid { VerticalAlignment = VerticalAlignment.Center };
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        _shell.Child = row;

        _back = IconButton(ChromeIcons.Back(), Copy.Back, Copy.BackTip, () => Back?.Invoke());
        Grid.SetColumn(_back, 0);
        row.Children.Add(_back);

        _forward = IconButton(ChromeIcons.Forward(), Copy.Forward, Copy.ForwardTip, () => Forward?.Invoke());
        _forward.Margin = new Thickness(2, 0, 0, 0);
        Grid.SetColumn(_forward, 1);
        row.Children.Add(_forward);

        _reload = IconButton(ChromeIcons.Reload(), Copy.Reload, Copy.ReloadTip, () => ReloadOrStop?.Invoke());
        _reload.Margin = new Thickness(2, 0, 8, 0);
        Grid.SetColumn(_reload, 2);
        row.Children.Add(_reload);

        _input.PlaceholderText = Copy.SearchPlaceholder;
        _input.BorderThickness = new Thickness(0);
        _input.Background = Paint.Brush("1A2330");
        _input.Foreground = Paint.Brush(Paint.White);
        _input.CornerRadius = new CornerRadius(18);
        _input.Height = 36;
        _input.MinWidth = 220;
        _input.Padding = new Thickness(16, 6, 16, 6);
        _input.FontSize = 15;
        _input.VerticalAlignment = VerticalAlignment.Center;
        _input.RequestedTheme = ElementTheme.Dark;
        _input.KeyDown += OnKey;
        Grid.SetColumn(_input, 3);
        row.Children.Add(_input);

        _bookmark = IconButton(ChromeIcons.Bookmark(false), Copy.Bookmark, Copy.BookmarkTip, () => Bookmark?.Invoke());
        _bookmark.Margin = new Thickness(8, 0, 0, 0);
        Grid.SetColumn(_bookmark, 4);
        row.Children.Add(_bookmark);

        _shield = IconButton(ChromeIcons.Shield(), Copy.ShieldTip, Copy.ShieldTip, () => { });
        _shield.Margin = new Thickness(2, 0, 0, 0);
        _shield.Flyout = BuildShield();
        Grid.SetColumn(_shield, 5);
        row.Children.Add(_shield);

        var menuButton = IconButton(ChromeIcons.Menu(), Copy.Menu, Copy.MenuTip, () => { });
        menuButton.Margin = new Thickness(2, 0, 0, 0);
        menuButton.Flyout = BuildMenu();
        Grid.SetColumn(menuButton, 6);
        row.Children.Add(menuButton);

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
        _shell.CornerRadius = new CornerRadius(pill ? 18 : 0);
        _shell.BorderThickness = new Thickness(pill ? 1 : 0, pill ? 1 : 0, pill ? 1 : 0, 1);
        Height = pill ? 64 : 52;
        Margin = new Thickness(0);
        _shell.Padding = new Thickness(pill ? 12 : 8, 0, 8, 0);
        _shield.Visibility = pill ? Visibility.Collapsed : Visibility.Visible;
    }

    public void SetLoading(bool loading)
    {
        _reload.Content = loading ? ChromeIcons.Stop() : ChromeIcons.Reload();
        var name = loading ? Copy.Stop : Copy.Reload;
        AutomationProperties.SetName(_reload, name);
        ToolTipService.SetToolTip(_reload, loading ? Copy.Stop : Copy.ReloadTip);
    }

    public void SetBookmarked(bool marked)
    {
        _bookmark.Content = ChromeIcons.Bookmark(marked);
        var name = marked ? Copy.Bookmarked : Copy.Bookmark;
        AutomationProperties.SetName(_bookmark, name);
        ToolTipService.SetToolTip(_bookmark, marked ? Copy.BookmarkedTip : Copy.BookmarkTip);
    }

    public void SetShield(string title, string detail, IReadOnlyList<string> lines)
    {
        var body = string.Join('\n', lines);
        var key = title + "\n" + detail + "\n" + body;
        if (key == _shieldKey)
        {
            return;
        }

        _shieldKey = key;
        _shieldTitle.Text = title;
        _shieldDetail.Text = detail;
        _shieldLines.Text = body;
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
        _back.Opacity = canBack ? 1 : 0.38;
        _forward.Opacity = canForward ? 1 : 0.38;
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
        _ = burnTop;
        _ = burnBottom;
        _shell.Background = Paint.Brush(fill);
    }

    public void ApplyBrand(Color brand) => _ = brand;

    Flyout BuildShield()
    {
        var stack = new StackPanel { Width = 280, Spacing = 4, RequestedTheme = ElementTheme.Dark };
        stack.Children.Add(_shieldTitle);
        stack.Children.Add(_shieldLines);
        stack.Children.Add(_shieldDetail);
        var open = new Button
        {
            Content = Copy.PrivacySettings,
            Height = 36,
            Margin = new Thickness(0, 12, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Stretch
        };
        Paint.FillButton(open, Paint.Brush(Paint.White, 24), Paint.Brush(Paint.White));
        open.Click += (_, _) => Settings?.Invoke();
        AutomationProperties.SetName(open, Copy.PrivacySettings);
        stack.Children.Add(open);
        return new Flyout
        {
            Placement = FlyoutPlacementMode.BottomEdgeAlignedRight,
            Content = stack
        };
    }

    MenuFlyout BuildMenu()
    {
        var menu = new MenuFlyout { Placement = FlyoutPlacementMode.BottomEdgeAlignedRight };
        foreach (var command in BrowserChrome.Menu)
        {
            if (command.SeparatorBefore)
            {
                menu.Items.Add(new MenuFlyoutSeparator());
            }

            menu.Items.Add(Item(command));
        }

        return menu;
    }

    MenuFlyoutItem Item(ChromeCommand command)
    {
        var item = new MenuFlyoutItem
        {
            Text = command.Label,
            KeyboardAcceleratorTextOverride = command.Shortcut
        };
        item.Click += (_, _) => Run(command.Action);
        return item;
    }

    void Run(string action)
    {
        switch (action)
        {
            case "new-tab":
                NewTab?.Invoke();
                break;
            case "bookmarks":
                Bookmarks?.Invoke();
                break;
            case "history":
                History?.Invoke();
                break;
            case "downloads":
                Downloads?.Invoke();
                break;
            case "extensions":
                Extensions?.Invoke();
                break;
            case "settings":
                Settings?.Invoke();
                break;
            case "deck":
                Deck?.Invoke();
                break;
            case "burn":
                Burn?.Invoke();
                break;
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

    static Button IconButton(FrameworkElement icon, string name, string tip, Action action)
    {
        var button = new Button
        {
            Content = icon,
            Width = 36,
            Height = 36,
            MinWidth = 36,
            Padding = new Thickness(0),
            CornerRadius = new CornerRadius(8),
            BorderThickness = new Thickness(0),
            Background = Paint.Brush(Paint.White, 0),
            VerticalAlignment = VerticalAlignment.Center
        };
        var clear = Paint.Brush(Paint.White, 0);
        Paint.TryTheme(button, "ButtonBackground", clear);
        Paint.TryTheme(button, "ButtonBackgroundPointerOver", Paint.Brush(Paint.White, 28));
        Paint.TryTheme(button, "ButtonBackgroundPressed", Paint.Brush(Paint.White, 48));
        Paint.TryTheme(button, "ButtonBackgroundDisabled", clear);
        Paint.TryTheme(button, "ButtonBorderBrush", clear);
        Paint.TryTheme(button, "ButtonBorderBrushPointerOver", clear);
        Paint.TryTheme(button, "ButtonBorderBrushPressed", clear);
        button.Click += (_, _) => action();
        AutomationProperties.SetName(button, name);
        ToolTipService.SetToolTip(button, tip);
        return button;
    }
}
