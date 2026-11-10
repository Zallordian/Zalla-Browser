namespace Zalla;

sealed class FindBar : Border
{
    readonly TextBox _input = new();
    readonly TextBlock _status = new() { FontSize = 13, VerticalAlignment = VerticalAlignment.Center, Foreground = Paint.Brush(Paint.White), Opacity = 0.8, MinWidth = 72 };

    public FindBar()
    {
        Visibility = Visibility.Collapsed;
        HorizontalAlignment = HorizontalAlignment.Right;
        VerticalAlignment = VerticalAlignment.Top;
        Margin = new Thickness(0, 12, 16, 0);
        Padding = new Thickness(8, 6, 6, 6);
        CornerRadius = new CornerRadius(10);
        Background = Paint.Brush("101820", 245);
        BorderBrush = Paint.Brush(Paint.White, 50);
        BorderThickness = new Thickness(1);
        RequestedTheme = ElementTheme.Dark;
        Canvas.SetZIndex(this, 30);

        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 6 };
        _input.Width = 240;
        _input.Height = 32;
        _input.PlaceholderText = "Find on page";
        _input.FontSize = 14;
        _input.Padding = new Thickness(10, 4, 10, 4);
        _input.Background = Paint.Brush("1A2330");
        _input.Foreground = Paint.Brush(Paint.White);
        _input.BorderThickness = new Thickness(0);
        _input.TextChanged += (_, _) => TextChanged?.Invoke(_input.Text);
        _input.KeyDown += (_, e) =>
        {
            if (e.Key == Windows.System.VirtualKey.Enter)
            {
                if (IsShift(e))
                {
                    Previous?.Invoke();
                }
                else
                {
                    Next?.Invoke();
                }

                e.Handled = true;
            }
            else if (e.Key == Windows.System.VirtualKey.Escape)
            {
                Dismiss?.Invoke();
                e.Handled = true;
            }
        };
        row.Children.Add(_input);
        row.Children.Add(_status);
        row.Children.Add(Small("Previous match", "Previous", () => Previous?.Invoke()));
        row.Children.Add(Small("Next match", "Next", () => Next?.Invoke()));
        row.Children.Add(Small("Close find", "Close", () => Dismiss?.Invoke()));
        Child = row;
    }

    public string Term => _input.Text ?? "";

    public event Action<string>? TextChanged;
    public event Action? Next;
    public event Action? Previous;
    public event Action? Dismiss;

    public void FocusBox()
    {
        _input.Focus(FocusState.Programmatic);
        _input.SelectAll();
    }

    public void SetStatus(string text) => _status.Text = text;

    static bool IsShift(KeyRoutedEventArgs e)
    {
        var state = Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(Windows.System.VirtualKey.Shift);
        return state.HasFlag(Windows.UI.Core.CoreVirtualKeyStates.Down);
    }

    static Button Small(string name, string glyph, Action action)
    {
        var button = new Button
        {
            Content = glyph,
            Height = 32,
            Padding = new Thickness(10, 0, 10, 0),
            FontSize = 13,
            Background = Paint.Brush(Paint.White, 16),
            Foreground = Paint.Brush(Paint.White),
            CornerRadius = new CornerRadius(6)
        };
        button.Click += (_, _) => action();
        AutomationProperties.SetName(button, name);
        ToolTipService.SetToolTip(button, name);
        return button;
    }
}
