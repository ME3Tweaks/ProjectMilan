using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Diagnostics;

namespace ProjectMilan.Pipelines.HeavyWeapons;

/// <summary>
/// Makes heavy weapon meshes cloak with the owning pawn
/// </summary>
internal static class HeavyWeaponCloakMaterials
{
    private const string LOG_CATEGORY = "MILAN-HeavyWeapons";

    private static readonly NameReference StealthTag = new NameReference("Stealth", 3);

    /// <summary>
    /// File we pull the material donor from
    /// </summary>
    private const string DonorFile = "SFXWeapon_Heavy_Cain.pcc";
    private const string DonorPath = "EffectsMaterials.Users.WPN_ALL_MASTER_MAT_1a_USER.CombinedEffect_Stealth_2";

    /// <summary>
    /// Donor parameter map for textures
    /// </summary>
    private static readonly (string StealthParameter, string[] SourceParameters)[] TextureParameters =
    [
        ("WPN_ALL_Diff_Stack", ["Diffuse_Map", "Diffuse"]),
        ("WPN_ALL_Spec_Stack", ["Specular_Map", "Specular"]),
        ("WPN_ALL_Norm_Stack", ["Normal_Map", "Normal"]),
    ];

    /// <summary>
    /// Adds a Stealth_2 entry to every effects user under the package's skeletal mesh materials that lacks one
    /// </summary>
    internal static void Apply(IMEPackage package)
    {
        var instances = GetSkeletalMeshMaterialInstances(package);
        var users = instances
            .Select(x => x.GetProperty<ObjectProperty>("Parent")?.ResolveToEntry(package))
            .OfType<ExportEntry>()
            .Where(x => x.ClassName == "RvrEffectsMaterialUser")
            .DistinctBy(x => x.UIndex)
            .ToList();

        IMEPackage? donorPackage = null;
        try
        {
            foreach (var user in users)
            {
                var multiplexor = user.GetProperty<ObjectProperty>("m_pMultiplexor")?.ResolveToEntry(package) as ExportEntry;
                var parents = multiplexor.GetProperty<ArrayProperty<StructProperty>>("m_lstParents");
                if (parents == null || parents.Count == 0)
                {
                    throw new InvalidOperationException($"{package.FileNameNoExtension}: multiplexor {multiplexor.InstancedFullPath} has no entries");
                }
                if (parents.Any(x => x.GetProp<NameProperty>("m_nmTag") is NameProperty tag && tag.Value == StealthTag))
                {
                    continue;
                }

                if (donorPackage == null)
                {
                    MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, DonorFile, out var donorFilePath);
                    donorPackage = MEPackageHandler.OpenMEPackage(donorFilePath, forceLoadFromDisk: true);
                }
                var stealthMaterial = PortStealthMaterial(donorPackage, package, user);

                var entry = parents[0].DeepClone();
                entry.Properties.AddOrReplaceProp(new ObjectProperty(stealthMaterial.UIndex, "m_pMaterial"));
                entry.Properties.AddOrReplaceProp(new NameProperty(StealthTag, "m_nmTag"));
                parents.Add(entry);
                multiplexor.WriteProperty(parents);

                foreach (var instance in instances.Where(x => x.GetProperty<ObjectProperty>("Parent")?.Value == user.UIndex))
                {
                    AddStealthTextureParameters(instance);
                }
                MilanLog.Information($"{package.FileNameNoExtension}: added stealth parameter to {user.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            }
        }
        finally
        {
            donorPackage?.Dispose();
        }
    }

    /// <summary>
    /// Gets all material instance constants that the package's skeletal meshes use
    /// </summary>
    private static List<ExportEntry> GetSkeletalMeshMaterialInstances(IMEPackage package)
    {
        var instances = new Dictionary<int, ExportEntry>();
        foreach (var mesh in package.Exports.Where(x => x.ClassName == "SkeletalMesh"))
        {
            foreach (var materialIndex in ObjectBinary.From<SkeletalMesh>(mesh).Materials)
            {
                if (package.GetEntry(materialIndex) is ExportEntry { ClassName: "MaterialInstanceConstant" } instance)
                {
                    instances.TryAdd(instance.UIndex, instance);
                }
            }
        }
        return instances.Values.ToList();
    }

    private static ExportEntry PortStealthMaterial(IMEPackage donorPackage, IMEPackage package, ExportEntry user)
    {
        if (package.FindExport($"{user.InstancedFullPath}.CombinedEffect_Stealth_2") is ExportEntry existing)
        {
            return existing;
        }
        var donor = donorPackage.FindExport(DonorPath);
        var results = EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, donor, package, user, true, new RelinkerOptionsPackage(), out var ported);
        if (results.Count > 0)
        {
            throw new InvalidOperationException($"{package.FileNameNoExtension} porting {DonorPath} failed: {string.Join("\n", results.Select(x => x.Message))}");
        }
        return (ExportEntry)ported;
    }

    /// <summary>
    /// Adds the stealth texture parameters to the given instance
    /// </summary>
    /// <param name="instance"></param>
    private static void AddStealthTextureParameters(ExportEntry instance)
    {
        var parameters = instance.GetProperty<ArrayProperty<StructProperty>>("TextureParameterValues") ?? new ArrayProperty<StructProperty>("TextureParameterValues");
        foreach (var (stealthParameter, sourceParameters) in TextureParameters)
        {
            if (parameters.Any(x => ParameterName(x) == stealthParameter))
            {
                continue;
            }
            var source = sourceParameters
                .Select(name => parameters.FirstOrDefault(x => ParameterName(x) == name))
                .FirstOrDefault(x => x != null);
            if (source == null)
            {
                Debugger.Break();
            }

            // Add new stealth parameters
            var copy = source.DeepClone();
            copy.Properties.AddOrReplaceProp(new NameProperty(stealthParameter, "ParameterName"));
            copy.Properties.AddOrReplaceProp(CommonStructs.GuidProp(Guid.Empty, "ExpressionGUID"));
            parameters.Add(copy);
        }
        instance.WriteProperty(parameters);
    }

    private static string? ParameterName(StructProperty parameter) => parameter.GetProp<NameProperty>("ParameterName")?.Value.Instanced;
}
