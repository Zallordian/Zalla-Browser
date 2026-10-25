using Windows.Graphics;

namespace Zalla;

public sealed partial class ShellWindow : Window
{
    readonly string _root;
    readonly string _spacesRoot;
    readonly ThemeCatalog _catalog;
    readonly Rectangle _scenery = new();
    readonly Ellipse _glow = new() { IsHitTestVisible = false, VerticalAlignment = VerticalAlignment.Bottom, HorizontalAlignment = HorizontalAlignment.Center, Width = 980, Height = 460, Margin = new Thickness(0, 0, 0, -120) };
    readonly Canvas _water = new() { Height = 260, VerticalAlignment = VerticalAlignment.Bottom, IsHitTestVisible = false };
    readonly Grid _page = new();
    readonly Grid _stack = new();
    readonly Grid _split = new() { Visibility = Visibility.Collapsed };
    readonly Grid _splitLeft = new();
    readonly Grid _splitRight = new();
    readonly Grid _classicIsland = new() { Visibility = Visibility.Collapsed };
    readonly Canvas _overlay = new();
    readonly DeckView _deck = new();
    readonly ClassicStrip _strip = new() { Visibility = Visibility.Collapsed };
    readonly IslandBar _island = new();
    readonly ShieldCard _shield = new();
    readonly SpacesBar _spaces = new();
    readonly TextBlock _hint = new();
    readonly Grid _dragStrip = new() { Height = 32, VerticalAlignment = VerticalAlignment.Top };
    readonly StackPanel _windowButtons = new() { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0, 10, 14, 0) };
    readonly Grid _fire = new() { IsHitTestVisible = false, Visibility = Visibility.Collapsed };
    readonly Border _toast = new() { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(0, 0, 0, 120), Padding = new Thickness(16, 8, 16, 8), CornerRadius = new CornerRadius(14), Visibility = Visibility.Collapsed, IsHitTestVisible = false };
    readonly TextBlock _toastText = new() { FontSize = 14 };
    readonly Grid _settingsLayer = new() { Visibility = Visibility.Collapsed };
    readonly Border _dropHint = new() { Width = 360, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Stretch, Margin = new Thickness(24), CornerRadius = new CornerRadius(20), Visibility = Visibility.Collapsed, IsHitTestVisible = false };
    readonly Button _maxButton;
    readonly Button _cardsButton;
    Grid _rootGrid = null!;

    AppSettings _settings = new();
    SpaceState _spaceState = SpaceState.CreateNew();
    SpaceKind _space = SpaceKind.Personal;
    readonly List<BrowserTab> _tabs = new();
    readonly Dictionary<SpaceKind, CoreWebView2Environment> _environments = new();
    int _active;
    bool _splitMode;
    string? _leftId;
    string? _rightId;
    bool _booted;
    bool _closing;
    bool _busy;
    bool _settingsOpen;
    bool _draggingIsland;
    bool _draggingCard;
    bool _splitDrag;
    bool _deckPinned;
    bool _hotkeysOn;
    int _saying;
    Point _dragStart;
    Point _islandStart;
    long _lastMove = Environment.TickCount64;
    long _toastUntil;
    int _lastCursorX;
    int _lastCursorY;
    DispatcherQueueTimer? _cursorTimer;
    DispatcherQueueTimer? _previewTimer;
    IntPtr _hwnd;
    SubclassProc? _subclass;

    public ShellWindow()
    {
        Title = "Zalla";
        _root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Zalla");
        _spacesRoot = SettingsStore.SpacesRoot(_root);
        Directory.CreateDirectory(_spacesRoot);
        SpaceWipe.ConsumePending(_spacesRoot);
        _catalog = ThemeCatalog.LoadEmbedded();
        _settings = SettingsStore.LoadApp(_root);
        _space = _settings.LastSpace;
        if (!SpaceNames.TryParse(_space.ToString(), out _))
        {
            _space = SpaceKind.Personal;
        }

        _maxButton = WindowButton(Paint.Hex("FFFFFF", 70), Copy.Maximize, ToggleMaximize);
        _cardsButton = Paint.Flat(new TextBlock { Text = "Cards", FontSize = 12, Margin = new Thickness(8, 0, 8, 0) }, 0);
        _cardsButton.Padding = new Thickness(10, 6, 10, 6);
        _cardsButton.Background = Paint.Brush(Paint.Black, 120);
        _cardsButton.CornerRadius = new CornerRadius(10);
        _cardsButton.HorizontalAlignment = HorizontalAlignment.Left;
        _cardsButton.VerticalAlignment = VerticalAlignment.Top;
        _cardsButton.Margin = new Thickness(16, 64, 0, 0);
        _cardsButton.Visibility = Visibility.Collapsed;
        _cardsButton.Click += (_, _) =>
        {
            _deckPinned = !_deckPinned;
            PlaceChrome();
        };

        Content = BuildRoot();
        Wire();
        LoadSpaceIntoTabs();
        ApplyTheme();
        ApplyLayout();
        ConfigureFrame();
        StartTimers();
        Activated += OnActivated;
        AppWindow.Closing += OnClosing;
    }

    ThemeRecord CurrentTheme() => _catalog.Require(_spaceState.ThemeId);

    string BrandHex => _catalog.ById("zallaRed")?.Colors.Primary ?? "E33B4F";

    Grid BuildRoot()
    {
        _rootGrid = new Grid { RequestedTheme = ElementTheme.Dark };
        _rootGrid.Children.Add(_scenery);
        _rootGrid.Children.Add(_glow);
        _rootGrid.Children.Add(_water);

        var pageHost = new Grid();
        pageHost.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        pageHost.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        pageHost.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });
        pageHost.Children.Add(_strip);
        Grid.SetRow(_classicIsland, 1);
        pageHost.Children.Add(_classicIsland);
        Grid.SetRow(_page, 2);
        _page.Children.Add(_stack);
        BuildSplit();
        _page.Children.Add(_split);
        _dropHint.Background = Paint.Brush("0F2F52", 170);
        _dropHint.BorderBrush = Paint.Brush(Paint.White, 50);
        _dropHint.BorderThickness = new Thickness(1);
        _dropHint.Child = new TextBlock { Text = Copy.DropToSplit, HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, FontSize = 16 };
        _page.Children.Add(_dropHint);
        pageHost.Children.Add(_page);
        _rootGrid.Children.Add(pageHost);

        Canvas.SetLeft(_deck, 26);
        Canvas.SetTop(_deck, 72);
        _overlay.Children.Add(_deck);
        _overlay.Children.Add(_shield);
        _overlay.Children.Add(_island);
        _hint.Text = Copy.IslandHint;
        _hint.FontSize = 11;
        _hint.Opacity = 0.55;
        _hint.TextAlignment = TextAlignment.Center;
        _hint.IsHitTestVisible = false;
        _overlay.Children.Add(_hint);
        _rootGrid.Children.Add(_overlay);

        _dragStrip.Background = Paint.Brush(Paint.White, 1);
        _dragStrip.PointerPressed += (_, e) =>
        {
            BeginWindowDrag();
            e.Handled = true;
        };
        _rootGrid.Children.Add(_dragStrip);
        _windowButtons.Children.Add(WindowButton(Paint.Hex("FFFFFF", 70), Copy.Minimize, Minimize));
        _windowButtons.Children.Add(_maxButton);
        _windowButtons.Children.Add(WindowButton(Paint.Hex("E33B4F"), Copy.Close, Close));
        _rootGrid.Children.Add(_windowButtons);
        _rootGrid.Children.Add(_cardsButton);

        _fire.Children.Add(new Rectangle
        {
            Fill = new RadialGradientBrush
            {
                GradientStops =
                {
                    new GradientStop { Color = Paint.Hex("FF7828", 220), Offset = 0 },
                    new GradientStop { Color = Paint.Hex("E5352B", 0), Offset = 1 }
                }
            }
        });
        _rootGrid.Children.Add(_fire);

        _toast.Background = Paint.Brush(Paint.Black, 190);
        _toast.Child = _toastText;
        _rootGrid.Children.Add(_toast);
        _rootGrid.Children.Add(_settingsLayer);

        _rootGrid.SizeChanged += (_, _) =>
        {
            PlaceChrome();
            DrawWater();
        };
        return _rootGrid;
    }

    void BuildSplit()
    {
        _split.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        _split.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(28) });
        _split.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        _split.Children.Add(_splitLeft);
        Grid.SetColumn(_splitRight, 2);
        _split.Children.Add(_splitRight);
        var grip = new Grid { Background = Paint.Brush(Paint.White, 18) };
        var close = Paint.Flat(new TextBlock { Text = "\u00D7", FontSize = 16, Foreground = Paint.Brush(Paint.White) }, 24);
        close.HorizontalAlignment = HorizontalAlignment.Center;
        close.VerticalAlignment = VerticalAlignment.Center;
        close.Click += (_, _) => EndSplit();
        AutomationProperties.SetName(close, Copy.CloseSplit);
        ToolTipService.SetToolTip(close, Copy.CloseSplit);
        grip.Children.Add(close);
        Grid.SetColumn(grip, 1);
        grip.PointerPressed += (_, e) =>
        {
            if (HitTestHelper.IsInteractive(e.OriginalSource as DependencyObject))
            {
                return;
            }

            _splitDrag = true;
            grip.CapturePointer(e.Pointer);
            e.Handled = true;
        };
        grip.PointerMoved += (_, e) =>
        {
            if (!_splitDrag)
            {
                return;
            }

            var total = Math.Max(360, _split.ActualWidth - 28);
            var left = Math.Clamp(e.GetCurrentPoint(_split).Position.X, 180, total - 180);
            _split.ColumnDefinitions[0].Width = new GridLength(left);
            _split.ColumnDefinitions[2].Width = new GridLength(total - left);
        };
        grip.PointerReleased += (_, _) => _splitDrag = false;
        _split.Children.Add(grip);
    }

    void Wire()
    {
        WindowDrag.Requested = BeginWindowDrag;
        _deck.SpacesHost.Children.Add(_spaces);
        _island.Back += Back;
        _island.Forward += Forward;
        _island.Burn += () => _ = BurnAsync();
        _island.NewTab += NewTabFromChrome;
        _island.Settings += OpenSettings;
        _island.Submit += OnSubmit;
        _deck.Selected += id => Select(id);
        _deck.Closed += CloseTab;
        _deck.Split += StartSplit;
        _deck.NewTab += NewTabFromChrome;
        _deck.DragDelta += dx =>
        {
            _draggingCard = Math.Abs(dx) > 1;
            _dropHint.Visibility = dx > 80 ? Visibility.Visible : Visibility.Collapsed;
        };
        _strip.Selected += id => Select(id);
        _strip.Closed += CloseTab;
        _strip.NewTab += NewTabFromChrome;
        _spaces.Selected += space => _ = SwitchSpaceAsync(space);
        _shield.OpenSettings += OpenSettings;
        HookIsland();
        _rootGrid.CharacterReceived += OnCharacter;
        _rootGrid.KeyDown += OnKeyDown;
    }

    void ConfigureFrame()
    {
        try
        {
            ExtendsContentIntoTitleBar = true;
            if (AppWindow.Presenter is OverlappedPresenter presenter)
            {
                presenter.SetBorderAndTitleBar(false, false);
                presenter.IsResizable = true;
                presenter.IsMaximizable = true;
                presenter.IsMinimizable = true;
                presenter.PreferredMinimumWidth = 720;
                presenter.PreferredMinimumHeight = 520;
            }

            AppWindow.Title = "Zalla";
            var icon = Path.Combine(AppContext.BaseDirectory, "Assets", "zalla.ico");
            if (File.Exists(icon))
            {
                AppWindow.SetIcon(icon);
            }
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }

    void OnActivated(object sender, WindowActivatedEventArgs args)
    {
        if (_booted)
        {
            return;
        }

        _booted = true;
        try
        {
            var area = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Primary);
            var work = area.WorkArea;
            var width = Math.Min(1440, Math.Max(960, work.Width - 80));
            var height = Math.Min(920, Math.Max(640, work.Height - 80));
            AppWindow.Resize(new SizeInt32(width, height));
            AppWindow.Move(new PointInt32(work.X + (work.Width - width) / 2, work.Y + Math.Max(0, (work.Height - height) / 2)));
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }

        InstallHotkeys();
        var tab = PrimaryOrNull();
        if (tab != null && tab.Url.Length > 0 && tab.Web?.CoreWebView2 == null)
        {
            _ = NavigateAsync(tab, tab.Url);
        }
    }

    void ApplyTheme()
    {
        var theme = CurrentTheme();
        var wash = Scenery.For(theme);
        _scenery.Fill = new LinearGradientBrush
        {
            StartPoint = new Point(0.5, 1),
            EndPoint = new Point(0.5, 0),
            GradientStops =
            {
                new GradientStop { Color = wash.Glow, Offset = 0 },
                new GradientStop { Color = wash.Mid, Offset = 0.42 },
                new GradientStop { Color = wash.Edge, Offset = 0.78 }
            }
        };
        _glow.Fill = new RadialGradientBrush
        {
            GradientStops =
            {
                new GradientStop { Color = Color.FromArgb(110, wash.Glow.R, wash.Glow.G, wash.Glow.B), Offset = 0 },
                new GradientStop { Color = Color.FromArgb(0, wash.Glow.R, wash.Glow.G, wash.Glow.B), Offset = 1 }
            }
        };
        var brand = Paint.Hex(BrandHex);
        _island.ApplyBrand(brand);
        var fill = theme.Id == "lakeSuperior"
            ? Color.FromArgb(184, 14, 30, 52)
            : Color.FromArgb(190, wash.Mid.R, wash.Mid.G, wash.Mid.B);
        _island.ApplyChrome(fill, Paint.Hex(theme.Colors.Highlight), brand);
        foreach (var tab in _tabs)
        {
            tab.Page?.SetBrand(brand);
            if (tab.Web != null)
            {
                tab.Web.DefaultBackgroundColor = wash.Edge;
            }
        }

        DrawWater();
        RefreshChrome();
    }

    void ApplyLayout()
    {
        var classic = _settings.Layout == ChromeLayout.Classic;
        _strip.Visibility = classic ? Visibility.Visible : Visibility.Collapsed;
        _classicIsland.Visibility = classic ? Visibility.Visible : Visibility.Collapsed;
        _island.UsePill(!classic);
        (_island.Parent as Panel)?.Children.Remove(_island);
        (_spaces.Parent as Panel)?.Children.Remove(_spaces);
        if (classic)
        {
            _classicIsland.Children.Clear();
            _classicIsland.Children.Add(_island);
            _island.Width = double.NaN;
            _island.HorizontalAlignment = HorizontalAlignment.Stretch;
            _strip.SpacesHost.Children.Clear();
            _strip.SpacesHost.Children.Add(_spaces);
            _deck.Visibility = Visibility.Collapsed;
            _hint.Visibility = Visibility.Collapsed;
            SetChromeOpacity(1);
        }
        else
        {
            _overlay.Children.Add(_island);
            _deck.SpacesHost.Children.Clear();
            _deck.SpacesHost.Children.Add(_spaces);
            _hint.Visibility = _settings.Island.HasMoved ? Visibility.Collapsed : Visibility.Visible;
            PositionIsland();
        }

        PlaceChrome();
    }

    void PlaceChrome()
    {
        var width = _rootGrid.ActualWidth;
        var height = _rootGrid.ActualHeight;
        if (_settings.Layout == ChromeLayout.Island)
        {
            var showDeck = width >= 860 || _deckPinned;
            _deck.Visibility = showDeck ? Visibility.Visible : Visibility.Collapsed;
            _cardsButton.Visibility = width < 860 ? Visibility.Visible : Visibility.Collapsed;
            PositionIsland();
        }
        else
        {
            _cardsButton.Visibility = Visibility.Collapsed;
        }

        var shieldWidth = _shield.ActualWidth > 1 ? _shield.ActualWidth : _shield.Width;
        Canvas.SetLeft(_shield, Math.Max(12, width - shieldWidth - 36));
        Canvas.SetTop(_shield, 72);
        _shield.Update(_spaceState.Privacy, _spaceState.BlockedThisWeek, width < 1100);
        UpdateInsets();
        if (height < 10)
        {
            return;
        }
    }

    void PositionIsland()
    {
        if (_settings.Layout != ChromeLayout.Island || _rootGrid.ActualWidth < 10)
        {
            return;
        }

        var width = _rootGrid.ActualWidth;
        var height = _rootGrid.ActualHeight;
        var islandWidth = Math.Min(820, Math.Max(420, width - 80));
        _island.Width = islandWidth;
        var iw = islandWidth;
        var ih = 70.0;
        double x;
        double y;
        switch (_settings.Island.Dock)
        {
            case DockEdge.Top:
                x = (width - iw) / 2;
                y = 48;
                break;
            case DockEdge.Left:
                x = 16;
                y = (height - ih) / 2;
                break;
            case DockEdge.Right:
                x = width - iw - 16;
                y = (height - ih) / 2;
                break;
            case DockEdge.Bottom:
                x = (width - iw) / 2;
                y = height - ih - 28;
                break;
            default:
                x = _settings.Island.X * width - iw / 2;
                y = _settings.Island.Y * height - ih / 2;
                break;
        }

        x = Math.Clamp(x, 12, Math.Max(12, width - iw - 12));
        y = Math.Clamp(y, 40, Math.Max(40, height - ih - 12));
        Canvas.SetLeft(_island, x);
        Canvas.SetTop(_island, y);
        Canvas.SetLeft(_hint, x);
        Canvas.SetTop(_hint, Math.Max(8, y - 22));
        _hint.Width = iw;
    }

    void DrawWater()
    {
        _water.Children.Clear();
        var width = Math.Max(300, _rootGrid.ActualWidth);
        for (var y = 8.0; y < 250; y += 14)
        {
            var line = new Rectangle
            {
                Width = width,
                Height = 1,
                Fill = Paint.Brush("78BEFF", 13)
            };
            Canvas.SetTop(line, y);
            _water.Children.Add(line);
        }
    }

    void UpdateInsets()
    {
        var deck = _deck.Visibility == Visibility.Visible ? 270 : 24;
        var shield = _settings.Layout == ChromeLayout.Classic ? 24 : 220;
        foreach (var tab in _tabs)
        {
            tab.Page?.SetSideInset(deck, shield);
        }
    }

    void RefreshChrome()
    {
        var cards = _tabs.Select(tab => new DeckCard
        {
            Id = tab.Id,
            Title = string.IsNullOrWhiteSpace(tab.Title) ? "New Tab" : tab.Title,
            ColorHex = tab.ColorHex,
            Preview = tab.Preview,
            Active = _tabs.Count > 0 && tab.Id == Primary.Id,
            Side = _splitMode && tab.Id == _rightId
        }).ToList();
        var accent = Paint.Hex(BrandHex);
        _deck.Bind(cards, accent);
        _strip.Bind(cards, accent);
        _spaces.SetActive(_space, accent);
        var primary = PrimaryOrNull();
        if (primary != null)
        {
            var core = primary.Web?.CoreWebView2;
            _island.SetHistory(core?.CanGoBack == true, core?.CanGoForward == true);
            _island.SetAddress(primary.Url);
        }

        PlaceChrome();
    }

    void OpenSettings()
    {
        _settingsOpen = true;
        SetChromeOpacity(1);
        _settingsLayer.Children.Clear();
        _settingsLayer.Children.Add(new SettingsView(
            _catalog,
            _spaceState.ThemeId,
            _settings.Layout,
            _settings.SearchEngineId,
            _settings.CustomSearchTemplate,
            _spaceState.Privacy,
            id =>
            {
                _spaceState.ThemeId = id;
                ApplyTheme();
                SaveCurrentSpace();
            },
            layout =>
            {
                if (_settings.Layout == layout)
                {
                    return;
                }

                _settings.Layout = layout;
                ApplyLayout();
                SettingsStore.SaveApp(_root, _settings);
                RefreshChrome();
            },
            (engine, template) =>
            {
                _settings.SearchEngineId = engine;
                _settings.CustomSearchTemplate = template;
                SettingsStore.SaveApp(_root, _settings);
            },
            () =>
            {
                SaveCurrentSpace();
                _shield.Update(_spaceState.Privacy, _spaceState.BlockedThisWeek, _rootGrid.ActualWidth < 1100);
            },
            CloseSettings));
        _settingsLayer.Visibility = Visibility.Visible;
    }

    void CloseSettings()
    {
        _settingsOpen = false;
        _settingsLayer.Visibility = Visibility.Collapsed;
        _settingsLayer.Children.Clear();
    }

    void Toast(string text)
    {
        _toastText.Text = text;
        _toast.Visibility = Visibility.Visible;
        _toastUntil = Environment.TickCount64 + 2600;
    }

    void ShowFire()
    {
        _fire.Opacity = 0;
        _fire.Visibility = Visibility.Visible;
        var start = Environment.TickCount64;
        var timer = DispatcherQueue.CreateTimer();
        timer.Interval = TimeSpan.FromMilliseconds(30);
        timer.IsRepeating = true;
        timer.Tick += (_, _) =>
        {
            var t = (Environment.TickCount64 - start) / 700.0;
            if (t >= 1)
            {
                timer.Stop();
                _fire.Visibility = Visibility.Collapsed;
                return;
            }

            _fire.Opacity = t < 0.35 ? t / 0.35 * 0.72 : (1 - t) / 0.65 * 0.72;
        };
        timer.Start();
    }

    void SetChromeOpacity(double opacity)
    {
        if (_settings.Layout == ChromeLayout.Classic)
        {
            opacity = 1;
        }

        _island.Opacity = opacity;
        _deck.Opacity = opacity;
        _shield.Opacity = opacity;
        _hint.Opacity = opacity;
        var hit = opacity > 0.2;
        _island.IsHitTestVisible = hit;
        _deck.IsHitTestVisible = hit;
        _shield.IsHitTestVisible = hit;
    }

    static Button WindowButton(Color color, string name, Action action)
    {
        var button = Paint.Flat(new Ellipse
        {
            Width = 12,
            Height = 12,
            Fill = Paint.Brush(color),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        }, 28);
        button.Click += (_, _) => action();
        AutomationProperties.SetName(button, name);
        ToolTipService.SetToolTip(button, name);
        return button;
    }

    void Minimize()
    {
        if (AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.Minimize();
        }
    }

    void ToggleMaximize()
    {
        if (AppWindow.Presenter is not OverlappedPresenter presenter)
        {
            return;
        }

        if (presenter.State == OverlappedPresenterState.Maximized)
        {
            presenter.Restore();
            ToolTipService.SetToolTip(_maxButton, Copy.Maximize);
        }
        else
        {
            presenter.Maximize();
            ToolTipService.SetToolTip(_maxButton, Copy.Restore);
        }
    }
}
