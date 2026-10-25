using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.BioP_MPCer2;

/// <summary>
/// Glacier Hazard's bee swarm now can be triggered by anyone
/// </summary>
internal class MPCer2Specific : LevelSpecificFixesBase
{
    private const string HazardPackageName = "BioD_MPCer2_HAZ";

    // WT_Everyone: Stormtrooper aim punishment
    private const string SwarmDamageWhoTriggers = "WT_Everyone";
    
    // InterpActor subclass that powers can impact (see SFXPowerCustomAction.CanImpactActor's BaseDelta).
    // Built into MPCommon
    private const string PowerTargetClassName = "MilanPowerTargetInterpActor";
    private const string PowerTargetClassPath = $"SFXGameContent_Milan.{PowerTargetClassName}";

    // UDK can't resolve the Milan class, and the swarm is hidden so it doesn't take part in it anyway, so we just do this here
    public override void PostLightingCorrect(LevelSpecificPipeline pipeline)
    {
        using var package = MEPackageHandler.OpenMEPackage(Path.Combine(pipeline.LevelOutputDir, $"{HazardPackageName}.pcc"), diskIOSyncLock: MilanShared.DiskIOSyncLock);
        if (MakeSwarmAngerFromAllDamage(package, pipeline.LogCategory))
        {
            package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanShared.RefreshMilanFiles = true;
        }
    }

    /// <summary>
    /// Makes the swarm's damage event accept every instigator, and makes the swarm a power target so powers damage it
    /// </summary>
    /// <param name="package">BioD_MPCer2_HAZ, which has the swarm and its Kismet</param>
    /// <param name="logCategory"></param>
    internal static bool MakeSwarmAngerFromAllDamage(IMEPackage package, string logCategory)
    {
        var damageEvent = package.Exports.First(x => x.ClassName == "SeqEvent_TakeDamage");
        var swarm = damageEvent.GetProperty<ObjectProperty>("Originator")?.ResolveToEntry(package) as ExportEntry;

        // Change who triggers
        var components = swarm.GetChildren<ExportEntry>().ToList();
        damageEvent.WriteProperty(new EnumProperty(SwarmDamageWhoTriggers, "EWhoTriggers", package.Game, "WhoTriggers"));
        swarm.Class = MilanLevelTools.GetOrAddForcedExportClassImport(package, PowerTargetClassPath);
        foreach (var component in components)
        {
            // Change over archetype
            component.Archetype = MilanLevelTools.GetOrAddForcedExportComponentTemplateImport(package, PowerTargetClassPath, component.Archetype!.ObjectName.Instanced, component.ClassName);
        }

        MilanLog.Information($"Bees now punish stormtrooper aim", customPrefix: logCategory);
        return true;
    }
}
