namespace MilanShaderHost
{
    /// <summary>
    /// Decides which decooked packages have to be renamed before the game will load them, and what
    /// they are called once renamed.
    ///
    /// LE3 loads a fixed set of packages at boot (<c>engine.startuppackages</c>). Our decooked copy
    /// of one of those declares the same object paths, so when the compiler level loads it Unreal
    /// already has those objects resolved and our copy never becomes the live one. Its shader maps
    /// are already populated, nothing is queued, and the capture ends with the game exiting 0, the
    /// host printing "Finished compiling shaders", and zero jobs written. Every signal says success.
    ///
    /// Giving our copy's package object a unique name breaks the tie. Measured 2026-09-17 on
    /// <c>BioG_VfxMaterials</c>: 0 jobs before, 94 jobs after, and all 94 byte-identical to shipping
    /// — so the object name does not reach the bytecode and a renamed capture is valid evidence.
    ///
    /// Renaming the <em>file</em> does nothing: the package object lives inside the file and keeps
    /// its name, so every object path is unchanged. The rename has to be applied to the package
    /// export, which is what <see cref="CaptureRootName"/> feeds.
    /// </summary>
    public static class CapturePackageNaming
    {
        /// <summary>Suffix appended to a package object to make Unreal load it as a unique object.</summary>
        public const string RenameSuffix = "MILAN";

        /// <summary>
        /// Packages LE3 loads at boot. This is the game's own declaration, not a guess:
        /// <c>engine.startuppackages&amp;package</c> from LE3's Coalesced.bin, verified 2026-09-17.
        /// Regenerate with:
        ///   <c>LECCLI dump-coalesced --game LE3 --output coalesced.txt</c>
        ///   <c>grep "engine.startuppackages&amp;package|Add|" coalesced.txt</c>
        ///
        /// The hand-maintained list this replaced overlapped it by only three entries, so the rename
        /// set was badly under-reported: the whole GUI group, BioG_VfxMaterials, BioVFX_FB_RenderSyle,
        /// BioStartupResources and Global_Events_S were never flagged.
        /// </summary>
        public static readonly IReadOnlySet<string> StartupPackages = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "BIOA_ControllerIcons_PC", "BIOA_ControllerIcons_XBOX", "BioG_VfxMaterials",
            "BioStartupResources", "BioVFX_FB_RenderSyle", "EngineDebugMaterials", "EngineFonts",
            "EngineMaterials", "GUI_SF_BlackScreen", "GUI_SF_ConversationWheel", "GUI_SF_GameOver",
            "GUI_SF_Jourdex", "GUI_SF_LoadSave", "GUI_SF_LoadScreenToolTips", "GUI_SF_ME2_HUD",
            "GUI_SF_ME2_PowerWheel", "GUI_SF_ME2_Reticle", "GUI_SF_MPPlayerCountdown",
            "GUI_SF_MainWheel", "GUI_SF_Markers", "GUI_SF_MessageBox", "GUI_SF_MessageBox_Hint",
            "GUI_SF_Options", "GUI_SF_PC_ME2_PowerWheel", "GUI_SF_PC_SharedAssets", "GUI_SF_PRCStore",
            "GUI_SF_PhotoMode", "GUI_SF_SaveLoadIndicator", "GUI_SF_SquadRecord", "GUI_SF_Subtitles",
            "GUI_SF_WpnReticleSniper", "GUI_SF_XBox_ControllerIcons", "Global_Events_S",

            // Always loaded, but not declared in startuppackages: the engine's own code packages.
            "Core", "Engine", "SFXGame", "Startup_INT", "WwiseAudio",
            "EngineResources", "EngineSounds", "EditorMaterials", "EditorResources"
        };

        /// <summary>
        /// Packages declared <c>engine.packagestoalwayscook&amp;seekfreepackage</c> — player mesh,
        /// face, hair and armour.
        ///
        /// These are NOT boot-loaded and must NOT be renamed. Four of them
        /// (BIOG_Humanoid_MASTER_MTR_R, BIOG_HMM_HED_PROMorph, BIOG_HMF_HED_PROMorph_R,
        /// BIOG_HMM_HGR_SHP_R) capture normally, and rebuilding them on 2026-09-17 changed their
        /// captured jobs — impossible if shipping's copy were winning. They are listed so capture
        /// planning can flag them as worth running (14 of the 19 never have been), not so they can
        /// be renamed.
        /// </summary>
        public static readonly IReadOnlySet<string> SeekFreePackages = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "BIOG_FaceFX_Assets", "BIOG_HMF_ARM_CTH_R", "BIOG_HMF_ARM_HVY_R", "BIOG_HMF_ARM_NKD_R",
            "BIOG_HMF_ARM_SHP_R", "BIOG_HMF_HED_Alignment", "BIOG_HMF_HED_PROMorph_R",
            "BIOG_HMF_HGR_SHP_R", "BIOG_HMF_HIR_PRO", "BIOG_HMM_ARM_CTH_R", "BIOG_HMM_ARM_HVY_R",
            "BIOG_HMM_ARM_NKD_R", "BIOG_HMM_ARM_SHP_R", "BIOG_HMM_HED_Alignment",
            "BIOG_HMM_HED_PROMorph", "BIOG_HMM_HGR_SHP_R", "BIOG_HMM_HIR_PRO_R",
            "BIOG_Humanoid_MASTER_MTR_R", "BIOG_MORPH_FACE"
        };

        /// <summary>
        /// Top-level package objects that already exist in memory at boot, because they live inside a
        /// package the engine force-loads natively. The file set is
        /// <c>EntryImporter.FilesSafeToImportFrom(MEGame.LE3)</c> — Core, Engine, GameFramework,
        /// IPDrv, GFxUI, WwiseAudio, SFXOnlineFoundation and SFXGame — which is the engine's own
        /// notion of what is always resident.
        ///
        /// <c>Startup.pcc</c> is in that list but is deliberately NOT scanned: LEC's own note says it
        /// "exists in METR Patch and is not used by game! (and is also wrong file)". Including it adds
        /// 39 bogus groups and would force needless renames on packages that demonstrably capture
        /// correctly today, EffectsMaterials (159,167 jobs) among them.
        ///
        /// This is the criterion that matters, and <see cref="StartupPackages"/> alone is not enough.
        /// <c>engine.startuppackages</c> is a different thing: most of its entries are not files at
        /// all, they are *groups inside* the force-loaded ones. The decook splits each group into its
        /// own file, so our copy of <c>BioVFX_FB_MotionBlur</c> is a file of that name while
        /// shipping's is a group inside <c>SFXGame.pcc</c>. The object path collides either way, and a
        /// rule that tests our file name against the startup-package list misses it completely — it
        /// catches 2 of the 39 colliding decooked packages and misses 37.
        ///
        /// The consequence is quiet and looks like bad data rather than a collision. The game resolves
        /// its own copy, which is cooked and therefore has its expression graph stripped, and compiles
        /// that. Measured on <c>MotionBlur_Mat</c> (2026-09-18): the capture generated 3 locals, no
        /// scalar uniforms and no scene-colour sample, against 41 locals, 3 scalar uniforms and 6
        /// scene-colour references once renamed — 20 mismatches to 0. The decooked material was never
        /// at fault; it simply never loaded.
        ///
        /// Regenerate with <c>ShaderResearchTool startup-collisions</c>, which scans the boot packages
        /// for top-level package exports and writes <c>startup-resident-groups.txt</c>.
        /// </summary>
        public static readonly IReadOnlySet<string> StartupResidentGroups = new HashSet<string>(StringComparer.OrdinalIgnoreCase)
        {
            "BioApl_Con_AmmoBox04", "bioapl_ind_batpack01", "BioApl_Uti_AmmoClip01",
            "BioBaseResources", "BIOG_2DA_PlotManager_X", "BIOG_AI_Bark", "BIOG_APL_MASTER_MATERIAL",
            "BIOG_CAM_FX_A", "BIOG_HMM_BC_A", "BIOG_HMM_EX_A", "BioG_MasterMats", "BIOG_PHM_General_F",
            "BIOG_PhotoMode", "BioG_VfxMaterials", "BioSFMovieReference", "BioSFResources",
            "BioVFX_B_Lift", "BioVFX_B_Singularity", "BioVFX_C_Blood", "BioVFX_C_CamAnim",
            "BioVFX_C_Impacts", "BioVFX_C_Mako2", "BioVFX_C_Reload", "BioVFX_C_Shield",
            "BioVFX_C_Weapons", "BioVFX_Crt_FlameThrower", "BioVFX_Env_Hologram",
            "BioVFX_FB_MotionBlur", "BioVFX_FB_PlayerDamage", "BioVFX_FB_RenderSyle",
            "BioVFX_Gui_CoverHUD", "BioVFX_MP_SquadOutline", "BioVFX_T_Melee", "BioVFX_T_TechPowers",
            "BioVFX_Z_FLARES", "BioVFX_Z_GLOBAL", "BioVFX_Z_MATERIALS", "BioVFX_Z_MESHES",
            "BioVFX_Z_TEXTURES", "CameraAnimations", "EngineFonts", "EngineMaterials", "EngineMeshes",
            "EngineResources", "GUI_GlobalIcons", "GUI_Icons", "GUI_SF_ME2_Weapon_Icons",
            "GUI_SF_PowerIcons", "GUI_SF_Store", "GUI_SF_WeaponModMods", "GUI_SF_WeaponModStats",
            "GUI_SF_WeaponSelect", "GUI_SF_WpnReticleCrosshair", "GUI_SF_WpnReticleSimple",
            "NodeBuddies", "SFXWwise_Init", "Wwise_Generic_Bullet_Impacts", "Wwise_Generic_Explosions",
            "Wwise_Generic_Foley", "Wwise_Generic_Foley_Procedural", "Wwise_Generic_Galaxy_Map",
            "Wwise_Generic_Gameplay", "Wwise_Generic_Gameplay_Streaming", "Wwise_Generic_GUI",
            "Wwise_Generic_Physics", "Wwise_Generic_Scripting", "Wwise_Generic_Shield",
            "Wwise_GUI_MultiPlayer_Specific", "Wwise_Main_Menu_Streaming", "Wwise_Power_Shared",
            "Wwise_Smls_CaptainsCabin", "Wwise_VFX_Biotics", "Wwise_VFX_Shield", "Wwise_VFX_Tech",
            "Wwise_VO_Exertions", "Wwise_Weapons_Generic", "Wwise_Weapons_P_Mantis",
            "Wwise_Weapons_S_MinigunTurret", "Wwise_Weapons_Standard_LowAmmo"
        };

        /// <summary>
        /// True when the game already holds this package's objects at boot, so our copy needs a unique
        /// name. Checks both the declared startup packages and the groups resident inside them — the
        /// second is what catches a decooked package whose name is a group in a boot file rather than
        /// a boot file itself, which is 37 of the 39 colliding packages in the LE3 decook.
        /// </summary>
        public static bool RequiresRename(string packageFileOrName)
        {
            var root = Path.GetFileNameWithoutExtension(packageFileOrName);
            return StartupPackages.Contains(root) || StartupResidentGroups.Contains(root);
        }

        /// <summary>True when the package is seek-free. Informational only — these are not renamed.</summary>
        public static bool IsSeekFree(string packageFileOrName) =>
            SeekFreePackages.Contains(Path.GetFileNameWithoutExtension(packageFileOrName));

        /// <summary>
        /// The name the package object carries during a capture: the package's own name, or that name
        /// plus <see cref="RenameSuffix"/> when the game would otherwise win the load.
        /// </summary>
        public static string CaptureRootName(string packageFileOrName)
        {
            var root = Path.GetFileNameWithoutExtension(packageFileOrName);
            return RequiresRename(root) ? root + RenameSuffix : root;
        }

        /// <summary>
        /// The original package name for a renamed capture, or null when the name is not a renamed
        /// one. Used to join a capture back to the shipping package it must be compared against.
        /// </summary>
        public static string? StripRenameSuffix(string packageRoot) =>
            packageRoot.EndsWith(RenameSuffix, StringComparison.Ordinal) && packageRoot.Length > RenameSuffix.Length
                ? packageRoot[..^RenameSuffix.Length]
                : null;

        /// <summary>
        /// Rewrites an instanced full path captured under a renamed root back to its shipping form.
        /// Returns null when <paramref name="instancedFullPath"/> is not under that root.
        /// </summary>
        public static string? DeRenameInstancedPath(string instancedFullPath, string captureRoot, string sourceRoot)
        {
            if (captureRoot == sourceRoot) return instancedFullPath;

            var prefix = captureRoot + ".";
            return instancedFullPath.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)
                ? sourceRoot + "." + instancedFullPath[prefix.Length..]
                : null;
        }
    }
}
