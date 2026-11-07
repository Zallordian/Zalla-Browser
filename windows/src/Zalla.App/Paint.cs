using Windows.Storage.Streams;

namespace Zalla;

static class Paint
{
    public static Color Hex(string hex, byte alpha = 255)
    {
        var h = hex.Trim().TrimStart('#');
        if (h.Length != 6)
        {
            h = "E33B4F";
        }

        return Color.FromArgb(alpha, Convert.ToByte(h[..2], 16), Convert.ToByte(h.Substring(2, 2), 16), Convert.ToByte(h.Substring(4, 2), 16));
    }

    public static Color Mix(Color from, Color to, double amount)
    {
        var t = Math.Clamp(amount, 0, 1);
        byte Channel(byte a, byte b) => (byte)Math.Clamp((int)Math.Round(a + (b - a) * t), 0, 255);
        return Color.FromArgb(255, Channel(from.R, to.R), Channel(from.G, to.G), Channel(from.B, to.B));
    }

    public static SolidColorBrush Brush(Color color) => new(color);

    public static SolidColorBrush Brush(Color color, byte alpha) => new(Color.FromArgb(alpha, color.R, color.G, color.B));

    public static SolidColorBrush Brush(string hex, byte alpha = 255) => new(Hex(hex, alpha));

    public static Color On(Color color)
    {
        var luminance = 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B;
        return luminance > 160 ? Hex("141414") : Hex("FFFFFF");
    }

    public static readonly Color Black = Hex("000000");
    public static readonly Color White = Hex("FFFFFF");

    public static Button Flat(object content, double size = 0)
    {
        var button = new Button
        {
            Content = content,
            Padding = new Thickness(0),
            BorderThickness = new Thickness(0),
            Background = Brush(White, 0),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        if (size > 0)
        {
            button.Width = size;
            button.Height = size;
            button.CornerRadius = new CornerRadius(size / 2);
        }

        var clear = Brush(White, 0);
        var hover = Brush(White, 28);
        var pressed = Brush(White, 48);
        TryTheme(button, "ButtonBackground", clear);
        TryTheme(button, "ButtonBackgroundPointerOver", hover);
        TryTheme(button, "ButtonBackgroundPressed", pressed);
        TryTheme(button, "ButtonBackgroundDisabled", clear);
        TryTheme(button, "ButtonBorderBrush", clear);
        TryTheme(button, "ButtonBorderBrushPointerOver", clear);
        TryTheme(button, "ButtonBorderBrushPressed", clear);
        TryTheme(button, "ButtonBorderBrushDisabled", clear);
        TryTheme(button, "ButtonForeground", Brush(White));
        TryTheme(button, "ButtonForegroundPointerOver", Brush(White));
        TryTheme(button, "ButtonForegroundPressed", Brush(White));
        return button;
    }

    public static void FillButton(Button button, Brush fill, Brush foreground)
    {
        button.Background = fill;
        button.Foreground = foreground;
        TryTheme(button, "ButtonBackground", fill);
        TryTheme(button, "ButtonBackgroundPointerOver", fill);
        TryTheme(button, "ButtonBackgroundPressed", fill);
        TryTheme(button, "ButtonBackgroundDisabled", fill);
        TryTheme(button, "ButtonForeground", foreground);
        TryTheme(button, "ButtonForegroundPointerOver", foreground);
        TryTheme(button, "ButtonForegroundPressed", foreground);
        TryTheme(button, "ButtonForegroundDisabled", foreground);
        var clear = Brush(White, 0);
        TryTheme(button, "ButtonBorderBrush", clear);
        TryTheme(button, "ButtonBorderBrushPointerOver", clear);
        TryTheme(button, "ButtonBorderBrushPressed", clear);
        TryTheme(button, "ButtonBorderBrushDisabled", clear);
    }

    public static void TryTheme(FrameworkElement element, string key, Brush? brush)
    {
        if (element is null || string.IsNullOrWhiteSpace(key) || brush is null)
        {
            return;
        }

        try
        {
            var copy = CopyBrush(brush);
            var resources = element.Resources;
            if (resources.ContainsKey(key))
            {
                resources.Remove(key);
            }

            resources.Add(key, copy);
        }
        catch (Exception ex)
        {
            AppLog.Write(ex);
        }
    }

    static Brush CopyBrush(Brush brush)
    {
        if (brush is SolidColorBrush solid)
        {
            return new SolidColorBrush(solid.Color);
        }

        if (brush is LinearGradientBrush linear)
        {
            var copy = new LinearGradientBrush
            {
                StartPoint = linear.StartPoint,
                EndPoint = linear.EndPoint,
                MappingMode = linear.MappingMode,
                SpreadMethod = linear.SpreadMethod
            };
            foreach (var stop in linear.GradientStops)
            {
                copy.GradientStops.Add(new GradientStop { Color = stop.Color, Offset = stop.Offset });
            }

            return copy;
        }

        return brush;
    }

    public static async Task<BitmapImage?> PngAsync(byte[]? png)
    {
        if (png is null || png.Length == 0)
        {
            return null;
        }

        var stream = new InMemoryRandomAccessStream();
        var writer = new DataWriter(stream);
        writer.WriteBytes(png);
        await writer.StoreAsync();
        writer.DetachStream();
        stream.Seek(0);
        var image = new BitmapImage();
        await image.SetSourceAsync(stream);
        return image;
    }
}

static class Scenery
{
    public readonly record struct Wash(Color Edge, Color Mid, Color Glow);

    public static Wash For(ThemeRecord theme)
    {
        if (theme.Id == "lakeSuperior")
        {
            return new Wash(Paint.Hex("050B14"), Paint.Hex("0F2F52"), Paint.Hex("1F6FA3"));
        }

        var deep = Paint.Hex(theme.Colors.Deep);
        var primary = Paint.Hex(theme.Colors.Primary);
        return new Wash(Paint.Mix(deep, Paint.Black, 0.62), Paint.Mix(deep, primary, 0.28), primary);
    }
}
