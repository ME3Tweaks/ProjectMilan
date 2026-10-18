using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Lights the whole shuttle (hull, doors and door frames) from one DynamicLightEnvironment.
    /// <para/>
    /// BioWare's shuttles only give the door frames (InterpActors hard-attached to the hull) their own enabled light
    /// environment. The hull and the doors are SkeletalMeshActors with no light environment exported, so in LE they don't
    /// get one. The two halves are then lit differently: CompositeDynamic lights (the fill lights maps add for characters)
    /// only reach the frames, which is very visible on MPDish where the shuttle sits in deep shade at the spawn. In
    /// direct sunlight both are dominated by the same sun and the difference disappears.
    /// <para/>
    /// This gives each hull actor an enabled light environment and points every attached shuttle part at it, the same
    /// way weapons share their pawn's light environment.
    /// </summary>
    internal static class ExtractionShuttleLightEnvironmentFix
    {
        private const string HullMeshPath = "BioApl_Veh_AlliDropShip.AlliDropShip_MDL_Cine";
        private const string LightEnvironmentClass = "DynamicLightEnvironmentComponent";
        private const string LightEnvironmentName = "MyLightEnvironment";

        public static void Apply(IMEPackage package, string logCategory)
        {
            var level = package.FindExport("TheWorld.PersistentLevel");
            if (level == null)
                return;

            var actors = package.Exports.Where(x => !x.IsDefaultObject && x.Parent == level).ToList();
            var basedOn = new Dictionary<int, List<ExportEntry>>();
            foreach (var actor in actors)
            {
                if (actor.GetProperty<ObjectProperty>("Base") is { Value: not 0 } baseProp)
                {
                    if (!basedOn.TryGetValue(baseProp.Value, out var list))
                        basedOn[baseProp.Value] = list = [];
                    list.Add(actor);
                }
            }

            foreach (var hull in actors.Where(x => x.IsA("SkeletalMeshActor")))
            {
                var hullMesh = GetPrimitive(hull);
                if (hullMesh?.GetProperty<ObjectProperty>("SkeletalMesh")?.ResolveToEntry(package)?.InstancedFullPath != HullMeshPath)
                    continue;

                var lightEnvironment = GetOrCreateLightEnvironment(hull, hullMesh);
                int sharedParts = 0;
                foreach (var part in GetAttachedParts(hull, basedOn))
                {
                    var primitive = GetPrimitive(part);
                    if (primitive == null)
                        continue;

                    // The frames' own light environment would otherwise still tick and light nothing
                    if (part.GetProperty<ObjectProperty>("LightEnvironment")?.ResolveToEntry(package) is ExportEntry ownLightEnvironment
                        && ownLightEnvironment != lightEnvironment && ownLightEnvironment.Parent == part)
                    {
                        ownLightEnvironment.WriteProperty(new BoolProperty(false, "bEnabled"));
                    }

                    part.WriteProperty(new ObjectProperty(lightEnvironment, "LightEnvironment"));
                    primitive.WriteProperty(new ObjectProperty(lightEnvironment, "LightEnvironment"));
                    sharedParts++;
                }

                MilanLog.Information($"  {package.FileNameNoExtension}: shuttle {hull.InstancedFullPath} and {sharedParts} attached part(s) share light environment {lightEnvironment.ObjectName.Instanced}",
                    customPrefix: logCategory);
            }
        }

        /// <summary>
        /// Gets the hull's own enabled light environment, adding one if it has none
        /// </summary>
        private static ExportEntry GetOrCreateLightEnvironment(ExportEntry hull, ExportEntry hullMesh)
        {
            var package = hull.FileRef;
            if (hull.GetProperty<ObjectProperty>("LightEnvironment")?.ResolveToEntry(package) is ExportEntry { ClassName: LightEnvironmentClass } existing
                && existing.Parent == hull)
            {
                existing.WriteProperty(new BoolProperty(true, "bEnabled"));
                return existing;
            }

            var componentClass = package.GetEntryOrAddImport($"Engine.{LightEnvironmentClass}", "Class");
            package.GetEntryOrAddImport("Engine.Default__SkeletalMeshActor", "SkeletalMeshActor", "Engine");
            var componentArchetype = package.GetEntryOrAddImport($"Engine.Default__SkeletalMeshActor.{LightEnvironmentName}", LightEnvironmentClass, "Engine");
            var lightEnvironment = new ExportEntry(package, hull, package.GetNextIndexedName(LightEnvironmentName), new byte[8])
            {
                Class = componentClass,
                Archetype = componentArchetype
            };
            lightEnvironment.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            package.AddExport(lightEnvironment);
            lightEnvironment.WriteProperty(new BoolProperty(true, "bEnabled"));

            // The hull inherits its Components from the class default, which reference the template light environment
            var components = hull.GetProperty<ArrayProperty<ObjectProperty>>("Components") ?? new ArrayProperty<ObjectProperty>([new ObjectProperty(hullMesh)], "Components");
            if (components.All(x => x.Value != lightEnvironment.UIndex))
                components.Insert(0, new ObjectProperty(lightEnvironment));
            hull.WriteProperty(components);
            hull.WriteProperty(new ObjectProperty(lightEnvironment, "LightEnvironment"));
            hullMesh.WriteProperty(new ObjectProperty(lightEnvironment, "LightEnvironment"));
            return lightEnvironment;
        }

        /// <summary>
        /// Gets the doors and door frames based on the hull, at any depth. Emitters and other actors without a mesh
        /// component are left alone.
        /// </summary>
        private static List<ExportEntry> GetAttachedParts(ExportEntry hull, Dictionary<int, List<ExportEntry>> basedOn)
        {
            var result = new List<ExportEntry>();
            var pending = new Queue<ExportEntry>([hull]);
            while (pending.Count > 0)
            {
                var current = pending.Dequeue();
                if (!basedOn.TryGetValue(current.UIndex, out var children))
                    continue;
                foreach (var child in children)
                {
                    pending.Enqueue(child);
                    if (child.IsA("SkeletalMeshActor") || child.IsA("DynamicSMActor"))
                        result.Add(child);
                }
            }
            return result;
        }

        private static ExportEntry? GetPrimitive(ExportEntry actor) =>
            (actor.GetProperty<ObjectProperty>("SkeletalMeshComponent") ?? actor.GetProperty<ObjectProperty>("StaticMeshComponent"))
            ?.ResolveToEntry(actor.FileRef) as ExportEntry;
    }
}
