using Windows.UI.Text;

namespace Zalla;

sealed class IslandBar : Grid
{
    readonly Border _shell = new();
    readonly Button _back;
    readonly Button _forward;
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
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        _shell.Child = row;

        var z = LetterButton("Z");
        z.Click += (_, _) => { };
        var menu = new MenuFlyout { Placement = FlyoutPlacementMode.Auto };
        menu.Items.Add(Item(Copy.NewTab, () => NewTab?.Invoke()));
        menu.Items.Add(Item(Copy.Settings, () => Settings?.Invoke()));
        menu.Items.Add(Item(Copy.BurnTooltip, () => Burn?.Invoke()));
        z.Flyout = menu;
        AutomationProperties.SetName(z, Copy.Menu);
        row.Children.Add(z);

        _back = GlyphButton("\u2190", Copy.Back);
        _back.Margin = new Thickness(8, 0, 0, 0);
        _back.Click += (_, _) => Back?.Invoke();
        Grid.SetColumn(_back, 1);
        row.Children.Add(_back);

        _forward = GlyphButton("\u2192", Copy.Forward);
        _forward.Margin = new Thickness(2, 0, 8, 0);
        _forward.Click += (_, _) => Forward?.Invoke();
        Grid.SetColumn(_forward, 2);
        row.Children.Add(_forward);

        _input.PlaceholderText = Copy.SearchPlaceholder;
        _input.BorderThickness = new Thickness(0);
        _input.Background = Paint.Brush(Paint.Black, 90);
        _input.Foreground = Paint.Brush(Paint.White);
        _input.CornerRadius = new CornerRadius(23);
        _input.Height = 46;
        _input.Padding = new Thickness(16, 8, 16, 8);
        _input.FontSize = 15;
        _input.VerticalAlignment = VerticalAlignment.Center;
        _input.RequestedTheme = ElementTheme.Dark;
        _input.KeyDown += OnKey;
        Grid.SetColumn(_input, 3);
        row.Children.Add(_input);

        _burn = LetterButton("\uD83D\uDD25");
        if (_burn.Content is TextBlock flame)
        {
            flame.FontFamily = new FontFamily("Segoe UI Emoji");
        }
        _burn.Margin = new Thickness(10, 0, 0, 0);
        _burn.Click += (_, _) => Burn?.Invoke();
        AutomationProperties.SetName(_burn, Copy.BurnTooltip);
        ToolTipService.SetToolTip(_burn, Copy.BurnTooltip);
        Grid.SetColumn(_burn, 4);
        row.Children.Add(_burn);

        SetHistory(false, false);
    }

    public TextBox Input => _input;

    public bool CommandMode { get; private set; }

    public event Action? Back;
    public event Action? Forward;
    public event Action? Burn;
    public event Action? NewTab;
    public event Action? Settings;
    public event Action<string, bool>? Submit;

    public void UsePill(bool pill)
    {
        _shell.CornerRadius = new CornerRadius(pill ? 35 : 16);
        Height = pill ? 70 : 56;
        Margin = pill ? new Thickness(0) : new Thickness(8, 0, 8, 8);
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

    static Button GlyphButton(string glyph, string name)
    {
        var label = new TextBlock
        {
            Text = glyph,
            FontSize = 18,
            Opacity = 0.85,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        var button = Paint.Flat(label, 40);
        button.Foreground = Paint.Brush(Paint.White);
        AutomationProperties.SetName(button, name);
        ToolTipService.SetToolTip(button, name);
        return button;
    }
}
