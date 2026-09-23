using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;
using Serilog;
using System;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Handles applying BaseDelta UnrealScript sources onto a vanilla package so it can be used in caches down the pipe.
    /// </summary>
    internal class ScriptPackagePatchTarget : IBasePatchClass
    {
        private readonly string packageName;
        private readonly string logCategory;

        public ScriptPackagePatchTarget(string packageName, string comment)
        {
            this.packageName = packageName;
            logCategory = $"Milan-{packageName}";
            Comment = comment;
        }

        public string GameFile => $"{packageName}.pcc";

        public string Comment { get; }

        private string GetVanillaLoadPath()
        {
            // Prefer loading from backup so we don't load a modded one.
            // Eventually this should hash check.
            var backupPath = ME3TweaksBackups.GetGameBackupPath(MEGame.LE3);
            if (backupPath != null && !Directory.Exists(backupPath))
            {
                backupPath = null;
            }
            return Path.Combine(LE3Directory.GetCookedPCPath(rootPathOverride: backupPath), GameFile);
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
        /// Modifies a vanilla package with BaseDelta changes and returns the serialized result.
        /// </summary>
        public byte[] BuildPatchTarget()
        {
            using var package = MEPackageHandler.OpenMEPackage(GetVanillaLoadPath());

            var baseDeltaFolder = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"BaseDelta", packageName);

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage
            {
                Cache = new PackageCache(),
                MissingObjectResolver = MilanShared.MissingObjectResolver,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                // Without this, FileLib's base-file resolution (Core/Engine/etc, needed to resolve types
                // this package's overrides reference) would load straight from the live mounted game path,
                // bypassing any other BaseDeltaHandler-patched packages those files might depend on.
                CustomFileResolver = MilanShared.LE3PackageResolver,
                AllowNativeStructEdits = true, // Live dangerously
            };
            FileLib fileLib;
            try
            {
                fileLib = new FileLib(package);
                if (!fileLib.Initialize(usop))
                {
                    MilanShared.LogFailedFileLibInit(fileLib);
                    MilanLog.Fatal($"Unable to initialize the FileLib for {packageName} - this is a fatal error.");
                    Environment.Exit(1);
                }
            }
            catch (Exception ex)
            {
                // Kill it
                MilanLog.Fatal($"Unable to initialize the FileLib for {packageName} - this is a fatal error. Exception: {ex.Message}");
                Environment.Exit(1);
                throw;
            }

            var classFolder = Path.Combine(baseDeltaFolder, "Classes");
            if (Directory.Exists(classFolder))
            {
                foreach (var cls in Directory.GetFiles(classFolder, "*.uc"))
                {
                    var className = Path.GetFileNameWithoutExtension(cls);
                    var classExport = package.FindExport(className);

                    MilanLog.Information($"Compiling class {className}", customPrefix: logCategory);
                    var classSource = File.ReadAllText(cls);
                    var (_, log) = UnrealScriptCompiler.CompileClass(package, classSource, fileLib, usop, export: classExport);
                    if (log.HasErrors)
                    {
                        MilanLog.LogUSCErrors(log);
                        MilanLog.Fatal($"Failed to compile {packageName} class {className} - this is a fatal error.");
                        Environment.Exit(1);
                    }
                }
            }

            var functionFolder = Path.Combine(baseDeltaFolder, "Functions");
            if (Directory.Exists(functionFolder))
            {
                foreach (var func in Directory.GetFiles(functionFolder, "*.uc", SearchOption.AllDirectories))
                {
                    var className = Directory.GetParent(func).Name;
                    var functionIFP = $"{className}.{Path.GetFileNameWithoutExtension(func)}";
                    var function = package.FindExport(functionIFP);

                    MilanLog.Information($"Compiling function {functionIFP}", customPrefix: logCategory);
                    var functionSource = File.ReadAllText(func);
                    var (_, log) = UnrealScriptCompiler.CompileFunction(function, functionSource, fileLib, usop);
                    if (log.HasErrors)
                    {
                        MilanLog.LogUSCErrors(log);
                        MilanLog.Fatal($"Failed to compile {packageName} function {functionIFP} - this is a fatal error.");
                        Environment.Exit(1);
                    }
                }
            }

            return package.SaveToStream(BaseDeltaHandler.UseCompressedPackages).ToArray();
        }
    }
}
