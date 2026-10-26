using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.UnrealScript;

namespace ProjectMilan.Pipelines.HeavyWeapons;

/// <summary>Builds cosmetic subclasses in the same package as their consumable weapons.</summary>
internal static class HiddenHeavyWeaponVariants
{
    internal const string Suffix = "_Hidden";

    internal static string GetClassPath(string classPath) => classPath + Suffix;

    internal static bool IsHiddenVariant(ExportEntry weaponClass)
    {
        var defaultsIndex = ObjectBinary.From<UClass>(weaponClass).Defaults;
        if (defaultsIndex <= 0)
        {
            return false;
        }
        var defaults = weaponClass.FileRef.GetUExport(defaultsIndex);
        return defaults.GetProperty<BoolProperty>("bHiddenVariant") is { Value: true };
    }

    internal static IReadOnlyDictionary<string, ExportEntry> Generate(IMEPackage package,
        IEnumerable<ExportEntry> weaponClasses, UnrealScriptOptionsPackage options)
    {
        // Compilation adds exports, so snapshot before walking the source classes.
        var originals = weaponClasses.Where(x => !IsHiddenVariant(x)).ToList();
        var variants = new Dictionary<string, ExportEntry>(StringComparer.OrdinalIgnoreCase);
        if (originals.Count == 0)
        {
            return variants;
        }

        using var library = new FileLib(package);
        if (!library.Initialize(options))
        {
            throw new InvalidOperationException($"Could not initialize {package.FileNameNoExtension} for hidden heavy weapons: {string.Join(Environment.NewLine, library.InitializationLog.AllErrors)}");
        }

        foreach (var original in originals)
        {
            var path = GetClassPath(original.InstancedFullPath);
            var variant = package.FindExport(path);
            if (variant == null)
            {
                // Make a stub class
                var source = $$"""
                    class {{original.ObjectName.Name}}{{Suffix}} extends {{original.ObjectName.Name}}
                        placeable
                        config(Weapon);

                    defaultproperties
                    {
                        bHiddenVariant = TRUE
                    }
                    """;
                var (_, log) = UnrealScriptCompiler.CompileClass(package, source, library, options, parent: original.Parent);
                if (log.HasErrors)
                {
                    throw new InvalidOperationException($"Could not compile {path}: {string.Join(Environment.NewLine, log.AllErrors)}");
                }
                variant = package.FindExport(path);
            }

            if (variant == null || !variant.IsClass || variant.SuperClass != original || !IsHiddenVariant(variant))
            {
                throw new InvalidOperationException($"{path} must be a hidden subclass of {original.InstancedFullPath}");
            }
            if (ObjectBinary.From<UClass>(variant).ClassFlags.HasFlag(UnrealFlags.EClassFlags.Abstract))
            {
                throw new InvalidOperationException($"{path} is abstract");
            }
            variant.AddToObjectReferencer();
            variants.Add(original.InstancedFullPath, variant);
        }

        return variants;
    }
}
