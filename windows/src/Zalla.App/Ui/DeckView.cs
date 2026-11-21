namespace Zalla;

sealed class DeckCard
{
    public required string Id { get; init; }
    public required string Title { get; init; }
    public required string ColorHex { get; init; }
    public byte[]? Preview { get; init; }
    public bool Active { get; init; }
    public bool Side { get; init; }
}

sealed class DeckView : Grid
{
    readonly TextBlock _header = new();
    readonly StackPanel _cards = new();
    readonly Dictionary<string, Image> _images = new();
    CardUi? _drag;
    Point _press;
    double _dx;
    double _dy;
    bool _moved;
    bool _fanned;

    public DeckView()
    {
        Width = 250;
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        Background = Paint.Brush(Paint.White, 1);

        _header.FontSize = 11;
        _header.Opacity = 0.55;
        _header.CharacterSpacing = 180;
        _header.Margin = new Thickness(4, 0, 0, 10);
        Children.Add(_header);

        _cards.Spacing = -42;
        _cards.ChildrenTransitions = new Microsoft.UI.Xaml.Media.Animation.TransitionCollection
        {
            new Microsoft.UI.Xaml.Media.Animation.RepositionThemeTransition()
        };
        Grid.SetRow(_cards, 1);
        Children.Add(_cards);

        var add = new Border
        {
            Margin = new Thickness(0, 14, 0, 0),
            Padding = new Thickness(10),
            CornerRadius = new CornerRadius(14),
            BorderBrush = Paint.Brush(Paint.White, 70),
            BorderThickness = new Thickness(1),
            Child = new TextBlock
            {
                Text = Copy.NewCard,
                FontSize = 13,
                Opacity = 0.75,
                HorizontalAlignment = HorizontalAlignment.Center
            }
        };
        add.PointerPressed += (_, e) =>
        {
            NewTab?.Invoke();
            e.Handled = true;
        };
        Grid.SetRow(add, 2);
        Children.Add(add);

        var spaces = new TextBlock
        {
            Text = Copy.Spaces,
            FontSize = 11,
            Opacity = 0.55,
            CharacterSpacing = 180,
            Margin = new Thickness(4, 26, 0, 8)
        };
        Grid.SetRow(spaces, 3);
        Children.Add(spaces);

        SpacesHost = new Grid();
        Grid.SetRow(SpacesHost, 4);
        Children.Add(SpacesHost);

        PointerEntered += (_, _) => SetFanned(true);
        PointerExited += (_, _) =>
        {
            if (_drag is null)
            {
                SetFanned(false);
            }
        };
    }

    public Grid SpacesHost { get; }

    public event Action<string>? Selected;
    public event Action<string>? Closed;
    public event Action<string>? Split;
    public event Action? NewTab;
    public event Action<double>? DragDelta;

    public void Bind(IReadOnlyList<DeckCard> cards, Color accent)
    {
        _header.Text = Copy.DeckCount(cards.Count);
        var same = cards.Count == _cards.Children.Count
            && cards.Select(card => card.Id).SequenceEqual(_cards.Children.OfType<CardUi>().Select(card => card.Id));
        if (!same)
        {
            _cards.Children.Clear();
            _images.Clear();
            foreach (var card in cards)
            {
                var ui = new CardUi(card.Id);
                ui.PointerPressed += (_, e) => OnPressed(ui, e);
                ui.PointerMoved += (_, e) => OnMoved(ui, e);
                ui.PointerReleased += (_, e) => OnReleased(ui, e);
                ui.PointerCanceled += (_, _) => CancelDrag(ui);
                ui.CloseClicked += () => Closed?.Invoke(ui.Id);
                _cards.Children.Add(ui);
                _images[card.Id] = ui.Preview;
            }
        }

        for (var i = 0; i < cards.Count; i++)
        {
            var ui = (CardUi)_cards.Children[i];
            ui.Apply(cards[i], accent, _fanned, i);
            _ = ui.SetPreviewAsync(cards[i].Preview);
        }
    }

    public void SetFanned(bool fanned)
    {
        if (_fanned == fanned)
        {
            return;
        }

        _fanned = fanned;
        _cards.Spacing = fanned ? 10 : -42;
        for (var i = 0; i < _cards.Children.Count; i++)
        {
            if (_cards.Children[i] is CardUi card)
            {
                card.SetFan(_fanned, i);
            }
        }
    }

    void OnPressed(CardUi card, PointerRoutedEventArgs e)
    {
        if (HitTestHelper.IsInteractive(e.OriginalSource as DependencyObject))
        {
            return;
        }

        _drag = card;
        _moved = false;
        _dx = 0;
        _dy = 0;
        _press = e.GetCurrentPoint(this).Position;
        card.CapturePointer(e.Pointer);
        e.Handled = true;
    }

    void OnMoved(CardUi card, PointerRoutedEventArgs e)
    {
        if (_drag != card)
        {
            return;
        }

        var pos = e.GetCurrentPoint(this).Position;
        _dx = pos.X - _press.X;
        _dy = pos.Y - _press.Y;
        if (Math.Abs(_dx) + Math.Abs(_dy) > 8)
        {
            _moved = true;
        }

        card.RenderTransform = new CompositeTransform { TranslateX = _dx, TranslateY = _dy, Rotation = _dx / 18 };
        DragDelta?.Invoke(_dx);
        e.Handled = true;
    }

    void OnReleased(CardUi card, PointerRoutedEventArgs e)
    {
        if (_drag != card)
        {
            return;
        }

        var dx = _dx;
        var dy = _dy;
        var moved = _moved;
        CancelDrag(card);
        card.ReleasePointerCaptures();
        if (!moved)
        {
            Selected?.Invoke(card.Id);
        }
        else if (dx < -80 || dy < -70)
        {
            Closed?.Invoke(card.Id);
        }
        else if (dx > 130)
        {
            Split?.Invoke(card.Id);
        }

        e.Handled = true;
    }

    void CancelDrag(CardUi card)
    {
        if (_drag != card)
        {
            return;
        }

        _drag = null;
        card.RenderTransform = new CompositeTransform();
        DragDelta?.Invoke(0);
        if (!_fanned)
        {
            SetFanned(false);
        }
    }

    sealed class CardUi : Grid
    {
        readonly Border _frame = new();
        readonly TextBlock _title = new();
        readonly Border _swatch = new();
        readonly Button _close;
        byte[]? _shown;

        public CardUi(string id)
        {
            Id = id;
            _frame.CornerRadius = new CornerRadius(16);
            _frame.Padding = new Thickness(12, 10, 12, 10);
            _frame.BorderThickness = new Thickness(1);
            _frame.RenderTransformOrigin = new Point(0.5, 0.5);
            Children.Add(_frame);

            var body = new StackPanel { Spacing = 8 };
            var titleRow = new Grid();
            titleRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            titleRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            _swatch.Width = 18;
            _swatch.Height = 18;
            _swatch.CornerRadius = new CornerRadius(5);
            _swatch.Margin = new Thickness(0, 0, 8, 0);
            titleRow.Children.Add(_swatch);
            _title.FontSize = 13;
            _title.TextTrimming = TextTrimming.CharacterEllipsis;
            _title.VerticalAlignment = VerticalAlignment.Center;
            Grid.SetColumn(_title, 1);
            titleRow.Children.Add(_title);
            body.Children.Add(titleRow);

            Preview = new Image { Height = 36, Stretch = Stretch.UniformToFill };
            var clipHost = new Border
            {
                CornerRadius = new CornerRadius(8),
                Height = 36,
                Child = Preview
            };
            body.Children.Add(clipHost);
            _frame.Child = body;

            _close = Paint.Flat(new TextBlock { Text = "\u00D7", FontSize = 16 }, 24);
            _close.HorizontalAlignment = HorizontalAlignment.Right;
            _close.VerticalAlignment = VerticalAlignment.Top;
            _close.Margin = new Thickness(0, 4, 4, 0);
            _close.Visibility = Visibility.Collapsed;
            _close.Click += (_, _) => CloseClicked?.Invoke();
            AutomationProperties.SetName(_close, Copy.Close);
            Children.Add(_close);
        }

        public string Id { get; }
        public Image Preview { get; }
        public event Action? CloseClicked;

        public void Apply(DeckCard card, Color accent, bool fanned, int index)
        {
            _title.Text = card.Title;
            _swatch.Background = Paint.Brush(card.ColorHex);
            _frame.Background = Paint.Brush(Paint.White, (byte)(card.Active ? 40 : 16));
            _frame.BorderBrush = card.Active
                ? Paint.Brush(accent, 180)
                : card.Side ? Paint.Brush(Paint.White, 90) : Paint.Brush(Paint.White, 20);
            if (_frame.Child is StackPanel body && body.Children.Count > 1 && body.Children[1] is Border host)
            {
                host.Height = card.Active ? 64 : 30;
                Preview.Height = host.Height;
            }

            SetFan(fanned, index);
        }

        public void SetFan(bool fanned, int index)
        {
            _close.Visibility = fanned ? Visibility.Visible : Visibility.Collapsed;
            var rotation = fanned || index == 0 ? 0 : (index % 2 == 0 ? 1.1 : -1.1);
            if (RenderTransform is not CompositeTransform current || Math.Abs(current.TranslateX) < 0.5)
            {
                _frame.RenderTransform = new CompositeTransform { Rotation = rotation };
            }
        }

        public async Task SetPreviewAsync(byte[]? png)
        {
            if (png is null || png.Length == 0 || ReferenceEquals(png, _shown))
            {
                return;
            }

            _shown = png;
            var image = await Paint.PngAsync(png);
            if (ReferenceEquals(_shown, png) && image is not null)
            {
                Preview.Source = image;
            }
        }
    }
}
