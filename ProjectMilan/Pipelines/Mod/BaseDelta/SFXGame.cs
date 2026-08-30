using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;
using System;
using System.Collections.Generic;
using System.Text;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Handles applying changes to a vanilla SFXGame package so it can be used in caches down the pipe.
    /// </summary>
    internal class SFXGame : IBasePatchClass
    {
        private const string LOG_CATEGORY = "Milan-SFXGame";

        public string GameFile => "SFXGame.pcc";

        public string Comment => "SFXGame.pcc class overrides (SFXShield_Base, SFXModule_Damage)";

        private static string GetVanillaLoadPath()
        {
            // Prefer loading from backup so we don't load a modded one.
            // Eventually this should hash check.
            var backupPath = ME3TweaksBackups.GetGameBackupPath(MEGame.LE3);
            if (backupPath != null && !Directory.Exists(backupPath))
            {
                backupPath = null;
            }
            return Path.Combine(LE3Directory.GetCookedPCPath(rootPathOverride: backupPath), @"SFXGame.pcc");
        }

        public byte[] GetVanillaBytes()
        {
            // Re-serialize through SaveToStream (rather than returning the raw file bytes) so vanilla
            // and patched bytes are in the same compression state - otherwise JDiff would be comparing
            // unrelated byte layouts and produce a huge, meaningless delta.
            using var vanillaPackage = MEPackageHandler.OpenMEPackage(GetVanillaLoadPath());
            return vanillaPackage.SaveToStream(BaseDeltaHandler.UseCompressedPackages).ToArray();
        }

        /// <summary>
        /// Modifies a vanilla SFXGame with our changes and returns the serialized result.
        /// </summary>
        public byte[] BuildPatchTarget()
        {
            using var sfxGamePackage = MEPackageHandler.OpenMEPackage(GetVanillaLoadPath());

            var baseDeltaFolder = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"BaseDelta", @"SFXGame");

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage
            {
                Cache = new PackageCache(),
                MissingObjectResolver = MilanShared.MissingObjectResolver,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                // Without this, FileLib's base-file resolution (Core/Engine/etc, needed to resolve types
                // SFXGame's overrides reference) would load straight from the live mounted game path,
                // bypassing any other BaseDeltaHandler-patched packages those files might depend on.
                CustomFileResolver = MilanShared.LE3PackageResolver
            };
            FileLib fileLib;
            try
            {
                fileLib = new FileLib(sfxGamePackage);
                if (!fileLib.Initialize(usop))
                {
                    MilanShared.LogFailedFileLibInit(fileLib);
                    MilanLog.Fatal("Unable to initialize the FileLib for SFXGame - this is a fatal error.");
                    Environment.Exit(1);
                }
            }
            catch (Exception ex)
            {
                // Kill it
                MilanLog.Fatal($"Unable to initialize the FileLib for SFXGame - this is a fatal error. Exception: {ex.Message}");
                Environment.Exit(1);
                throw;
            }

            foreach (var cls in Directory.GetFiles(baseDeltaFolder, "*.uc"))
            {
                var className = Path.GetFileNameWithoutExtension(cls);
                var classExport = sfxGamePackage.FindExport(className);

                MilanLog.Information($"Compiling class {className}", customPrefix: LOG_CATEGORY);
                var classSource = File.ReadAllText(cls);
                UnrealScriptCompiler.CompileClass(sfxGamePackage, classSource, fileLib, usop, export: classExport);
            }

            return sfxGamePackage.SaveToStream(BaseDeltaHandler.UseCompressedPackages).ToArray();
        }
    }
}
