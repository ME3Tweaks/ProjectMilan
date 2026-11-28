using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Pipelines.HeavyWeapons;

/// <summary>
/// Gives consumable flamethrowers a copy of the flame effect whose particles stop at walls
/// </summary>
internal static class HeavyWeaponFlameCollision
{
    private const string LOG_CATEGORY = "MILAN-HeavyWeapons";

    private const string FlamePath = "BioVFX_C_FlameThrower.Particles.Flame_Thrower_Player";
    private const string CollidingFlameName = "Flame_Thrower_Player_Collide";
    private const string DonorFile = "SFXPower_Incinerate.pcc";
    private const string DonorPath = "BioVFX_C_Blood.Particles.Gib_Fire.ParticleModuleCollision_6";

    /// <summary>
    /// Points the weapons' flame components at the colliding copy
    /// </summary>
    internal static void Apply(IMEPackage package, IReadOnlyCollection<ExportEntry> weaponClasses)
    {
        if (package.FindExport(FlamePath) is not { ClassName: "ParticleSystem" } flame)
        {
            return;
        }
        var components = GetFlameComponents(package, flame, weaponClasses);
        if (components.Count == 0)
        {
            return;
        }

        var colliding = package.FindExport($"{flame.Parent.InstancedFullPath}.{CollidingFlameName}") ?? CreateCollidingFlame(package, flame);
        foreach (var component in components)
        {
            component.WriteProperty(new ObjectProperty(colliding, "Template"));
            MilanLog.Information($"{package.FileNameNoExtension}: {component.InstancedFullPath} uses {colliding.InstancedFullPath}", customPrefix: LOG_CATEGORY);
        }
    }

    /// <summary>
    /// Gets the particle system components under the weapons' defaults (and their hidden variants) that draw the flame
    /// </summary>
    private static List<ExportEntry> GetFlameComponents(IMEPackage package, ExportEntry flame, IReadOnlyCollection<ExportEntry> weaponClasses)
    {
        var classes = weaponClasses.Concat(weaponClasses.Select(x => package.FindExport(HiddenHeavyWeaponVariants.GetClassPath(x.InstancedFullPath))).OfType<ExportEntry>()).DistinctBy(x => x.UIndex);
        var components = new List<ExportEntry>();
        foreach (var weaponClass in classes)
        {
            var defaults = weaponClass.GetDefaults();
            components.AddRange(package.Exports.Where(x => x.Parent == defaults && x.ClassName == "ParticleSystemComponent" && GetTemplate(x) == flame.UIndex));
        }
        return components;
    }

    /// <summary>
    /// Template set on the component or inherited from its archetypes
    /// </summary>
    private static int GetTemplate(ExportEntry component)
    {
        for (var current = component; current != null; current = current.Archetype as ExportEntry)
        {
            if (current.GetProperty<ObjectProperty>("Template") is { } template)
            {
                return template.Value;
            }
        }
        return 0;
    }

    private static ExportEntry CreateCollidingFlame(IMEPackage package, ExportEntry flame)
    {
        // Pull in an existing version that does what we want
        var colliding = EntryCloner.CloneTree(flame);
        colliding.ObjectName = new NameReference(CollidingFlameName);

        MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, DonorFile, out var donorFilePath);
        using var donorPackage = MEPackageHandler.OpenMEPackage(donorFilePath, forceLoadFromDisk: true);
        var donor = donorPackage.FindExport(DonorPath);

        ExportEntry portedModule = null;
        foreach (var emitter in colliding.GetProperty<ArrayProperty<ObjectProperty>>("Emitters").Select(x => x.ResolveToEntry(package)).OfType<ExportEntry>())
        {
            var lods = emitter.GetProperty<ArrayProperty<ObjectProperty>>("LODLevels")?.Select(x => x.ResolveToEntry(package)).OfType<ExportEntry>().ToList();
            if (lods == null || lods.Count == 0)
            {
                continue;
            }
            var lod0Modules = lods[0].GetProperty<ArrayProperty<ObjectProperty>>("Modules");
            var moduleClasses = lod0Modules.Select(x => package.GetEntry(x.Value)?.ClassName).ToList();

            if (!moduleClasses.Contains("ParticleModuleVelocity") || moduleClasses.Any(x => x != null && x.Contains("Collision")))
            {
                continue;
            }

            // Pull in donor
            ExportEntry module;
            if (portedModule == null)
            {
                var results = EntryExporter.ExportExportToPackage(donor, package, out var ported);
                if (results.Count > 0)
                {
                    throw new InvalidOperationException($"{package.FileNameNoExtension} porting {DonorPath} failed: {string.Join("\n", results.Select(x => x.Message))}");
                }
                portedModule = (ExportEntry)ported;
                module = portedModule;
            }
            else
            {
                module = EntryCloner.CloneEntry(portedModule);
            }
            ConfigureModule(module, lods.Count);

            // Add to every module
            foreach (var lod in lods)
            {
                var modules = lod.GetProperty<ArrayProperty<ObjectProperty>>("Modules");
                modules.Add(new ObjectProperty(module));
                lod.WriteProperty(modules);
            }
            MilanLog.Information($"{package.FileNameNoExtension}: added wall collision to {colliding.ObjectName.Instanced} emitter {emitter.GetProperty<NameProperty>("EmitterName")?.Value.Instanced}", customPrefix: LOG_CATEGORY);
        }

        if (portedModule == null)
        {
            throw new InvalidOperationException($"{FlamePath} has no moving emitters to add collision to");
        }
        return colliding;
    }

    /// <summary>
    /// Kill after the last bounce
    /// </summary>
    private static void ConfigureModule(ExportEntry module, int lodCount)
    {
        var properties = module.GetProperties();
        var completion = properties.GetProp<EnumProperty>("CollisionCompletionOption");
        completion.Value = new NameReference("EPCC_Kill");
        properties.AddOrReplaceProp(new BoolProperty(false, "bOnlyVerticalNormalsDecrementCount"));
        properties.AddOrReplaceProp(new ByteProperty((byte)((1 << lodCount) - 1), "LODValidity"));
        properties.RemoveNamedProperty("bEnabled");
        module.WriteProperties(properties);
    }
}
