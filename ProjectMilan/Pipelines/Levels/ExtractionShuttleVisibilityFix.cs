using LegendaryExplorerCore.Kismet;
using LegendaryExplorerCore.Matinee;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Hides the extraction shuttle until the Matinee that flies it in starts.
    /// This is relevant in a few maps, most notably MPHosp, where the shuttle is just straight up visible from the gameplay area
    /// </summary>
    internal static class ExtractionShuttleVisibilityFix
    {
        private const string ExtractionEventClass = "SFXSeqEvt_StartExtractionShuttle";
        private const string AttachmentGroupName = "ShuttleAttachments";

        public static void Apply(IMEPackage package, string logCategory)
        {
            var events = package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == ExtractionEventClass).ToList();
            if (events.Count == 0)
            {
                // Some levels don't have a shuttle
                return;
            }

            // Some maps have a few shuttles, we need to track them so we don't hide the same shuttle multiple times if multiple events lead to the same Matinee
            var handledShuttles = new HashSet<int>();
            foreach (var interp in GetReachableInterps(events))
            {
                foreach (var (group, shuttle) in GetShuttleGroups(interp))
                {
                    if (!handledShuttles.Add(shuttle.UIndex))
                        continue;
                    // Add matinee group and keys
                    HideUntilMatineeStarts(interp, group, shuttle, logCategory);
                }
            }
        }

        /// <summary>
        /// Find interp nodes that are reachable from the list of given event node exports
        /// </summary>
        private static List<ExportEntry> GetReachableInterps(List<ExportEntry> events)
        {
            var interps = new List<ExportEntry>();
            var visited = new HashSet<int>(events.Select(x => x.UIndex));
            var queue = new Queue<ExportEntry>(events);
            while (queue.Count > 0)
            {
                var node = queue.Dequeue();
                foreach (var link in KismetHelper.GetOutputLinksOfNode(node).SelectMany(x => x))
                {
                    if (link.LinkedOp is not ExportEntry next || !visited.Add(next.UIndex))
                        continue;
                    if (next.ClassName == "SeqAct_Interp")
                        interps.Add(next);
                    queue.Enqueue(next);
                }
            }
            return interps;
        }

        /// <summary>
        /// Get the groups of the interpdata that all move with the shuttle's skeletalmeshactor
        /// The actor is whatever the interp has linked to the variable link named after the group
        /// </summary>
        private static IEnumerable<(ExportEntry Group, ExportEntry Shuttle)> GetShuttleGroups(ExportEntry interp)
        {
            var package = interp.FileRef;
            var varLinks = KismetHelper.GetVariableLinksOfNode(interp);
            var interpData = varLinks.FirstOrDefault(x => x.LinkDesc == "Data")?.LinkedNodes.OfType<ExportEntry>().FirstOrDefault();
            var groups = interpData?.GetProperty<ArrayProperty<ObjectProperty>>("InterpGroups");
            if (groups == null)
                // Short circuit out
                yield break;

            // For every interp group...
            foreach (var group in groups.Select(x => x.ResolveToEntry(package)).OfType<ExportEntry>())
            {
                // Filter the type we care about
                if (group.ClassName != "InterpGroup" || GetTracks(group).All(x => !x.IsA("InterpTrackMove")))
                    continue;

                // Find shuttles and return them
                var groupName = group.GetProperty<NameProperty>("GroupName")?.Value.Name;
                var shuttles = varLinks.Where(x => x.LinkDesc == groupName)
                    .SelectMany(x => x.LinkedNodes.OfType<ExportEntry>())
                    .Select(x => x.GetProperty<ObjectProperty>("ObjValue")?.ResolveToEntry(package))
                    .OfType<ExportEntry>()
                    .Where(x => x.IsA("SkeletalMeshActor"));
                foreach (var shuttle in shuttles)
                    yield return (group, shuttle);
            }
        }

        /// <summary>
        /// Hides the shuttle and all its attachments until the matinee starts playing
        /// </summary>
        /// <param name="interp"></param>
        /// <param name="shuttleGroup"></param>
        /// <param name="shuttle"></param>
        /// <param name="logCategory"></param>
        private static void HideUntilMatineeStarts(ExportEntry interp, ExportEntry shuttleGroup, ExportEntry shuttle, string logCategory)
        {
            var package = interp.FileRef;
            // Already hidden or has a visiblity track; might already have been processed
            if (shuttle.GetProperty<BoolProperty>("bHidden")?.Value == true || GetTracks(shuttleGroup).Any(x => x.IsA("InterpTrackVisibility")))
                return;

            // Hide shuttle and all attachments
            var attachments = GetAttachments(shuttle);
            shuttle.WriteProperty(new BoolProperty(true, "bHidden"));
            foreach (var attachment in attachments)
                attachment.WriteProperty(new BoolProperty(true, "bHidden"));

            // Add key that unhides shuttle's group
            AddShowKey(shuttleGroup);

            if (attachments.Count > 0)
            {
                // Build the attachment group to unhide
                var interpData = KismetHelper.GetVariableLinksOfNode(interp).First(x => x.LinkDesc == "Data").LinkedNodes.OfType<ExportEntry>().First();
                var attachmentGroup = MatineeHelper.AddNewGroupToInterpData(interpData, AttachmentGroupName);
                AddShowKey(attachmentGroup);

                // The interp binds actors to a group through the variable link named after it
                var sequence = KismetHelper.GetParentSequence(interp)!;
                var attachmentVars = attachments.Select(x => SequenceObjectCreator.CreateObject(sequence, x)).ToList();
                AddGroupVariableLink(interp, shuttleGroup.GetProperty<NameProperty>("GroupName")!.Value.Name, AttachmentGroupName, attachmentVars);
            }

            MilanLog.Information($"  {package.FileNameNoExtension}: extraction shuttle {shuttle.InstancedFullPath} and {attachments.Count} attached actor(s) start hidden and are shown when {interp.ObjectName.Instanced} starts",
                customPrefix: logCategory);
        }

        /// <summary>
        /// Gets all attachments on the given shuttle actor
        /// </summary>
        private static List<ExportEntry> GetAttachments(ExportEntry shuttle)
        {
            var package = shuttle.FileRef;
            var level = package.FindExport("TheWorld.PersistentLevel");
            var basedOn = new Dictionary<int, List<ExportEntry>>();
            foreach (var actor in package.Exports.Where(x => !x.IsDefaultObject && x.Parent == level))
            {
                if (actor.GetProperty<ObjectProperty>("Base") is { Value: not 0 } baseProp)
                {
                    if (!basedOn.TryGetValue(baseProp.Value, out var list))
                        basedOn[baseProp.Value] = list = [];
                    list.Add(actor);
                }
            }

            var result = new List<ExportEntry>();
            var pending = new Queue<ExportEntry>([shuttle]);
            while (pending.Count > 0)
            {
                var current = pending.Dequeue();
                if (!basedOn.TryGetValue(current.UIndex, out var children))
                    continue;
                foreach (var child in children)
                {
                    pending.Enqueue(child);
                    if (!IsInactiveEmitter(child))
                        result.Add(child);
                }
            }
            return result;
        }

        /// <summary>
        /// Checks if an emitter is actually active or not
        /// </summary>
        /// <param name="actor"></param>
        /// <returns></returns>
        private static bool IsInactiveEmitter(ExportEntry actor)
        {
            if (!actor.IsA("Emitter"))
                return false;
            var component = actor.GetProperty<ObjectProperty>("ParticleSystemComponent")?.ResolveToEntry(actor.FileRef) as ExportEntry;
            return component?.GetProperty<BoolProperty>("bAutoActivate")?.Value == false;
        }

        private static void AddShowKey(ExportEntry group)
        {
            var game = group.Game;
            var track = MatineeHelper.AddNewTrackToGroup(group, "InterpTrackVisibility");
            // Add the visibility key on the first possible frame the matinee will begin playing
            track.WriteProperty(new ArrayProperty<StructProperty>(
            [
                new StructProperty("VisibilityTrackKey", false,
                    new FloatProperty(0f, "Time"),
                    new EnumProperty("EVTA_Show", "EVisibilityTrackAction", game, "Action"),
                    new EnumProperty("EVTC_Always", "EVisibilityTrackCondition", game, "ActiveCondition"),
                    new NoneProperty())
            ], "VisibilityTrack"));
        }

        /// <summary>
        /// Adds a variable link named for a new group, modeled on the link of the existing group
        /// </summary>
        private static void AddGroupVariableLink(ExportEntry interp, string templateLinkDesc, string linkDesc, List<ExportEntry> variables)
        {
            var linksProp = interp.GetProperty<ArrayProperty<StructProperty>>("VariableLinks")!;
            var link = linksProp.First(x => x.GetProp<StrProperty>("LinkDesc") == templateLinkDesc).DeepClone();
            link.GetProp<StrProperty>("LinkDesc")!.Value = linkDesc;
            var linked = link.GetProp<ArrayProperty<ObjectProperty>>("LinkedVariables")!;
            linked.Values.Clear();
            linked.Values.AddRange(variables.Select(x => new ObjectProperty(x)));
            linksProp.Add(link);
            interp.WriteProperty(linksProp);
        }

        /// <summary>
        /// Get interp tracks of a group
        /// </summary>
        /// <param name="group"></param>
        /// <returns></returns>
        private static List<ExportEntry> GetTracks(ExportEntry group) => group.GetProperty<ArrayProperty<ObjectProperty>>("InterpTracks")?.Select(x => x.ResolveToEntry(group.FileRef)).OfType<ExportEntry>().ToList() ?? [];
    }
}
