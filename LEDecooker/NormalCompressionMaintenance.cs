using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;

namespace LEDecooker;

/// <summary>Normal-parameter maintenance for existing packages; no T3D compilation or corpus rebuild.</summary>
public static class NormalCompressionMaintenance
{
    private static readonly JsonSerializerOptions ReportOptions = new()
    {
        Converters = { new JsonStringEnumConverter() }
    };

    /// <summary>Caller owns the package. Applies verified corrections in memory, without saving it.</summary>
    public static IReadOnlyList<NormalCompressionFinding> FixPackage(IMEPackage package)
    {
        using var cache = new PackageCache();
        var findings = NormalCompressionHelper.FixNormalCompressionOverrides(package, CreateResolver(package, cache));
        LogFindings(package, findings);
        return findings;
    }

    /// <summary>Caller owns the package. Read-only analysis, including destination-specific texture encodings.</summary>
    public static IReadOnlyList<NormalCompressionFinding> AnalyzePackage(IMEPackage package)
    {
        using var cache = new PackageCache();
        return NormalCompressionHelper.AnalyzeNormalCompressionOverrides(package, CreateResolver(package, cache));
    }

    internal static Func<IEntry, ExportEntry> CreateResolver(IMEPackage package, PackageCache cache)
    {
        var folder = Path.GetDirectoryName(package.FilePath)!;
        return Resolve;

        ExportEntry Resolve(IEntry entry)
        {
            if (entry is ExportEntry export) return export;
            if (entry is not ImportEntry import) return null!;
            // Prefer the assembled sibling assets, including UDK packages whose self package export
            // was removed during conversion. Never resolve a UDK import against an LE3 donor.
            var rootName = import.GetRoot().ObjectName.Name;
            foreach (var extension in new[] { ".pcc", ".upk" })
            {
                var sibling = Path.Combine(folder, rootName + extension);
                if (!File.Exists(sibling)) continue;
                var donor = cache.GetCachedPackage(sibling);
                if (donor.Game != package.Game) continue;
                var fullPath = import.InstancedFullPath;
                var resolved = donor.FindExport(fullPath);
                int separator = fullPath.IndexOf('.');
                if (resolved == null && separator >= 0) resolved = donor.FindExport(fullPath[(separator + 1)..]);
                if (resolved != null && resolved.ClassName.Equals(import.ClassName, StringComparison.OrdinalIgnoreCase)) return resolved;
            }
            return EntryImporter.ResolveImport(import, cache, fileResolver: (name, resolverCache) =>
            {
                var siblingPath = Path.Combine(folder, Path.GetFileName(name));
                return File.Exists(siblingPath) ? resolverCache.GetCachedPackage(siblingPath) : null;
            });
        }
    }

    private static void LogFindings(IMEPackage package, IReadOnlyList<NormalCompressionFinding> findings)
    {
        foreach (var finding in findings.Where(f => f.Applied))
            DecookerLog.Information($"Normal compression: {finding.InstancePath} [{finding.Quality}] {finding.ParameterName}: "
                + $"{finding.StoredCompression} -> {finding.ExpectedCompression} ({finding.TextureCompression}, {finding.TexturePath})");
        foreach (var finding in findings.Where(f => f.Status is NormalCompressionStatus.Unresolved or NormalCompressionStatus.Unsupported))
            DecookerLog.Warning($"Normal compression {finding.Status}: {finding.InstancePath} {finding.ParameterName}: {finding.Reason}");
        if (findings.Count > 0)
            DecookerLog.Information($"{package.FileNameNoExtension}: examined {findings.Count} normal entries, corrected "
                + $"{findings.Count(f => f.Applied)}, unresolved {findings.Count(f => f.Status == NormalCompressionStatus.Unresolved)}, "
                + $"unsupported {findings.Count(f => f.Status == NormalCompressionStatus.Unsupported)}");
    }

    /// <summary>
    /// Audits or repairs a file/folder, backs up each changed file, and saves only changed packages.
    /// The report records each finding and saved-file verification. Returns false if any package failed.
    /// </summary>
    public static bool ProcessPackages(string inputPath, bool apply, string reportPath,
        string backupDirectory, IEnumerable<string>? packageNames = null)
    {
        var selected = packageNames?.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var files = File.Exists(inputPath) ? new[] { Path.GetFullPath(inputPath) }
            : Directory.GetFiles(inputPath).Where(f => Path.GetExtension(f).Equals(".pcc", StringComparison.OrdinalIgnoreCase)
                || Path.GetExtension(f).Equals(".upk", StringComparison.OrdinalIgnoreCase)).Order().ToArray();
        if (selected is { Count: > 0 }) files = files.Where(f => selected.Contains(Path.GetFileNameWithoutExtension(f))).ToArray();
        if (files.Length == 0) throw new InvalidOperationException("No packages selected for normal-compression maintenance.");
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(reportPath))!);
        using var report = new StreamWriter(new FileStream(reportPath, FileMode.CreateNew, FileAccess.Write));
        int changed = 0, corrected = 0, failures = 0;
        var statuses = new Dictionary<NormalCompressionStatus, int>();
        foreach (var file in files)
        {
            string? backupPath = null;
            bool saveAttempted = false;
            try
            {
                using var package = MEPackageHandler.OpenMEPackage(file);
                using var cache = new PackageCache();
                var resolver = CreateResolver(package, cache);
                var findings = apply ? NormalCompressionHelper.FixNormalCompressionOverrides(package, resolver)
                    : NormalCompressionHelper.AnalyzeNormalCompressionOverrides(package, resolver);
                bool verified = true;
                if (findings.Any(f => f.Applied))
                {
                    Directory.CreateDirectory(backupDirectory);
                    backupPath = Path.Combine(backupDirectory, Path.GetFileName(file));
                    File.Copy(file, backupPath, overwrite: false);
                    if (!SHA256.HashData(File.ReadAllBytes(file)).SequenceEqual(SHA256.HashData(File.ReadAllBytes(backupPath))))
                        throw new IOException("Per-package backup verification failed.");
                    saveAttempted = true;
                    package.Save();
                    using var saved = MEPackageHandler.OpenMEPackage(file);
                    using var verificationCache = new PackageCache();
                    var after = NormalCompressionHelper.AnalyzeNormalCompressionOverrides(saved, CreateResolver(saved, verificationCache));
                    verified = findings.Where(f => f.Applied).All(f => after.Any(a => a.InstancePath == f.InstancePath
                        && a.Quality == f.Quality && a.ParameterIndex == f.ParameterIndex && a.ExpressionGuid == f.ExpressionGuid
                        && a.StoredCompression == f.ExpectedCompression && a.Status == NormalCompressionStatus.Match));
                    if (!verified) throw new InvalidDataException("Saved normal corrections failed read-back verification.");
                    changed++;
                    corrected += findings.Count(f => f.Applied);
                }
                foreach (var finding in findings) statuses[finding.Status] = statuses.GetValueOrDefault(finding.Status) + 1;
                report.WriteLine(JsonSerializer.Serialize(new { package = file, backupPath, apply, verified, findings }, ReportOptions));
                report.Flush();
                LogFindings(package, findings);
            }
            catch (Exception ex)
            {
                // A failed save or verification must not leave a partially repaired input behind.
                if (saveAttempted && backupPath != null) File.Copy(backupPath, file, overwrite: true);
                failures++;
                report.WriteLine(JsonSerializer.Serialize(new { package = file, restoredBackup = saveAttempted ? backupPath : null, error = ex.ToString() }, ReportOptions));
                report.Flush();
                DecookerLog.Error($"Normal compression failed for {file}: {ex.Message}");
            }
        }
        var summary = new { packages = files.Length, changedPackages = changed, correctedParameters = corrected, failures,
            statuses = statuses.ToDictionary(kv => kv.Key.ToString(), kv => kv.Value) };
        report.WriteLine(JsonSerializer.Serialize(new { summary }, ReportOptions));
        DecookerLog.Information(JsonSerializer.Serialize(summary, ReportOptions));
        return failures == 0;
    }
}
