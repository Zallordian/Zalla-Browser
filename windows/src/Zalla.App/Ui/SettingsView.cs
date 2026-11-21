namespace Zalla;

sealed class SettingsView : Grid
{
    public SettingsView(
        ThemeCatalog catalog,
        string themeId,
        ChromeLayout layout,
        string searchEngineId,
        string customTemplate,
        PrivacySettings privacy,
        Action<string> themeChanged,
        Action<ChromeLayout> layoutChanged,
        Action<string, string> searchChanged,
        Action privacyChanged,
        Action close)
    {
        Background = Paint.Brush(Paint.Black, 150);
        PointerPressed += (_, e) =>
        {
            if (ReferenceEquals(e.OriginalSource, this))
            {
                close();
            }
        };

        var card = new Border
        {
            Width = 860,
            Height = 640,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            CornerRadius = new CornerRadius(16),
            Background = Paint.Brush("101820"),
            BorderBrush = Paint.Brush(Paint.White, 36),
            BorderThickness = new Thickness(1),
            RequestedTheme = ElementTheme.Dark
        };
        var root = new Grid();
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(220) });
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        card.Child = root;
        Children.Add(card);

        var rail = new StackPanel { Spacing = 4, Padding = new Thickness(16, 20, 12, 16), Background = Paint.Brush("0C121A") };
        rail.Children.Add(new TextBlock
        {
            Text = Copy.Settings,
            FontSize = 22,
            FontWeight = FontWeights.SemiBold,
            Foreground = Paint.Brush(Paint.White),
            Margin = new Thickness(8, 0, 0, 12)
        });
        var pages = new Dictionary<string, UIElement>();
        var buttons = new Dictionary<string, Button>();
        foreach (var section in BrowserChrome.SettingsSections)
        {
            var name = section;
            var button = SectionButton(name);
            button.Click += (_, _) => Show(name);
            buttons[name] = button;
            rail.Children.Add(button);
        }

        root.Children.Add(rail);

        var host = new Grid { Margin = new Thickness(8, 48, 8, 8) };
        pages[BrowserChrome.SettingsSections[0]] = Appearance(catalog, themeId, layout, themeChanged, layoutChanged);
        pages[BrowserChrome.SettingsSections[1]] = Search(searchEngineId, customTemplate, searchChanged);
        pages[BrowserChrome.SettingsSections[2]] = Privacy(privacy, privacyChanged);
        pages[BrowserChrome.SettingsSections[3]] = About();
        foreach (var page in pages.Values)
        {
            host.Children.Add(page);
        }

        Grid.SetColumn(host, 1);
        root.Children.Add(host);

        var closeButton = CaptionButtons.Create(CaptionKind.Close, close);
        closeButton.HorizontalAlignment = HorizontalAlignment.Right;
        closeButton.VerticalAlignment = VerticalAlignment.Top;
        closeButton.Margin = new Thickness(0, 8, 8, 0);
        Grid.SetColumn(closeButton, 1);
        root.Children.Add(closeButton);

        void Show(string name)
        {
            foreach (var pair in pages)
            {
                pair.Value.Visibility = pair.Key == name ? Visibility.Visible : Visibility.Collapsed;
            }

            foreach (var pair in buttons)
            {
                Paint.FillButton(pair.Value, Paint.Brush(Paint.White, pair.Key == name ? (byte)28 : (byte)0), Paint.Brush(Paint.White));
            }
        }

        Show(BrowserChrome.SettingsSections[0]);
    }

    static UIElement Appearance(ThemeCatalog catalog, string themeId, ChromeLayout layout, Action<string> themeChanged, Action<ChromeLayout> layoutChanged)
    {
        var stack = Page();
        stack.Children.Add(Heading(BrowserChrome.SettingsSections[0]));
        stack.Children.Add(Body(Copy.LayoutHelp));
        var browser = new RadioButton { Content = Copy.LayoutClassic, GroupName = "layout", IsChecked = layout == ChromeLayout.Classic, Foreground = Paint.Brush(Paint.White) };
        var floating = new RadioButton { Content = Copy.LayoutIsland, GroupName = "layout", IsChecked = layout == ChromeLayout.Island, Foreground = Paint.Brush(Paint.White) };
        browser.Checked += (_, _) => layoutChanged(ChromeLayout.Classic);
        floating.Checked += (_, _) => layoutChanged(ChromeLayout.Island);
        stack.Children.Add(browser);
        stack.Children.Add(floating);
        AddThemeGroup(stack, catalog, themeId, "accent", Copy.Colors, themeChanged);
        AddThemeGroup(stack, catalog, themeId, "pack", Copy.Themes, themeChanged);
        AddThemeGroup(stack, catalog, themeId, "pro", Copy.Pro, themeChanged);
        AddThemeGroup(stack, catalog, themeId, "seasonal", Copy.Seasons, themeChanged);
        return Scroll(stack);
    }

    static UIElement Search(string searchEngineId, string customTemplate, Action<string, string> searchChanged)
    {
        var stack = Page();
        stack.Children.Add(Heading(BrowserChrome.SettingsSections[1]));
        stack.Children.Add(Body("Words you type in the address field open with this search."));
        var engines = SearchEngine.All;
        var combo = new ComboBox { MinWidth = 280, Margin = new Thickness(0, 8, 0, 8) };
        foreach (var engine in engines)
        {
            combo.Items.Add(engine.Label);
        }

        var selected = SearchEngine.Find(searchEngineId);
        combo.SelectedItem = selected.Label;
        var custom = new TextBox
        {
            PlaceholderText = Copy.CustomSearch,
            Text = customTemplate,
            Margin = new Thickness(0, 4, 0, 8),
            Visibility = selected.Id == SearchEngine.Custom.Id ? Visibility.Visible : Visibility.Collapsed
        };
        combo.SelectionChanged += (_, _) =>
        {
            var label = combo.SelectedItem as string;
            var engine = engines.First(item => item.Label == label);
            custom.Visibility = engine.Id == SearchEngine.Custom.Id ? Visibility.Visible : Visibility.Collapsed;
            searchChanged(engine.Id, custom.Text);
        };
        custom.LostFocus += (_, _) => searchChanged(SearchEngine.Find(combo.SelectedItem as string).Id, custom.Text);
        stack.Children.Add(combo);
        stack.Children.Add(custom);
        return Scroll(stack);
    }

    static UIElement Privacy(PrivacySettings privacy, Action privacyChanged)
    {
        var stack = Page();
        stack.Children.Add(Heading(BrowserChrome.SettingsSections[2]));
        stack.Children.Add(Heading(Copy.WorkingNow));
        stack.Children.Add(Body("These are active in this Space."));
        Toggle(stack, Copy.HttpsOnly, "Opens pages over HTTPS. If a page has no secure version, Zalla tries it once over HTTP.", privacy.HttpsOnly, value => { privacy.HttpsOnly = value; privacyChanged(); });
        Toggle(stack, "Clean tracking from links", "Removes tracking tags such as utm_source and fbclid from addresses you open.", privacy.CleanLinks, value => { privacy.CleanLinks = value; privacyChanged(); });
        Toggle(stack, "Trim referrer", "Sites you open next are told the last site's name, not the exact page you were on.", privacy.TrimReferrer, value => { privacy.TrimReferrer = value; privacyChanged(); });
        stack.Children.Add(Heading(Copy.PreviewHeading));
        stack.Children.Add(Body(Copy.PrivacyNote));
        Toggle(stack, "Block trackers", Copy.PreviewSaved, privacy.BlockTrackers, value => { privacy.BlockTrackers = value; privacyChanged(); });
        Toggle(stack, "Block common ads", Copy.PreviewSaved, privacy.BlockCommonAds, value => { privacy.BlockCommonAds = value; privacyChanged(); });
        Toggle(stack, "Full ad blocking", Copy.PreviewSaved, privacy.FullAdBlocking, value => { privacy.FullAdBlocking = value; privacyChanged(); });
        Toggle(stack, "Hide ad spaces", Copy.PreviewSaved, privacy.HideAdSpaces, value => { privacy.HideAdSpaces = value; privacyChanged(); });
        Toggle(stack, "Cookie banners", Copy.PreviewSaved, privacy.CookieBanners, value => { privacy.CookieBanners = value; privacyChanged(); });
        Toggle(stack, "Fingerprinting protection", Copy.PreviewSaved, privacy.Fingerprinting, value => { privacy.Fingerprinting = value; privacyChanged(); });
        Toggle(stack, "Encrypted DNS", Copy.PreviewSaved, privacy.EncryptedDns, value => { privacy.EncryptedDns = value; privacyChanged(); });
        Toggle(stack, Copy.ProxyTitle, Copy.ProxyDetail, privacy.OwnProxy, value => { privacy.OwnProxy = value; privacyChanged(); });
        var proxy = new TextBox
        {
            PlaceholderText = "proxy.example:8080",
            Text = privacy.ProxyAddress,
            Margin = new Thickness(0, 0, 0, 8)
        };
        proxy.LostFocus += (_, _) =>
        {
            privacy.ProxyAddress = proxy.Text.Trim();
            privacyChanged();
        };
        stack.Children.Add(proxy);
        return Scroll(stack);
    }

    static UIElement About()
    {
        var stack = Page();
        stack.Children.Add(Heading(BrowserChrome.SettingsSections[3]));
        stack.Children.Add(Body(Copy.About));
        stack.Children.Add(Body(Copy.EngineNote));
        stack.Children.Add(Body(Copy.ExtensionNote));
        return Scroll(stack);
    }

    static ScrollViewer Scroll(StackPanel stack) => new()
    {
        Content = stack,
        Padding = new Thickness(20, 4, 20, 20),
        VerticalScrollBarVisibility = ScrollBarVisibility.Auto
    };

    static StackPanel Page() => new() { Spacing = 2 };

    static Button SectionButton(string name)
    {
        var button = new Button
        {
            Content = name,
            HorizontalAlignment = HorizontalAlignment.Stretch,
            HorizontalContentAlignment = HorizontalAlignment.Left,
            Height = 40,
            Padding = new Thickness(12, 0, 12, 0),
            FontSize = 15,
            CornerRadius = new CornerRadius(8),
            BorderThickness = new Thickness(0)
        };
        AutomationProperties.SetName(button, name);
        return button;
    }

    static void AddThemeGroup(StackPanel stack, ThemeCatalog catalog, string themeId, string group, string title, Action<string> themeChanged)
    {
        var themes = catalog.Themes.Where(theme => theme.Group == group).ToList();
        if (themes.Count == 0)
        {
            return;
        }

        stack.Children.Add(Heading(title));
        var wrap = new WrapPanel { Margin = new Thickness(0, 0, 0, 8) };
        foreach (var theme in themes)
        {
            var color = Paint.Hex(theme.Colors.Primary);
            var chip = new Button
            {
                Content = theme.Name,
                Margin = new Thickness(0, 0, 8, 8),
                Padding = new Thickness(12, 6, 12, 6),
                CornerRadius = new CornerRadius(14),
                BorderThickness = new Thickness(theme.Id == themeId ? 2 : 0),
                BorderBrush = Paint.Brush(Paint.White)
            };
            Paint.FillButton(chip, Paint.Brush(color), Paint.Brush(Paint.On(color)));
            var id = theme.Id;
            chip.Click += (_, _) => themeChanged(id);
            wrap.Children.Add(chip);
        }

        stack.Children.Add(wrap);
    }

    static TextBlock Heading(string text) => new()
    {
        Text = text,
        FontSize = 18,
        FontWeight = FontWeights.SemiBold,
        Foreground = Paint.Brush(Paint.White),
        Margin = new Thickness(0, 14, 0, 4)
    };

    static TextBlock Body(string text) => new()
    {
        Text = text,
        FontSize = 14,
        Foreground = Paint.Brush(Paint.White),
        Opacity = 0.82,
        TextWrapping = TextWrapping.Wrap,
        Margin = new Thickness(0, 0, 0, 8)
    };

    static void Toggle(StackPanel stack, string title, string detail, bool value, Action<bool> changed)
    {
        var toggle = new ToggleSwitch
        {
            Header = new TextBlock { Text = title, FontSize = 15, Foreground = Paint.Brush(Paint.White) },
            IsOn = value,
            OnContent = "On",
            OffContent = "Off"
        };
        toggle.Toggled += (_, _) => changed(toggle.IsOn);
        stack.Children.Add(toggle);
        stack.Children.Add(new TextBlock
        {
            Text = detail,
            FontSize = 13,
            Foreground = Paint.Brush(Paint.White),
            Opacity = 0.7,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, -2, 0, 10)
        });
    }
}
