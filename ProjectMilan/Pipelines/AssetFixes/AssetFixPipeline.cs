using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling;
using LegendaryExplorerCore.UnrealScript.Language.Tree;
using ProjectMilanCore;
using ProjectMilan.Pipelines.Startups;

namespace ProjectMilan.Pipelines;

/// <summary>Applies property/mesh fixes and GUI texture mip/residency policy across the generated mod.</summary>
internal static class AssetFixPipeline
{
    private const string LogCategory = "MILAN-AssetFix";
    private static string FixFolder => Path.Combine(MilanShared.PipelineRoot, "AssetFixes");

    public static void RunPipeline()
    {
        if (!Directory.Exists(FixFolder))
        {
            MilanLog.Information($"No asset fix folder at {FixFolder}", customPrefix: LogCategory);
        }

        var guiTextures = GUITextureMipper.DiscoverTexturePaths(Program.Settings.OutputModPath);
        var guiPackages = new List<string>();

        // A filename is the complete memory path of the export, independent of the containing package.
        // Subfolders only organize fixes; they are not part of the matching path.
        var fixes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var file in (Directory.Exists(FixFolder) ? Directory.EnumerateFiles(FixFolder, "*.uc", SearchOption.AllDirectories) : Enumerable.Empty<string>()).Order(StringComparer.OrdinalIgnoreCase))
        {
            var path = Path.GetFileNameWithoutExtension(file);
            if (!fixes.TryAdd(path, File.ReadAllText(file)))
            {
                throw new InvalidDataException($"Duplicate asset fix for {path}: {file}");
            }
        }
        var meshFixes = AssetMeshFixes.DiscoverFixes(FixFolder);
        if (fixes.Count == 0 && meshFixes.Count == 0 && guiTextures.Count == 0)
        {
            // Do nothing.
            return;
        }

        var matched = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var matchedMeshes = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        int changedPackages = 0, changedExports = 0;
        MilanShared.RefreshMilanFiles = true;
        // Reuse resolved dependencies across the entire scan, with the existing global/MPCommon
        // tiers as parents. Only this pipeline-owned child is disposed at the end of the run.
        using var cache = MilanShared.GetMPCommonTieredPackageCache()
            .ChainNewCache(debugName: "AssetFix pipeline cache");
        foreach (var file in Directory.EnumerateFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase))
        {
            // Most packages have no matching exports; inspect their tables before loading export data.
            using (var header = MEPackageHandler.UnsafePartialLoad(file, _ => false))
            {
                if (!header.Exports.Any(e => fixes.ContainsKey(e.InstancedFullPath) || meshFixes.ContainsKey(e.InstancedFullPath) ||
                    (e.ClassName == "Texture2D" && guiTextures.Contains(e.InstancedFullPath))))
                {
                    // Nothing in this file, skip
                    continue;
                }
            }


            using var package = MEPackageHandler.OpenMEPackage(file, forceLoadFromDisk: true);
            int changed = 0;
            // Import first so an accompanying .uc fix can override generated mesh properties.
            foreach (var export in package.Exports.Where(e => meshFixes.ContainsKey(e.InstancedFullPath)).ToArray())
            {
                string path = export.InstancedFullPath;
                matchedMeshes.Add(path);
                if (AssetMeshFixes.ApplyFix(export, meshFixes[path]))
                {
                    changed++;
                    MilanLog.Information($"{package.FileNameNoExtension}: replaced mesh {path}", customPrefix: LogCategory);
                }
            }
            if (package.Exports.Any(e => fixes.ContainsKey(e.InstancedFullPath)))
            {
                var options = new UnrealScriptOptionsPackage
                {
                    Cache = cache,
                    CustomFileResolver = MilanShared.LE3PackageResolver,
                    MissingObjectResolver = MilanShared.MissingObjectResolver,
                    GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                    BaseFilesFileLib = LE3FileLibCache.GetBaseFilesFileLibFor(package),
                };
                using var lib = new FileLib(package);
                if (!lib.Initialize(options))
                {
                    MilanShared.LogFailedFileLibInit(lib);
                    throw new InvalidDataException($"Unable to initialize the asset fix FileLib for {file}");
                }

                // Compilation can add imports; the targets are the exports present before any fixes.
                foreach (var export in package.Exports.Where(e => fixes.ContainsKey(e.InstancedFullPath)).ToArray())
                {
                    string path = export.InstancedFullPath;
                    matched.Add(path);
                    if (ApplyPropertyFix(export, fixes[path], lib, options))
                    {
                        changed++;
                        MilanLog.Information($"{package.FileNameNoExtension}: fixed {path}", customPrefix: LogCategory);
                    }
                }
            }
            if (package.Exports.Any(e => e.ClassName == "Texture2D" && guiTextures.Contains(e.InstancedFullPath)))
            {
                guiPackages.Add(file);
                changed += GUITextureMipper.GenerateMipsForPackage(package, guiTextures);
            }
            // A failure above leaves this package unsaved. Save only packages with changed export data.
            if (changed > 0)
            {
                package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                changedPackages++;
                changedExports += changed;
            }
        }

        GUITextureMipper.VerifyTexturesAreConsistent(guiPackages, guiTextures);
        foreach (var path in fixes.Keys.Where(path => !matched.Contains(path)))
        {
            MilanLog.Warning($"Asset fix matched no exports: {path}", customPrefix: LogCategory);
        }
        foreach (var path in meshFixes.Keys.Where(path => !matchedMeshes.Contains(path)))
        {
            MilanLog.Warning($"Mesh asset fix matched no exports: {path}", customPrefix: LogCategory);
        }
        MilanLog.Information($"Fixed {changedExports} exports in {changedPackages} packages ({matched.Count}/{fixes.Count} property fix paths, {matchedMeshes.Count}/{meshFixes.Count} mesh fix paths matched)", customPrefix: LogCategory);
    }

    /// <summary>
    /// Replaces the complete serialized property set. Omitted properties are removed. This also supports
    /// defaults without rebuilding their class or deleting child exports; binary data is preserved.
    /// </summary>
    internal static bool ApplyPropertyFix(ExportEntry export, string source, FileLib lib, UnrealScriptOptionsPackage options)
    {
        if (export.IsClass)
        {
            throw new InvalidDataException($"Asset fixes target objects, not class exports: {export.InstancedFullPath}");
        }

        var (ast, log) = UnrealScriptCompiler.CompileDefaultProperties(export, source, lib, options, noCompile: true);
        if (log.HasErrors || log.HasLexErrors || ast is not DefaultPropertiesBlock block)
        {
            MilanLog.LogUSCErrors(log);
            throw new InvalidDataException($"Invalid asset fix for {export.InstancedFullPath} in {export.FileRef.FilePath}");
        }
        if (block.Statements.Any(statement => statement is not AssignStatement))
        {
            throw new InvalidDataException($"Asset fixes only support property assignments, not subobjects: {export.InstancedFullPath}");
        }

        var originalData = export.Data.ToArray();
        try
        {
            // The normal-object compiler writes only the supplied properties. Using it for defaults
            // deliberately avoids CompileDefault__Object's subobject reconstruction/pruning.
            ScriptPropertiesCompiler.CompilePropertiesForNormalObject(block.Statements, export, options);
            return !originalData.AsSpan().SequenceEqual(export.Data);
        }
        catch
        {
            export.Data = originalData;
            throw;
        }
    }
}
