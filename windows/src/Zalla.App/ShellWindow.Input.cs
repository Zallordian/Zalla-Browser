using System.Runtime.InteropServices;

namespace Zalla;

public sealed partial class ShellWindow
{
    const int WmHotkey = 0x0312;
    const int WmNcLButtonDown = 0x00A1;
    const int HtCaption = 2;
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
            if (_settings.Layout == ChromeLayout.Classic || HitTestHelper.IsInteractive(e.OriginalSource as DependencyObject))
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

            var pos = e.GetCurrentPoint(_overlay).Position;
            Canvas.SetLeft(_island, _islandStart.X + pos.X - _dragStart.X);
            Canvas.SetTop(_island, _islandStart.Y + pos.Y - _dragStart.Y);
            _settings.Island.Dock = DockEdge.None;
            _settings.Island.HasMoved = true;
            _hint.Visibility = Visibility.Collapsed;
            e.Handled = true;
        };
        _island.PointerReleased += (_, e) =>
        {
            if (!_draggingIsland)
            {
                return;
            }

            _draggingIsland = false;
            _island.ReleasePointerCaptures();
            SnapIsland();
            SettingsStore.SaveApp(_root, _settings);
            e.Handled = true;
        };
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
        var control = IsKeyDown(Windows.System.VirtualKey.Control);
        var shift = IsKeyDown(Windows.System.VirtualKey.Shift);
        var alt = IsKeyDown(Windows.System.VirtualKey.Menu);
        if (!control && !alt)
        {
            return;
        }

        if (control && args.Key == Windows.System.VirtualKey.K)
        {
            _island.FocusCommand(true);
            args.Handled = true;
        }
        else if (control && args.Key == Windows.System.VirtualKey.L)
        {
            _island.FocusCommand(false);
            args.Handled = true;
        }
        else if (control && args.Key == Windows.System.VirtualKey.T)
        {
            NewTabFromChrome();
            args.Handled = true;
        }
        else if (control && args.Key == Windows.System.VirtualKey.W)
        {
            var tab = PrimaryOrNull();
            if (tab != null)
            {
                CloseTab(tab.Id);
            }

            args.Handled = true;
        }
        else if (control && args.Key == Windows.System.VirtualKey.Tab)
        {
            Cycle(shift ? -1 : 1);
            args.Handled = true;
        }
        else if (alt && args.Key == Windows.System.VirtualKey.Left)
        {
            Back();
            args.Handled = true;
        }
        else if (alt && args.Key == Windows.System.VirtualKey.Right)
        {
            Forward();
            args.Handled = true;
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
        _cursorTimer.Interval = TimeSpan.FromMilliseconds(90);
        _cursorTimer.IsRepeating = true;
        _cursorTimer.Tick += (_, _) => OnCursor();
        _cursorTimer.Start();

        _previewTimer = DispatcherQueue.CreateTimer();
        _previewTimer.Interval = TimeSpan.FromSeconds(5);
        _previewTimer.IsRepeating = true;
        _previewTimer.Tick += (_, _) =>
        {
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
        if (GetCursorPos(out var point))
        {
            if (Math.Abs(point.X - _lastCursorX) + Math.Abs(point.Y - _lastCursorY) > 2)
            {
                _lastMove = Environment.TickCount64;
            }

            _lastCursorX = point.X;
            _lastCursorY = point.Y;
        }

        if (_toastUntil > 0 && Environment.TickCount64 > _toastUntil)
        {
            _toast.Visibility = Visibility.Collapsed;
            _toastUntil = 0;
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

    void BeginWindowDrag()
    {
        var hwnd = _hwnd != 0 ? _hwnd : WinRT.Interop.WindowNative.GetWindowHandle(this);
        if (hwnd == 0)
        {
            return;
        }

        ReleaseCapture();
        SendMessage(hwnd, WmNcLButtonDown, (IntPtr)HtCaption, IntPtr.Zero);
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

        return DefSubclassProc(hwnd, msg, wParam, lParam, id, data);
    }

    [DllImport("user32.dll")]
    static extern bool RegisterHotKey(IntPtr hwnd, int id, uint modifiers, uint key);

    [DllImport("user32.dll")]
    static extern bool UnregisterHotKey(IntPtr hwnd, int id);

    [DllImport("user32.dll")]
    static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    static extern bool ReleaseCapture();

    [DllImport("user32.dll")]
    static extern bool GetCursorPos(out PointNative point);

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
