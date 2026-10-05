using LegendaryExplorerCore.Packages;

namespace LEDecooker;

public static class MaterialGraphValidation
{
    /// <summary>Malformed root expressions cannot resolve to another package or to a local graph node.</summary>
    public static void ThrowIfInvalid(IMEPackage package)
    {
        var invalid = package.Imports.Where(i => i.idxLink == 0
            && (i.ClassName.StartsWith("MaterialExpression", StringComparison.Ordinal)
                || i.ClassName.StartsWith("BioMaterialExpression", StringComparison.Ordinal))).ToArray();
        if (invalid.Length > 0)
            throw new InvalidDataException($"{package.FileNameNoExtension}: {invalid.Length} malformed root expression import(s): "
                + string.Join(", ", invalid.Take(5).Select(i => i.InstancedFullPath)));
        foreach (var group in package.Imports.Where(i => i.idxLink == 0 && i.ClassName != "Package")
                     .GroupBy(i => i.ClassName))
            DecookerLog.Warning($"{package.FileNameNoExtension}: unresolved root {group.Key} dependencies: "
                + string.Join(", ", group.Select(i => i.InstancedFullPath)));
    }
}
