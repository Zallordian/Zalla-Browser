using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Shapes;

namespace Zalla;

static class CaptionButtons
{
    public static Button Create(CaptionKind kind, Action action)
    {
        var plate = new Grid
        {
            Width = 16,
            Height = 16,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        plate.Children.Add(Mark(kind));
        var close = kind == CaptionKind.Close;
        var button = new Button
        {
            Content = plate,
            Width = 46,
            Height = 40,
            Padding = new Thickness(0),
            Margin = new Thickness(0),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(6),
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Top
        };
        var rest = Paint.Brush(close ? "8E2430" : "101820", close ? (byte)235 : (byte)210);
        var hover = Paint.Brush(close ? "C42B1C" : "243044", 245);
        var pressed = Paint.Brush(close ? "8E1C12" : "0A1018", 255);
        var edge = Paint.Brush(Paint.White, close ? (byte)90 : (byte)70);
        var ink = Paint.Brush(Paint.White);
        button.Background = rest;
        button.Foreground = ink;
        button.BorderBrush = edge;
        Paint.TryTheme(button, "ButtonBackground", rest);
        Paint.TryTheme(button, "ButtonBackgroundPointerOver", hover);
        Paint.TryTheme(button, "ButtonBackgroundPressed", pressed);
        Paint.TryTheme(button, "ButtonBackgroundDisabled", rest);
        Paint.TryTheme(button, "ButtonBackgroundFocused", rest);
        Paint.TryTheme(button, "ButtonForeground", ink);
        Paint.TryTheme(button, "ButtonForegroundPointerOver", ink);
        Paint.TryTheme(button, "ButtonForegroundPressed", ink);
        Paint.TryTheme(button, "ButtonBorderBrush", edge);
        Paint.TryTheme(button, "ButtonBorderBrushPointerOver", Paint.Brush(Paint.White, 160));
        Paint.TryTheme(button, "ButtonBorderBrushPressed", edge);
        Paint.TryTheme(button, "ButtonBorderBrushDisabled", edge);
        Paint.TryTheme(button, "ButtonBorderBrushFocused", Paint.Brush(Paint.White, 220));
        var name = CaptionMark.AccessibleName(kind);
        button.Click += (_, _) => action();
        AutomationProperties.SetName(button, name);
        ToolTipService.SetToolTip(button, name);
        return button;
    }

    public static void Show(Button button, CaptionKind kind, string name)
    {
        if (button.Content is Grid plate)
        {
            plate.Children.Clear();
            plate.Children.Add(Mark(kind));
        }

        AutomationProperties.SetName(button, name);
        ToolTipService.SetToolTip(button, name);
    }

    static FrameworkElement Mark(CaptionKind kind)
    {
        var ink = Paint.Brush(Paint.White);
        return kind switch
        {
            CaptionKind.Minimize => new Border
            {
                Width = 12,
                Height = 2,
                Background = ink,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 5, 0, 0)
            },
            CaptionKind.Maximize => Square(ink, 12),
            CaptionKind.Restore => Restore(ink),
            _ => Cross(ink)
        };
    }

    static Border Square(Brush ink, double size) => new()
    {
        Width = size,
        Height = size,
        BorderBrush = ink,
        BorderThickness = new Thickness(1.6),
        Background = Paint.Brush(Paint.White, 0),
        HorizontalAlignment = HorizontalAlignment.Center,
        VerticalAlignment = VerticalAlignment.Center
    };

    static Grid Restore(Brush ink)
    {
        var grid = new Grid { Width = 14, Height = 14 };
        var back = Square(ink, 9);
        back.HorizontalAlignment = HorizontalAlignment.Right;
        back.VerticalAlignment = VerticalAlignment.Top;
        var front = Square(ink, 9);
        front.HorizontalAlignment = HorizontalAlignment.Left;
        front.VerticalAlignment = VerticalAlignment.Bottom;
        front.Background = Paint.Brush("101820");
        grid.Children.Add(back);
        grid.Children.Add(front);
        return grid;
    }

    static Microsoft.UI.Xaml.Shapes.Path Cross(Brush ink)
    {
        var geometry = new PathGeometry();
        geometry.Figures.Add(Line(new Point(2, 2), new Point(12, 12)));
        geometry.Figures.Add(Line(new Point(12, 2), new Point(2, 12)));
        return new Microsoft.UI.Xaml.Shapes.Path
        {
            Data = geometry,
            Stroke = ink,
            StrokeThickness = 1.8,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
            Width = 14,
            Height = 14,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
    }

    static PathFigure Line(Point start, Point end)
    {
        var figure = new PathFigure { StartPoint = start, IsClosed = false };
        figure.Segments.Add(new LineSegment { Point = end });
        return figure;
    }
}
