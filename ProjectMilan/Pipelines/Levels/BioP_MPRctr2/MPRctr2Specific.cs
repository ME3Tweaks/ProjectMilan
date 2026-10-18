using System.Numerics;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilan.Pipelines.Levels.BioP_MPRctr2;

/// <summary>
/// Rctr2's doors need fixed when exporting to UDK for light baking because they by default are in the up position which can't get light in the wall
/// </summary>
internal class MPRctr2Specific : LevelSpecificFixesBase
{
    // Position to place SMC's for the doors so they get light. These are the end positions of them if the interp was in the door closed position.
    private static readonly (string ComponentPath, float ClosedZ)[] DoorBakePositions =
    [
        ("TheWorld.PersistentLevel.InterpActor_12.StaticMeshComponent_6", -33f),
        ("TheWorld.PersistentLevel.InterpActor_13.StaticMeshComponent_6", -295f),
        ("TheWorld.PersistentLevel.InterpActor_14.StaticMeshComponent_6", -295f)
    ];

    public override void CorrectUDKExport(LevelSpecificPipeline pipeline, IMEPackage udk)
    {
        // Only apply to BioD_MPRctr2
        if (!udk.FileNameNoExtension.Equals("BioD_MPRctr2", StringComparison.OrdinalIgnoreCase))
            return;


        var placedActors = udk.GetLevelBinary().Actors.ToHashSet();
        var doorSMCs = udk.Exports.Where(actor => actor.ClassName == "StaticMeshActor" && placedActors.Contains(actor.UIndex)).ToArray();
        var corrections = new List<(ExportEntry Actor, Vector3 Position)>();

        foreach (var (path, closedZ) in DoorBakePositions)
        {
            // Tag.Name is the original component path
            var door = doorSMCs.FirstOrDefault(actor => actor.GetProperty<NameProperty>("Tag")?.Value.Name == path);
            if (door == null)
                throw new InvalidOperationException($"Reactor door bake: couldn't resolve the door!");
            var location = door.GetProperty<StructProperty>("Location");
            var position = CommonStructs.GetVector3(location);
            // Correct the Z position to the closed position so it gets light baked onto the visible parts
            position.Z = closedZ;
            corrections.Add((door, position));
        }

        foreach (var (actor, position) in corrections)
        {
            actor.WriteProperty(CommonStructs.Vector3Prop(position, "Location"));
            MilanLog.Information($"Corrected Reactor blast door for UDK export", customPrefix: pipeline.LogCategory);
        }
    }
}
