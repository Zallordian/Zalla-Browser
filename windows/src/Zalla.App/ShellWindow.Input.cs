using System.Runtime.InteropServices;

namespace Zalla;

public sealed partial class ShellWindow
{
    const int WmKeyDown = 0x0100;
    const int WmSysKeyDown = 0x0104;
    const int WmHotkey = 0x0312;
    const int WmSysCommand = 0x0112;
    const int ScMaximize = 0xF030;
    const uint ModAlt = 0x0001;
    const uint ModControl = 0x0002;
    const uint ModShift = 0x0004;

    [UnmanagedFunctionPointer(CallingConvention.Winapi)]
    delegate IntPtr SubclassProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam, nuint id, nuint data);

    void OnSubmit(string text, bool commandMode)
    {
        var decision = InputRouter.Decide(text, commandMode);
        if (decision.Route == InputRoute.Navigate)
        {
            var tab = PrimaryOrNull();
            if (tab != null)
            {
                _ = NavigateAsync(tab, decision.Text);
            }

            return;
        }

        if (decision.Route == InputRoute.Command)
        {
            Run(decision.Command);
        }
    }

    void Run(ParsedCommand command)
    {
        switch (command.Kind)
        {
            case CommandKind.Burn:
                _ = BurnAsync();
                break;
            case CommandKind.Reader:
                Toast(CommandParser.ReaderNote);
                _island.LeaveCommand();
                break;
            case CommandKind.Theme:
                var theme = _catalog.Match(command.Argument);
                if (theme is null)
                {
                    Toast(Copy.NoTheme);
                }
                else
                {
                    _spaceState.ThemeId = theme.Id;
                    ApplyTheme();
                    SaveCurrentSpace();
                    Toast(Copy.ThemeOn(theme.Name));
                }

                _island.LeaveCommand();
                break;
            case CommandKind.NewTab:
                NewTabFromChrome();
                _island.LeaveCommand();
                break;
            case CommandKind.CloseTab:
                var current = PrimaryOrNull();
                if (current != null)
                {
                    CloseTab(current.Id);
                }

                _island.LeaveCommand();
                break;
            case CommandKind.Unknown:
                Toast(string.IsNullOrEmpty(command.Note) ? CommandParser.UnknownNote : command.Note);
                break;
        }
    }

    void HookIsland()
    {
        _island.PointerPressed += (_, e) =>
        {
            var surface = _settings.Layout == ChromeLayout.Classic || HitTestHelper.IsInteractive(e.OriginalSource as DependencyObject)
                ? DragSurface.Control
                : DragSurface.IslandChrome;
            if (!DragPolicy.MoveIsland(surface, e.GetCurrentPoint(_island).Properties.IsLeftButtonPressed))
            {
                return;
            }

            _draggingIsland = true;
            _dragStart = e.GetCurrentPoint(_overlay).Position;
            var left = Canvas.GetLeft(_island);
            var top = Canvas.GetTop(_island);
            _islandStart = new Point(double.IsNaN(left) ? 0 : left, double.IsNaN(top) ? 0 : top);
            _island.CapturePointer(e.Pointer);
            e.Handled = true;
        };
        _island.PointerMoved += (_, e) =>
        {
            if (!_draggingIsland)
            {
                return;
            }

            if (!DragPolicy.KeepDragging(e.GetCurrentPoint(_island).Properties.IsLeftButtonPressed))
            {
                EndIslandDrag();
                return;
            }

            var pos = e.GetCurrentPoint(_overlay).Position;
            Canvas.SetLeft(_island, _islandStart.X + pos.X - _dragStart.X);
            Canvas.SetTop(_island, _islandStart.Y + pos.Y - _dragStart.Y);
            _settings.Island.Dock = DockEdge.None;
            _settings.Island.HasMoved = true;
            _hint.Visibility = Visibility.Collapsed;
            e.Handled = true;
        };
        _island.PointerReleased += (_, _) => EndIslandDrag();
        _island.PointerCaptureLost += (_, _) => EndIslandDrag();
        _island.PointerCanceled += (_, _) => EndIslandDrag();
    }

    void EndIslandDrag()
    {
        if (!_draggingIsland)
        {
            return;
        }

        _draggingIsland = false;
        _island.ReleasePointerCaptures();
        SnapIsland();
        SettingsStore.SaveApp(_root, _settings);
    }

    void SnapIsland()
    {
        var width = _rootGrid.ActualWidth;
        var height = _rootGrid.ActualHeight;
        var x = Canvas.GetLeft(_island);
        var y = Canvas.GetTop(_island);
        if (double.IsNaN(x) || double.IsNaN(y) || width < 10 || height < 10)
        {
            return;
        }

        var cx = x + _island.ActualWidth / 2;
        var cy = y + _island.ActualHeight / 2;
        const double snap = 72;
        if (cy < snap)
        {
            _settings.Island.Dock = DockEdge.Top;
        }
        else if (height - cy < snap)
        {
            _settings.Island.Dock = DockEdge.Bottom;
        }
        else if (cx < snap)
        {
            _settings.Island.Dock = DockEdge.Left;
        }
        else if (width - cx < snap)
        {
            _settings.Island.Dock = DockEdge.Right;
        }
        else
        {
            _settings.Island.Dock = DockEdge.None;
            _settings.Island.X = cx / width;
            _settings.Island.Y = cy / height;
        }

        PositionIsland();
    }

    void OnCharacter(UIElement sender, CharacterReceivedRoutedEventArgs args)
    {
        if (args.Character != '/')
        {
            return;
        }

        if (FocusManager.GetFocusedElement() is TextBox or WebView2)
        {
            return;
        }

        args.Handled = true;
        _island.FocusCommand(true);
    }

    void OnKeyDown(object sender, KeyRoutedEventArgs args)
    {
        var action = BrowserGestures.Match(
            IsKeyDown(Windows.System.VirtualKey.Control),
            IsKeyDown(Windows.System.VirtualKey.Shift),
            IsKeyDown(Windows.System.VirtualKey.Menu),
            (int)args.Key,
            out var tabNumber);
        if (action == BrowserAction.None)
        {
            return;
        }

        RunGesture(action, tabNumber);
        args.Handled = true;
    }

    void RunGesture(BrowserAction action, int tabNumber)
    {
        switch (action)
        {
            case BrowserAction.NewTab:
                NewTabFromChrome();
                break;
            case BrowserAction.CloseTab:
                var tab = PrimaryOrNull();
                if (tab != null)
                {
                    CloseTab(tab.Id);
                }

                break;
            case BrowserAction.FocusAddress:
                _island.FocusCommand(false);
                break;
            case BrowserAction.Command:
                _island.FocusCommand(true);
                break;
            case BrowserAction.NextTab:
                Cycle(1);
                break;
            case BrowserAction.PreviousTab:
                Cycle(-1);
                break;
            case BrowserAction.ReopenTab:
                ReopenClosedTab();
                break;
            case BrowserAction.SelectTab:
                var index = BrowserGestures.TabIndex(_tabs.Count, tabNumber);
                if (index is int chosen)
                {
                    Select(_tabs[chosen].Id);
                }

                break;
            case BrowserAction.Reload:
                ReloadOrStop();
                break;
            case BrowserAction.FullScreen:
                ToggleFullScreen();
                break;
            case BrowserAction.Back:
                Back();
                break;
            case BrowserAction.Forward:
                Forward();
                break;
            case BrowserAction.Bookmark:
                ToggleBookmark();
                break;
            case BrowserAction.History:
                ShowHistory();
                break;
            case BrowserAction.Find:
                ShowFind();
                break;
            case BrowserAction.ZoomIn:
                ChangeZoom(1);
                break;
            case BrowserAction.ZoomOut:
                ChangeZoom(-1);
                break;
            case BrowserAction.ZoomReset:
                ChangeZoom(0);
                break;
        }
    }

    static bool IsKeyDown(Windows.System.VirtualKey key)
    {
        var state = Microsoft.UI.Input.InputKeyboardSource.GetKeyStateForCurrentThread(key);
        return state.HasFlag(Windows.UI.Core.CoreVirtualKeyStates.Down);
    }

    void Cycle(int delta)
    {
        if (_tabs.Count == 0)
        {
            return;
        }

        var index = (_active + delta) % _tabs.Count;
        if (index < 0)
        {
            index += _tabs.Count;
        }

        Select(_tabs[index].Id);
    }

    void StartTimers()
    {
        _cursorTimer = DispatcherQueue.CreateTimer();
        _cursorTimer.Interval = TimeSpan.FromMilliseconds(200);
        _cursorTimer.IsRepeating = true;
        _cursorTimer.Tick += (_, _) => OnCursor();
        _cursorTimer.Start();

        _previewTimer = DispatcherQueue.CreateTimer();
        _previewTimer.Interval = TimeSpan.FromSeconds(5);
        _previewTimer.IsRepeating = true;
        _previewTimer.Tick += (_, _) =>
        {
            if (_settings.Layout != ChromeLayout.Island)
            {
                return;
            }

            var tab = PrimaryOrNull();
            if (tab != null)
            {
                _ = CaptureAsync(tab);
            }
        };
        _previewTimer.Start();
    }

    void OnCursor()
    {
        if (_toastUntil > 0 && Environment.TickCount64 > _toastUntil)
        {
            _toast.Visibility = Visibility.Collapsed;
            _toastUntil = 0;
        }

        if (_settings.Layout != ChromeLayout.Island)
        {
            return;
        }

        if (GetCursorPos(out var point))
        {
            if (Math.Abs(point.X - _lastCursorX) + Math.Abs(point.Y - _lastCursorY) > 2)
            {
                _lastMove = Environment.TickCount64;
            }

            _lastCursorX = point.X;
            _lastCursorY = point.Y;
        }

        var fade = ShouldFade() && Environment.TickCount64 - _lastMove > 2200;
        SetChromeOpacity(fade ? 0 : 1);
    }

    bool ShouldFade()
    {
        if (_settings.Layout != ChromeLayout.Island || _settingsOpen || _draggingIsland || _draggingCard)
        {
            return false;
        }

        if (_island.Input.FocusState != FocusState.Unfocused)
        {
            return false;
        }

        var tab = PrimaryOrNull();
        return tab != null && tab.Url.Length > 0;
    }

    void InstallHotkeys()
    {
        if (_hotkeysOn)
        {
            return;
        }

        try
        {
            _hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            if (_hwnd == 0)
            {
                return;
            }

            _subclass = WndProc;
            SetWindowSubclass(_hwnd, _subclass, 1, 0);
            RegisterHotKey(_hwnd, 1, ModControl, 0x4B);
            RegisterHotKey(_hwnd, 2, ModControl, 0x54);
            RegisterHotKey(_hwnd, 3, ModControl, 0x57);
            RegisterHotKey(_hwnd, 4, ModControl, 0x4C);
            RegisterHotKey(_hwnd, 5, ModControl, 0x09);
            RegisterHotKey(_hwnd, 6, ModControl | ModShift, 0x09);
            RegisterHotKey(_hwnd, 7, ModAlt, 0x25);
            RegisterHotKey(_hwnd, 8, ModAlt, 0x27);
            _hotkeysOn = true;
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }

    void RemoveHotkeys()
    {
        if (_hwnd == 0)
        {
            return;
        }

        for (var id = 1; id <= 8; id++)
        {
            UnregisterHotKey(_hwnd, id);
        }

        if (_subclass != null)
        {
            RemoveWindowSubclass(_hwnd, _subclass, 1);
            foreach (var child in _webKeys)
            {
                RemoveWindowSubclass(child, _subclass, 2);
            }

            _webKeys.Clear();
        }

        _hotkeysOn = false;
    }

    void DispatchHotkey(int id)
    {
        switch (id)
        {
            case 1:
                _island.FocusCommand(true);
                break;
            case 2:
                NewTabFromChrome();
                break;
            case 3:
                var tab = PrimaryOrNull();
                if (tab != null)
                {
                    CloseTab(tab.Id);
                }

                break;
            case 4:
                _island.FocusCommand(false);
                break;
            case 5:
                Cycle(1);
                break;
            case 6:
                Cycle(-1);
                break;
            case 7:
                Back();
                break;
            case 8:
                Forward();
                break;
        }
    }

    IntPtr WndProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam, nuint id, nuint data)
    {
        if (msg == WmHotkey)
        {
            var hotkey = wParam.ToInt32();
            DispatcherQueue.TryEnqueue(() => DispatchHotkey(hotkey));
            return IntPtr.Zero;
        }

        if (msg == WmKeyDown || msg == WmSysKeyDown)
        {
            var key = wParam.ToInt32();
            var ctrl = (GetKeyState(0x11) & 0x8000) != 0;
            var shift = (GetKeyState(0x10) & 0x8000) != 0;
            var alt = (GetKeyState(0x12) & 0x8000) != 0;
            var action = BrowserGestures.Match(ctrl, shift, alt, key, out var tabNumber);
            if (action != BrowserAction.None && hwnd != _hwnd)
            {
                DispatcherQueue.TryEnqueue(() => RunGesture(action, tabNumber));
                return IntPtr.Zero;
            }
        }

        if (msg == WmSysCommand && ((int)wParam.ToInt64() & 0xFFF0) == ScMaximize)
        {
            DispatcherQueue.TryEnqueue(ToggleMaximize);
            return IntPtr.Zero;
        }

        return DefSubclassProc(hwnd, msg, wParam, lParam, id, data);
    }

    void WatchWebKeys()
    {
        if (_hwnd == 0 || _subclass == null)
        {
            return;
        }

        var found = new List<IntPtr>();
        CollectChildren(_hwnd, found);
        foreach (var child in found)
        {
            if (_webKeys.Add(child))
            {
                SetWindowSubclass(child, _subclass, 2, 0);
            }
        }
    }

    void CollectChildren(IntPtr parent, List<IntPtr> found)
    {
        var kids = new List<IntPtr>();
        EnumChildWindows(parent, (child, _) =>
        {
            kids.Add(child);
            return true;
        }, IntPtr.Zero);
        foreach (var child in kids)
        {
            found.Add(child);
            CollectChildren(child, found);
        }
    }

    [DllImport("user32.dll")]
    static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);

    [DllImport("user32.dll")]
    static extern bool EnumChildWindows(IntPtr hwnd, EnumProc proc, IntPtr data);

    delegate bool EnumProc(IntPtr hwnd, IntPtr data);

    [DllImport("user32.dll")]
    static extern bool UnregisterHotKey(IntPtr hwnd, int id);

    [DllImport("user32.dll")]
    static extern bool GetCursorPos(out PointNative point);

    [DllImport("user32.dll")]
    static extern short GetKeyState(int key);

    [DllImport("comctl32.dll")]
    static extern bool SetWindowSubclass(IntPtr hwnd, SubclassProc callback, nuint id, nuint data);

    [DllImport("comctl32.dll")]
    static extern bool RemoveWindowSubclass(IntPtr hwnd, SubclassProc callback, nuint id);

    [DllImport("comctl32.dll")]
    static extern IntPtr DefSubclassProc(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam, nuint id, nuint data);

    [StructLayout(LayoutKind.Sequential)]
    struct PointNative
    {
        public int X;
        public int Y;
    }
}
