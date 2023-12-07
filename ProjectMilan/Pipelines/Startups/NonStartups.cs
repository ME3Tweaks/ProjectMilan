using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Pass-throughable settings for MPCommon pipelne
    /// </summary>
    class NonStartupPipelineVars
    {
        public string OutputPath { get; set; }

        /// <summary>
        /// Extra packages to port
        /// </summary>
        public readonly string[] PackageFiles = new[]
        {
            "BioSimpleDlgContainer_Horde",
            
            // OBJECTIVES
            "SFXEngagement_Annex_Hack",
            "SFXEngagement_Annex_Upload",
            "SFXEngagement_Assassination",
            "SFXEngagement_Disarm_Disable",
            "SFXEngagement_Disarm_Enable",
            "SFXEngagement_Extraction",
            // Todo: add MP2, MP3 objectives
            // "SFXEngagement_Retrieve" // I don't think this is used - this is basegame version which is broken. May leave however if ModMaker somehow is ported to LE.
            // "SFXEngagement_SupplyDrop" // This is a cut objective that has no implementation

            // GUI IMAGES (Basegame)
            "SFXMPCardImages",
            "SFXMPImagesCrates",
            "SFXMPImagesMaps1",
            "SFXMPImagesMaps2",
            "SFXMPImagesMatchSettings",
            "SFXMPImagesStore",
            "SFXMPKitImagesAdept",
            "SFXMPKitImagesEngineer",
            "SFXMPKitImagesInfiltrator",
            "SFXMPKitImagesOther1",
            "SFXMPKitImagesOther2",
            "SFXMPKitImagesSentinel",
            "SFXMPKitImagesSoldier",
            "SFXMPKitImagesVanguard",
            "SFXMPMedalImages",
            "SFXMPObjectives",
            "SFXMPObjectives_Special",
            "SFXMPSupplyCardImages",

            // MP1
            "MP1Images",
            "MP1PowerIcons",
            "SFXGE_MP1_MatchConsumables",
            "SFXGUI_WeaponUIDataDLC_CON_MP1SF",
            "SFXGUI_W_A_Krogan",
            "SFXGUI_W_SMG_Geth",
            "SFXGUI_W_S_Batarian",

            // MP2
            "MP2Images",
            "MP2PowerIcons",
            "SFXEngagement_RetrieveDLC",
            "SFXGUI_WeaponUIDataDLC_CON_MP2SF",
            "SFXGUI_W_A_Cerberus",
            "SFXGUI_W_A_Prothean_MP",
            "SFXGUI_W_SG_Quarian",
            "SFXGUI_W_S_Turian",
            "SFXMP2Gear1",
            "SFXMP2Gear2",
            "SFXMP2GearImages1",
            "SFXMPObjectiveRetrieve",
            "SFX_GUI_PR_Images_1",

            // MP3
            "MP3GearImages",
            "MP3Images",
            "MP3PowerIcons",
            "SFXGUI_WeaponUIDataDLC_CON_MP3SF",
            "SFXGUI_WeaponUIDataDLC_SharedSF",
            "SFXGUI_WMod_AssaultRifleMelee",
            "SFXGUI_WMod_AssaultRifleSuperPen",
            "SFXGUI_WMod_AssaultRifleSuperScope",
            "SFXGUI_WMod_PistolHeadShot",
            "SFXGUI_WMod_PistolSuperDamage",
            "SFXGUI_WMod_ShotgunDamageAndPen",
            "SFXGUI_WMod_ShotgunSuperMelee",
            "SFXGUI_WMod_SMGPenetration",
            "SFXGUI_WMod_SniperRifleDamageAndPen",
            "SFXGUI_WMod_SniperRifleSuperScope",
            "SFXGUI_W_A_LMG",
            "SFXGUI_W_P_Asari",
            "SFXGUI_W_SG_Assault",
            "SFXMobileAnnex",

            // These were redone in MP4 as they don't work properly in MP3
            /*"SFXModsMP3_AssaultRifle",
            "SFXModsMP3_Pistol",
            "SFXModsMP3_Shotgun",
            "SFXModsMP3_SMG",
            "SFXModsMP3_SniperRifle",*/
            "SFXMP3Gear",
            "SFXSharedGear",
            "SFXSharedModGameEffects",
            "SFXSharedModImages",


            // MP4
            "GUI_CollectorHUDOverlay", // We should port this to SP
            "GUI_MPChallengeImages",
            "MP4GUIImages",
            "MP4Images",
            "MP_DLC_SFResources_Cooked",
            "SFXGUI_FontsJPN_DLC",
            "SFXGUI_Fonts_DLC",
            "SFXGUI_WeaponUIDataDLC_CON_MP4SF",
            "SFXGUI_W_SMG_Collector",
            "SFXGUI_W_S_Collector",
            "SFXHazardMapImages",
            "SFXModsMP3_AssaultRifle", // These fix MP3 versions
            "SFXModsMP3_Pistol",
            "SFXModsMP3_Shotgun",
            "SFXModsMP3_SMG",
            "SFXModsMP3_SniperRifle",
            "SFXMP4AmmoImages",
            "SFXMP4AmmoPowers",
            "SFXMP4CardImages",
            "SFXMP4Gear",
            "SFXMP4GearImages",
            "SFXMP4KitImages",
            //"SFXPawn_Abomination", // Collector faction, Geth, Cerb new enemy
            //"SFXPawn_Atlas2", // Faster, more armor pieces
            //"SFXPawn_Banshee2", // I think changes to warp ball?
            //"SFXPawn_Cannibal2", // Can eat players
            //"SFXPawn_CollectorCaptain",
            //"SFXPawn_CollectorTrooper",
            //"SFXPawn_GethBomber",
            //"SFXPawn_GethPyro2", // Cannot be grabbed
            //"SFXPawn_Marauder2", // Can stomp players
            //"SFXPawn_Phoenix",
            //"SFXPawn_Praetorian",
            //"SFXPawn_Scion",
            "SFXSharedModGameEffects",
            "SFXSharedModImages",
            // "SFXWeapon_SniperRifle_Collector", // Use this version instead of EGM's as it may improve audio and/or other things with newer tooling

            // MP5
            "GUI_MPChallengeImages",
            "MP_DLC_SFResources_Cooked",
            "SFXGUI_WeaponUIDataDLC_CON_MP5SF",
            "SFXGUI_WMod_PistolPowerDamage_MP5",
            "SFXGUI_WMod_SMGPowerDamage_MP5",
            "SFXGUI_W_A_Adas_MP",
            "SFXGUI_W_A_Lancer_MP",
            "SFXGUI_W_A_Spitfire",
            "SFXGUI_W_P_Bloodpack_MP",
            "SFXGUI_W_P_Silencer_MP",
            "SFXGUI_W_SG_Salarian_MP",
            "SFXGUI_W_SMG_Bloodpack_MP",
            "SFXMP5Gear",
            "SFXMP5GearImages",
            "SFXMP5KitImages",
            "SFXMP5ModImages",
            "SFXMP5Mods",
            "SFXMP5PowerImages",
            "SFXMP5WeaponImages",
            "SFXPawn_GethPrime2", // Changes to stagger, I think?



        };

        // If other options are ever needed for pass through they will be defined here
    }

    /// <summary>
    /// Ports non-startup files, such as objectives, GUI images, etc
    /// </summary>
    internal class NonStartupPipeline
    {
        private const string LOG_CATEGORY = @"Milan-NonStartup";
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
            // We use .Distince() cause list might have duplicates due to duplicates in DLC folders
            Parallel.ForEach(vars.PackageFiles.Distinct(),
                new ParallelOptions() { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, packageBaseName =>
                {
                    //if (packageBaseName != "SFXEngagement_Extraction")
                    //    return;
                    var cache = new PackageCache();
                    MilanLog.Information($"Porting file {packageBaseName}", customPrefix: LOG_CATEGORY);
                    var packageName = $"{packageBaseName}.pcc";
                    var me3File = MilanShared.GetME3Package(packageName);
                    var le3File = MEPackageHandler.CreateAndOpenPackage(Path.Combine(vars.OutputPath, packageName), MEGame.LE3);
                    le3File.LECLTagData.ImportHintFiles.Add("BIOP_MP_COMMON.pcc"); // Hint common package

                    MilanShared.PortObjectReferencer(me3File, le3File, cache, LOG_CATEGORY);
                    MilanShared.PortLocalizations(packageBaseName, vars.OutputPath, cache, LOG_CATEGORY);
                });
        }
    }
}
