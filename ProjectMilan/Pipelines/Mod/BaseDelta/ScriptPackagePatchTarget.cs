using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.Collections;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;
using Serilog;
using System;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Textures;
using Image = LegendaryExplorerCore.Textures.Image;
using ProjectMilan.Utility;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using ProjectMilan.Pipelines.Startups;

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
            var vanillaVTables = VTableCascade.ReadAllSlots(package);

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

            // Some subclasses need a new superclass member to exist before their Classes/ source compiles.
            if (ApplyClassElements(package, fileLib, usop, Path.Combine(baseDeltaFolder, "EarlyAddToClassOrReplace")))
            {
                if (!fileLib.ReInitializeFile(usop))
                {
                    MilanShared.LogFailedFileLibInit(fileLib);
                    MilanLog.Fatal($"Unable to re-initialize the FileLib for {packageName} after early class elements - this is a fatal error.");
                    Environment.Exit(1);
                }
            }

            var classFolder = Path.Combine(baseDeltaFolder, "Classes");
            bool compiledClasses = false;
            if (Directory.Exists(classFolder))
            {
                // Packages this build added for Classes/<Package>/ folders, by name
                var addedPackages = new Dictionary<string, ExportEntry>(StringComparer.OrdinalIgnoreCase);

                // sorting this is a bit hacky, should probably have a manifest
                foreach (var cls in Directory.GetFiles(classFolder, "*.uc", searchOption: SearchOption.AllDirectories).OrderBy(f => f))
                {
                    // a prefix that ends with a dash (-) allows us to make sure certain classes build before others. Not very pretty, but it works 
                    string className;
                    if (cls.Contains('-'))
                    {
                        className = Path.GetFileNameWithoutExtension(cls.Split("-")[1]);
                    }
                    else
                    {
                        className = Path.GetFileNameWithoutExtension(cls);
                    }
                    ExportEntry? classExport = null;
                    IEntry? classParent = null;
                    var relativeFolder = Path.GetRelativePath(classFolder, Path.GetDirectoryName(cls)!);
                    if (relativeFolder == ".")
                    {
                        // Classes/<Class>.uc: a class at the root of the file, new or replacing a vanilla one
                        classExport = package.FindExport(className);
                    }
                    else
                    {
                        // Classes/<Package>/<Class>.uc: a new class in its own forced-export package
                        if (relativeFolder.Contains(Path.DirectorySeparatorChar) || relativeFolder.Contains(Path.AltDirectorySeparatorChar))
                        {
                            MilanLog.Fatal($"{packageName} class {className} is nested too deep (Classes/{relativeFolder.Replace('\\', '/')}) - classes go in Classes/ or Classes/<Package>/. This is a fatal error.", customPrefix: logCategory);
                            Environment.Exit(1);
                        }

                        if (package.FindExport(className) != null)
                        {
                            MilanLog.Fatal($"{packageName} already has a class {className}, so it can't also be added to package {relativeFolder} - edit it in Classes/{className}.uc or rename it. This is a fatal error.", customPrefix: logCategory);
                            Environment.Exit(1);
                        }

                        classParent = GetOrCreateAddedPackage(package, relativeFolder, addedPackages);
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
                    compiledClasses = true;
                }
            }

            var functionFolder = Path.Combine(baseDeltaFolder, "Functions");
            if (Directory.Exists(functionFolder))
            {
                if (compiledClasses)
                {
                    // We need to re-init the FileLib so that any new functions added to classes above are visible to the function compiler.
                    if (!fileLib.ReInitializeFile(usop))
                    {
                        MilanShared.LogFailedFileLibInit(fileLib);
                        MilanLog.Fatal($"Unable to re-initialize the FileLib for {packageName} before compiling functions - this is a fatal error.");
                        Environment.Exit(1);
                    }
                }

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
            ApplyTextureUpdates(package, baseDeltaFolder, packageName, logCategory);
            ApplyGUIMips(package, packageName, logCategory);

            ApplyClassElements(package, fileLib, usop, Path.Combine(baseDeltaFolder, "AddToClassOrReplace"));

            // After all script: subclasses of a class that gained functions need their vtables and the calls into them updated.
            BaseDeltaVTables.Apply(package, fileLib, usop, vanillaVTables, logCategory);

            // Runs last so no class recompile above can undo it.
            postCompile?.Invoke(package);

            // After every edit: numbers what was added (including the class packages above) past each linker's vanilla indexes.
            BaseDeltaNetIndexing.Apply(package, GameFile);

            return package.SaveToStream(BaseDeltaHandler.UseCompressedPackages).ToArray();
        }

        /// <summary>
        /// Applies class members from a folder. EarlyAddToClassOrReplace runs before Classes/ so
        /// subclasses can override new superclass hooks; AddToClassOrReplace keeps its late position.
        /// </summary>
        private bool ApplyClassElements(IMEPackage package, FileLib fileLib, UnrealScriptOptionsPackage usop, string folder)
        {
            if (!Directory.Exists(folder))
                return false;

            bool applied = false;
            foreach (var atcor in Directory.GetFiles(folder, "*.uc").OrderBy(f => f))
            {
                // a prefix that ends with a dash (-) allows us to make sure certain classes build before others. Not very pretty, but it works
                string atcorName;
                if (atcor.Contains('-'))
                {
                    atcorName = Path.GetFileNameWithoutExtension(atcor.Split("-")[1]);
                }
                else
                {
                    atcorName = Path.GetFileNameWithoutExtension(atcor);
                }
                var atcorExport = package.FindExport(atcorName.Split(".")[0]);
                if (atcorExport == null)
                {
                    MilanLog.Fatal($"{packageName} has no class for {atcorName} in {folder} - this is a fatal error.");
                    Environment.Exit(1);
                    return false;
                }

                // AddOrReplaceInClass reads the whole class through FileLib's binary cache
                // Refresh before each member so earlier function overrides and added members are visible
                if (!fileLib.ReInitializeFile(usop))
                {
                    MilanShared.LogFailedFileLibInit(fileLib);
                    MilanLog.Fatal($"Unable to re-initialize the FileLib for {packageName} before compiling {atcorName} - this is a fatal error.");
                    Environment.Exit(1);
                }

                MilanLog.Information($"Compiling class element {atcorName}", customPrefix: logCategory);
                var source = File.ReadAllText(atcor);
                var log = UnrealScriptCompiler.AddOrReplaceInClass(atcorExport, source, fileLib, usop);
                if (log.HasErrors)
                {
                    MilanLog.LogUSCErrors(log);
                    MilanLog.Fatal($"Failed to compile {packageName} class {atcorName} - this is a fatal error.");
                    Environment.Exit(1);
                }
                applied = true;
            }
            return applied;
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

        /// <summary>
        /// Replaces the texture named by each file's name (minus extension) in <paramref name="baseDeltaFolder"/>/TextureUpdate
        /// with that image, package stored and in the texture's existing format.
        /// </summary>
        internal static void ApplyTextureUpdates(IMEPackage package, string baseDeltaFolder, string packageName, string logCategory)
        {
            var textureUpdateFolder = Path.Combine(baseDeltaFolder, "TextureUpdate");
            if (!Directory.Exists(textureUpdateFolder))
                return;

            foreach (var file in Directory.GetFiles(textureUpdateFolder, "*"))
            {
                var texName = Path.GetFileNameWithoutExtension(file);
                var texExport = package.FindExport(texName);
                if (texExport?.ClassName != "Texture2D")
                {
                    MilanLog.Fatal($"{packageName} has no Texture2D {texName} to replace from TextureUpdate/{Path.GetFileName(file)} - this is a fatal error.", customPrefix: logCategory);
                    Environment.Exit(1);
                }

                MilanLog.Information($"Replacing texture {texName}", customPrefix: logCategory);
                var messages = new Texture2D(texExport).Replace(Image.LoadFromFile(file, PixelFormat.ARGB), texExport.GetProperties(), isPackageStored: true);
                foreach (var message in messages)
                    MilanLog.Warning($"{texName}: {message}", customPrefix: logCategory);
            }
        }

        /// <summary>
        /// Mips the GUI textures listed for this package in <see cref="GUITextureMipper.BaseDeltaTexturePaths"/>, after any
        /// TextureUpdate has replaced them.
        /// </summary>
        internal static void ApplyGUIMips(IMEPackage package, string packageName, string logCategory)
        {
            var missing = GUITextureMipper.MipBaseDeltaPackage(package, packageName);
            if (missing.Count > 0)
            {
                MilanLog.Fatal($"{packageName} has no Texture2D for GUI mip path(s) {string.Join(", ", missing)} in GUITextureMipper.BaseDeltaTexturePaths - this is a fatal error.", customPrefix: logCategory);
                Environment.Exit(1);
            }
        }

        /// <summary>
        /// Returns the forced-export package a Classes/&lt;Package&gt;/ folder compiles into, creating it the first time. The name
        /// must be new to the file: reusing a vanilla export would put our classes into (or under) something we don't own.
        /// </summary>
        private ExportEntry GetOrCreateAddedPackage(IMEPackage package, string name, Dictionary<string, ExportEntry> addedPackages)
        {
            if (addedPackages.TryGetValue(name, out var existing))
                return existing;

            if (package.FindExport(name) != null)
            {
                MilanLog.Fatal($"{packageName} already has an export named {name} - a Classes/<Package>/ folder must name a new package. This is a fatal error.", customPrefix: logCategory);
                Environment.Exit(1);
            }

            var packageExport = ExportCreator.CreatePackageExport(package, NameReference.FromInstancedString(name), forcedExport: true, reuseExisting: false);
            packageExport.PackageFlags = UnrealFlags.EPackageFlags.AllowDownload | UnrealFlags.EPackageFlags.NoExportsData;
            packageExport.PackageGUID = Utilities.GenerateNewPackageGuid(name);
            addedPackages[name] = packageExport;
            MilanLog.Information($"Added package {name}", customPrefix: logCategory);
            return packageExport;
        }

    }
}
