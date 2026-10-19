using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling;
using LegendaryExplorerCore.UnrealScript.Language.Tree;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines;

/// <summary>Replaces serialized property sets on every matching asset in the generated mod.</summary>
internal static class AssetFixPipeline
{
    private const string LogCategory = "MILAN-AssetFix";
    private static string FixFolder => Path.Combine(MilanShared.PipelineRoot, "AssetFixes");

    public static void RunPipeline()
    {
        if (!Directory.Exists(FixFolder))
        {
            MilanLog.Information($"No asset fix folder at {FixFolder}", customPrefix: LogCategory);
            return;
        }

        // A filename is the complete memory path of the export, independent of the containing package.
        // Subfolders only organize fixes; they are not part of the matching path.
        var fixes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var file in Directory.EnumerateFiles(FixFolder, "*.uc", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase))
        {
            var path = Path.GetFileNameWithoutExtension(file);
            if (!fixes.TryAdd(path, File.ReadAllText(file)))
            {
                throw new InvalidDataException($"Duplicate asset fix for {path}: {file}");
            }
        }
        if (fixes.Count == 0)
        {
            // Do nothing.
            return;
        }

        var matched = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        int changedPackages = 0, changedExports = 0;
        MilanShared.RefreshMilanFiles = true;
        // Reuse resolved dependencies across the entire scan, with the existing global/MPCommon
        // tiers as parents. Only this pipeline-owned child is disposed at the end of the run.
        using var cache = MilanShared.GetMPCommonTieredPackageCache()
            .ChainNewCache(debugName: "AssetFix pipeline cache");
        foreach (var file in Directory.EnumerateFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories).Order(StringComparer.OrdinalIgnoreCase))
        {
            // Most packages have no matching exports. Read their tables without loading export data to quickly
            // 
            using (var header = MEPackageHandler.UnsafePartialLoad(file, _ => false))
            {
                if (!header.Exports.Any(e => fixes.ContainsKey(e.InstancedFullPath)))
                {
                    // Nothing in this file, skip
                    continue;
                }
            }


            using var package = MEPackageHandler.OpenMEPackage(file, forceLoadFromDisk: true);
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

            int changed = 0;
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
            // A failure above leaves this package unsaved. Identical fixes do not rewrite the file.
            if (changed > 0)
            {
                package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                changedPackages++;
                changedExports += changed;
            }
        }

        foreach (var path in fixes.Keys.Where(path => !matched.Contains(path)))
        {
            MilanLog.Warning($"Asset fix matched no exports: {path}", customPrefix: LogCategory);
        }
        MilanLog.Information($"Fixed {changedExports} exports in {changedPackages} packages ({matched.Count}/{fixes.Count} fix paths matched)", customPrefix: LogCategory);
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
