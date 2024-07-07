using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilan;
using ProjectMilan.Utility;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Rejects
{
    /// <summary>
    /// Builds rejection enemies and updates the config file with necessary changes to work.
    /// </summary>
    public static class RejectsPipeline
    {
        private static string CookedPCFolder => Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole");
        private static string MergedContentPath => Path.Combine(CookedPCFolder, "MergedContent.pcc");

        /// <summary>
        /// Variable container class for passing through. May have nothing in it - do not remove.
        /// </summary>
        public class RejectVars
        {
            public PackageCache Cache { get; set; } = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3).ChainNewCache();
        }

        class RejectPawnSource
        {
            public string SourceFile { get; set; }
            public string ArchetypeIFP { get; set; }
            public string Name { get; set; }

            /// <summary>
            /// If this is not an archetype, but a necessary asset that our relinker didn't pull in
            /// </summary>
            public bool IsSupportingObject { get; set; }

            public string RemappedArchetypeIFP => $"Char_Enemies_Milan.{Name}";
        }

        private static List<RejectPawnSource> PawnSources = new List<RejectPawnSource>([
            // First - assets that fail import resolution
            new RejectPawnSource() { SourceFile = "SFXCharacterClass_Infiltrator.pcc", ArchetypeIFP = "BIOG_HMM_BC_A.HMM_BC_MeleeInfiltrator_BC_OmniInfiltrator", Name="InfiltratorMeleeAnim", IsSupportingObject = true},
            new RejectPawnSource() { SourceFile = "BIO_COMMON.pcc", ArchetypeIFP = "Wwise_Generic_Foley._Play_foot_scuffs_short", Name="Foley1", IsSupportingObject = true},
            new RejectPawnSource() { SourceFile = "SFXPawn_Husk.pcc", ArchetypeIFP = "Wwise_Generic_Foley.Play_foley_melee_hit_standard_flesh", Name="Foley2", IsSupportingObject = true},

            // Second - pawns
            new RejectPawnSource() { SourceFile = "SFXPawn_Demo.pcc", ArchetypeIFP = "Char_Enemies_Citadel.Demo", Name="Specialist"},
            new RejectPawnSource() { SourceFile = "SFXPawn_Heavy.pcc", ArchetypeIFP = "Char_Enemies_Citadel.Heavy", Name="Heavy"},
            new RejectPawnSource() { SourceFile = "SFXPawn_Sniper.pcc", ArchetypeIFP = "Char_Enemies_Citadel.Sniper", Name="Sniper"},
            new RejectPawnSource() { SourceFile = "BioD_OMG003_303Trap.pcc", ArchetypeIFP = "Char_Omega_Enemies.Archetypes.Rampart_Combat", Name="Rampart"},
            new RejectPawnSource() { SourceFile = "BioD_OMG003_125LitExtra.pcc", ArchetypeIFP = "Char_Omega_Enemies.Archetypes.Adjutant_Combat", Name="Adjutant"},
            new RejectPawnSource() { SourceFile = "BioD_Cit004_270ShuttleBay1.pcc", ArchetypeIFP = "Char_Enemies_Citadel.Bosses.FemmeFatale", Name="Forerunner"},
            new RejectPawnSource() { SourceFile = "BioD_Cit004_272MaleClone.pcc", ArchetypeIFP = "Char_Enemies_Citadel.Bosses.CloneShepardMale", Name="Executioner"},
            new RejectPawnSource() { SourceFile = "BioD_Cit003_600MechEvent.pcc", ArchetypeIFP = "Char_Enemies_Citadel.Atlas", Name="Catlas"},
            new RejectPawnSource() { SourceFile = "BioD_Cat004_625ProtoReaper.pcc", ArchetypeIFP = "BioChar_Cat004.Archetypes.Nemesis_Legion", Name="GethAssassin"},
            new RejectPawnSource() { SourceFile = "BioD_Cat004_800KaiLeng.pcc", ArchetypeIFP = "char_enemies.Archetypes.Cerberus.KaiLeng", Name="Agent"},
            // FemClone Char_Enemies_Citadel.Bosses.CloneShepardFemale BioD_Cit004_273FemClone
        ]);

        /// <summary>
        /// Prepares the mod folder and then runs the pipeline.
        /// </summary>
        internal static void RunPipelineEC()
        {
            ExtraContentInit.PrepareContent(EExtraContent.Rejects);
            RunPipeline();
        }

        /// <summary>
        /// Runs the pipeline, assuming folder is already prepared for mod use.
        /// </summary>
        public static void RunPipeline()
        {
            var vars = new RejectVars();
            Directory.CreateDirectory(CookedPCFolder); // Ensure it exists.
            InternalRunPipeline(vars);
        }

        private static void InternalRunPipeline(RejectVars vars)
        {
            MergeConfig(vars);
            MergeTLK(vars);
            GenerateGUIPackage(vars);
            GenerateMergedContent(vars);
            SplitEnemyPackages(vars);
        }

        private static string PipelineRoot => Path.Combine(SharedECPipelines.ECPipelineRoot, "Rejects");

        private static void GenerateGUIPackage(RejectVars vars)
        {
            MilanLog.Information($"Generating GUI assets package", customPrefix: LOG_CATEGORY);
            var pccP = Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole", "SFXGUIMPImages_Milan_Rejects.pcc");
            var pcc = MEPackageHandler.CreateAndOpenPackage(pccP, MEGame.LE3);
            var bannerExp = Texture2D.CreateTexture(pcc, "OptEmyRejects", 1024, 256, PixelFormat.BC7, false);
            var bannerTex = new Texture2D(bannerExp);
            var imagePath = Path.Combine(PipelineRoot, "Assets", "Textures", "GUI", "factionbanner.png");
            var image = Image.LoadFromFile(imagePath, PixelFormat.DXT5);
            bannerTex.Replace(image, bannerExp.GetProperties());
            bannerExp.WriteProperty(new BoolProperty(false, "sRGB"));
            pcc.Save();
        }

        private static void MergeTLK(RejectVars vars)
        {
            MilanLog.Information($"Merging TLK data", customPrefix: LOG_CATEGORY);

        }

        private static void MergeConfig(RejectVars vars)
        {
            MilanLog.Information($"Merging config file", customPrefix: LOG_CATEGORY);
            var configDest = Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole", $"Default_{Path.GetFileName(BaseBuildSettings.OutputModPath)}.bin");
            var configSourceF = Path.Combine(SharedECPipelines.ECPipelineRoot, "Rejects", "Config");
            var configSourceManifest = Path.Combine(configSourceF, "Default_DLC_MOD_PMR2.xml");
            var ms = new MemoryStream();
            CoalescedConverter.ConvertToBin(configSourceManifest, null, outStream: ms);
            ms.Position = 0;
            var sourceAssetBundle = ConfigAssetBundle.FromSingleStream(MEGame.LE3, ms);
            var destAssetBundle = ConfigAssetBundle.FromSingleFile(MEGame.LE3, configDest);
            sourceAssetBundle.MergeInto(destAssetBundle);
            destAssetBundle.CommitAssets(configDest);
        }

        /// <summary>
        /// Generates a single package file that has all assets for all enemies, so that one change affects them all. Moves and renames all archetype objects accordingly.
        /// </summary>
        /// <param name="vars"></param>
        private static void GenerateMergedContent(RejectVars vars)
        {
            MilanLog.Information($"Building MergedContent", customPrefix: LOG_CATEGORY);
            var mergedPackage = MEPackageHandler.CreateAndOpenPackage(MergedContentPath, MEGame.LE3);
            mergedPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this is an MP subfile

            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3);

            // Pass 1: Import everything, without changes.
            foreach (var source in PawnSources)
            {
                MilanLog.Information($"Porting {source.Name} into MergedContent", customPrefix: LOG_CATEGORY);
                if (!loadedFiles.TryGetValue(source.SourceFile, out var path))
                {
                    MilanLog.Error($@"Could not find source pawn package: {source.SourceFile}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                var package = MEPackageHandler.OpenMEPackage(path);
                var archetype = package.FindExport(source.ArchetypeIFP);
                if (archetype == null)
                {
                    MilanLog.Error($@"Could not find source pawn archetype {source.ArchetypeIFP} in {source.SourceFile}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                EntryExporter.ExportExportToPackage(archetype, mergedPackage, out _, vars.Cache, new RelinkerOptionsPackage() { Cache = vars.Cache, PortImportsMemorySafe = true, PortLocalizationImportsMemorySafe = false });
            }

            // Pass 2: Rename archetypes
            var charEnemies = ExportCreator.CreatePackageExport(mergedPackage, "Char_Enemies_Milan", cache: vars.Cache);
            foreach (var source in PawnSources.Where(x => !x.IsSupportingObject))
            {
                var archetypeObj = mergedPackage.FindExport(source.ArchetypeIFP);
                archetypeObj.idxLink = charEnemies.UIndex;
                archetypeObj.ObjectName = source.Name;
            }

            mergedPackage.Save();
        }

        private const string LOG_CATEGORY = @"MILAN-Rejection";

        /// <summary>
        /// Makes individual enemy packages seek free
        /// </summary>
        /// <param name="vars"></param>
        private static void SplitEnemyPackages(RejectVars vars)
        {
        }
    }
}
