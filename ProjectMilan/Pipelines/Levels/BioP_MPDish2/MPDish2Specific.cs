using System.Drawing;
using System.Numerics;
using System.Security.Cryptography;
using System.Text;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Pipelines.Levels.BioP_MPDish2;

internal class MPDish2Specific : LevelSpecificFixesBase
{
    // Dish2's sandstorm lamp light cones are unlit meshes with no corresponding spotlights in ME3.
    // Add static lights before porting so the fixtures illuminate both the game and the UDK bake.
    private const int ExpectedLampCount = 19;
    private const string HeadMeshPath = "BioG_LevelDetails.LightFlood_Top_01";
    private const string ConeMeshPath1 = "BioT_MPDish2.Light_Volumes_01";
    private const string ConeMeshPath2 = "BioT_MPDish2.Light_Volumes_02";

    // Centers of the first/last 20-vertex rings in the original cone meshes, in mesh-local space.
    // Their axes are already angled in the geometry; copying actor Rotation would aim horizontally.
    // These are taken from how they look in MPMoon.
    private static readonly Vector3 ConeStart1 = new(-13.24878f, 15.045705f, -10.53903f);
    private static readonly Vector3 ConeEnd1 = new(-633.614675f, 36.751955f, -657.21093f);
    private static readonly Vector3 ConeStart2 = new(-11.748095f, 18.35111f, -11.867665f);
    private static readonly Vector3 ConeEnd2 = new(-615.899225f, 21.67406f, -674.71179f);

    public override void PreCorrect(LevelSpecificPipeline pipeline)
    {
        var lamps = RequirePackage(pipeline, "BioA_MPDish2_300");
        var background = RequirePackage(pipeline, "BioA_MPDish2_000_BG");
        var heads = FindMeshComponents(lamps, HeadMeshPath).ToArray();
        var cones = FindMeshComponents(background, ConeMeshPath1, ConeMeshPath2)
            .OrderBy(x => x.InstancedFullPath, StringComparer.Ordinal).ToArray();
        if (heads.Length != ExpectedLampCount || cones.Length != ExpectedLampCount)
            throw new InvalidOperationException($"Dish2 floodlights: expected {ExpectedLampCount} heads/cones, found {heads.Length}/{cones.Length}.");

        // Check the complete association before changing the package. The distant BG fixtures are
        // deliberately excluded: the 19 visible cones each match one head in the playable _300 level.
        var placements = new List<(ExportEntry Head, Vector3 Position, Vector3 Direction)>();
        var matchedHeads = new HashSet<int>();
        var headTransforms = heads.ToDictionary(x => x, GetMeshWorldTransform);
        foreach (var cone in cones)
        {
            var coneTransform = GetMeshWorldTransform(cone);
            var head = heads.MinBy(x => Vector2.DistanceSquared(
                new Vector2(headTransforms[x].M41, headTransforms[x].M42),
                new Vector2(coneTransform.M41, coneTransform.M42)))!;
            var headTransform = headTransforms[head];
            if (Vector2.DistanceSquared(new Vector2(headTransform.M41, headTransform.M42),
                    new Vector2(coneTransform.M41, coneTransform.M42)) > 100f * 100f
                || !matchedHeads.Add(head.UIndex))
                throw new InvalidOperationException($"Dish2 floodlights: cannot uniquely match {cone.InstancedFullPath} to a nearby lamp head.");

            bool secondMesh = string.Equals(GetMeshPath(cone), ConeMeshPath2, StringComparison.OrdinalIgnoreCase);
            var start = Vector3.Transform(secondMesh ? ConeStart2 : ConeStart1, coneTransform);
            var end = Vector3.Transform(secondMesh ? ConeEnd2 : ConeEnd1, coneTransform);
            float lengthSquared = Vector3.DistanceSquared(start, end);
            if (!float.IsFinite(start.X) || !float.IsFinite(start.Y) || !float.IsFinite(start.Z)
                || !float.IsFinite(lengthSquared) || lengthSquared < 1f)
                throw new InvalidOperationException($"Dish2 floodlights: {cone.InstancedFullPath} has an invalid cone transform.");
            placements.Add((head, start, Vector3.Normalize(end - start)));
        }

        var level = lamps.GetLevel();
        var levelBinary = lamps.GetLevelBinary();
        var lightClass = lamps.GetEntryOrAddImport("Engine.SpotLight", "Class");
        var componentClass = lamps.GetEntryOrAddImport("Engine.SpotLightComponent", "Class");
        var lightArchetype = lamps.GetEntryOrAddImport("Engine.Default__SpotLight", "SpotLight", "Engine");
        var componentArchetype = lamps.GetEntryOrAddImport("Engine.Default__SpotLight.SpotLightComponent0", "SpotLightComponent", "Engine");
        int added = 0;
        foreach (var (head, position, direction) in placements)
        {
            // Use the source path, not a package-local UIndex, for stable names and bake GUIDs.
            string identity = $"BioA_MPDish2_300:{head.InstancedFullPath}";
            string name = $"MilanDish2FloodLight_{Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identity)))[..16]}";
            if (lamps.FindExport($"{level.InstancedFullPath}.{name}") != null)
                continue;

            var actor = new ExportEntry(lamps, level, name, EntryImporter.CreateStack(lamps.Game, lightClass.UIndex))
            {
                Class = lightClass,
                Archetype = lightArchetype
            };
            actor.ObjectFlags |= UnrealFlags.EObjectFlags.HasStack;
            lamps.AddExport(actor);
            var component = new ExportEntry(lamps, actor, "SpotLightComponent0", new byte[8])
            {
                Class = componentClass,
                Archetype = componentArchetype
            };
            lamps.AddExport(component);
            actor.WriteProperties(new PropertyCollection
            {
                new ObjectProperty(component, "LightComponent"),
                new NameProperty("MilanDish2FloodLight", "Tag"),
                CommonStructs.Vector3Prop(position, "Location"),
                CommonStructs.RotatorProp(Rotator.FromDirectionVector(direction), "Rotation")
            });
            component.WriteProperties(new PropertyCollection
            {
                // Condor's beam-adjacent lights supply the initial cone/source/bounce profile.
                new FloatProperty(20f, "InnerConeAngle"),
                new FloatProperty(40f, "OuterConeAngle"),
                new FloatProperty(1024f, "Radius"),
                new FloatProperty(2f, "FalloffExponent"),
                new FloatProperty(1f, "Brightness"),
                // Warm tint from Dish2's cone materials, encoded from linear RGB to gamma 2.2 bytes.
                CommonStructs.ColorProp(Color.FromArgb(255, 243, 211, 114), "LightColor"),
                new StructProperty("LightmassPointLightSettings", new PropertyCollection
                {
                    new FloatProperty(8f, "LightSourceRadius"),
                    new FloatProperty(0.3f, "IndirectLightingScale")
                }, "LightmassSettings"),
                new StructProperty("LightingChannelContainer", new PropertyCollection
                {
                    new BoolProperty(true, "bInitialized"),
                    new BoolProperty(true, "BSP"),
                    new BoolProperty(true, "Static"),
                    new BoolProperty(true, "Dynamic"),
                    new BoolProperty(true, "CompositeDynamic")
                }, "LightingChannels"),
                new BoolProperty(true, "bEnabled"),
                new BoolProperty(true, "UseDirectLightMap"),
                new BoolProperty(true, "CastShadows"),
                new BoolProperty(true, "CastStaticShadows"),
                new BoolProperty(true, "CastDynamicShadows"),
                // Characters use composite light environments; include these lamps in their shadows.
                new BoolProperty(true, "bCastCompositeShadow"),
                new BoolProperty(true, "bAffectCompositeShadowDirection"),
                new BoolProperty(false, "bHasLightEverBeenBuiltIntoLightMap"),
                CommonStructs.GuidProp(StableGuid(identity + ":light"), "LightGuid"),
                CommonStructs.GuidProp(StableGuid(identity + ":lightmap"), "LightmapGuid")
            });
            component.WriteBinary(LightComponent.Create());
            levelBinary.Actors.Add(actor.UIndex);
            added++;
        }
        level.WriteBinary(levelBinary);
        MilanLog.Information($"Dish2: added {added} static floodlights to {lamps.FileNameNoExtension} ({ExpectedLampCount} matched sandstorm cones).", customPrefix: pipeline.LogCategory);
    }

    private static IMEPackage RequirePackage(LevelSpecificPipeline pipeline, string name) =>
        pipeline.ME3Packages.Values.FirstOrDefault(x => x.FileNameNoExtension.Equals(name, StringComparison.OrdinalIgnoreCase))
        ?? throw new InvalidOperationException($"Dish2 floodlights: required sublevel {name} is not loaded.");

    private static IEnumerable<ExportEntry> FindMeshComponents(IMEPackage package, params string[] meshPaths) =>
        package.Exports.Where(x => x.ClassName == "StaticMeshComponent"
            && x.InstancedFullPath.StartsWith("TheWorld.PersistentLevel.", StringComparison.Ordinal)
            && meshPaths.Contains(GetMeshPath(x), StringComparer.OrdinalIgnoreCase));

    private static string? GetMeshPath(ExportEntry component) =>
        component.GetProperty<ObjectProperty>("StaticMesh")?.ResolveToEntry(component.FileRef)?.InstancedFullPath;

    // Also used by MPRctr2Specific to place the reactor button hitboxes
    internal static Matrix4x4 GetMeshWorldTransform(ExportEntry component)
    {
        Matrix4x4 parentTransform;
        if (StaticCollectionActor.TryGetStaticCollectionActorAndIndex(component, out var collection, out int index))
            parentTransform = collection.LocalToWorldTransforms[index];
        else if (component.Parent is ExportEntry actor)
            parentTransform = ActorUtils.GetLocalToWorld(actor);
        else
            throw new InvalidOperationException($"{component.InstancedFullPath} has no actor transform.");

        // Component transforms remain separate from collection matrices. One cone has Scale3D.X=-1;
        // retain that mirror so its light points along the visible beam rather than the opposite way.
        var rotation = component.GetProperty<StructProperty>("Rotation");
        return ActorUtils.ComposeLocalToWorld(
            CommonStructs.GetVector3(component, "Translation", Vector3.Zero),
            rotation == null ? new Rotator(0, 0, 0) : CommonStructs.GetRotator(rotation),
            CommonStructs.GetVector3(component, "Scale3D", Vector3.One) * (component.GetProperty<FloatProperty>("Scale")?.Value ?? 1f))
            * parentTransform;
    }

    private static Guid StableGuid(string identity) => new(SHA256.HashData(Encoding.UTF8.GetBytes(identity)).AsSpan(0, 16));
}
