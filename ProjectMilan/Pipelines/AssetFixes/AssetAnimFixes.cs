using CommandLine;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;

namespace ProjectMilan.Pipelines;

internal static class AssetAnimFixes
{
    internal static Dictionary<string, string> DiscoverFixes(string folder)
    {
        var fixes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (Directory.Exists(folder))
        {
            // We don't care about the .config file
            foreach (var file in Directory.EnumerateFiles(folder, "*.psa", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase))
            {
                // The filename is the full instanced path; subfolders only organize files
                var path = Path.GetFileNameWithoutExtension(file);
                if (!fixes.TryAdd(path, file))
                {
                    throw new InvalidDataException($"Duplicate animation asset fix for {path}: {file}");
                }
            }
        }
        return fixes;
    }

    /// <summary>
    /// Applies a psa fix to the given export
    /// </summary>
    /// <param name="export"></param>
    /// <param name="file"></param>
    /// <returns></returns>
    /// <exception cref="InvalidDataException"></exception>
    internal static bool ApplyFix(ExportEntry export, string file)
    {
        if (export.ClassName != "AnimSet")
        {
            throw new InvalidDataException($"PSA asset fixes require an AnimSet: {export.InstancedFullPath} in {export.FileRef.FilePath}");
        }

        // 10/22/2026 - Try/catch so this not working doesn't kill builds
        PSA psa;
        List<AnimSequence> animSequences;
        try
        {
            psa = PSA.FromFile(file);
            animSequences = psa.GetAnimSequences();
            if (animSequences.IsEmpty())
            {
                MilanLog.Fatal($"PSA {file} contains no sequences."); 
                return false;
            }
        } catch (Exception ex)
        {
#if SHIPPING_RELEASE
            MilanLog.Fatal($"Unable to load PSA: {ex}");
            throw;
#endif
            MilanLog.Error($"Unable to load PSA: - this should be a blocking error in final release! {ex}");
            return false;
        }

        // REFERENCED FROM LEX - LegendaryExplorer/Tools/PackageEditor/Experiments/PackageEditorExperimentsSquid.cs
        
        // 2026/11/16 - Stumpy - Save sequences before overwriting
        var originalSequences = export.GetProperty<ArrayProperty<ObjectProperty>>("Sequences").Select(x => x.ResolveToExport(export.FileRef, new PackageCache()));

        // 2026/11/16 - Stumpy - Find animSet, animSetData, and sequence list
        var animSetProps = export.GetProperties();
        var sequencesProp = animSetProps.GetProp<ArrayProperty<ObjectProperty>>("Sequences");
        var animSetDataProp = animSetProps.GetProp<ObjectProperty>("m_pBioAnimSetData");
        var animSetData = export.FileRef.GetUExport(animSetDataProp.Value);

        List<ExportEntry> sequenceExports = [];
        foreach (var prop in sequencesProp)
        {
            ExportEntry seqExp;
            AnimSequence? seq;
            if((seqExp = export.FileRef.GetUExport(prop.Value)) != null)
            {
                var props = seqExp.GetProperties();
                if ((seq = animSequences.Find(x => seqExp.ObjectName.ToString().EndsWith(x.Name))) != null && seqExp.ClassName == "AnimSequence")
                {
                    Enum.TryParse<AnimationCompressionFormat>(props.GetProp<EnumProperty>("RotationCompressionFormat")?.Value.Name, out var format);
                    seq.UpdateProps(props, export.FileRef.Game, AnimationCompressionFormat.ACF_BioFixed48, forceUpdate: true);
                    props.AddOrReplaceProp(new ObjectProperty(animSetData, "m_pBioAnimSetData"));
                    seqExp.WriteProperties(props);
                    seqExp.WriteBinary(seq);
                    sequenceExports.Add(seqExp);
                }
            }
        }

        animSetData.WriteProperty(new ArrayProperty<NameProperty>(psa.Bones.Select(x => new NameProperty(x.Name)), "TrackBoneNames"));

        // not sure how important this is
        animSetData.WriteProperty(new ArrayProperty<NameProperty>([new NameProperty("Root"), new NameProperty("Prop01"), new NameProperty("Prop02")], "UseTranslationBoneNames"));

        // shouldn't need this for direct animation replacement, but could be useful if/when we decide to add new animations to animsets
        export.WriteProperty(new ArrayProperty<ObjectProperty>(sequenceExports.Select(x => (ObjectProperty)x), "Sequences"));

        // 2026/11/16 - Stumpy - Not sure how relevant this is for replacing animations within the same export, but leaving this here just in case
        // copy the footstep/sound/event notifies from the selected set onto this one
        if (export.Class.ObjectNameString == "AnimSet")
        {
            foreach (var seq in sequenceExports)
            {
                var seqName = seq.GetProperty<NameProperty>("SequenceName").Value;
                var correspondingSequence = originalSequences.FirstOrDefault(x => x.GetProperty<NameProperty>("SequenceName").Value == seqName);
                if (correspondingSequence == null)
                {
                    continue;
                }
                var originalNotifies = correspondingSequence.GetProperty<ArrayProperty<StructProperty>>("Notifies");
                if (originalNotifies == null)
                {
                    continue;
                }
                var notifies = new ArrayProperty<StructProperty>("Notifies");
                foreach (var notify in originalNotifies)
                {
                    var newEntry = EntryCloner.CloneTree(notify.GetProp<ObjectProperty>("Notify").ResolveToEntry(export.FileRef), false);
                    newEntry.Parent = seq;
                    var newNotify = notify.DeepClone();
                    newNotify.Properties.AddOrReplaceProp(new ObjectProperty(newEntry, "Notify"));
                    notifies.Add(newNotify);
                }
                seq.WriteProperty(notifies);
            }
            return true;
        }
        return false;
    }
}

