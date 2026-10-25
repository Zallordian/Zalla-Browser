# Zalla for Windows

Phase 1 of the desktop browser. The iOS app is unchanged. Theme colors live in `shared/themes.json`, exported from the Swift theme files so both apps can share them.

## Download and run

1. Open the Windows workflow run on GitHub Actions for the pull request.
2. Download the artifact named `Zalla-Windows-win-x64`.
3. Unzip it.
4. Double click `Zalla.exe`.

Windows 11 already includes the Microsoft Edge WebView2 Runtime, which is what loads pages. On Windows 10 (version 1809 or later), install Microsoft's Evergreen WebView2 Runtime if Zalla says it is missing.

The other artifact, `Zalla-Windows-win-x64-msix`, is an unsigned package. Windows will not install it until it is signed. Use the zip.

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
