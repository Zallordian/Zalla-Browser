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
        Background = Paint.Brush(Paint.Black, 120);
        PointerPressed += (_, e) =>
        {
            if (ReferenceEquals(e.OriginalSource, this))
            {
                close();
            }
        };

        var card = new Border
        {
            Width = 720,
            MaxHeight = 760,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            CornerRadius = new CornerRadius(24),
            Padding = new Thickness(8),
            Background = Paint.Brush("0E1E34", 235),
            BorderBrush = Paint.Brush(Paint.White, 40),
            BorderThickness = new Thickness(1)
        };
        var scroll = new ScrollViewer
        {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Padding = new Thickness(20, 8, 20, 20)
        };
        var stack = new StackPanel { Spacing = 8 };
        scroll.Content = stack;
        card.Child = scroll;
        Children.Add(card);

        var header = new Grid { Margin = new Thickness(0, 8, 0, 8) };
        header.Children.Add(new TextBlock { Text = Copy.Settings, FontSize = 28, FontWeight = FontWeights.Bold });
        var closeButton = Paint.Flat(new TextBlock { Text = "\u00D7", FontSize = 22 }, 36);
        closeButton.HorizontalAlignment = HorizontalAlignment.Right;
        closeButton.Click += (_, _) => close();
        AutomationProperties.SetName(closeButton, Copy.Close);
        header.Children.Add(closeButton);
        stack.Children.Add(header);

        stack.Children.Add(Heading(Copy.Appearance));
        stack.Children.Add(Body(Copy.LayoutHelp));
        var island = new RadioButton { Content = Copy.LayoutIsland, GroupName = "layout", IsChecked = layout == ChromeLayout.Island };
        var classic = new RadioButton { Content = Copy.LayoutClassic, GroupName = "layout", IsChecked = layout == ChromeLayout.Classic };
        island.Checked += (_, _) => layoutChanged(ChromeLayout.Island);
        classic.Checked += (_, _) => layoutChanged(ChromeLayout.Classic);
        stack.Children.Add(island);
        stack.Children.Add(classic);

        AddThemeGroup(stack, catalog, themeId, "accent", Copy.Colors, themeChanged);
        AddThemeGroup(stack, catalog, themeId, "pack", Copy.Themes, themeChanged);
        AddThemeGroup(stack, catalog, themeId, "pro", Copy.Pro, themeChanged);
        AddThemeGroup(stack, catalog, themeId, "seasonal", Copy.Seasons, themeChanged);

        stack.Children.Add(Heading(Copy.Search));
        var engines = SearchEngine.All;
        var combo = new ComboBox { MinWidth = 240, Margin = new Thickness(0, 4, 0, 4) };
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

        stack.Children.Add(Heading(Copy.Privacy));
        stack.Children.Add(Body(Copy.PrivacyNote));
        Toggle(stack, "Block trackers", "Stops known tracking and analytics requests.", privacy.BlockTrackers, value => { privacy.BlockTrackers = value; privacyChanged(); });
        Toggle(stack, "Block common ads", "Stops requests to known ad networks.", privacy.BlockCommonAds, value => { privacy.BlockCommonAds = value; privacyChanged(); });
        Toggle(stack, "Full ad blocking", "Adds detailed rules for ads that the common list misses.", privacy.FullAdBlocking, value => { privacy.FullAdBlocking = value; privacyChanged(); });
        Toggle(stack, "Hide ad spaces", "Hides leftover ad boxes on the page.", privacy.HideAdSpaces, value => { privacy.HideAdSpaces = value; privacyChanged(); });
        Toggle(stack, "Cookie banners", "Hides cookie notices and other popups.", privacy.CookieBanners, value => { privacy.CookieBanners = value; privacyChanged(); });
        Toggle(stack, Copy.HttpsOnly, "Opens pages over HTTPS. If a page has no secure version, Zalla tries it once over HTTP.", privacy.HttpsOnly, value => { privacy.HttpsOnly = value; privacyChanged(); });
        Toggle(stack, "Clean tracking from links", "Removes tracking tags such as utm_source and fbclid from addresses you open.", privacy.CleanLinks, value => { privacy.CleanLinks = value; privacyChanged(); });
        Toggle(stack, "Trim referrer", "Sites you open next are told the last site's name, not the exact page you were on.", privacy.TrimReferrer, value => { privacy.TrimReferrer = value; privacyChanged(); });
        Toggle(stack, "Fingerprinting protection", "Makes it harder for a page to single out this PC. It can affect some games and web apps.", privacy.Fingerprinting, value => { privacy.Fingerprinting = value; privacyChanged(); });
        Toggle(stack, "Encrypted DNS", "Looks up site names over an encrypted connection when Zalla can do that lookup itself.", privacy.EncryptedDns, value => { privacy.EncryptedDns = value; privacyChanged(); });
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

        stack.Children.Add(Heading(Copy.AboutTitle));
        stack.Children.Add(Body(Copy.About));
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
        Margin = new Thickness(0, 16, 0, 4)
    };

    static TextBlock Body(string text) => new()
    {
        Text = text,
        FontSize = 13,
        Opacity = 0.78,
        TextWrapping = TextWrapping.Wrap,
        Margin = new Thickness(0, 0, 0, 6)
    };

    static void Toggle(StackPanel stack, string title, string detail, bool value, Action<bool> changed)
    {
        var toggle = new ToggleSwitch
        {
            Header = title,
            IsOn = value,
            OnContent = "On",
            OffContent = "Off"
        };
        toggle.Toggled += (_, _) => changed(toggle.IsOn);
        stack.Children.Add(toggle);
        stack.Children.Add(new TextBlock
        {
            Text = detail,
            FontSize = 12,
            Opacity = 0.68,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, -4, 0, 8)
        });
    }
}
