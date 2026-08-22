using BankConverter.Bnk;
using BankConverter.Bnk.Chunks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ME3Tweaks.Wwiser;
using System.Collections.Concurrent;
using System.Security.Cryptography;

namespace ProjectMilan.Pipelines.Audio;

internal static class AudioPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio";

    public static void RunPipeline()
    {
        InternalRunPipeline();
    }

    /// <summary>
    /// Deletes the on-disk converted-WEM cache, forcing a full re-conversion of all audio on the next pipeline run.
    /// </summary>
    public static void Clean()
    {
        AFCHandler.ClearDiskCache();
    }

    /// <summary>
    /// Skipped-HIRC-object counts, aggregated across every unique bank converted this run (keyed by the raw v56
    /// eHircType byte - see HircTypeName for what each one is). A non-empty entry here means every Event/container
    /// that referenced an object of that type now references nothing - it'll post/play without erroring, but
    /// produce silence, which looks identical to a volume/routing bug in-game unless you know to check this.
    /// </summary>
    private static readonly ConcurrentDictionary<byte, int> _aggregateSkipped = new();
    private static readonly ConcurrentBag<string> _aggregateErrors = new();

    private static string HircTypeName(byte type) => type switch
    {
        0x01 => "State",
        0x02 => "Sound",
        0x03 => "Action",
        0x04 => "Event",
        0x05 => "RandomSequenceContainer",
        0x06 => "SwitchContainer",
        0x07 => "ActorMixer",
        0x08 => "Bus",
        0x09 => "LayerContainer",
        0x0A => "MusicSegment",
        0x0B => "MusicTrack",
        0x0C => "MusicSwitchContainer",
        0x0D => "MusicRandomSequenceContainer",
        0x0E => "Attenuation",
        0x0F => "DialogueEvent",
        0x10 => "MotionBus",
        0x11 => "MotionFx",
        0x12 => "FxShareSet/Effect",
        0x13 => "FxCustom",
        0x14 => "AuxiliaryBus",
        _ => $"Unknown(0x{type:X2})",
    };

    private static void InternalRunPipeline()
    {
        AFCHandler.ResetWemCaches();
        _aggregateSkipped.Clear();
        _aggregateErrors.Clear();
        BusRemap.FallbackUses.Clear();

        // Phase 1: partial-load scan over every package - finds which ones actually contain WwiseBank exports, and
        // for each bank, gathers (without converting anything yet) every streamed/embedded WEM ID that needs
        // conversion. Must fully complete before phase 2 starts, because a bank's PrefetchStreaming source may only
        // have its full audio available via a WwiseStream living in a *different* package.
        var bankPackagePaths = GatherBanksInPackages();

        // Phase 2: batch re-encode everything gathered in phase 1 - a handful of WwiseCLI invocations (chunked) rather
        // than one per WEM, which is what made this slow. See AFCHandler.BatchConvertPending for why this isn't
        // parallelized.
        AFCHandler.BatchConvertPending();

        // Phase 3: re-open each bank-bearing package and patch its streaming WwiseStream exports to point at the
        // now-converted audio in the Milan AFCs. Packages are re-opened rather than kept open from phase 1, since
        // UnsafePartialLoad packages can't be saved and we don't want every bank-bearing package (which can be a
        // large fraction of the game) held open/in-memory across every phase.
        PatchBanksInPackages(bankPackagePaths);

        // Phase 4: convert each bank's own binary (BKHD/HIRC/DIDX/DATA) to v134, now that every WEM referenced
        // anywhere has a cached converted replacement. Packages are re-opened again for the same reason as phase 3.
        ConvertBankBodiesInPackages(bankPackagePaths);

        // We no longer need the AFC streams open.
        AFCHandler.CloseHandler();
    }

    public static bool EnsureWwise7110()
    {
        var wwisePath = Environment.GetEnvironmentVariable("WWISEROOT");
        if (wwisePath == null || !Directory.Exists(wwisePath))
        {
            MilanLog.Fatal("The Audio pipeline requires Wwise 7110 to be installed. Ensure WWISEROOT is set as an environment variable.", customPrefix: LOG_CATEGORY);
            Environment.Exit(1);
            return false;
        }

        return true;
    }

    private static List<string> GatherBanksInPackages()
    {
        var result = new ConcurrentBag<string>();
        var files = Directory.GetFileSystemEntries(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories);

        Parallel.ForEach(files, new ParallelOptions { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, pf =>
        {
            // Only need data for these 3 classes - everything AFCHandler.GatherBank needs to read, nothing else.
            var package = MEPackageHandler.UnsafePartialLoad(pf, x => x.ClassName is "WwiseBank" or "WwiseEvent" or "WwiseStream");
            var bankExports = package.Exports.Where(x => x.ClassName == @"WwiseBank").ToList();
            if (bankExports.Count == 0) return;

            result.Add(pf);
            foreach (var exp in bankExports)
            {
                AFCHandler.GatherBank(exp);
            }
        });

        MilanLog.Information($"Found {result.Count} package(s) containing WwiseBanks", customPrefix: LOG_CATEGORY);
        return result.ToList();
    }

    private static void PatchBanksInPackages(List<string> packagePaths)
    {
        Parallel.ForEach(packagePaths, new ParallelOptions { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, pf =>
        {
            using var package = MEPackageHandler.OpenMEPackage(pf, forceLoadFromDisk: true);
            var modified = false;
            foreach (var exp in package.Exports.Where(x => x.ClassName == @"WwiseBank").ToList())
            {
                modified |= AFCHandler.PatchBank(exp);
            }

            if (modified)
            {
                MilanLog.Information($"Patched WwiseBank exports in {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                package.Save();
            }
        });
    }

    private static void ConvertBankBodiesInPackages(List<string> packagePaths)
    {
        // Snapshotted once and reused for every bank - rebuilding per-bank would be O(banks * unique WEM count).
        var prefetchFragments = AFCHandler.SnapshotPrefetchFragments();
        var embeddedReplacements = AFCHandler.SnapshotEmbeddedReplacements();

        // Many packages reference byte-identical bank data; converting is comparatively expensive, so dedupe by content hash.
        var bankBinaryCache = new ConcurrentDictionary<string, Lazy<byte[]>>();

        Parallel.ForEach(packagePaths, new ParallelOptions { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, pf =>
        {
            using var package = MEPackageHandler.OpenMEPackage(pf, forceLoadFromDisk: true);
            var modified = false;
            foreach (var exp in package.Exports.Where(x => x.ClassName == @"WwiseBank").ToList())
            {
                var bankBin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(exp);
                if (bankBin.BnkFile.Length == 0)
                {
                    MilanLog.Error($"Invalid 0-length bank: {exp.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                using (var versionStream = new MemoryStream(bankBin.BnkFile, writable: false))
                {
                    if (WwiseBankParser.GetWwiseBankVersion(versionStream) != 56) continue; // already converted (or not ours to touch)
                }

                var hash = Convert.ToHexString(SHA256.HashData(bankBin.BnkFile));
                var convertedBytes = bankBinaryCache.GetOrAdd(hash, _ => new Lazy<byte[]>(() =>
                    ConvertBankBytes(exp, bankBin.BnkFile, prefetchFragments, embeddedReplacements))).Value;

                bankBin.BnkFile = convertedBytes;
                exp.WriteBinary(bankBin);
                MilanLog.Information($"Converted WwiseBank {exp.InstancedFullPath} to v134", customPrefix: LOG_CATEGORY);
                modified = true;
            }

            if (modified)
            {
                package.Save();
            }
        });

        LogConversionDiagnosticsSummary();
    }

    private static byte[] ConvertBankBytes(ExportEntry bankExport, byte[] rawV56Bytes, Dictionary<uint, byte[]> prefetchFragments, Dictionary<uint, byte[]> embeddedReplacements)
    {
        var stats = new HircConversionStats();
        var missingWems = new List<uint>();
        var bank = BankFile.ReadV56(rawV56Bytes);
        var converted = bank.ConvertToV134(stats, wemReplacements: embeddedReplacements, missingWems: missingWems, prefetchFragments: prefetchFragments);

        if (missingWems.Count > 0)
        {
            MilanLog.Warning($"Bank {bankExport.InstancedFullPath}: {missingWems.Distinct().Count()} WEM id(s) had no converted replacement and were left unconverted (still v56 audio - WILL crash on playback)", customPrefix: LOG_CATEGORY);
        }

        foreach (var (type, count) in stats.Skipped)
        {
            _aggregateSkipped.AddOrUpdate(type, count, (_, existing) => existing + count);
        }

        if (stats.Errors.Count > 0)
        {
            MilanLog.Warning($"Bank {bankExport.InstancedFullPath}: {stats.Errors.Count} HIRC object(s) failed to parse/convert and were dropped: {string.Join("; ", stats.Errors.Take(5))}", customPrefix: LOG_CATEGORY);
            foreach (var e in stats.Errors) _aggregateErrors.Add($"{bankExport.InstancedFullPath}: {e}");
        }

        return converted;
    }

    /// <summary>
    /// Logs the HIRC-object types dropped across every bank converted this run (see <see cref="_aggregateSkipped"/>
    /// and <see cref="HircTypeName"/>) and any bus IDs that had to fall back to the unmixed Master Audio Bus (see
    /// <see cref="BusRemap.FallbackUses"/>). Both are silent-in-game failure modes - a dropped HIRC object means
    /// whatever referenced it still posts/plays without erroring, it just has nothing left to actually play.
    /// </summary>
    private static void LogConversionDiagnosticsSummary()
    {
        if (!_aggregateSkipped.IsEmpty)
        {
            var breakdown = string.Join(", ", _aggregateSkipped.OrderByDescending(kv => kv.Value).Select(kv => $"{HircTypeName(kv.Key)}={kv.Value}"));
            MilanLog.Warning($"HIRC objects dropped during v56->v134 conversion (unsupported type - referencing Events/containers will post but play nothing): {breakdown}", customPrefix: LOG_CATEGORY);
        }

        if (!_aggregateErrors.IsEmpty)
        {
            MilanLog.Warning($"{_aggregateErrors.Count} HIRC object(s) across all banks failed to parse/convert (see per-bank warnings above for details)", customPrefix: LOG_CATEGORY);
        }

        if (!BusRemap.FallbackUses.IsEmpty)
        {
            var totalUses = BusRemap.FallbackUses.Values.Sum();
            MilanLog.Warning($"{BusRemap.FallbackUses.Count} distinct v56 bus ID(s) ({totalUses} reference(s)) had no known v134 mapping and were routed to the raw, unmixed Master Audio Bus - affected sounds will be loud/unmixed, not silent, but is still a release blocker. IDs: {string.Join(", ", BusRemap.FallbackUses.OrderByDescending(kv => kv.Value).Select(kv => $"{kv.Key}x{kv.Value}"))}", customPrefix: LOG_CATEGORY);
        }
    }
}
