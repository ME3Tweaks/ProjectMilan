using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using System.Diagnostics;
using LegendaryExplorerCore.Gammtek.Extensions;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Rejects
{
    internal static class RejectsShared
    {
        // Spawnable -> Archetyped onto Appr
        // Appr -> Archetyped onto SFXPawn defaults
        // Defaults -> Archetyped onto superclass defaults (we do not need to edit this)

        /// <summary>
        /// Changes the archetypes to a new class
        /// </summary>
        /// <param name="spawnableArchetype">Archetype object</param>
        /// <param name="pawnClass">The class to rearchetype objects onto</param>
        public static void ChangeoverArchetype(ExportEntry spawnableArchetype, ExportEntry pawnClass)
        {
            // Move the appearance archetype to our BioG and set the class
            if (spawnableArchetype.Archetype is ExportEntry apprArchetype)
            {
                apprArchetype.Class = pawnClass;
                var appr = ExportCreator.CreatePackageExport(spawnableArchetype.FileRef, MilanPackages.BIOG_Milan_Appearances);
                apprArchetype.idxLink = appr.UIndex; // Move under new object
                apprArchetype.ObjectName = new NameReference(pawnClass.ObjectName.Name.Substring(8) + "_ARC"); // Pawn_ARC
                apprArchetype.RemoveProperty("Tag");
                RearchetypeSubObjects(apprArchetype, pawnClass.GetDefaults());

                // Spawnable archetype will be moved after port
                spawnableArchetype.Class = pawnClass;
                spawnableArchetype.RemoveProperty("Tag");

                // Sub objects
                RearchetypeSubObjects(spawnableArchetype, apprArchetype);
            }
            else
            {
                Debugger.Break();
            }
        }

        /// <summary>
        /// Re-archetypes objects under the base object onto ones under the newArchetypeBaseObject
        /// </summary>
        /// <param name="baseObject"></param>
        /// <param name="newArchetypeBaseObject"></param>
        private static void RearchetypeSubObjects(ExportEntry baseObject, IEntry newArchetypeBaseObject)
        {
            Debug.WriteLine($"Change archetypes of {baseObject.InstancedFullPath} children to ones under {newArchetypeBaseObject.InstancedFullPath}");

            var properties = baseObject.GetProperties();
            foreach (var prop in properties)
            {
                if (prop is ObjectProperty { Value: > 0 } op)
                {
                    var subObj = baseObject.FileRef.GetUExport(op.Value);
                    if (subObj == null || subObj.idxLink != baseObject.UIndex)
                        continue;
                    RearchetypeSubObject(subObj, newArchetypeBaseObject);
                }

                if (prop is ArrayProperty<ObjectProperty> ops)
                {
                    foreach (var op2 in ops.Where(x => x.Value > 0))
                    {
                        var subObj = baseObject.FileRef.GetUExport(op2.Value);
                        if (subObj == null || subObj.idxLink != baseObject.UIndex)
                            continue;
                        RearchetypeSubObject(subObj, newArchetypeBaseObject);
                    }
                }
            }
        }

        private static void RearchetypeSubObject(ExportEntry subObj, IEntry newBaseObj)
        {
            if (subObj.HasArchetype)
            {
                var newArchetypeIfp = $"{newBaseObj.InstancedFullPath}.{subObj.ObjectName.Instanced}";
                var newArchetype = subObj.FileRef.FindEntry(newArchetypeIfp);
                if (newArchetype == null)
                {
                    // name might have changed. Try to find by class
                    var candidates = subObj.FileRef.Exports.Where(x=>x.idxLink == newBaseObj.UIndex && x.Class == subObj.Class).ToList();
                    if (candidates.Count != 1)
                    {
                        Debugger.Break();
                    }

                    newArchetype = candidates[0];
                }
                Debug.WriteLine($"Changing archetype {subObj.InstancedFullPath} from {subObj.Archetype.InstancedFullPath} -> {newArchetype.InstancedFullPath}");
                subObj.Archetype = newArchetype;

                RearchetypeSubObjects(subObj, subObj.Archetype);
            }
        }
    }
}
