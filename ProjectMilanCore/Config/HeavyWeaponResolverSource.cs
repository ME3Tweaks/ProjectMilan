using System.Text;

namespace ProjectMilanCore.Config;

public static class HeavyWeaponResolverSource
{
    /// <summary>
    /// Adds classes that are used to find what heavy weapon to load
    /// </summary>
    /// <param name="source"></param>
    /// <returns></returns>
    public static string Build(IEnumerable<HeavyWeaponCatalogEntry> source)
    {
        var entries = HeavyWeaponCatalogRegistration.ValidateAndOrder(source);
        var fallback = entries.Single(x => x.Id == 0);
        static string Quote(string value) => "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        var script = new StringBuilder("""
            public static final function class<SFXHeavyWeapon> ResolveClass(int Id)
            {
                local string ClassPath;
                local class<SFXHeavyWeapon> WeaponClass;
                switch (Id)
                {
            """);
        foreach (var entry in entries.OrderBy(x => x.Id))
        {
            script.AppendLine().AppendLine($"        case {entry.Id}:");
            if (entry.NoWeapon)
                script.AppendLine("            return None;");
            else
                script.AppendLine($"            ClassPath = {Quote(entry.ClassPath)};").AppendLine("            break;");
        }
        script.AppendLine($"        default: ClassPath = {Quote(fallback.ClassPath)};");
        script.AppendLine("""
                }
                WeaponClass = class<SFXHeavyWeapon>(DynamicLoadObject(ClassPath, Class'Class', TRUE));
                if (WeaponClass == None)
                {
                    return Class'SFXWeapon_Heavy_ConsumableRocketLauncher';
                }
                return WeaponClass;
            }
            """);
        return script.ToString();
    }
}
