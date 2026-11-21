namespace Zalla;

sealed class WrapPanel : Panel
{
    protected override Size MeasureOverride(Size available)
    {
        var limit = double.IsInfinity(available.Width) ? 640 : available.Width;
        double x = 0, y = 0, row = 0, width = 0;
        foreach (var child in Children)
        {
            child.Measure(new Size(limit, double.PositiveInfinity));
            var desired = child.DesiredSize;
            if (x > 0 && x + desired.Width > limit)
            {
                x = 0;
                y += row;
                row = 0;
            }

            x += desired.Width;
            row = Math.Max(row, desired.Height);
            width = Math.Max(width, x);
        }

        return new Size(width, y + row);
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        double x = 0, y = 0, row = 0;
        foreach (var child in Children)
        {
            var desired = child.DesiredSize;
            if (x > 0 && x + desired.Width > finalSize.Width)
            {
                x = 0;
                y += row;
                row = 0;
            }

            child.Arrange(new Rect(x, y, desired.Width, desired.Height));
            x += desired.Width;
            row = Math.Max(row, desired.Height);
        }

        return finalSize;
    }
}
