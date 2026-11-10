using Microsoft.UI.Xaml.Shapes;

namespace Zalla;

static class ChromeIcons
{
    public static FrameworkElement Back() => Chevron(forward: false);

    public static FrameworkElement Forward() => Chevron(forward: true);

    public static FrameworkElement Reload()
    {
        var geometry = new PathGeometry();
        var arc = new PathFigure { StartPoint = new Point(12.2, 5.2), IsClosed = false };
        arc.Segments.Add(new ArcSegment
        {
            Point = new Point(8, 3.2),
            Size = new Size(5, 5),
            SweepDirection = SweepDirection.Clockwise,
            IsLargeArc = true
        });
        geometry.Figures.Add(arc);
        var head = new PathFigure { StartPoint = new Point(5.2, 3.2), IsClosed = true };
        head.Segments.Add(new LineSegment { Point = new Point(8.6, 1.1) });
        head.Segments.Add(new LineSegment { Point = new Point(8.6, 5.3) });
        geometry.Figures.Add(head);
        return Icon(Stroke(geometry));
    }

    public static FrameworkElement Stop()
    {
        var mark = new Border
        {
            Width = 8,
            Height = 8,
            CornerRadius = new CornerRadius(1),
            Background = Paint.Brush(Paint.White),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        return Icon(mark);
    }

    public static FrameworkElement Bookmark(bool filled)
    {
        var geometry = new PathGeometry();
        var figure = new PathFigure { StartPoint = new Point(4, 2), IsClosed = true };
        figure.Segments.Add(new LineSegment { Point = new Point(12, 2) });
        figure.Segments.Add(new LineSegment { Point = new Point(12, 14) });
        figure.Segments.Add(new LineSegment { Point = new Point(8, 11) });
        figure.Segments.Add(new LineSegment { Point = new Point(4, 14) });
        geometry.Figures.Add(figure);
        var path = new Microsoft.UI.Xaml.Shapes.Path
        {
            Data = geometry,
            Stroke = Paint.Brush(Paint.White),
            StrokeThickness = 1.4,
            StrokeLineJoin = PenLineJoin.Round,
            Fill = filled ? Paint.Brush(Paint.White) : Paint.Brush(Paint.White, 0)
        };
        return Icon(path);
    }

    public static FrameworkElement Shield()
    {
        var geometry = new PathGeometry();
        var figure = new PathFigure { StartPoint = new Point(8, 1.6), IsClosed = true };
        figure.Segments.Add(new LineSegment { Point = new Point(13.2, 3.6) });
        figure.Segments.Add(new LineSegment { Point = new Point(13.2, 8) });
        figure.Segments.Add(new BezierSegment
        {
            Point1 = new Point(13.2, 11),
            Point2 = new Point(10.6, 13),
            Point3 = new Point(8, 14.4)
        });
        figure.Segments.Add(new BezierSegment
        {
            Point1 = new Point(5.4, 13),
            Point2 = new Point(2.8, 11),
            Point3 = new Point(2.8, 8)
        });
        figure.Segments.Add(new LineSegment { Point = new Point(2.8, 3.6) });
        geometry.Figures.Add(figure);
        return Icon(Stroke(geometry));
    }

    public static FrameworkElement Menu()
    {
        var column = new StackPanel
        {
            Width = 16,
            Spacing = 2,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        for (var i = 0; i < 3; i++)
        {
            column.Children.Add(new Ellipse
            {
                Width = 3.2,
                Height = 3.2,
                Fill = Paint.Brush(Paint.White),
                HorizontalAlignment = HorizontalAlignment.Center
            });
        }

        return Icon(column);
    }

    public static FrameworkElement Plus()
    {
        var grid = new Grid { Width = 12, Height = 12 };
        grid.Children.Add(new Border
        {
            Width = 12,
            Height = 1.8,
            Background = Paint.Brush(Paint.White),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        });
        grid.Children.Add(new Border
        {
            Width = 1.8,
            Height = 12,
            Background = Paint.Brush(Paint.White),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        });
        return grid;
    }

    static FrameworkElement Chevron(bool forward)
    {
        var geometry = new PathGeometry();
        var figure = new PathFigure
        {
            StartPoint = forward ? new Point(6, 3) : new Point(10, 3),
            IsClosed = false
        };
        figure.Segments.Add(new LineSegment { Point = forward ? new Point(11, 8) : new Point(5, 8) });
        figure.Segments.Add(new LineSegment { Point = forward ? new Point(6, 13) : new Point(10, 13) });
        geometry.Figures.Add(figure);
        return Icon(Stroke(geometry));
    }

    static Microsoft.UI.Xaml.Shapes.Path Stroke(Geometry geometry) => new()
    {
        Data = geometry,
        Stroke = Paint.Brush(Paint.White),
        StrokeThickness = 1.7,
        StrokeStartLineCap = PenLineCap.Round,
        StrokeEndLineCap = PenLineCap.Round,
        StrokeLineJoin = PenLineJoin.Round
    };

    static Viewbox Icon(UIElement mark) => new()
    {
        Width = 16,
        Height = 16,
        HorizontalAlignment = HorizontalAlignment.Center,
        VerticalAlignment = VerticalAlignment.Center,
        Child = mark
    };
}
