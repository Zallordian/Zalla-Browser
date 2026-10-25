using Windows.Storage.Streams;

namespace Zalla;

public sealed partial class ShellWindow
{
    BrowserTab? PrimaryOrNull() => _tabs.Count == 0 ? null : Primary;

    BrowserTab Active => _tabs[Math.Clamp(_active, 0, _tabs.Count - 1)];

    BrowserTab Primary => _splitMode ? Find(_leftId) ?? Active : Active;

    BrowserTab? Find(string? id) => id == null ? null : _tabs.FirstOrDefault(tab => tab.Id == id);

    void LoadSpaceIntoTabs()
    {
        ClearTabs();
        _spaceState = SettingsStore.LoadSpace(_root, _space);
        if (_spaceState.Tabs.Count == 0)
        {
            _spaceState.Tabs.Add(new TabState { Id = Guid.NewGuid().ToString("N"), Title = "New Tab" });
        }

        foreach (var saved in _spaceState.Tabs)
        {
            AddTab(saved, select: false, refresh: false);
        }

        _active = Math.Clamp(_spaceState.ActiveIndex, 0, _tabs.Count - 1);
        LayoutHosts();
        RefreshChrome();
    }

    void ClearTabs()
    {
        _splitMode = false;
        _leftId = null;
        _rightId = null;
        foreach (var tab in _tabs.ToList())
        {
            Destroy(tab);
        }

        _tabs.Clear();
        _active = 0;
        _split.Visibility = Visibility.Collapsed;
        _stack.Visibility = Visibility.Visible;
    }

    BrowserTab AddTab(TabState? saved, bool select, bool refresh = true)
    {
        var tab = new BrowserTab
        {
            Id = string.IsNullOrWhiteSpace(saved?.Id) ? Guid.NewGuid().ToString("N") : saved!.Id,
            Title = string.IsNullOrWhiteSpace(saved?.Title) ? "New Tab" : saved!.Title,
            Url = saved?.Url ?? ""
        };
        tab.ColorHex = ColorFor(tab.Url);
        var saying = Copy.Sayings[_saying % Copy.Sayings.Length];
        _saying++;
        tab.Page = new NewTabPage(saying, url => _ = NavigateAsync(tab, url));
        tab.Page.SetBrand(Paint.Hex(BrandHex));
        tab.Host.Children.Add(tab.Page);
        _stack.Children.Add(tab.Host);
        _tabs.Add(tab);
        if (select)
        {
            Select(tab.Id);
        }
        else
        {
            tab.Host.Visibility = Visibility.Collapsed;
            if (refresh)
            {
                RefreshChrome();
            }
        }

        return tab;
    }

    void NewTabFromChrome()
    {
        AddTab(null, true);
        SaveCurrentSpace();
    }

    void Select(string id)
    {
        var index = _tabs.FindIndex(tab => tab.Id == id);
        if (index < 0)
        {
            return;
        }

        _active = index;
        if (_splitMode && id != _rightId)
        {
            _leftId = id;
        }

        LayoutHosts();
        var tab = Primary;
        if (!string.IsNullOrEmpty(tab.Url) && tab.Web?.CoreWebView2 == null && _booted)
        {
            _ = NavigateAsync(tab, tab.Url);
        }
        else if (string.IsNullOrEmpty(tab.Url))
        {
            ShowPage(tab);
        }

        RefreshChrome();
        SaveCurrentSpace();
    }

    void CloseTab(string id)
    {
        var index = _tabs.FindIndex(tab => tab.Id == id);
        if (index < 0)
        {
            return;
        }

        var closingPrimary = _tabs[index].Id == Primary.Id;
        if (_splitMode && (id == _leftId || id == _rightId))
        {
            _splitMode = false;
            _leftId = null;
            _rightId = null;
        }

        Destroy(_tabs[index]);
        _tabs.RemoveAt(index);
        if (_tabs.Count == 0)
        {
            AddTab(null, true);
        }
        else if (closingPrimary)
        {
            Select(_tabs[Math.Clamp(index, 0, _tabs.Count - 1)].Id);
        }
        else
        {
            _active = Math.Clamp(_active > index ? _active - 1 : _active, 0, _tabs.Count - 1);
            LayoutHosts();
            RefreshChrome();
        }

        SaveCurrentSpace();
    }

    void StartSplit(string id)
    {
        if (_tabs.Count < 2)
        {
            Toast(Copy.NeedAnother);
            return;
        }

        var dragged = Find(id);
        if (dragged is null)
        {
            return;
        }

        var other = dragged.Id == Active.Id
            ? _tabs.First(tab => tab.Id != dragged.Id)
            : Active;
        _splitMode = true;
        _leftId = other.Id;
        _rightId = dragged.Id;
        _active = _tabs.IndexOf(other);
        LayoutHosts();
        if (_booted && !string.IsNullOrEmpty(dragged.Url) && dragged.Web?.CoreWebView2 == null)
        {
            _ = NavigateAsync(dragged, dragged.Url);
        }

        if (_booted && !string.IsNullOrEmpty(other.Url) && other.Web?.CoreWebView2 == null)
        {
            _ = NavigateAsync(other, other.Url);
        }

        RefreshChrome();
    }

    void EndSplit()
    {
        if (!_splitMode)
        {
            return;
        }

        _splitMode = false;
        _leftId = null;
        _rightId = null;
        LayoutHosts();
        RefreshChrome();
    }

    void LayoutHosts()
    {
        if (_tabs.Count == 0)
        {
            return;
        }

        if (_splitMode)
        {
            _stack.Visibility = Visibility.Collapsed;
            _split.Visibility = Visibility.Visible;
            var left = Find(_leftId) ?? Active;
            var right = Find(_rightId);
            _leftId = left.Id;
            Place(left, _splitLeft);
            left.Host.Visibility = Visibility.Visible;
            if (right != null)
            {
                Place(right, _splitRight);
                right.Host.Visibility = Visibility.Visible;
            }

            foreach (var tab in _tabs)
            {
                if (tab != left && tab != right)
                {
                    tab.Host.Visibility = Visibility.Collapsed;
                }
            }
        }
        else
        {
            _split.Visibility = Visibility.Collapsed;
            _stack.Visibility = Visibility.Visible;
            foreach (var tab in _tabs)
            {
                Place(tab, _stack);
                tab.Host.Visibility = tab.Id == Active.Id ? Visibility.Visible : Visibility.Collapsed;
            }
        }
    }

    static void Place(BrowserTab tab, Panel parent)
    {
        if (!ReferenceEquals(tab.Host.Parent, parent))
        {
            (tab.Host.Parent as Panel)?.Children.Remove(tab.Host);
            parent.Children.Add(tab.Host);
        }
    }

    static void Destroy(BrowserTab tab)
    {
        try
        {
            tab.Web?.Close();
        }
        catch
        {
            // The control can already be gone during shutdown.
        }

        (tab.Host.Parent as Panel)?.Children.Remove(tab.Host);
        tab.Web = null;
        tab.Ready = false;
    }

    async Task SwitchSpaceAsync(SpaceKind next)
    {
        if (next == _space || _busy)
        {
            return;
        }

        _busy = true;
        try
        {
            var leaving = _space;
            SaveCurrentSpace();
            ClearTabs();
            if (SpaceWipe.WipesOnClose(leaving))
            {
                _environments.Remove(leaving);
                await Task.Delay(150);
                SpaceWipe.RequestWipe(_spacesRoot, leaving);
                var result = SpaceWipe.Wipe(_spacesRoot, leaving);
                if (result is WipeResult.Wiped or WipeResult.Missing)
                {
                    ForgetMarker();
                }
            }

            _space = next;
            _settings.LastSpace = next;
            SettingsStore.SaveApp(_root, _settings);
            LoadSpaceIntoTabs();
            ApplyTheme();
            var tab = PrimaryOrNull();
            if (tab != null && tab.Url.Length > 0)
            {
                await NavigateAsync(tab, tab.Url);
            }
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
        finally
        {
            _busy = false;
        }
    }

    async Task NavigateAsync(BrowserTab tab, string input)
    {
        var resolved = AddressResolver.Resolve(input, SearchEngine.Find(_settings.SearchEngineId), _settings.CustomSearchTemplate);
        if (resolved.Kind == AddressKind.Empty)
        {
            return;
        }

        if (resolved.Kind == AddressKind.Rejected)
        {
            Toast(Copy.WebOnly);
            return;
        }

        var url = resolved.Url;
        if (_spaceState.Privacy.CleanLinks && TrackingCleaner.TryClean(url, out var cleaned))
        {
            url = cleaned;
        }

        tab.Url = url;
        tab.Title = TitleFor(url);
        tab.ColorHex = ColorFor(url);
        ShowWeb(tab);
        RefreshChrome();
        try
        {
            await EnsureWebAsync(tab);
            tab.Web?.CoreWebView2.Navigate(url);
            _island.LeaveCommand();
            _island.SetAddress(url);
            SaveCurrentSpace();
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }

    async Task EnsureWebAsync(BrowserTab tab)
    {
        if (tab.Ready && tab.Web?.CoreWebView2 != null)
        {
            ShowWeb(tab);
            return;
        }

        tab.Web ??= new WebView2
        {
            HorizontalAlignment = HorizontalAlignment.Stretch,
            VerticalAlignment = VerticalAlignment.Stretch
        };
        if (!ReferenceEquals(tab.Web.Parent, tab.Host))
        {
            (tab.Web.Parent as Panel)?.Children.Remove(tab.Web);
            tab.Host.Children.Add(tab.Web);
        }

        var environment = await EnvironmentForAsync(_space);
        await tab.Web.EnsureCoreWebView2Async(environment);
        tab.Web.DefaultBackgroundColor = Scenery.For(CurrentTheme()).Edge;
        var core = tab.Web.CoreWebView2;
        core.Settings.IsPasswordAutosaveEnabled = false;
        core.Settings.IsGeneralAutofillEnabled = false;
        core.Settings.AreBrowserAcceleratorKeysEnabled = true;
        WireCore(tab, core);
        tab.Ready = true;
        ShowWeb(tab);
    }

    async Task<CoreWebView2Environment> EnvironmentForAsync(SpaceKind space)
    {
        if (_environments.TryGetValue(space, out var existing))
        {
            return existing;
        }

        var folder = SettingsStore.WebViewDirectory(_root, space);
        Directory.CreateDirectory(folder);
        var environment = await CoreWebView2Environment.CreateAsync(null!, folder);
        _environments[space] = environment;
        return environment;
    }

    void WireCore(BrowserTab tab, CoreWebView2 core)
    {
        core.NavigationStarting += (_, args) => OnStarting(tab, args);
        core.NavigationCompleted += (_, args) => OnCompleted(tab, args);
        core.HistoryChanged += (_, _) =>
        {
            if (tab.Id == Primary.Id)
            {
                _island.SetHistory(core.CanGoBack, core.CanGoForward);
            }
        };
        core.SourceChanged += (_, _) =>
        {
            tab.Url = core.Source;
            tab.ColorHex = ColorFor(tab.Url);
            if (tab.Id == Primary.Id)
            {
                _island.SetAddress(tab.Url);
            }

            SaveCurrentSpace();
        };
        core.DocumentTitleChanged += (_, _) =>
        {
            if (!string.IsNullOrWhiteSpace(core.DocumentTitle))
            {
                tab.Title = core.DocumentTitle;
                RefreshChrome();
            }
        };
        core.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All);
        core.WebResourceRequested += (_, args) => TrimReferrer(args);
    }

    void OnStarting(BrowserTab tab, CoreWebView2NavigationStartingEventArgs args)
    {
        var url = args.Uri;
        if (tab.AllowHttpOnce && url.StartsWith("http://", StringComparison.OrdinalIgnoreCase))
        {
            tab.AllowHttpOnce = false;
            return;
        }

        if (_spaceState.Privacy.CleanLinks && TrackingCleaner.TryClean(url, out var cleaned) && !string.Equals(cleaned, url, StringComparison.OrdinalIgnoreCase))
        {
            args.Cancel = true;
            tab.Web?.CoreWebView2.Navigate(cleaned);
            return;
        }

        if (_spaceState.Privacy.HttpsOnly)
        {
            var https = HttpsUpgrade.ToHttps(url);
            if (https is not null)
            {
                args.Cancel = true;
                tab.PendingHttp = url;
                tab.Web?.CoreWebView2.Navigate(https);
            }
        }
    }

    void OnCompleted(BrowserTab tab, CoreWebView2NavigationCompletedEventArgs args)
    {
        if (!args.IsSuccess && tab.PendingHttp is not null)
        {
            var http = tab.PendingHttp;
            tab.PendingHttp = null;
            tab.AllowHttpOnce = true;
            tab.Web?.CoreWebView2.Navigate(http);
            return;
        }

        tab.PendingHttp = null;
        if (args.IsSuccess)
        {
            _ = CaptureSoon(tab);
        }

        RefreshChrome();
    }

    void TrimReferrer(CoreWebView2WebResourceRequestedEventArgs args)
    {
        if (!_spaceState.Privacy.TrimReferrer)
        {
            return;
        }

        try
        {
            if (!args.Request.Headers.Contains("Referer"))
            {
                return;
            }

            var value = args.Request.Headers.GetHeader("Referer");
            if (Uri.TryCreate(value, UriKind.Absolute, out var uri))
            {
                args.Request.Headers.SetHeader("Referer", uri.GetLeftPart(UriPartial.Authority));
            }
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }

    async Task CaptureSoon(BrowserTab tab)
    {
        await Task.Delay(450);
        await CaptureAsync(tab);
    }

    async Task CaptureAsync(BrowserTab tab)
    {
        if (tab.CaptureBusy || tab.Web?.CoreWebView2 is null || string.IsNullOrEmpty(tab.Url))
        {
            return;
        }

        tab.CaptureBusy = true;
        try
        {
            var stream = new InMemoryRandomAccessStream();
            await tab.Web.CoreWebView2.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png, stream);
            stream.Seek(0);
            var size = (uint)stream.Size;
            if (size == 0 || size > 8_000_000)
            {
                return;
            }

            var reader = new DataReader(stream);
            await reader.LoadAsync(size);
            var bytes = new byte[size];
            reader.ReadBytes(bytes);
            reader.DetachStream();
            tab.Preview = bytes;
            RefreshChrome();
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
        finally
        {
            tab.CaptureBusy = false;
        }
    }

    void ShowWeb(BrowserTab tab)
    {
        if (tab.Page != null)
        {
            tab.Page.Visibility = Visibility.Collapsed;
        }

        if (tab.Web != null)
        {
            tab.Web.Visibility = Visibility.Visible;
        }
    }

    static void ShowPage(BrowserTab tab)
    {
        if (tab.Page != null)
        {
            tab.Page.Visibility = Visibility.Visible;
        }

        if (tab.Web != null)
        {
            tab.Web.Visibility = Visibility.Collapsed;
        }
    }

    void Back()
    {
        var core = PrimaryOrNull()?.Web?.CoreWebView2;
        if (core?.CanGoBack == true)
        {
            core.GoBack();
        }
    }

    void Forward()
    {
        var core = PrimaryOrNull()?.Web?.CoreWebView2;
        if (core?.CanGoForward == true)
        {
            core.GoForward();
        }
    }

    async Task BurnAsync()
    {
        if (_busy)
        {
            return;
        }

        _busy = true;
        ShowFire();
        try
        {
            var core = _tabs.Select(tab => tab.Web?.CoreWebView2).FirstOrDefault(item => item != null);
            if (core != null)
            {
                await core.Profile.ClearBrowsingDataAsync(BrowsingKinds());
            }

            ClearTabs();
            AddTab(null, true);
            SaveCurrentSpace();
            Toast(Copy.Cleared(SpaceNames.Label(_space)));
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
            Toast(Copy.BurnFailed);
        }
        finally
        {
            _busy = false;
        }
    }

    static CoreWebView2BrowsingDataKinds BrowsingKinds()
    {
        if (Enum.TryParse("AllProfile", out CoreWebView2BrowsingDataKinds all) && all != 0)
        {
            return all;
        }

        return CoreWebView2BrowsingDataKinds.Cookies
            | CoreWebView2BrowsingDataKinds.DiskCache
            | CoreWebView2BrowsingDataKinds.DownloadHistory
            | CoreWebView2BrowsingDataKinds.BrowsingHistory
            | CoreWebView2BrowsingDataKinds.GeneralAutofill
            | CoreWebView2BrowsingDataKinds.PasswordAutosave
            | CoreWebView2BrowsingDataKinds.Settings
            | CoreWebView2BrowsingDataKinds.IndexedDb
            | CoreWebView2BrowsingDataKinds.LocalStorage
            | CoreWebView2BrowsingDataKinds.CacheStorage
            | CoreWebView2BrowsingDataKinds.FileSystems
            | CoreWebView2BrowsingDataKinds.WebSql;
    }

    void SaveCurrentSpace()
    {
        if (_tabs.Count == 0 || SpaceWipe.WipesOnClose(_space))
        {
            return;
        }

        _spaceState.Tabs = _tabs.Select(tab => new TabState { Id = tab.Id, Title = tab.Title, Url = tab.Url }).ToList();
        var index = _tabs.FindIndex(tab => tab.Id == Primary.Id);
        _spaceState.ActiveIndex = Math.Max(0, index);
        SettingsStore.SaveSpace(_root, _space, _spaceState);
    }

    void OnClosing(AppWindow sender, AppWindowClosingEventArgs args)
    {
        if (_closing)
        {
            return;
        }

        args.Cancel = true;
        _closing = true;
        try
        {
            SaveCurrentSpace();
            SettingsStore.SaveApp(_root, _settings);
            foreach (var tab in _tabs)
            {
                try
                {
                    tab.Web?.Close();
                }
                catch
                {
                    // Best effort before the process exits.
                }
            }

            if (SpaceWipe.WipesOnClose(_space))
            {
                _environments.Remove(_space);
                Thread.Sleep(200);
                SpaceWipe.RequestWipe(_spacesRoot, _space);
                var result = SpaceWipe.Wipe(_spacesRoot, _space);
                if (result is WipeResult.Wiped or WipeResult.Missing)
                {
                    ForgetMarker();
                }
            }

            RemoveHotkeys();
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }

        Close();
    }

    void ForgetMarker()
    {
        var marker = Path.Combine(_spacesRoot, SpaceWipe.PendingFileName);
        if (File.Exists(marker))
        {
            File.Delete(marker);
        }
    }

    static string ColorFor(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || string.IsNullOrEmpty(uri.Host))
        {
            return "E33B4F";
        }

        var hash = 0;
        foreach (var ch in uri.Host)
        {
            hash = unchecked(hash * 31 + ch);
        }

        string[] palette = ["E33B4F", "FF6A00", "2EA44F", "3AA0FF", "7C5CFF", "F2B84B"];
        return palette[Math.Abs(hash) % palette.Length];
    }

    static string TitleFor(string url)
    {
        if (Uri.TryCreate(url, UriKind.Absolute, out var uri) && !string.IsNullOrEmpty(uri.Host))
        {
            return uri.Host.StartsWith("www.", StringComparison.OrdinalIgnoreCase) ? uri.Host[4..] : uri.Host;
        }

        return "New Tab";
    }
}

sealed class BrowserTab
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Title { get; set; } = "New Tab";
    public string Url { get; set; } = "";
    public string ColorHex { get; set; } = "E33B4F";
    public byte[]? Preview { get; set; }
    public Grid Host { get; } = new();
    public NewTabPage? Page { get; set; }
    public WebView2? Web { get; set; }
    public bool Ready { get; set; }
    public bool AllowHttpOnce { get; set; }
    public string? PendingHttp { get; set; }
    public bool CaptureBusy { get; set; }
}
