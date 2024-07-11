using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Paths;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using ProjectMilan;
using ProjectMilan.Utility;
using ProjectMilan_ExtraContent.Rejects.Enemies;
using ProjectMilan_ExtraContent.Shared;
using ProjectMilanCore;
using System.Security.AccessControl;

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
            // Cannot use the MPCommon cache here as it may not be in the destination folder.
            public PackageCache Cache { get; set; } = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3).ChainNewCache();

            public readonly CaseInsensitiveDictionary<string> LoadedFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3);

        }

        class RejectPawnSource : PortingAsset
        {
            public string Name { get; set; }

            /// <summary>
            /// If this is not an archetype, but a necessary asset that our relinker didn't pull in
            /// </summary>
            public bool IsSupportingObject { get; set; }

            public string RemappedArchetypeIFP => $"Char_Enemies_Milan.{Name}";
        }

        private static List<RejectPawnSource> PawnSources = new List<RejectPawnSource>([
            // First - assets that fail import resolution
            new RejectPawnSource() { SourceFile = "SFXCharacterClass_Infiltrator.pcc", AssetIFP = "BIOG_HMM_BC_A.HMM_BC_MeleeInfiltrator_BC_OmniInfiltrator", Name="InfiltratorMeleeAnim", IsSupportingObject = true},
            new RejectPawnSource() { SourceFile = "BIO_COMMON.pcc", AssetIFP = "Wwise_Generic_Foley._Play_foot_scuffs_short", Name="Foley1", IsSupportingObject = true},
            new RejectPawnSource() { SourceFile = "SFXPawn_Husk.pcc", AssetIFP = "Wwise_Generic_Foley.Play_foley_melee_hit_standard_flesh", Name="Foley2", IsSupportingObject = true},

            //// Second - pawns
            new RejectPawnSource() { SourceFile = "SFXPawn_Demo.pcc", AssetIFP = "Char_Enemies_Citadel.Demo", Name="Specialist"},
            new RejectPawnSource() { SourceFile = "SFXPawn_Heavy.pcc", AssetIFP = "Char_Enemies_Citadel.Heavy", Name="Heavy"},
            new RejectPawnSource() { SourceFile = "SFXPawn_Sniper.pcc", AssetIFP = "Char_Enemies_Citadel.Sniper", Name="Sniper"},
            new RejectPawnSource() { SourceFile = "BioD_OMG003_303Trap.pcc", AssetIFP = "Char_Omega_Enemies.Archetypes.Rampart_Combat", Name="RampartMP", PrePortingDelegate = RejectsRampart.PrePort},
            new RejectPawnSource() { SourceFile = "BioD_OMG003_125LitExtra.pcc", AssetIFP = "Char_Omega_Enemies.Archetypes.Adjutant_Combat", Name="Adjutant"},
            new RejectPawnSource() { SourceFile = "BioD_Cit004_270ShuttleBay1.pcc", AssetIFP = "Char_Enemies_Citadel.Bosses.FemmeFatale", Name="Forerunner", PrePortingDelegate = RejectsForerunner.PrePort},
            new RejectPawnSource() { SourceFile = "BioD_Cit004_272MaleClone.pcc", AssetIFP = "Char_Enemies_Citadel.Bosses.CloneShepardMale", Name="Executioner", PrePortingDelegate = RejectsExecutioner.PrePort},
            new RejectPawnSource() { SourceFile = "BioD_Cit003_600MechEvent.pcc", AssetIFP = "Char_Enemies_Citadel.Atlas", Name="Catlas"},
            new RejectPawnSource() { SourceFile = "BioD_Cat004_625ProtoReaper.pcc", AssetIFP = "BioChar_Cat004.Archetypes.Nemesis_Legion", Name="GethAssassin", PrePortingDelegate = RejectsGethAssassin.PrePort},
            new RejectPawnSource() { SourceFile = "BioD_Cat004_800KaiLeng.pcc", AssetIFP = "char_enemies.Archetypes.Cerberus.KaiLeng", Name="Agent"},
            // FemClone Char_Enemies_Citadel.Bosses.CloneShepardFemale BioD_Cit004_273FemClone
        ]);

        /// <summary>
        /// Prepares the mod folder and then runs the pipeline.
        /// </summary>
        internal static void RunPipelineEC()
        {
            ExtraContentInit.PrepareContent(EExtraContent.Rejects);
            RunPipeline();
            MilanShared.MoveTexturesToTFC("Textures", MilanShared.REJECTS_DLC_NAME, false, @"MILANEC-TFC");
            ExtraContentInit.CompactTFC(EExtraContent.Rejects); // Milan main will handle this when it pulls everything together
            ExtraContentInit.CompactAFC(EExtraContent.Rejects); // Milan main will handle this when it pulls everything together
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
            SharedECPipelines.MergeConfig(EExtraContent.Rejects);
            SharedECPipelines.MergeTLK(EExtraContent.Rejects);
            GenerateGUIPackage(vars);
            GenerateMergedContent(vars);
            // To speed up builds don't split enemy packages in dev mode    
#if !DEBUG
            SplitEnemyPackages(vars);
#endif
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

        /// <summary>
        /// Generates a single package file that has all assets for all enemies, so that one change affects them all. Moves and renames all archetype objects accordingly.
        /// </summary>
        /// <param name="vars"></param>
        private static void GenerateMergedContent(RejectVars vars)
        {

            MilanLog.Information($"Building MergedContent", customPrefix: LOG_CATEGORY);
            var mergedPackage = MEPackageHandler.CreateAndOpenPackage(MergedContentPath, MEGame.LE3);
            mergedPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this is an MP subfile

            // Add localized packages.
            MilanPackageCache localizedCache = new MilanPackageCache();
            foreach (var loc in BaseBuildSettings.SupportedVOLanguages)
            {
                var localizedPackage = MEPackageHandler.CreateAndOpenPackage(MergedContentPath.SetUnrealLocalization(MEGame.LE3, loc, true), MEGame.LE3);
                localizedCache.InsertIntoCache(localizedPackage);
            }

            // Pass 1: Import everything, without changes.
            foreach (var source in PawnSources)
            {
                if (!vars.LoadedFiles.TryGetValue(source.SourceFile, out var path))
                {
                    MilanLog.Error($@"Could not find source pawn package: {source.SourceFile}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                var package = MEPackageHandler.OpenMEPackage(path);
                var archetype = package.FindExport(source.AssetIFP);
                if (archetype == null)
                {
                    MilanLog.Error($@"Could not find source pawn archetype {source.AssetIFP} in {source.SourceFile}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                // Installs new classes into the target
                CompileNewEnemyClasses(vars, source, package);

                // Prepare for porting by hooking up data to the new classes and changing things that need changed to not port them over
                source.PrePortingDelegate?.Invoke(vars, package);

                MilanLog.Information($"Porting {source.Name} into MergedContent", customPrefix: LOG_CATEGORY);
                EntryExporter.ExportExportToPackage(archetype, mergedPackage, out _, vars.Cache, new RelinkerOptionsPackage() { Cache = vars.Cache, PortImportsMemorySafe = true, PortLocalizationImportsMemorySafe = false });
                if (!source.IsSupportingObject)
                {
                    // Calculate once outside of loop to improve performance.
                    var references = EntryImporter.GetAllReferencesOfExport(archetype).OfType<ImportEntry>().ToList();
                    Parallel.ForEach(BaseBuildSettings.SupportedVOLanguages, loc =>
                    {
                        MilanLog.Information($"Porting localized content for {source.Name} into MergedContent_{loc}", customPrefix: LOG_CATEGORY);
                        SharedLoc.GenerateLocalizedContent(archetype, localizedCache.GetPackages().FirstOrDefault(x => x.Localization == loc), loc, vars.Cache, source.Name, references);
                    });

                    //foreach (var loc in BaseBuildSettings.SupportedVOLanguages)
                    //{
                    //    MilanLog.Information($"Porting localized content for {source.Name} into MergedContent_{loc}", customPrefix: LOG_CATEGORY);
                    //    SharedLoc.GenerateLocalizedContent(archetype, localizedCache.GetPackages().FirstOrDefault(x => x.Localization == loc), loc, vars.Cache, source.Name);
                    //}
                }
            }

            // Pass 2: Rename archetypes
            var charEnemies = ExportCreator.CreatePackageExport(mergedPackage, "Char_Enemies_Milan", cache: vars.Cache);
            foreach (var source in PawnSources.Where(x => !x.IsSupportingObject))
            {
                var archetypeObj = mergedPackage.FindExport(source.AssetIFP);
                archetypeObj.idxLink = charEnemies.UIndex;
                archetypeObj.ObjectName = source.Name;
            }

            // Pass 3: Post porting delegates
            foreach (var source in PawnSources.Where(x => !x.IsSupportingObject))
            {
                source.PostPortingDelegate?.Invoke(vars, mergedPackage.FindExport(source.RemappedArchetypeIFP));
            }

            // Save merged content
            mergedPackage.Save();

            // Save merged content localizations
            foreach (var package in localizedCache.GetPackages())
            {
                package.Save();
            }
        }

        private static void CompileNewEnemyClasses(RejectVars vars, RejectPawnSource rps, IMEPackage sourcePackage)
        {
            var looseClassesFolder = Path.Combine(SharedECPipelines.ECPipelineRoot, EExtraContent.Rejects.ToString(), "Assets", "Classes", rps.Name);
            if (!Directory.Exists(looseClassesFolder))
                return;

            var classes = new List<UnrealScriptCompiler.LooseClass>();
            var files = Directory.GetFiles(looseClassesFolder, "*.uc");
            foreach (var f in files)
            {
                var source = File.ReadAllText(f);
                classes.Add(new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(f), source, f));
            }

            // Maps Package -> Classes under them. Organization.
            // Rejects only uses SFXGameContent_Milan.
            var looseClassPackages = new List<UnrealScriptCompiler.LooseClassPackage>();
            var looseClassPackage = new UnrealScriptCompiler.LooseClassPackage(MilanPackages.SFXGameContentMilan, classes);
            looseClassPackages.Add(looseClassPackage);

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = vars.Cache,
                MissingObjectResolver = MilanShared.MissingObjectResolver,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor
            };

            MilanLog.Information($@"Compiling classes for {rps.Name}:", customPrefix: LOG_CATEGORY);
            foreach (var c in files)
            {
                MilanLog.Information($"   {Path.GetFileNameWithoutExtension(c)}", customPrefix: LOG_CATEGORY);
            }
            MessageLog log = UnrealScriptCompiler.CompileLooseClasses(sourcePackage, looseClassPackages, usop);

            if (log.HasErrors)
            {
                MilanLog.LogUSCErrors(log);
            }
        }

        private const string LOG_CATEGORY = @"MILAN-Rejection";

        /// <summary>
        /// Makes individual enemy packages seek free
        /// </summary>
        /// <param name="vars"></param>
        private static void SplitEnemyPackages(RejectVars vars)
        {
            using var mergedContent = MEPackageHandler.OpenMEPackage(MergedContentPath);
            Parallel.ForEach(PawnSources.Where(x => !x.IsSupportingObject), ps =>
            {
                MilanLog.Information($"Splitting {ps.Name} to individual package", customPrefix: LOG_CATEGORY);
                var splitPackage = MEPackageHandler.CreateAndOpenPackage(
                    Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole", $"SFXPawn_{ps.Name}.pcc"),
                    MEGame.LE3);
                EntryExporter.ExportExportToPackage(mergedContent.FindExport(ps.RemappedArchetypeIFP), splitPackage, out var archetype, vars.Cache);
                PackageTools.AddToObjectReferencer(archetype);
                splitPackage.Save();
            });

            // Change to release settings.
            SharedECPipelines.MergeConfig(EExtraContent.Rejects, "Release");

            // Delete MergedContent
#if !DEBUG
            File.Delete(MergedContentPath);
#endif
        }
    }
}
