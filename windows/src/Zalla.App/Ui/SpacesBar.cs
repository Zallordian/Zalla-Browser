namespace Zalla;

sealed class SpacesBar : StackPanel
{
    readonly Button _personal;
    readonly Button _work;
    readonly Button _ghost;
    readonly TextBlock _note = new();

    public SpacesBar()
    {
        Orientation = Orientation.Vertical;
        Spacing = 8;
        var row = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        _personal = Pill(SpaceKind.Personal);
        _work = Pill(SpaceKind.Work);
        _ghost = Pill(SpaceKind.Ghost);
        row.Children.Add(_personal);
        row.Children.Add(_work);
        row.Children.Add(_ghost);
        Children.Add(row);

        _note.Text = Copy.GhostNote;
        _note.FontSize = 12;
        _note.Opacity = 0.65;
        _note.TextWrapping = TextWrapping.Wrap;
        _note.Margin = new Thickness(2, 0, 0, 0);
        _note.Visibility = Visibility.Collapsed;
        Children.Add(_note);
    }

    public event Action<SpaceKind>? Selected;

    public void SetActive(SpaceKind space, Color accent)
    {
        PaintPill(_personal, space == SpaceKind.Personal, accent);
        PaintPill(_work, space == SpaceKind.Work, accent);
        PaintPill(_ghost, space == SpaceKind.Ghost, accent);
        _note.Visibility = space == SpaceKind.Ghost ? Visibility.Visible : Visibility.Collapsed;
    }

    Button Pill(SpaceKind space)
    {
        var button = new Button
        {
            Content = SpaceNames.Label(space),
            CornerRadius = new CornerRadius(12),
            Padding = new Thickness(12, 6, 12, 6),
            BorderThickness = new Thickness(0),
            FontSize = 12
        };
        button.Click += (_, _) => Selected?.Invoke(space);
        return button;
    }

    static void PaintPill(Button button, bool active, Color accent)
    {
        var fill = active ? Paint.Brush(accent) : Paint.Brush(Paint.White, 26);
        var foreground = active ? Paint.Brush(Paint.On(accent)) : Paint.Brush(Paint.White);
        Paint.FillButton(button, fill, foreground);
    }
}
