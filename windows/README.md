# Zalla for Windows

Phase 1 of the desktop browser. The iOS app is unchanged. Theme colors live in `shared/themes.json`, exported from the Swift theme files so both apps can share them.

## Download and run

1. Open the Windows workflow run on GitHub Actions for the pull request.
2. Download the artifact named `Zalla-Windows-win-x64`. That download is one zip of the app files. `Zalla.exe` is at the top of the zip.
3. Unzip it once.
4. Double click `Zalla.exe`.

Copy the unzipped folder onto another Windows PC and run `Zalla.exe`. There is no installer. The folder already contains the Windows App SDK runtime.

Pages are drawn by Microsoft Edge WebView2. That engine is Chromium, the same family Chrome uses. Zalla is not Chrome and it does not include Chrome's toolbar, the Chrome Web Store, or the Edge Add-ons store. An unpacked extension can be loaded from a folder you already have. Zalla will not download extensions. Many Chrome-only features will not run. Replacing WebView2 with a full Chrome shell would be a different app and is not this build.

The default layout is a browser bar above the page: tabs, back, forward, reload or stop, the address field, bookmarks, history, and downloads. Floating cards remain in Settings if you want that experiment.

You need 64-bit Windows 10 version 1809 or Windows 11, and the Microsoft Edge WebView2 Runtime. Windows 11 usually has that runtime. Windows 10, and some managed work PCs, do not. A company policy can block an unsigned program or the WebView2 Runtime. Zalla does not bypass that. If pages cannot load, install Microsoft's Evergreen WebView2 Runtime only when you are allowed to.

Drag the dark strip at the top to move the window. The caption buttons stay visible. The square one maximizes inside the taskbar. F11 is full screen and covers the taskbar. F11 again, or the restore button, leaves full screen.

The first window is shown before a saved page is opened. Opening that page still starts WebView2, which is the slow part on a cold start. A line in `%LOCALAPPDATA%\Zalla\zalla.log` records the phase names. That is a trace, not a promise of a particular startup time.

The other artifact, `Zalla-Windows-win-x64-msix`, is unsigned. Windows will not install it until it is signed. Use the app zip.

If the window opens but only shows an error, the text includes the real exception. The same text is in `%LOCALAPPDATA%\Zalla\zalla.log`.

Settings and Spaces are stored in `%LOCALAPPDATA%\Zalla`. Ghost keeps its pages in its own folder and deletes that folder when you leave the Space or close the app. If a file is still locked, Zalla tries the delete again next launch.

## Build on Windows

You need the .NET 8 SDK.

```
dotnet test windows/tests/Zalla.Core.Tests/Zalla.Core.Tests.csproj -c Release
dotnet publish windows/src/Zalla.App/Zalla.App.csproj -c Release -r win-x64 --self-contained true -p:Platform=x64 -p:WindowsAppSDKSelfContained=true -p:WindowsPackageType=None -o windows/artifacts/publish
```

The test project does not use WinUI, so it also runs on macOS and Linux. The app project builds on Windows only.

Regenerate the shared theme file after the Swift colors change:

```
python windows/tools/export_themes.py
python windows/tools/export_themes.py --check
```

## What this build does

- Frameless window. The page fills it. Drag the thin strip at the top, or empty space on the new tab page, to move the window.
- Command Island: Zalla menu, back, forward, one search box, Burn It All. Drag it and drop it near an edge to dock it. It fades while you read a page and comes back when the mouse moves. Press `/` or Ctrl K for commands: burn, reader, theme and a name, new tab, close tab. Ctrl L focuses the address, Ctrl T opens a tab, Ctrl W closes one.
- The Deck stacks tab cards on the left. Hover to fan them out, click to switch, drag up or left to close, drag right to open that card beside the current one.
- Spaces: Personal, Work, and Ghost. Each has its own WebView2 profile. Ghost is wiped on close.
- Themes from the iOS app. Lake Superior is the start theme. Settings can switch to a classic tab strip.
- Burn It All clears browsing data for the current Space.
- Privacy switches start on. The proxy switch starts off. Zalla does not ship a proxy.

## Not in this build yet

Tracker lists, ad lists, cookie banner hiding, fingerprint changes, and encrypted DNS are saved and switched on, but they are not enforced yet. The shield count stays at the real number, which starts at zero.

Reader only shows a note. Proxy routing is not connected. Split view is two panes in the same window, not a second window. Card previews refresh when a page finishes loading and about every five seconds. Seasonal dates are in the theme file, and every theme is available here. There is no purchase flow.
