namespace Zalla.Core;

public static class ResourceMap
{
    public static bool TryPut(IDictionary<string, object> map, string key, object? value)
    {
        if (map is null || string.IsNullOrWhiteSpace(key) || value is null)
        {
            return false;
        }

        foreach (var existing in map.Values)
        {
            if (ReferenceEquals(existing, value))
            {
                return false;
            }
        }

        map[key] = value;
        return true;
    }
}
