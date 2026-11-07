using Microsoft.UI.Xaml.Shapes;
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
    readonly ScrollViewer _bookmarks = new()
    {
        Height = 44,
        Visibility = Visibility.Collapsed,
        HorizontalScrollBarVisibility = ScrollBarVisibility.Hidden,
        VerticalScrollBarVisibility = ScrollBarVisibility.Disabled
    };
    readonly StackPanel _bookmarkItems = new() { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Thickness(12, 4, 12, 8) };
    readonly List<DownloadNote> _downloads = new();
    readonly Canvas _overlay = new();
    readonly DeckView _deck = new();
    readonly ClassicStrip _strip = new() { Visibility = Visibility.Collapsed };
    readonly IslandBar _island = new();
    readonly ShieldCard _shield = new();
    readonly SpacesBar _spaces = new();
    readonly TextBlock _hint = new();
    readonly Grid _dragStrip = new() { Height = 40, VerticalAlignment = VerticalAlignment.Top, Margin = new Thickness(0, 0, 148, 0) };
    readonly StackPanel _windowButtons = new() { Orientation = Orientation.Horizontal, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Top };
    readonly Grid _fire = new() { IsHitTestVisible = false, Visibility = Visibility.Collapsed };
    readonly Border _toast = new() { HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Bottom, Margin = new Thickness(0, 0, 0, 120), Padding = new Thickness(16, 8, 16, 8), CornerRadius = new CornerRadius(14), Visibility = Visibility.Collapsed, IsHitTestVisible = false };
    readonly TextBlock _toastText = new() { FontSize = 14 };
    readonly Grid _settingsLayer = new() { Visibility = Visibility.Collapsed };
    readonly Border _dropHint = new() { Width = 360, HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Stretch, Margin = new Thickness(24), CornerRadius = new CornerRadius(20), Visibility = Visibility.Collapsed, IsHitTestVisible = false };
    readonly Button _maxButton;
    readonly Button _cardsButton;
    bool _workMaximized;
    bool _fullScreen;
    bool _movingFrame;
    RectInt32 _restoreBounds;
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
    bool _loading;
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
    readonly LaunchClock _launch = new();
    bool _loggedPage;

    public ShellWindow()
    {
        Title = "Zalla";
        _root = System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Zalla");
        _spacesRoot = SettingsStore.SpacesRoot(_root);
        Directory.CreateDirectory(_spacesRoot);
        _launch.Mark("wipe-deferred");
        _catalog = ThemeCatalog.LoadEmbedded();
        _settings = SettingsStore.LoadApp(_root);
        if (ChromeMigration.Apply(_settings))
        {
            SettingsStore.SaveApp(_root, _settings);
        }
        _space = _settings.LastSpace;
        if (!SpaceNames.TryParse(_space.ToString(), out _))
        {
            _space = SpaceKind.Personal;
        }

        _maxButton = CaptionButtons.Create(CaptionKind.Maximize, ToggleMaximize);
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
        _launch.Mark("tree");
        Wire();
        LoadSpaceIntoTabs();
        ApplyTheme();
        ApplyLayout();
        ConfigureFrame();
        _launch.Mark("ready");
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
        _classicIsland.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        _classicIsland.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        _bookmarks.Content = _bookmarkItems;
        _bookmarks.Background = Paint.Brush("070B12");
        Grid.SetRow(_bookmarks, 1);
        _classicIsland.Children.Add(_bookmarks);
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

        _dragStrip.Background = Paint.Brush("070B12", 150);
        _rootGrid.Children.Add(_dragStrip);
        _windowButtons.Children.Add(CaptionButtons.Create(CaptionKind.Minimize, Minimize));
        _windowButtons.Children.Add(_maxButton);
        _windowButtons.Children.Add(CaptionButtons.Create(CaptionKind.Close, Close));
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
        _deck.SpacesHost.Children.Add(_spaces);
        _island.Back += Back;
        _island.Forward += Forward;
        _island.Burn += () => _ = BurnAsync();
        _island.ReloadOrStop += ReloadOrStop;
        _island.Bookmark += ToggleBookmark;
        _island.Bookmarks += ShowBookmarks;
        _island.History += ShowHistory;
        _island.Downloads += ShowDownloads;
        _island.Extensions += ShowExtensions;
        _island.Deck += () =>
        {
            _settings.Layout = _settings.Layout == ChromeLayout.Island ? ChromeLayout.Classic : ChromeLayout.Island;
            ApplyLayout();
            SettingsStore.SaveApp(_root, _settings);
            RefreshChrome();
        };
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
            AppWindow.Changed += OnAppWindowChanged;
            SetTitleBar(_dragStrip);
            var icon = System.IO.Path.Combine(AppContext.BaseDirectory, "Assets", "zalla.ico");
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
        StartTimers();
        DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, StartAfterFirstFrame);
    }

    void StartAfterFirstFrame()
    {
        _launch.Mark("first-frame");
        AppLog.WriteText("launch " + _launch.Line());
        var spaces = _spacesRoot;
        _ = Task.Run(() =>
        {
            try
            {
                SpaceWipe.ConsumePending(spaces);
            }
            catch (Exception ex)
            {
                AppLog.Write(ex);
            }
        });
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
        var fill = _settings.Layout == ChromeLayout.Classic
            ? Color.FromArgb(255, 10, 16, 26)
            : theme.Id == "lakeSuperior"
                ? Color.FromArgb(184, 14, 30, 52)
                : Color.FromArgb(190, wash.Mid.R, wash.Mid.G, wash.Mid.B);
        _strip.Background = Paint.Brush("070B12");
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
        if (classic)
        {
            MoveElement(_island, _classicIsland);
            Grid.SetRow(_island, 0);
            _island.Width = double.NaN;
            _island.HorizontalAlignment = HorizontalAlignment.Stretch;
            MoveElement(_spaces, _strip.SpacesHost);
            _deck.Visibility = Visibility.Collapsed;
            _hint.Visibility = Visibility.Collapsed;
            SetChromeOpacity(1);
        }
        else
        {
            MoveElement(_island, _overlay);
            MoveElement(_spaces, _deck.SpacesHost);
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
        _shield.Update(_spaceState.Privacy, width < 1100);
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
            _island.SetBookmarked(BrowserLibrary.IsBookmarked(_settings.Bookmarks, primary.Url));
            RefreshBookmarks();
        }

        PlaceChrome();
    }

    void ReloadOrStop()
    {
        var core = PrimaryOrNull()?.Web?.CoreWebView2;
        if (core == null)
        {
            return;
        }

        if (_loading)
        {
            core.Stop();
            _loading = false;
            _island.SetLoading(false);
        }
        else
        {
            core.Reload();
        }
    }

    void ToggleBookmark()
    {
        var tab = PrimaryOrNull();
        if (tab == null || !BrowserLibrary.IsPage(tab.Url))
        {
            Toast("Open a page before you bookmark it.");
            return;
        }

        var added = BrowserLibrary.ToggleBookmark(_settings.Bookmarks, tab.Url, tab.Title);
        SettingsStore.SaveApp(_root, _settings);
        _island.SetBookmarked(added);
        RefreshBookmarks();
        Toast(added ? "Bookmark saved." : "Bookmark removed.");
    }

    void RefreshBookmarks()
    {
        _bookmarkItems.Children.Clear();
        if (_settings.Layout != ChromeLayout.Classic || _settings.Bookmarks.Count == 0)
        {
            _bookmarks.Visibility = Visibility.Collapsed;
            return;
        }

        _bookmarks.Visibility = Visibility.Visible;
        foreach (var mark in _settings.Bookmarks)
        {
            var label = string.IsNullOrWhiteSpace(mark.Title) ? mark.Url : mark.Title;
            var button = new Button
            {
                Content = label,
                Height = 32,
                MaxWidth = 220,
                Padding = new Thickness(12, 0, 12, 0),
                FontSize = 14
            };
            Paint.FillButton(button, Paint.Brush(Paint.White, 24), Paint.Brush(Paint.White));
            var url = mark.Url;
            button.Click += (_, _) => OpenAddress(url);
            AutomationProperties.SetName(button, label);
            _bookmarkItems.Children.Add(button);
        }
    }

    void OpenAddress(string url)
    {
        var tab = PrimaryOrNull();
        if (tab != null)
        {
            _ = NavigateAsync(tab, url);
        }

        CloseSettings();
    }

    void ShowBookmarks()
    {
        ShowLibrary(Copy.Bookmarks, "Saved on this PC. They stay when you switch Spaces.", _settings.Bookmarks.Select(mark => (Label: string.IsNullOrWhiteSpace(mark.Title) ? mark.Url : mark.Title, Url: mark.Url)).ToList(), "No bookmarks yet. Use Bookmark or Ctrl D on a page.", null, null);
    }

    void ShowHistory()
    {
        ShowLibrary(Copy.History, "Recent pages in this Space. Ghost does not keep them.", _spaceState.History.Select(item => (Label: item.Title + "  " + item.Url, Url: (string?)item.Url)).ToList(), "No pages yet.", null, null);
    }

    void ShowDownloads()
    {
        ShowLibrary(Copy.Downloads, "Files this window has started saving. The usual save prompt still appears.", _downloads.Select(item => (Label: item.Name + "  " + item.State, Url: (string?)null)).ToList(), "No downloads yet.", null, null);
    }

    void ShowExtensions()
    {
        ShowLibrary(Copy.Extensions, Copy.ExtensionNote, [], "No extension is loaded from here until you pick a folder.", LoadUnpackedExtension, Copy.LoadExtension);
    }

    async void LoadUnpackedExtension()
    {
        var core = PrimaryOrNull()?.Web?.CoreWebView2;
        if (core == null)
        {
            Toast("Open a page first, then choose the extension folder.");
            return;
        }

        try
        {
            var picker = new Windows.Storage.Pickers.FolderPicker();
            WinRT.Interop.InitializeWithWindow.Initialize(picker, _hwnd != 0 ? _hwnd : WinRT.Interop.WindowNative.GetWindowHandle(this));
            picker.FileTypeFilter.Add("*");
            var folder = await picker.PickSingleFolderAsync();
            if (folder == null)
            {
                return;
            }

            if (!BrowserLibrary.IsUnpackedExtension(folder.Path))
            {
                Toast("That folder needs a manifest.json file. Zalla will not download an extension for you.");
                return;
            }

            await core.Profile.AddBrowserExtensionAsync(folder.Path);
            Toast("That unpacked extension is loaded for this Space. Chrome Web Store installs are not available.");
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
            Toast("Zalla could not load that extension. Many Chrome-only features will not run here.");
        }
    }

    void ShowLibrary(string title, string note, IReadOnlyList<(string Label, string? Url)> rows, string empty, Action? extra, string? extraLabel)
    {
        _settingsOpen = true;
        SetChromeOpacity(1);
        _settingsLayer.Children.Clear();
        _settingsLayer.Children.Add(new LibraryPanel(title, note, rows, empty, OpenAddress, extra, extraLabel, CloseSettings));
        _settingsLayer.Visibility = Visibility.Visible;
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
                _shield.Update(_spaceState.Privacy, _rootGrid.ActualWidth < 1100);
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

    void SyncCaption()
    {
        if (_fullScreen)
        {
            CaptionButtons.Show(_maxButton, CaptionKind.Restore, Copy.LeaveFullScreen);
        }
        else if (_workMaximized)
        {
            CaptionButtons.Show(_maxButton, CaptionKind.Restore, Copy.Restore);
        }
        else
        {
            CaptionButtons.Show(_maxButton, CaptionKind.Maximize, Copy.Maximize);
        }
    }

    ScreenRect CurrentRect()
    {
        var position = AppWindow.Position;
        var size = AppWindow.Size;
        return new ScreenRect(position.X, position.Y, size.Width, size.Height);
    }

    ScreenRect CurrentWork()
    {
        var area = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Nearest);
        var work = area.WorkArea;
        return new ScreenRect(work.X, work.Y, work.Width, work.Height);
    }

    ScreenRect CurrentMonitor()
    {
        var area = DisplayArea.GetFromWindowId(AppWindow.Id, DisplayAreaFallback.Nearest);
        var bounds = area.OuterBounds;
        return new ScreenRect(bounds.X, bounds.Y, bounds.Width, bounds.Height);
    }

    void MoveFrame(ScreenRect rect)
    {
        _movingFrame = true;
        try
        {
            AppWindow.MoveAndResize(new RectInt32(rect.X, rect.Y, rect.Width, rect.Height));
        }
        finally
        {
            DispatcherQueue.TryEnqueue(() => _movingFrame = false);
        }
    }

    void RememberRestored()
    {
        if (!_workMaximized && !_fullScreen)
        {
            var current = CurrentRect();
            _restoreBounds = new RectInt32(current.X, current.Y, current.Width, current.Height);
        }
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
        if (_fullScreen || _workMaximized)
        {
            RestoreWindow();
        }
        else
        {
            MaximizeWindow();
        }
    }

    void ToggleFullScreen()
    {
        if (_fullScreen)
        {
            RestoreWindow();
        }
        else
        {
            EnterFullScreen();
        }
    }

    void MaximizeWindow()
    {
        try
        {
            RememberRestored();
            _fullScreen = false;
            _workMaximized = true;
            MoveFrame(WindowFrame.Maximize(CurrentWork()));
            SyncCaption();
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }

    void EnterFullScreen()
    {
        try
        {
            RememberRestored();
            _workMaximized = false;
            _fullScreen = true;
            MoveFrame(WindowFrame.FullScreen(CurrentMonitor()));
            SyncCaption();
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }

    void RestoreWindow()
    {
        try
        {
            _workMaximized = false;
            _fullScreen = false;
            if (_restoreBounds.Width > 200 && _restoreBounds.Height > 160)
            {
                AppWindow.MoveAndResize(_restoreBounds);
            }

            SyncCaption();
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }

    void OnAppWindowChanged(AppWindow sender, AppWindowChangedEventArgs args)
    {
        if (_movingFrame || (!_workMaximized && !_fullScreen))
        {
            return;
        }

        if (!args.DidSizeChange && !args.DidPositionChange)
        {
            return;
        }

        try
        {
            var target = _fullScreen ? WindowFrame.FullScreen(CurrentMonitor()) : WindowFrame.Maximize(CurrentWork());
            var now = CurrentRect();
            if (Math.Abs(now.Width - target.Width) > 8 || Math.Abs(now.Height - target.Height) > 8)
            {
                _workMaximized = false;
                _fullScreen = false;
                SyncCaption();
            }
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }
}
