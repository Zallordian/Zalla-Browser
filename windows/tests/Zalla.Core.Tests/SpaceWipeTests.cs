namespace Zalla.Core.Tests;

public class SpaceWipeTests
{
    [Fact]
    public void GhostWipesAndTheOtherSpacesStay()
    {
        var root = NewRoot();
        File.WriteAllText(Path.Combine(root, "Personal", "state.json"), "personal");
        File.WriteAllText(Path.Combine(root, "Work", "note.txt"), "work");
        File.WriteAllText(Path.Combine(root, "Ghost", "WebView2", "Cookies"), "secret");

        Assert.Equal(WipeResult.Skipped, SpaceWipe.Wipe(root, SpaceKind.Personal));
        Assert.Equal(WipeResult.Skipped, SpaceWipe.Wipe(root, SpaceKind.Work));
        Assert.True(File.Exists(Path.Combine(root, "Personal", "state.json")));
        Assert.True(File.Exists(Path.Combine(root, "Work", "note.txt")));

        Assert.Equal(WipeResult.Wiped, SpaceWipe.Wipe(root, SpaceKind.Ghost));
        Assert.False(Directory.Exists(Path.Combine(root, "Ghost")));
        Assert.True(File.Exists(Path.Combine(root, "Personal", "state.json")));
        Assert.True(File.Exists(Path.Combine(root, "Work", "note.txt")));
    }

    [Fact]
    public void MissingGhostIsNotAnError()
    {
        var root = NewRoot();
        Directory.Delete(Path.Combine(root, "Ghost"), recursive: true);
        Assert.Equal(WipeResult.Missing, SpaceWipe.Wipe(root, SpaceKind.Ghost));
        Assert.True(Directory.Exists(Path.Combine(root, "Personal")));
    }

    [Theory]
    [InlineData("..")]
    [InlineData(".")]
    [InlineData("")]
    [InlineData("Ghost/../../etc")]
    [InlineData(@"Work\..\Personal")]
    public void UnsafeFolderNamesAreRefused(string name)
    {
        var root = NewRoot();
        Assert.Equal(WipeResult.Refused, SpaceWipe.TryDeleteContained(root, name));
        Assert.True(Directory.Exists(Path.Combine(root, "Personal")));
        Assert.True(Directory.Exists(Path.Combine(root, "Work")));
        Assert.True(Directory.Exists(Path.Combine(root, "Ghost")));
    }

    [Fact]
    public void PendingMarkerOnlyDeletesGhost()
    {
        var root = NewRoot();
        File.WriteAllText(Path.Combine(root, "Personal", "state.json"), "keep");
        SpaceWipe.RequestWipe(root, SpaceKind.Personal);
        Assert.False(File.Exists(Path.Combine(root, SpaceWipe.PendingFileName)));

        SpaceWipe.RequestWipe(root, SpaceKind.Ghost);
        Assert.Equal(WipeResult.Wiped, SpaceWipe.ConsumePending(root));
        Assert.False(Directory.Exists(Path.Combine(root, "Ghost")));
        Assert.False(File.Exists(Path.Combine(root, SpaceWipe.PendingFileName)));
        Assert.True(File.Exists(Path.Combine(root, "Personal", "state.json")));

        File.WriteAllText(Path.Combine(root, SpaceWipe.PendingFileName), "Personal");
        Assert.Equal(WipeResult.Refused, SpaceWipe.ConsumePending(root));
        Assert.True(File.Exists(Path.Combine(root, "Personal", "state.json")));
        Assert.False(File.Exists(Path.Combine(root, SpaceWipe.PendingFileName)));
    }

    [Fact]
    public void ALockedGhostKeepsTheMarker()
    {
        var root = NewRoot();
        var blocker = Path.Combine(root, "Ghost", "lock");
        File.WriteAllText(blocker, "open");
        using var stream = new FileStream(blocker, FileMode.Open, FileAccess.Read, FileShare.None);
        SpaceWipe.RequestWipe(root, SpaceKind.Ghost);
        var result = SpaceWipe.ConsumePending(root);
        if (result == WipeResult.Wiped)
        {
            Assert.False(File.Exists(Path.Combine(root, SpaceWipe.PendingFileName)));
            return;
        }

        Assert.Equal(WipeResult.Refused, result);
        Assert.True(Directory.Exists(Path.Combine(root, "Ghost")));
        Assert.True(File.Exists(Path.Combine(root, SpaceWipe.PendingFileName)));
    }

    [Fact]
    public void PathsOutsideTheRootAreNotInside()
    {
        var root = NewRoot();
        Assert.False(SpaceWipe.IsInside(root, root));
        Assert.False(SpaceWipe.IsInside(root, Path.GetDirectoryName(root)!));
        Assert.True(SpaceWipe.IsInside(root, Path.Combine(root, "Ghost")));
        Assert.False(SpaceWipe.IsInside(root, Path.Combine(root, "Ghost", "WebView2")));
    }

    [Fact]
    public void GhostStateIsNotWrittenBesidePersonal()
    {
        var appRoot = Path.Combine(Path.GetTempPath(), "zalla-settings-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(appRoot);
        var settings = new AppSettings { LastSpace = SpaceKind.Ghost, Layout = ChromeLayout.Classic };
        SettingsStore.SaveApp(appRoot, settings);
        var loaded = SettingsStore.LoadApp(appRoot);
        Assert.Equal(ChromeLayout.Classic, loaded.Layout);
        Assert.Equal(SpaceKind.Ghost, loaded.LastSpace);

        var personal = SpaceState.CreateNew();
        personal.ThemeId = "aurora";
        SettingsStore.SaveSpace(appRoot, SpaceKind.Personal, personal);
        Assert.Equal("aurora", SettingsStore.LoadSpace(appRoot, SpaceKind.Personal).ThemeId);

        var ghost = SpaceState.CreateNew();
        ghost.Tabs[0].Url = "https://example.com";
        SettingsStore.SaveSpace(appRoot, SpaceKind.Ghost, ghost);
        Assert.False(File.Exists(SettingsStore.SpaceStatePath(appRoot, SpaceKind.Ghost)));
        Assert.Equal("", SettingsStore.LoadSpace(appRoot, SpaceKind.Ghost).Tabs[0].Url);
    }

    static string NewRoot()
    {
        var root = Path.Combine(Path.GetTempPath(), "zalla-spaces-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(root, "Personal"));
        Directory.CreateDirectory(Path.Combine(root, "Work"));
        Directory.CreateDirectory(Path.Combine(root, "Ghost", "WebView2"));
        return root;
    }
}
