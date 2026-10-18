using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Kismet;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Restores the shuttle fly-in on maps we port from LE3 and not ME3. LE3's version of the base maps stripped the MP shuttle.
    /// </summary>
    internal static class BasegameExtractionShuttleRestore
    {
        private const string ExtractionEventClass = "SFXSeqEvt_StartExtractionShuttle";
        private const string ExtractionEventClassPath = "SFXGameMPContent.SFXSeqEvt_StartExtractionShuttle";
        private const string MainSequencePath = "TheWorld.PersistentLevel.Main_Sequence";

        /// <summary>
        /// Donor file to pull the event data from
        /// </summary>
        private const string ClassDonorFile = "BioD_MPHosp.pcc";

        public static void Apply(LevelSpecificPipeline levelPipeline)
        {
            var bioDName = levelPipeline.BioP.Replace("BioP_", "BioD_", StringComparison.Ordinal);

            // ME3 is the source of truth for whether the map has a shuttle at all (MPRctr does not)
            var me3BioD = MilanShared.GetME3Package($"{bioDName}.pcc", logIfNotFound: false);
            var me3Event = me3BioD?.Exports.FirstOrDefault(x => !x.IsDefaultObject && x.ClassName == ExtractionEventClass);
            if (me3Event == null)
            {
                MilanLog.Information($"{bioDName} has no extraction shuttle in ME3, nothing to restore", customPrefix: levelPipeline.LogCategory);
                return;
            }

            // Our own copy of the file, as the shuttle fix and the event change it
            using var package = MEPackageHandler.OpenMEPackage(Path.Combine(LE3Directory.CookedPCPath, $"{bioDName}.pcc"), diskIOSyncLock: MilanShared.DiskIOSyncLock);
            var sequence = package.FindExport(MainSequencePath);
            if (sequence == null)
            {
                MilanLog.Warning($"{bioDName} has no Main_Sequence, cannot restore the extraction shuttle", customPrefix: levelPipeline.LogCategory);
                return;
            }

            if (package.Exports.Any(x => !x.IsDefaultObject && x.ClassName == ExtractionEventClass))
            {
                MilanLog.Information($"{bioDName} already has the extraction shuttle event", customPrefix: levelPipeline.LogCategory);
            }
            else
            {
                // The class has to come from a map that has no other classes. Porting it out of the basegame BioD itself fails, as
                // cross-game function recompilation initializes a FileLib of the whole source file, and that file also has classes
                // that extend SFXGameInfoMP (which is not in LE3's SFXGame)
                var donorClass = MilanShared.GetME3Package(ClassDonorFile)?.FindExport(ExtractionEventClassPath);
                if (donorClass == null)
                {
                    MilanLog.Warning($"  Could not find {ExtractionEventClassPath} in {ClassDonorFile}, cannot restore the extraction shuttle in {bioDName}", customPrefix: levelPipeline.LogCategory);
                    return;
                }

                var classPackage = package.CreatePackageExport(donorClass.Parent!.ObjectName);
                ReportBadLinks(EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, donorClass, package, classPackage, true,
                    CreateRelinkerOptions(levelPipeline), out _), levelPipeline);

                // Pull stuff in and report what fails.
                ReportBadLinks(EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, me3Event, package, sequence, true,
                    CreateRelinkerOptions(levelPipeline), out var newEvent), levelPipeline);

                KismetHelper.AddObjectToSequence((ExportEntry) newEvent, sequence);
                MilanLog.Information($"  Restored {newEvent.InstancedFullPath} in {bioDName}", customPrefix: levelPipeline.LogCategory);
            }

            // The LE3 BioD still branches on SFXGameInfoSP, which does not exist in LMP; the ported maps get this bypassed in LevelShared.PortLevel, so also do it here
            // so bad references don't happen in M3's references check
            LevelShared.FixSequencing(sequence, levelPipeline);

            ExtractionShuttleVisibilityFix.Apply(package, levelPipeline.LogCategory);
            // Try to also fix the lighting as its a bit wonk.
            ExtractionShuttleLightEnvironmentFix.Apply(package, levelPipeline.LogCategory);

            package.Save(Path.Combine(levelPipeline.LevelOutputDir, $"{bioDName}.pcc"), diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanShared.RefreshMilanFiles = true;
        }

        private static RelinkerOptionsPackage CreateRelinkerOptions(LevelSpecificPipeline levelPipeline) => new()
        {
            IsCrossGame = true,
            TargetGameDonorDB = MilanShared.LE3ObjectDB,
            Cache = levelPipeline.Cache,
            PortExportsAsImportsWhenPossible = true,
            PortImportsMemorySafe = true,
            DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
            SourceCustomImportFileResolver = MilanShared.ME3PackageResolver,
        };

        private static void ReportBadLinks(List<EntryStringPair> badLinks, LevelSpecificPipeline levelPipeline)
        {
            foreach (var badLink in badLinks)
            {
                MilanLog.Warning($"  Extraction event relink problem: {badLink.Entry?.InstancedFullPath}: {badLink.Message}", customPrefix: levelPipeline.LogCategory);
            }
        }
    }
}
