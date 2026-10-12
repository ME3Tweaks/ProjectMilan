using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;
using Serilog;
using System;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Handles applying BaseDelta UnrealScript sources onto a vanilla package so it can be used in caches down the pipe.
    /// </summary>
    internal class ScriptPackagePatchTarget : IBasePatchClass
    {
        private readonly string packageName;
        private readonly string logCategory;
        private readonly Action? preBuild;
        private readonly Action<IMEPackage>? postCompile;

        /// <param name="preBuild">
        /// Optional step run before the package is patched - for generating BaseDelta inputs (e.g. Scaleform SWFs).
        /// Runs whenever this target is built from source, including a checkpoint restore that has no patch for it,
        /// and is skipped when the target is restored from its checkpointed patch.
        /// </param>
        /// <param name="postCompile">
        /// Optional step run on the package after all UnrealScript has been compiled in, just before it is
        /// serialized - for edits that depend on the compiled script (e.g. registering new functions in defaults).
        /// </param>
        public ScriptPackagePatchTarget(string packageName, string comment, Action? preBuild = null, Action<IMEPackage>? postCompile = null)
        {
            this.packageName = packageName;
            logCategory = $"Milan-{packageName}";
            Comment = comment;
            this.preBuild = preBuild;
            this.postCompile = postCompile;
        }

        public string GameFile => $"{packageName}.pcc";

        public string Comment { get; }

        private string GetVanillaLoadPath() => BaseDeltaHandler.GetVanillaCookedFilePath(GameFile);

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
            preBuild?.Invoke();

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
                // sorting this is a bit hacky, should probably have a manifest
                foreach (var cls in Directory.GetFiles(classFolder, "*.uc", searchOption: SearchOption.AllDirectories).OrderBy(f => f))
                {
                    var className = Path.GetFileNameWithoutExtension(cls);
                    var classExport = package.FindExport(className);
                    IEntry classParent = null;
                    if (!Path.GetDirectoryName(cls).EndsWith(classFolder))
                    {
                        var classParentName = Directory.GetParent(cls)?.Name;
                        classParent = ExportCreator.CreatePackageExport(package, classParentName, forcedExport: true);
                        var classParentExport = (ExportEntry)classParent;
                        classParentExport.PackageFlags = (UnrealFlags.EPackageFlags.AllowDownload |
                                                          UnrealFlags.EPackageFlags.NoExportsData);
                        classParentExport.PackageGUID = GetAddedPackageGuid(classParentName);
                        

                    }

                    MilanLog.Information($"Compiling class {(classParent.IsNull() ? "" : $"{classParent?.ObjectNameString}.")}{className}", customPrefix: logCategory);
                    var classSource = File.ReadAllText(cls);
                    var (_, log) = UnrealScriptCompiler.CompileClass(package, classSource, fileLib, usop, export: classExport, parent: classParent);
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
                    if (function == null)
                    {
                        MilanLog.Fatal($"{packageName} has no existing function {functionIFP} to replace - new functions go in AddToClassOrReplace/{functionIFP}.uc. This is a fatal error.");
                        Environment.Exit(1);
                    }

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

            // Currently only full default property replaces are supported
            var propFolder = Path.Combine(baseDeltaFolder, "DefaultProperties");
            if (Directory.Exists(propFolder))
            {
                foreach (var prop in Directory.GetFiles(propFolder, "*.uc"))
                {
                    var propName = Path.GetFileNameWithoutExtension(prop);
                    var propExport = package.FindExport(propName);

                    MilanLog.Information($"Compiling property {propName}", customPrefix: logCategory);
                    var propSource = File.ReadAllText(prop);
                    var (_, log) = UnrealScriptCompiler.CompileDefaultProperties(propExport, propSource, fileLib, usop);
                    if (log.HasErrors)
                    {
                        MilanLog.LogUSCErrors(log);
                        MilanLog.Fatal($"Failed to compile {packageName} property {propName} - this is a fatal error.");
                        Environment.Exit(1);
                    }
                }
            }

            ApplyPropertyUpdates(package, baseDeltaFolder, packageName, logCategory);

            var atcorFolder = Path.Combine(baseDeltaFolder, "AddToClassOrReplace");
            if (Directory.Exists(atcorFolder))
            {
                foreach (var atcor in Directory.GetFiles(atcorFolder, "*.uc"))
                {
                    var atcorName = Path.GetFileNameWithoutExtension(atcor);
                    var atcorExport = package.FindExport(atcorName.Split(".")[0]);

                    // AddOrReplaceInClass decompiles the whole class and recompiles it, reading member bytecode
                    // through FileLib's object binary cache - which still holds what was there at Initialize.
                    // Without a re-init, any Functions/ override in this class (or an earlier element added
                    // here) is silently reverted to its stale cached body.
                    if (!fileLib.ReInitializeFile(usop))
                    {
                        MilanShared.LogFailedFileLibInit(fileLib);
                        MilanLog.Fatal($"Unable to re-initialize the FileLib for {packageName} before compiling {atcorName} - this is a fatal error.");
                        Environment.Exit(1);
                    }

                    MilanLog.Information($"Compiling class element {atcorName}", customPrefix: logCategory);
                    var atorSource = File.ReadAllText(atcor);
                    var log = UnrealScriptCompiler.AddOrReplaceInClass(atcorExport, atorSource, fileLib, usop);
                    if (log.HasErrors)
                    {
                        MilanLog.LogUSCErrors(log);
                        MilanLog.Fatal($"Failed to compile {packageName} class {atcorName} - this is a fatal error.");
                        Environment.Exit(1);
                    }
                }
            }

            // Runs last so no class recompile above can undo it.
            postCompile?.Invoke(package);

            return package.SaveToStream(BaseDeltaHandler.UseCompressedPackages).ToArray();
        }

        /// <summary>
        /// Applies every file in <paramref name="baseDeltaFolder"/>/PropertyUpdate to the export named by its
        /// filename (minus extension) - swf and bnk only for now.
        /// </summary>
        internal static void ApplyPropertyUpdates(IMEPackage package, string baseDeltaFolder, string packageName, string logCategory)
        {
            var propUpdateFolder = Path.Combine(baseDeltaFolder, "PropertyUpdate");
            if (!Directory.Exists(propUpdateFolder))
                return;

            foreach (var prop in Directory.GetFiles(propUpdateFolder, "*"))
            {
                var propExtension = Path.GetExtension(prop);
                var propName = Path.GetFileNameWithoutExtension(prop);
                var propExport = package.FindExport(propName);
                if (propExport == null)
                {
                    MilanLog.Fatal($"{packageName} has no export {propName} to update from PropertyUpdate/{Path.GetFileName(prop)} - this is a fatal error.", customPrefix: logCategory);
                    Environment.Exit(1);
                }

                var propSource = File.ReadAllBytes(prop);

                switch (propExtension)
                {
                    case ".swf":
                        MilanLog.Information($"Updating property in {propName}", customPrefix: logCategory);
                        var data = new ImmutableByteArrayProperty(propSource, "RawData");
                        propExport.WriteProperty(data);
                        break;
                    case ".bnk":
                        MilanLog.Information($"Updating WwiseBank {propName}", customPrefix: logCategory);
                        ObjectBinary.EditBinary<WwiseBank>(propExport, binary => { binary.BnkFile = propSource; });
                        break;
                    case ".uc": // TODO: property update for individual properties
                    default:
                        MilanLog.Warning($"{propExtension} files are not currently supported with property update!", customPrefix: logCategory);
                        break;
                }
            }
        }

        private static Guid GetAddedPackageGuid(string name)
        {
            return new Guid(System.Security.Cryptography.MD5.HashData(
                System.Text.Encoding.UTF8.GetBytes($"ProjectMilan.{name.ToUpperInvariant()}")));
        }

    }
}
