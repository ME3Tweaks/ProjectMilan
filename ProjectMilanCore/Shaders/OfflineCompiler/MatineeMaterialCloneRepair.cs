using LegendaryExplorerCore.Kismet;
using LegendaryExplorerCore.Matinee;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

public sealed record MaterialCloneBinding(string SourceIdentity, string CloneIdentity, string PackagePath);

/// <summary>Extends Matinee material bindings to the instances cloned during shader installation.</summary>
public static class MatineeMaterialCloneRepair
{
    // Yikes dude! 
    // Who else hates doing kismet edits in code?

    public static int Repair(IMEPackage package, Func<string, IReadOnlyList<ExportEntry>> findClones,
        PackageCache cache)
    {
        int added = 0;
        foreach (var interp in package.Exports.Where(e => e.ClassName == "SeqAct_Interp").ToArray())
        {
            var links = KismetHelper.GetVariableLinksOfNode(interp);
            var data = links.FirstOrDefault(l => l.LinkDesc == "Data")?.LinkedNodes.OfType<ExportEntry>().FirstOrDefault();
            if (data == null)
                continue;
            bool changed = false;
            foreach (var link in links)
            {
                // Check we have a matinee track we care about
                if (!MatineeHelper.TryGetInterpGroup(data, link.LinkDesc, out var group)
                    || !(MatineeHelper.TryGetInterpTrack(group, "InterpTrackFloatMaterialParam", out _)
                        || MatineeHelper.TryGetInterpTrack(group, "InterpTrackVectorMaterialParam", out _)))
                    continue;


                foreach (var variable in link.LinkedNodes.OfType<ExportEntry>().Where(v => v.ClassName == "SeqVar_Object").ToArray())
                {
                    var actor = KismetHelper.ResolveObjectVarValue(variable) as ExportEntry;
                    if (actor?.ClassName != "MaterialInstanceActor")
                    {
                        continue;
                    }
                    var target = actor.GetProperty<ObjectProperty>("MatInst")?.ResolveToEntry(package);
                    if (target == null)
                    {
                        continue;
                    }
                    string identity = target is ExportEntry export ? export.MemoryFullPath : target.InstancedFullPath;
                    foreach (var donor in findClones(identity).DistinctBy(e => e.MemoryFullPath))
                    {
                        var material = ImportMaterial(donor, package, cache);
                        if (link.LinkedNodes.Any(v => BoundMaterial(v) == material.UIndex))
                        {
                            continue;
                        }
                        var controller = package.Exports.FirstOrDefault(e => e.ClassName == "MaterialInstanceActor"
                            && e.idxLink == actor.idxLink && e.GetProperty<ObjectProperty>("MatInst")?.Value == material.UIndex);
                        if (controller == null)
                        {
                            controller = EntryCloner.CloneTree(actor);
                            controller.WriteProperty(new ObjectProperty(material, "MatInst"));
                            package.AddToLevelActorsIfNotThere(controller);
                        }
                        var sequence = KismetHelper.GetParentSequence(interp)
                            ?? throw new InvalidDataException($"{interp.InstancedFullPath} has no parent sequence.");
                        var cloneVar = KismetHelper.GetSequenceObjects(sequence).OfType<ExportEntry>()
                            .FirstOrDefault(e => e.ClassName == "SeqVar_Object" && KismetHelper.ResolveObjectVarValue(e) == controller);
                        if (cloneVar == null)
                        {
                            cloneVar = KismetHelper.CloneObject(variable, sequence, topLevel: false);
                            cloneVar.WriteProperty(new ObjectProperty(controller, "ObjValue"));
                        }
                        link.LinkedNodes.Add(cloneVar);
                        added++;
                        changed = true;
                    }
                }
            }
            if (!changed) continue;
            var props = interp.GetProperties();
            KismetHelper.WriteVariableLinksToProperties(links, props);
            // MaxVars must be raised separately when adding bindings.
            foreach (var (raw, link) in props.GetProp<ArrayProperty<StructProperty>>("VariableLinks")!.Zip(links))
                if (link.LinkedNodes.Count > (raw.GetProp<IntProperty>("MaxVars")?.Value ?? 255))
                    raw.Properties.AddOrReplaceProp(new IntProperty(link.LinkedNodes.Count, "MaxVars"));
            interp.WriteProperties(props);
        }
        return added;
    }

    private static int? BoundMaterial(IEntry? variable)
    {
        var actor = variable is ExportEntry export ? KismetHelper.ResolveObjectVarValue(export) as ExportEntry : null;
        return actor?.ClassName == "MaterialInstanceActor" ? actor.GetProperty<ObjectProperty>("MatInst")?.Value : null;
    }
    private static ExportEntry ImportMaterial(ExportEntry donor, IMEPackage package, PackageCache cache)
    {
        if (package.FindExport(donor.InstancedFullPath) is { } existing) return existing;
        int before = package.ExportCount;
        var issues = EntryExporter.ExportExportToPackage(donor, package, out var entry, cache,
            new RelinkerOptionsPackage { Cache = cache, ImportExportDependencies = true, CheckImportsWhenExportingToPackage = false });
        if (issues.Count > 0 || entry is not ExportEntry material)
            throw new InvalidDataException($"Cannot copy {donor.InstancedFullPath} to {package.FileNameNoExtension}: {string.Join("; ", issues)}");

        // New material dependencies need their already compiled shaders in this package too.
        var sources = package.Exports.Skip(before).Where(e => e.IsA("Material") || e.IsA("MaterialInstance"))
            .Select(e => donor.FileRef.FindExport(e.InstancedFullPath)).OfType<ExportEntry>().ToList();
        if (donor.FileRef.FindExport("SeekFreeShaderCache") is { } shaderCache)
        {
            var keys = new HashSet<StaticParameterSet>();
            foreach (var source in sources)
            {
                if (source.IsA("Material")) keys.Add((StaticParameterSet)ObjectBinary.From<Material>(source).SM3MaterialResource.ID);
                else if (source.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true)
                    keys.Add(ObjectBinary.From<MaterialInstance>(source).SM3StaticParameterSet);
            }
            ShaderCacheManipulator.AddShadersToFile(package, ShaderCacheManipulator.GetLocalShaders(keys, shaderCache));
        }
        return material;
    }
}
