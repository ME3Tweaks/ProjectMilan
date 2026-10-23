using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Pass-throughable settings for MPCommon pipelne
    /// </summary>
    class NonStartupPipelineVars
    {
        public string OutputPath { get; set; }

        // If other options are ever needed for pass through they will be defined here
    }

    /// <summary>
    /// Category of a file from NonStartup
    /// </summary>
    enum NonStartupCategory
    {
        /// <summary>
        /// Contains SWF GUIs
        /// </summary>
        GUI,

        /// <summary>
        /// Contains dialogue packages (VO)
        /// </summary>
        Dialogue,

        /// <summary>
        /// Contains assets used by GUIs
        /// </summary>
        Images,

        /// <summary>
        /// Objective packages
        /// </summary>
        Objectives,

        /// <summary>
        /// SFXGUI_W files for weapon bench preview
        /// </summary>
        WeaponPreviews,

        /// <summary>
        /// SFXGUI_WMod files for weapon bench preview
        /// </summary>
        WeaponModPreviews,

        /// <summary>
        /// Weapon mod classes
        /// </summary>
        WeaponMods,

        /// <summary>
        /// Gear files
        /// </summary>
        Gear,

        /// <summary>
        /// AmmoPowers
        /// </summary>
        Consumables,

        /// <summary>
        /// Enemy pawns
        /// </summary>
        Pawns,
    }

    /// <summary>
    /// Ports non-startup files, such as objectives, GUI images, etc
    /// </summary>
    internal class NonStartupPipeline
    {
        private const string LOG_CATEGORY = @"MILAN-NonStartup";

        /// <summary>
        /// File mapping to their category, used for organizing.
        /// </summary>
        public static readonly CaseInsensitiveDictionary<NonStartupCategory> FileMap = new()
        {
            // --- VO -- 
            { "BioSimpleDlgContainer_Horde", NonStartupCategory.Dialogue },

            // --- GUI ---
            { "GUI_CollectorHUDOverlay", NonStartupCategory.GUI },
            { "MP_DLC_SFResources_Cooked", NonStartupCategory.GUI },
            { "SFXGE_MP1_MatchConsumables", NonStartupCategory.GUI },
            // SFXGUI_WeaponUIDataDLC_CON_MP{1-5}SF are NOT ported generically here - their weapon (m_aWeapons)
            // data is merged with the shipped LE3 SP data by PortWeaponDataPackage() instead. SharedSF is still ported
            // generically, but is no longer registered in BioUI: its weapons and mods are merged into the packages built by
            // PortWeaponDataPackage() and PortWeaponModDataPackage(). It stays so that the objects other packages import from it
            // still exist, and is mipped like the merged ones (see WeaponImagePackages).
            { "SFXGUI_WeaponUIDataDLC_SharedSF", NonStartupCategory.GUI },

            // --- Images ---
            { "GUI_MPChallengeImages", NonStartupCategory.Images },
            { "MP1Images", NonStartupCategory.Images },
            { "MP1PowerIcons", NonStartupCategory.Images },
            { "MP2Images", NonStartupCategory.Images },
            { "MP2PowerIcons", NonStartupCategory.Images },
            { "MP3GearImages", NonStartupCategory.Images },
            { "MP3Images", NonStartupCategory.Images },
            { "MP3PowerIcons", NonStartupCategory.Images },
            { "MP4GUIImages", NonStartupCategory.Images },
            { "MP4Images", NonStartupCategory.Images },
            { "SFXHazardMapImages", NonStartupCategory.Images },
            { "SFXMP2GearImages1", NonStartupCategory.Images },
            { "SFXMP4AmmoImages", NonStartupCategory.Images },
            { "SFXMP4CardImages", NonStartupCategory.Images },
            { "SFXMP4GearImages", NonStartupCategory.Images },
            { "SFXMP4KitImages", NonStartupCategory.Images },
            { "SFXMP5GearImages", NonStartupCategory.Images },
            { "SFXMP5KitImages", NonStartupCategory.Images },
            { "SFXMP5ModImages", NonStartupCategory.Images },
            { "SFXMP5PowerImages", NonStartupCategory.Images },
            { "SFXMP5WeaponImages", NonStartupCategory.Images },
            { "SFXMPCardImages", NonStartupCategory.Images },
            { "SFXMPImagesCrates", NonStartupCategory.Images },
            { "SFXMPImagesMaps1", NonStartupCategory.Images },
            { "SFXMPImagesMaps2", NonStartupCategory.Images },
            { "SFXMPImagesMatchSettings", NonStartupCategory.Images },
            { "SFXMPImagesStore", NonStartupCategory.Images },
            { "SFXMPKitImagesAdept", NonStartupCategory.Images },
            { "SFXMPKitImagesEngineer", NonStartupCategory.Images },
            { "SFXMPKitImagesInfiltrator", NonStartupCategory.Images },
            { "SFXMPKitImagesOther1", NonStartupCategory.Images },
            { "SFXMPKitImagesOther2", NonStartupCategory.Images },
            { "SFXMPKitImagesSentinel", NonStartupCategory.Images },
            { "SFXMPKitImagesSoldier", NonStartupCategory.Images },
            { "SFXMPKitImagesVanguard", NonStartupCategory.Images },
            { "SFXMPMedalImages", NonStartupCategory.Images },
            { "SFXMPSupplyCardImages", NonStartupCategory.Images },
            { "SFXSharedModImages", NonStartupCategory.Images },
            { "SFX_GUI_PR_Images_1", NonStartupCategory.Images },

            // --- Objectives ---
            { "SFXEngagement_Annex_Hack", NonStartupCategory.Objectives },
            { "SFXEngagement_Annex_Upload", NonStartupCategory.Objectives },
            { "SFXEngagement_Assassination", NonStartupCategory.Objectives },
            { "SFXEngagement_Disarm_Disable", NonStartupCategory.Objectives },
            { "SFXEngagement_Disarm_Enable", NonStartupCategory.Objectives },
            { "SFXEngagement_Extraction", NonStartupCategory.Objectives },
            { "SFXEngagement_RetrieveDLC", NonStartupCategory.Objectives },
            { "SFXMobileAnnex", NonStartupCategory.Objectives },
            { "SFXMPObjectiveRetrieve", NonStartupCategory.Objectives },
            { "SFXMPObjectives", NonStartupCategory.Objectives },
            { "SFXMPObjectives_Special", NonStartupCategory.Objectives },

            // --- WeaponPreview ---
            //{ "SFXGUI_W_A_Adas_MP", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_A_Cerberus", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_A_Krogan", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_A_Lancer_MP", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_A_LMG", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_A_Prothean_MP", NonStartupCategory.WeaponPreviews },
            { "SFXGUI_W_A_Spitfire", NonStartupCategory.WeaponPreviews }, // Not in actual SP (its heavy weapon)
            //{ "SFXGUI_W_P_Asari", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_P_Bloodpack_MP", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_P_Silencer_MP", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_SG_Assault", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_SG_Quarian", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_SG_Salarian_MP", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_SMG_Bloodpack_MP", NonStartupCategory.WeaponPreviews },
            { "SFXGUI_W_SMG_Collector", NonStartupCategory.WeaponPreviews }, // Not in SP
            //{ "SFXGUI_W_SMG_Geth", NonStartupCategory.WeaponPreviews },
            //{ "SFXGUI_W_S_Batarian", NonStartupCategory.WeaponPreviews },
            { "SFXGUI_W_S_Collector", NonStartupCategory.WeaponPreviews }, // Not in SP
            //{ "SFXGUI_W_S_Turian", NonStartupCategory.WeaponPreviews },

            // --- WeaponModPreview ---
            { "SFXGUI_WMod_AssaultRifleMelee", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_AssaultRifleSuperPen", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_AssaultRifleSuperScope", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_PistolHeadShot", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_PistolPowerDamage_MP5", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_PistolSuperDamage", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_ShotgunDamageAndPen", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_ShotgunSuperMelee", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_SMGPenetration", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_SMGPowerDamage_MP5", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_SniperRifleDamageAndPen", NonStartupCategory.WeaponModPreviews },
            { "SFXGUI_WMod_SniperRifleSuperScope", NonStartupCategory.WeaponModPreviews },

            // --- WeaponMods ---
            { "SFXModsMP3_AssaultRifle", NonStartupCategory.WeaponMods },
            { "SFXModsMP3_Pistol", NonStartupCategory.WeaponMods },
            { "SFXModsMP3_Shotgun", NonStartupCategory.WeaponMods },
            { "SFXModsMP3_SMG", NonStartupCategory.WeaponMods },
            { "SFXModsMP3_SniperRifle", NonStartupCategory.WeaponMods },
            { "SFXMP5Mods", NonStartupCategory.WeaponMods },
            { "SFXSharedModGameEffects", NonStartupCategory.WeaponMods },

            // --- Gear ---
            { "SFXMP2Gear1", NonStartupCategory.Gear },
            { "SFXMP2Gear2", NonStartupCategory.Gear },
            { "SFXMP3Gear", NonStartupCategory.Gear },
            { "SFXMP4Gear", NonStartupCategory.Gear },
            { "SFXMP5Gear", NonStartupCategory.Gear },
            { "SFXSharedGear", NonStartupCategory.Gear },

            // --- Consumables ---
            { "SFXGE_MatchConsumables", NonStartupCategory.Consumables },
            { "SFXGE_MP1_MatchConsumables", NonStartupCategory.Consumables },
            { "SFXMP4AmmoPowers", NonStartupCategory.Consumables },

            // --- Pawns ---
            { "SFXPawn_Abomination", NonStartupCategory.Pawns },
            { "SFXPawn_Atlas2", NonStartupCategory.Pawns },
            { "SFXPawn_Banshee2", NonStartupCategory.Pawns },
            { "SFXPawn_Cannibal2", NonStartupCategory.Pawns },
            { "SFXPawn_CollectorCaptain", NonStartupCategory.Pawns },
            { "SFXPawn_GethBomber", NonStartupCategory.Pawns },
            { "SFXPawn_GethPrime2", NonStartupCategory.Pawns },
            { "SFXPawn_GethPyro2", NonStartupCategory.Pawns },
            { "SFXPawn_Marauder2", NonStartupCategory.Pawns },
            { "SFXPawn_Phoenix", NonStartupCategory.Pawns },
            { "SFXPawn_Praetorian", NonStartupCategory.Pawns },
            { "SFXPawn_Scion", NonStartupCategory.Pawns }
        };

        /// <summary>
        /// Replays the process-global state this pipeline publishes - the set of GUI images our own image packages
        /// built, which later pipelines (Levels) check their image references against. Called instead of
        /// <see cref="RunPipeline"/> when a restored checkpoint already contains the NonStartup output.
        /// </summary>
        internal static void RehydrateFromCheckpoint()
        {
            var outputPath = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", "NonStartup");
            ImagePackageBuilder.RehydrateFromCheckpoint(Path.Combine(outputPath, NonStartupCategory.Images.ToString()));
        }

        public static void RunPipeline()
        {
            var vars = new NonStartupPipelineVars()
            {
                OutputPath = Directory.CreateDirectory(Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", "NonStartup")).FullName,
            };
            InternalRunPipeline(vars);
        }


        private static void InternalRunPipeline(NonStartupPipelineVars vars)
        {
            // Chained to the long-lived MPCommon tier so files hit repeatedly within this pipeline (but not
            // globally hot enough to be in MPCommon) get promoted here instead of reopened per-file. Disposed
            // once every file is done, so nothing here outlives the NonStartup pipeline.
            using var pipelineCache = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache(canPromoteInto: true, debugName: "NonStartups pipeline cache");

            MilanLog.LogDonorMessages = false; // Turn off spammy messaging.

            Parallel.ForEach(FileMap.Keys,
                new ParallelOptions() { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, packageBaseName =>
                {
                    //if (packageBaseName != "SFXEngagement_RetrieveDLC")
                    //{
                    //    return;
                    //}
                    using var cache = pipelineCache.ChainNewCache(debugName: $"NonStartups file cache ({packageBaseName})");
                    //cache.InsertIntoCache(MilanShared.GetLE3GlobalPackages());
                    MilanLog.Information($"Porting file {packageBaseName}", customPrefix: LOG_CATEGORY);
                    var packageName = $"{packageBaseName}.pcc";
                    var me3File = MilanShared.GetME3Package(packageName);
                    me3File.LECLTagData.ImportHintFiles.Add("Startup_DLC_CON_MP2_INT.pcc"); // Fix some decomp issues
                    me3File.LECLTagData.ImportHintFiles.Add("Startup_DLC_CON_MP3_INT.pcc");
                    me3File.LECLTagData.ImportHintFiles.Add("Startup_DLC_CON_MP4_INT.pcc");

                    var mapping = packageBaseName.StripUnrealLocalization();
                    var category = FileMap[mapping];
                    var outputFolder = Path.Combine(vars.OutputPath, category.ToString());
                    lock (pipelineCache)
                    {
                        // Ensure we don't have duplicate creation issues
                        Directory.CreateDirectory(outputFolder);
                    }
                    var le3File = MEPackageHandler.CreateAndOpenPackage(Path.Combine(outputFolder, packageName), MEGame.LE3);
                    le3File.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint common package
                    le3File.LECLTagData.IsPostLoadFile = false;

                    //NonStartupPrecorrection(me3File, LOG_CATEGORY);
                    MilanShared.PortObjectReferencer(me3File, le3File, cache, LOG_CATEGORY, null);
                    MilanShared.PortLocalizations(packageBaseName, outputFolder, cache, LOG_CATEGORY);
                });
            MilanLog.LogDonorMessages = true; // Turn off spammy messaging.

            // Our own GUI image packages (e.g. the images ME3 used to download from EA's servers) go alongside
            // the ported ones
            var builtImages = ImagePackageBuilder.BuildImagePackages(Path.Combine(vars.OutputPath, NonStartupCategory.Images.ToString()));
            MipWeaponImagePackages(vars.OutputPath);
            OnlineContentRegistration.RegisterOnlineBanners(builtImages);
            OnlineContentRegistration.RegisterMilanBanners(builtImages); // This is technically not 'Online' content, but it fits right here anyways.
            OnlineContentRegistration.RegisterOnlineStorePacks(builtImages);
            MilanPipelinesShared.CommitConfigBundle(); // Flush the image packages' dynamic load mappings and the online content using them
        }

        private static void NonStartupPrecorrection(IMEPackage me3File, string logCategory)
        {
            // Precorrection logic specific to NonStartup files can be implemented here.
            // This may include fixing references, adjusting properties, or any other necessary modifications
            // before porting the package to the LE3 format.
        
            switch (me3File.FileNameNoExtension)
            {
                //case "SFXGUI_W_S_Turian.pcc":
                //    var donorPackage = me3File.CreatePackageExport("BIOG_WPN_SNP_L_CON_GUN01");
                //    me3File.FindExport("Wwise_Weapons_S_Turian").ObjectName = "Wwise_Weapons_S_Turian_SP";
                //    me3File.FindExport("BIOG_WPN_SNP_L_CON_MP2").ObjectName = "BIOG_WPN_SNP_L_CON_GUN01";
                //    break;
                //case "SFXGUI_W_S_Turian.pcc":
                //    me3File.FindExport("BIOG_WPN_A_CON_MP1").ObjectName = "BIOG_WPN_SNP_L_CON_GUN01";
                //    break;
            }
        }

        /// <summary>
        /// NonStartup has no on-disk cache of its own today - it ports packages directly from ME3 to the LE3
        /// output with no intermediate decompile/donor step like MPCommon has. Stubbed here for symmetry with
        /// MPCommon.Clean() in case that changes in the future.
        /// </summary>
        internal static void Clean()
        {
        }
    }
}
