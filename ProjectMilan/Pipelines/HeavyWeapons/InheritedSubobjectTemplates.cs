using System.Text;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.UnrealScript;

namespace ProjectMilan.Pipelines.HeavyWeapons;

/// <summary>
/// Gives a custom class templates from its parents
/// </summary>
internal static class InheritedSubobjectTemplates
{
    /// <summary>
    /// Adds a template for each of the superclass' default subobjects. Superclass must exist in the same package
    /// </summary>
    /// <returns>The names of the added templates</returns>
    internal static IReadOnlyList<string> Apply(ExportEntry classExport, FileLib library, UnrealScriptOptionsPackage options)
    {
        var package = classExport.FileRef;
        if (classExport.SuperClass is not ExportEntry superClass)
        {
            // Not supported - superclass must be in this package
            return [];
        }

        // Get defaults for comparison
        var defaults = package.GetUExport(ObjectBinary.From<UClass>(classExport).Defaults);
        var superDefaults = package.GetUExport(ObjectBinary.From<UClass>(superClass).Defaults);

        // See what's missing
        var ownNames = new HashSet<string>(package.Exports.Where(x => x.idxLink == defaults.UIndex).Select(x => x.ObjectName.Instanced), StringComparer.OrdinalIgnoreCase);
        var missing = package.Exports.Where(x => x.idxLink == superDefaults.UIndex && !ownNames.Contains(x.ObjectName.Instanced)).ToList();
        if (missing.Count == 0)
        {
            // Nothing to copy
            return [];
        }

        // Assign templates
        var missingNames = missing.ToDictionary(x => x.UIndex, x => x.ObjectName.Instanced);
        var ownProperties = defaults.GetProperties();
        var assignments = new List<string>();
        foreach (var property in superDefaults.GetProperties())
        {
            var references = property switch
            {
                ObjectProperty op => [op.Value],
                ArrayProperty<ObjectProperty> ap => ap.Select(x => x.Value).ToList(),
                _ => new List<int>(),
            };
            if (!references.Any(missingNames.ContainsKey))
            {
                ThrowOnNestedReference(property, missingNames, classExport);
                continue;
            }
            // Don't copy property from superclass, as we already have it
            if (ownProperties.ContainsNamedProp(property.Name))
            {
                continue;
            }

            // Object reference assignments are written differently
            if (property is ObjectProperty)
            {
                assignments.Add($"{property.Name} = {missingNames[references[0]]}");
                continue;
            }
            // Array with subobjects isn't supported for this code
            if (!references.All(x => missingNames.ContainsKey(x) || ownNames.Contains(package.GetEntry(x)?.ObjectName.Instanced ?? "")))
            {
                throw new InvalidOperationException($"{superDefaults.InstancedFullPath}.{property.Name} mixes subobjects with other objects");
            }
            assignments.Add($"{property.Name} = ({string.Join(", ", references.Select(x => package.GetEntry(x).ObjectName.Instanced))})");
        }

        // We find the last index of }, then append to it. Real hackjob, but it works
        var (_, source) = UnrealScriptCompiler.DecompileExport(defaults, library, options);
        var close = source.LastIndexOf('}');
        if (close < 0)
        {
            throw new InvalidOperationException($"Could not decompile {defaults.InstancedFullPath}");
        }

        // Add templates
        var added = new StringBuilder();
        foreach (var subobject in missing)
        {
            added.AppendLine($"    Begin Template Class={subobject.ClassName} Name={subobject.ObjectName.Instanced}");
            added.AppendLine("    End Template");
        }

        // Add object assignments
        foreach (var assignment in assignments)
        {
            added.AppendLine($"    {assignment}");
        }

        // Coalesce the script text to compile
        source = source[..close] + added + source[close..];

        var (_, log) = UnrealScriptCompiler.CompileDefaultProperties(defaults, source, library, options);
        if (log.HasErrors)
        {
            throw new InvalidOperationException($"Could not compile {defaults.InstancedFullPath}: {string.Join(Environment.NewLine, log.AllErrors)}");
        }
        return missing.Select(x => x.ObjectName.Instanced).ToList();
    }

    /// <summary>
    /// A reference inside a struct isn't reassigned, so fail rather than leave it on the superclass's copy
    /// </summary>
    private static void ThrowOnNestedReference(Property property, Dictionary<int, string> missingNames, ExportEntry classExport)
    {
        if (property is StructProperty or ArrayProperty<StructProperty> && ObjectReferences(property).Any(missingNames.ContainsKey))
        {
            throw new InvalidOperationException($"{classExport.InstancedFullPath} inherits {property.Name}, a struct referencing a superclass default subobject");
        }
    }

    private static IEnumerable<int> ObjectReferences(Property property) => property switch
    {
        ObjectProperty op => [op.Value],
        StructProperty sp => sp.Properties.SelectMany(ObjectReferences),
        ArrayProperty<ObjectProperty> ap => ap.Select(x => x.Value),
        ArrayProperty<StructProperty> ap => ap.SelectMany(ObjectReferences),
        _ => [],
    };
}
