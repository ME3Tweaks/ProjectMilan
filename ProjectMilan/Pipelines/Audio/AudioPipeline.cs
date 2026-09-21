using BankConverter.Bnk;
using BankConverter.Bnk.Chunks;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ME3Tweaks.Wwiser;
using ProjectMilanCore;
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

    /// <summary>
    /// Every source ID embedded by a converted bank this run, mapped to the distinct embedded byte lengths seen for
    /// it and which bank produced each. Wwise's media pool is global across all loaded banks and keyed only by source
    /// ID, so two of OUR banks embedding the same ID with different bytes is the same defect as colliding with a
    /// stock bank (see BuildStockResidentMedia) - one of the two blobs wins for every consumer, and any consumer
    /// declaring the other one's InMemoryMediaSize then decodes garbage. Reported by
    /// <see cref="LogConversionDiagnosticsSummary"/>; note ME3 duplicating one WEM across several banks is normal
    /// and harmless, it only becomes a problem when the copies come out of conversion differing.
    /// </summary>
    private static readonly ConcurrentDictionary<uint, ConcurrentDictionary<uint, string>> _embeddedMediaOwners = new();

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
        _embeddedMediaOwners.Clear();
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

        // Phase 5: verify the finished output obeys UE3's object-identity rule. Runs last because phases 3 and 4
        // both rewrite bank data per-package, so only the final bytes on disk can settle it.
        AuditBankNameConsistency(bankPackagePaths);

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
                package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            }
        });
    }

    private static void ConvertBankBodiesInPackages(List<string> packagePaths)
    {
        // Snapshotted once and reused for every bank - rebuilding per-bank would be O(banks * unique WEM count).
        var prefetchFragments = AFCHandler.SnapshotPrefetchFragments();
        var embeddedReplacements = AFCHandler.SnapshotEmbeddedReplacements();
        var stockResidentMedia = BuildExternallyProvidedMedia(packagePaths);
        var canonicalBanks = BuildCanonicalV56Banks(packagePaths);

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

                // Always convert the canonical source for this bank identity, never this package's own copy -
                // see BuildCanonicalV56Banks. Two packages holding different v56 bytes under one object name would
                // otherwise produce two different v134 banks under that name, and UE3 keeps whichever loads first.
                var sourceBytes = canonicalBanks.TryGetValue(CanonicalBankKey(exp, pf), out var canonical)
                    ? canonical
                    : bankBin.BnkFile;

                var hash = Convert.ToHexString(SHA256.HashData(sourceBytes));
                var convertedBytes = bankBinaryCache.GetOrAdd(hash, _ => new Lazy<byte[]>(() =>
                    ConvertBankBytes(exp, sourceBytes, prefetchFragments, embeddedReplacements, stockResidentMedia))).Value;

                bankBin.BnkFile = convertedBytes;
                exp.WriteBinary(bankBin);
                MilanLog.Information($"Converted WwiseBank {exp.InstancedFullPath} to v134", customPrefix: LOG_CATEGORY);
                modified = true;
            }

            if (modified)
            {
                package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            }
        });

        LogConversionDiagnosticsSummary();
    }

    /// <summary>
    /// Every source ID that will already be in Wwise's global media pool from a bank we are NOT converting, mapped to
    /// the byte length that copy has. Two sources:
    ///
    /// 1. LE3's always-loaded packages (see <see cref="BuildStockResidentMedia"/>) - resident for the whole session.
    /// 2. The donored LE3-native banks the mod itself ships. These arrive already at v134, so the conversion loop
    ///    skips them - but they still register their media globally the moment their package loads. This is the case
    ///    that the resident-only version of this map missed: Wwise_Crt_DLC_MP4_shared is donored byte-identical from
    ///    LE3's Citadel DLC (44.1kHz media), while Wwise_MP5_shared has no LE3 counterpart and must be converted from
    ///    ME3 (32kHz) - and both embed the same source IDs. A Collector kit fighting Collector enemies loads both, and
    ///    whichever registered first wins for every consumer, so the loser's consumers decode garbage. Deferring to
    ///    the stock copy is right here for the same reason it is for resident banks: it is the one the donored,
    ///    unmodified LE3 content expects.
    /// </summary>
    private static IReadOnlyDictionary<uint, uint> BuildExternallyProvidedMedia(List<string> packagePaths)
    {
        var result = new ConcurrentDictionary<uint, uint>();

        var donoredBanks = 0;
        Parallel.ForEach(packagePaths, new ParallelOptions { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, pf =>
        {
            var package = MEPackageHandler.UnsafePartialLoad(pf, x => x.ClassName == "WwiseBank");
            foreach (var exp in package.Exports.Where(x => x.ClassName == "WwiseBank"))
            {
                var bnk = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(exp).BnkFile;
                if (bnk is not { Length: > 0 }) continue;

                using (var versionStream = new MemoryStream(bnk, writable: false))
                {
                    // v56 banks are the ones we're about to convert - they provide nothing yet. Anything already at
                    // v134 in the output is LE3-native content the donor system brought in untouched.
                    if (WwiseBankParser.GetWwiseBankVersion(versionStream) == 56) continue;
                }

                Interlocked.Increment(ref donoredBanks);
                foreach (var m in ReadMediaIndex(bnk))
                {
                    result[m.Id] = m.Size;
                }
            }
        });

        MilanLog.Information($"Mod-shipped donored (already-v134) banks provide {result.Count} source ID(s) across {donoredBanks} bank(s)", customPrefix: LOG_CATEGORY);

        // Stock wins on the rare ID both provide - it's the copy that's loaded unconditionally.
        foreach (var (id, size) in BuildStockResidentMedia())
        {
            result[id] = size;
        }

        MilanLog.Information($"Externally-provided media total: {result.Count} source ID(s) that converted banks must not re-embed", customPrefix: LOG_CATEGORY);
        return result;
    }

    /// <summary>
    /// Source IDs LE3 already ships inside its always-loaded packages' banks, mapped to the byte length LE3 embeds.
    /// Those banks are resident for the whole session, and Wwise resolves embedded media globally by source ID rather
    /// than per-bank - so any ID in here is already owned by the stock game and must not be re-embedded by a ported
    /// bank. See BankFile.ConvertToV134's externallyProvidedMedia for the failure this prevents.
    ///
    /// The file set is EntryImporter's own always-loaded lists rather than a hardcoded SFXGame.pcc: SFXGame carries
    /// the bulk of it (22 banks), but WwiseAudio.pcc (the Init bank + Wwise_Generic_Foley_Procedural) and Startup.pcc
    /// are resident too and were missed when this only looked at SFXGame. PostLoad files are included because a bank
    /// rooted at first level transition is still loaded for the entire rest of the session - which is all that
    /// matters here, since a ported bank only has to avoid colliding with it, not import from it.
    /// </summary>
    internal static IReadOnlyDictionary<uint, uint> BuildStockResidentMedia()
    {
        var result = new Dictionary<uint, uint>();
        var fileNames = EntryImporter.FilesSafeToImportFrom(MEGame.LE3)
            .Concat(EntryImporter.FilesSafeToImportFromPostLoad(MEGame.LE3))
            .Distinct(StringComparer.OrdinalIgnoreCase);

        var scanned = 0;
        foreach (var fileName in fileNames)
        {
            if (!MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, fileName, out var filePath))
            {
                // Not every always-loaded name exists in every install (and the script-only ones have no audio at
                // all) - only worth a warning for the one we know carries most of the resident media.
                if (string.Equals(fileName, "SFXGame.pcc", StringComparison.OrdinalIgnoreCase))
                {
                    MilanLog.Warning($"Stock LE3 {fileName} not found; ported banks may re-embed media LE3 already owns", customPrefix: LOG_CATEGORY);
                }
                continue;
            }

            using var package = MEPackageHandler.UnsafePartialLoad(filePath, x => x.ClassName == "WwiseBank");
            foreach (var exp in package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "WwiseBank"))
            {
                var bnk = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(exp).BnkFile;
                if (bnk is not { Length: > 0 }) continue;

                scanned++;
                foreach (var m in ReadMediaIndex(bnk))
                {
                    result[m.Id] = m.Size;
                }
            }
        }

        MilanLog.Information($"Stock LE3 resident media: {result.Count} source ID(s) across {scanned} bank(s) in LE3's always-loaded packages", customPrefix: LOG_CATEGORY);
        return result;
    }

    /// <summary>Walks a bank's top-level chunks and returns its DIDX entries. DIDX is format-stable across v56/v134,
    /// so this works on stock LE3 (v134) banks without needing a version-specific full parse.</summary>
    private static List<MediaHeader> ReadMediaIndex(byte[] bankBytes)
    {
        var r = new BankReader(bankBytes);
        while (r.Position + 8 <= r.Length)
        {
            var tag = r.Tag4();
            var size = r.U32();
            if (size > r.Length - r.Position) break;
            if (tag == "DIDX") return DidxChunk.Read(r, size).Media;
            r.Skip((int)size);
        }
        return [];
    }

    private static byte[] ConvertBankBytes(ExportEntry bankExport, byte[] rawV56Bytes, Dictionary<uint, byte[]> prefetchFragments, Dictionary<uint, byte[]> embeddedReplacements, IReadOnlyDictionary<uint, uint> stockResidentMedia)
    {
        var stats = new HircConversionStats();
        var missingWems = new List<uint>();
        var bank = BankFile.ReadV56(rawV56Bytes);
        var converted = bank.ConvertToV134(stats, wemReplacements: embeddedReplacements, missingWems: missingWems, prefetchFragments: prefetchFragments, externallyProvidedMedia: stockResidentMedia);

        // Record what this bank ends up owning in the global media pool, so LogConversionDiagnosticsSummary can
        // catch two banks registering different bytes under one source ID. Done on the CONVERTED bytes, since
        // that's what actually ships - deferred entries (externallyProvidedMedia) are already gone by here.
        foreach (var m in ReadMediaIndex(converted))
        {
            _embeddedMediaOwners.GetOrAdd(m.Id, _ => new ConcurrentDictionary<uint, string>())
                .TryAdd(m.Size, bankExport.ObjectName.Instanced);
        }

        if (stats.ExternallyProvidedMedia > 0)
        {
            MilanLog.Information($"Bank {bankExport.InstancedFullPath}: deferred {stats.ExternallyProvidedMedia} media entry/entries ({stats.ExternallyProvidedBytesSaved} bytes) to LE3's own resident banks", customPrefix: LOG_CATEGORY);
        }

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
    /// Identity of a bank for consistency purposes: its instanced full path, scoped by the package's localization.
    /// Two languages' copies never load together (switching language needs a game restart) and a base package's
    /// copy versus its own _LOC_ file is the localization override mechanism, so only banks at the same
    /// localization are the "same object" for this purpose.
    /// </summary>
    private static string CanonicalBankKey(ExportEntry bankExport, string packagePath) =>
        $"{bankExport.InstancedFullPath}|{packagePath.GetUnrealLocalization()}";

    /// <summary>
    /// One canonical v56 source per bank identity, so every package shipping a given bank converts the SAME bytes
    /// and therefore ends up with the same v134 bank.
    ///
    /// ME3 does not guarantee this itself: "Wwise_VO_Exertions_DLC_CON_MP1" ships at 6662 bytes in DLC_CON_MP1 and
    /// at 5234 bytes in DLC_CON_MP4 under the identical instanced full path. Both reference the same 16 Batarian
    /// exertion VO lines; the MP4 copy was simply re-exported from Wwise with every object renumbered and a smaller
    /// switch mapping (3 SwitchContainers at 325 bytes instead of 801 - which is the whole 1428-byte difference).
    /// Converting each package's own copy faithfully reproduces that ambiguity into our output, and UE3 discards
    /// every copy after the first one loaded, so which build the game gets comes down to load order.
    ///
    /// Tie-break is the LARGEST source, i.e. the copy carrying the most content - a superset of switch associations
    /// can still resolve anything a trimmed one could, where the reverse isn't guaranteed. For the one real case in
    /// the corpus this selects MP1's copy, which is the intended outcome. Anything this has to collapse is logged,
    /// because a second case may well want a different answer than "bigger".
    /// </summary>
    private static Dictionary<string, byte[]> BuildCanonicalV56Banks(List<string> packagePaths)
    {
        var variants = new ConcurrentDictionary<string, ConcurrentDictionary<string, (byte[] Bytes, ConcurrentBag<string> Packages)>>();

        Parallel.ForEach(packagePaths, new ParallelOptions { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, pf =>
        {
            using var package = MEPackageHandler.UnsafePartialLoad(pf, x => x.ClassName == "WwiseBank");
            foreach (var exp in package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "WwiseBank"))
            {
                var bnk = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(exp).BnkFile;
                if (bnk is not { Length: > 0 }) continue;

                using (var versionStream = new MemoryStream(bnk, writable: false))
                {
                    if (WwiseBankParser.GetWwiseBankVersion(versionStream) != 56) continue; // donored v134 - not ours
                }

                var hash = Convert.ToHexString(SHA256.HashData(bnk));
                variants.GetOrAdd(CanonicalBankKey(exp, pf), _ => new ConcurrentDictionary<string, (byte[], ConcurrentBag<string>)>())
                    .GetOrAdd(hash, _ => (bnk, new ConcurrentBag<string>()))
                    .Packages.Add(Path.GetFileName(pf));
            }
        });

        var result = new Dictionary<string, byte[]>();
        var collapsed = 0;
        foreach (var (key, byHash) in variants)
        {
            if (byHash.Count == 1)
            {
                result[key] = byHash.Values.First().Bytes;
                continue;
            }

            collapsed++;
            var ordered = byHash.Values.OrderByDescending(v => v.Bytes.Length).ToList();
            var winner = ordered[0];
            result[key] = winner.Bytes;

            MilanLog.Warning($"{key.Split('|')[0]} ships {byHash.Count} different v56 banks under one name - converting the largest so every package agrees:", customPrefix: LOG_CATEGORY);
            foreach (var v in ordered)
            {
                var pkgs = v.Packages.Distinct().OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList();
                var shown = string.Join(", ", pkgs.Take(4)) + (pkgs.Count > 4 ? $", +{pkgs.Count - 4} more" : "");
                MilanLog.Warning($"    {(ReferenceEquals(v.Bytes, winner.Bytes) ? "USING " : "      ")}{v.Bytes.Length} bytes from {shown}", customPrefix: LOG_CATEGORY);
            }
        }

        if (collapsed > 0)
        {
            MilanLog.Information($"Canonicalized {collapsed} bank name(s) that ME3 ships more than one version of", customPrefix: LOG_CATEGORY);
        }
        return result;
    }

    /// <summary>
    /// Verifies the finished output obeys UE3's object-identity rule for banks: two exports sharing an instanced
    /// full path are the SAME object to the engine - whichever package loads first wins and every later copy is
    /// discarded - so two banks under one name MUST be byte-identical, or which build the game actually gets is
    /// decided by load order and is not deterministic.
    ///
    /// This is not hypothetical and is not only ours to create: ME3 itself ships "Wwise_VO_Exertions_DLC_CON_MP1"
    /// at 6662 bytes in DLC_CON_MP1 and a different 5234-byte bank under the exact same instanced full path in
    /// DLC_CON_MP4 (verified 2026-09-19 - same 16 VO lines either way, but re-exported from Wwise with every object
    /// renumbered and a smaller switch mapping), so ported content can carry a violation in from the source game.
    /// The conversion can also create one unaided: ConvertBankBodiesInPackages dedupes by SOURCE hash, so two
    /// packages whose v56 bytes differ produce two different v134 banks under one name.
    ///
    /// **Localization is not a violation, in either of its two forms.** Banks are compared only against others at
    /// the same localization:
    /// <list type="bullet">
    /// <item>Two languages' copies (Foo_LOC_INT vs Foo_LOC_DEU) legitimately hold different audio under one object
    /// name - only one language's packages are ever mounted, and switching needs a game restart.</item>
    /// <item>A base package and its own LOC file (Foo vs Foo_LOC_INT) are the localization override mechanism
    /// itself, not a conflict.</item>
    /// </list>
    /// Comparing across those axes reports every localized VO bank in the game as a false positive - measured at 7
    /// such names on the first pass, then 3 more (SFXPawn_Atlas2, SFXPawn_Phoenix) when only the language axis was
    /// fixed. Neither was a real defect.
    ///
    /// Reported as errors rather than fixed here: picking a winner is a content decision (which DLC's build of the
    /// bank do we want), not something to resolve silently at the end of a build.
    /// </summary>
    internal static void AuditBankNameConsistency(List<string> packagePaths)
    {
        var entries = new ConcurrentBag<(string BankName, MELocalization Loc, string Hash, int Size, string Package)>();

        Parallel.ForEach(packagePaths, new ParallelOptions { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, pf =>
        {
            using var package = MEPackageHandler.UnsafePartialLoad(pf, x => x.ClassName == "WwiseBank");
            var loc = pf.GetUnrealLocalization();
            foreach (var exp in package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "WwiseBank"))
            {
                var bnk = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(exp).BnkFile;
                if (bnk is not { Length: > 0 }) continue;
                entries.Add((exp.InstancedFullPath, loc, Convert.ToHexString(SHA256.HashData(bnk))[..12], bnk.Length, Path.GetFileName(pf)));
            }
        });

        var all = entries.ToList();
        var violations = all
            .GroupBy(x => (x.BankName, x.Loc))
            .Where(g => g.Select(x => x.Hash).Distinct().Count() > 1)
            .OrderBy(g => g.Key.BankName, StringComparer.OrdinalIgnoreCase)
            .ThenBy(g => g.Key.Loc)
            .ToList();

        var distinctNames = all.Select(x => x.BankName).Distinct(StringComparer.OrdinalIgnoreCase).Count();
        if (violations.Count == 0)
        {
            MilanLog.Information($"Bank name consistency: OK - {distinctNames} distinct bank name(s), every one byte-identical across everything that can be loaded together", customPrefix: LOG_CATEGORY);
            return;
        }

        MilanLog.Error($"{violations.Count} bank name(s) ship with DIFFERENT content across packages that load together. UE3 keeps only the first copy loaded and discards the rest, so which build the game gets is decided by load order - this must be made consistent:", customPrefix: LOG_CATEGORY);
        foreach (var group in violations)
        {
            var scope = group.Key.Loc == MELocalization.None ? "unlocalized" : group.Key.Loc.ToString();
            MilanLog.Error($"  {group.Key.BankName} [{scope}]", customPrefix: LOG_CATEGORY);
            foreach (var variant in group.GroupBy(x => x.Hash).OrderByDescending(v => v.Count()))
            {
                var pkgs = variant.Select(x => x.Package).Distinct().OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList();
                var shown = string.Join(", ", pkgs.Take(4)) + (pkgs.Count > 4 ? $", +{pkgs.Count - 4} more" : "");
                MilanLog.Error($"      {variant.First().Size} bytes (sha {variant.Key}) in {pkgs.Count} package(s): {shown}", customPrefix: LOG_CATEGORY);
            }
        }
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

        var collisions = _embeddedMediaOwners.Where(kv => kv.Value.Count > 1).ToList();
        if (collisions.Count > 0)
        {
            MilanLog.Warning($"{collisions.Count} source ID(s) were embedded by more than one converted bank with DIFFERENT byte lengths - Wwise's media pool is global and keyed only by source ID, so one blob wins for everyone and consumers expecting the other will decode garbage:", customPrefix: LOG_CATEGORY);
            foreach (var (id, byLength) in collisions.OrderBy(kv => kv.Key))
            {
                var detail = string.Join(", ", byLength.OrderBy(x => x.Key).Select(x => $"{x.Value}={x.Key}B"));
                MilanLog.Warning($"  source {id}: {detail}", customPrefix: LOG_CATEGORY);
            }
        }

        if (!BusRemap.FallbackUses.IsEmpty)
        {
            var totalUses = BusRemap.FallbackUses.Values.Sum();
            MilanLog.Warning($"{BusRemap.FallbackUses.Count} distinct v56 bus ID(s) ({totalUses} reference(s)) had no known v134 mapping and were routed to the raw, unmixed Master Audio Bus - affected sounds will be loud/unmixed, not silent, but is still a release blocker. IDs: {string.Join(", ", BusRemap.FallbackUses.OrderByDescending(kv => kv.Value).Select(kv => $"{kv.Key}x{kv.Value}"))}", customPrefix: LOG_CATEGORY);
        }
    }
}
