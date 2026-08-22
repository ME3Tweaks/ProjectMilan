using BankConverter.Bnk;
using BankConverter.Bnk.Chunks;
using BankConverter.Bnk.Hirc;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ME3Tweaks.Wwiser;
using ProjectMilanCore;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO.Compression;
using System.Linq;
using System.Threading;

namespace ProjectMilan.Pipelines.Audio
{
    /// <summary>
    /// Handles conversion of AFCs and the WEM audio referenced by WwiseBanks, from ME3-era (v56) to LE3-era (v134).
    /// </summary>
    internal class AFCHandler
    {
        private const string LOG_CATEGORY = @"MILAN-Audio-AFC";

        /// <summary>
        /// Base name of the single consolidated AFC (per localization) that all converted streaming audio is written into.
        /// </summary>
        private const string MilanAFCBaseName = @"Wwise_ProjectMilan";

        /// <summary>
        /// Location + prefetch info for a WEM that has been converted and written into a Milan AFC. Deliberately does
        /// NOT hold the full converted audio - streamed audio can total several GB across the whole game, so only a
        /// small header+margin fragment (for embedding as a bank's prefetch buffer, see <see cref="PrefetchBuilder"/>)
        /// is kept once the full data has been written out to disk.
        /// </summary>
        private sealed class StreamedWemInfo
        {
            public string AfcKey = null!;
            public long Offset;
            public int Size;
            public byte[] PrefetchFragment = null!;
        }

        /// <summary>
        /// Where to find a pending streamed WEM's raw (ME3-era) bytes, deferred until batch conversion time so the
        /// gather pass never has to hold raw streaming audio (potentially GB-scale across the whole game) in memory.
        /// </summary>
        private sealed class StreamSourceLocation
        {
            public string SourceAfcName = null!;
            public MELocalization Loc;
            public int Offset;
            public int Size;
        }

        /// <summary>
        /// How many unique WEMs are re-encoded per <see cref="WemReencoder.ReencodeBatch"/> call. Spinning up
        /// ww2ogg/ffmpeg/WwiseCLI is expensive - batching amortizes that cost across many WEMs per invocation instead
        /// of once per WEM - while still bounding how much raw+converted audio is held in memory at once.
        /// </summary>
        private const int BatchSize = 500;

        /// <summary>
        /// How often (in converted WEMs) <see cref="BatchConvertPending"/> logs a progress update.
        /// </summary>
        private const int ProgressLogInterval = 25;

        /// <summary>
        /// When set (env var MILAN_KEEP_AUDIO_WORKDIRS=1), each chunk's decode/convert work directory is kept on disk
        /// under Pipelines/Audio/ConversionReview instead of being deleted right after that chunk finishes, for manual
        /// review - it contains, per chunk: wem/{id}.wem (raw source audio as read from the ME3 AFC), wav/{id}.wav
        /// (the decoded audio - ww2ogg+ffmpeg output, what actually gets fed to WwiseCLI), and out/Windows/{id}.wem
        /// (the final v134 audio - what actually ships). Off by default - this is debug-only, disk usage adds up fast
        /// (uncompressed .wav) and nothing prunes ConversionReview automatically.
        /// </summary>
        private static readonly bool KeepConversionWorkDirs = Environment.GetEnvironmentVariable("MILAN_KEEP_AUDIO_WORKDIRS") == "1";
        // Set above to true to review output

        private static string CreateChunkWorkDir()
        {
            if (true)
            // if (KeepConversionWorkDirs)
                {
                    var folder = Path.Combine(MilanShared.PipelineRoot, "Audio", "ConversionReview",
                    DateTime.Now.ToString("yyyyMMdd_HHmmss") + "_" + Guid.NewGuid().ToString("N")[..8]);
                Directory.CreateDirectory(folder);
                return folder;
            }

            return Path.Combine(Path.GetTempPath(), "MilanWemReencodeBatch_" + Guid.NewGuid().ToString("N"));
        }

        /// <summary>
        /// AFC map to store the AFC files and their corresponding streams
        /// </summary>
        private static readonly ConcurrentDictionary<string, Stream> convertedAFCMap = new();
        private static readonly ConcurrentDictionary<string, Lock> convertedAFCLocks = new();
        private static readonly ConcurrentDictionary<string, Stream> sourceAFCMap = new();
        private static readonly ConcurrentDictionary<string, Lock> sourceAFCLocks = new();

        /// <summary>
        /// Streamed WEM IDs that have been discovered (during the gather pass) as needing conversion, but not yet
        /// converted. Consumed and cleared out (into <see cref="streamedWemCache"/>) by <see cref="BatchConvertPending"/>.
        /// </summary>
        private static readonly ConcurrentDictionary<uint, StreamSourceLocation> pendingStreamedSources = new();

        /// <summary>
        /// Embedded (Data-type) WEM IDs discovered as needing conversion, along with their raw bytes (always small,
        /// safe to hold directly - unlike streamed sources these aren't available again once the source package that
        /// held them is closed). Consumed and cleared out (into <see cref="embeddedWemCache"/>) by <see cref="BatchConvertPending"/>.
        /// </summary>
        private static readonly ConcurrentDictionary<uint, byte[]> pendingEmbeddedRaw = new();

        /// <summary>
        /// Every WEM ID that has been streamed into a Milan AFC, populated by <see cref="BatchConvertPending"/>.
        /// </summary>
        private static readonly ConcurrentDictionary<uint, StreamedWemInfo> streamedWemCache = new();

        /// <summary>
        /// Every WEM ID that is only ever embedded (Data-type, never streamed via an external AFC), populated by
        /// <see cref="BatchConvertPending"/>. These are always short clips (that's why they weren't streamed to begin
        /// with), so caching the full converted bytes is safe.
        /// </summary>
        private static readonly ConcurrentDictionary<uint, byte[]> embeddedWemCache = new();

        private static WemReencodeOptions? _reencodeOptions;
        private static WemReencodeOptions ReencodeOptions => _reencodeOptions ??= new WemReencodeOptions
        {
            WwiseProjectPath = ExtractWwiseConversionTemplateProject(),
            DecodeParallelism = Program.Settings.MaxThreads
        };

        /// <summary>
        /// Extracts the Wwise project bundled at Pipelines/Audio/Template/TemplateProject.zip (which defines the
        /// "Milan Max Quality" Conversion Settings preset used to re-encode ME3-era v56 WEM audio to LE3-era v134)
        /// to a fresh folder in %TEMP%, deleting any copy left over from a previous run first.
        /// </summary>
        private static string ExtractWwiseConversionTemplateProject()
        {
            var templateZip = Path.Combine(MilanShared.PipelineRoot, "Audio", "Template", "TemplateProject.zip");
            var extractFolder = Path.Combine(Path.GetTempPath(), "MilanWwiseConversionTemplateProject");

            if (Directory.Exists(extractFolder))
            {
                Directory.Delete(extractFolder, true);
            }
            ZipFile.ExtractToDirectory(templateZip, extractFolder);

            return Path.Combine(extractFolder, "LE3TemplateProject.wproj");
        }

        /// <summary>
        /// On-disk cache of converted (v134) WEM bytes, keyed by ID, surviving across pipeline runs. Re-running the
        /// pipeline without changes to the source audio then skips WwiseCLI entirely for anything already cached here.
        /// Cleared out by <see cref="ClearDiskCache"/> (hooked up to Program.CleanupMilan) for a full rebuild.
        /// </summary>
        private static readonly Lazy<string> _wemDiskCacheFolder = new(() =>
        {
            var folder = Path.Combine(MilanShared.PipelineRoot, "Audio", "ConvertedCache");
            Directory.CreateDirectory(folder);
            return folder;
        });
        /// <summary>
        /// Public for Research.ExtractConvertedBanksForTesting - Wwise's default sample low-level I/O hook (which
        /// WwiseHook.exe uses, unmodified) resolves a streamed source by opening "&lt;sourceId&gt;.wem" directly in
        /// the bank's own directory, which happens to be exactly this cache's naming - copying the relevant entries
        /// alongside an extracted test bank is enough to make streaming playback work with zero WwiseHook changes.
        /// </summary>
        public static string WemDiskCacheFolder => _wemDiskCacheFolder.Value;

        private static string GetWemDiskCachePath(uint id) => Path.Combine(WemDiskCacheFolder, $"{id}.wem");

        private static byte[]? TryGetDiskCachedWem(uint id)
        {
            var path = GetWemDiskCachePath(id);
            return File.Exists(path) ? File.ReadAllBytes(path) : null;
        }

        private static void WriteDiskCachedWem(uint id, byte[] convertedBytes)
        {
            try
            {
                File.WriteAllBytes(GetWemDiskCachePath(id), convertedBytes);
            }
            catch (Exception e)
            {
                MilanLog.Exception(e, $"Failed to write WEM disk cache for id {id}", customPrefix: LOG_CATEGORY);
            }
        }

        /// <summary>
        /// Deletes the on-disk converted-WEM cache, forcing a full re-conversion (and re-download of nothing, since
        /// it's all local) on the next pipeline run. Not currently wired up to run automatically - see
        /// AudioPipeline.Clean(), called from Program.CleanupMilan().
        /// </summary>
        public static void ClearDiskCache()
        {
            if (Directory.Exists(WemDiskCacheFolder))
            {
                MilanLog.Information($"Deleting WEM conversion cache: {WemDiskCacheFolder}", customPrefix: LOG_CATEGORY);
                Directory.Delete(WemDiskCacheFolder, true);
            }
        }

        /// <summary>
        /// Clears the WEM conversion caches. Should be called once before a pipeline run starts (defensive - guards
        /// against stale data if the pipeline is ever run more than once in the same process). Does NOT touch the
        /// on-disk cache - see <see cref="ClearDiskCache"/> for that.
        /// </summary>
        public static void ResetWemCaches()
        {
            pendingStreamedSources.Clear();
            pendingEmbeddedRaw.Clear();
            streamedWemCache.Clear();
            embeddedWemCache.Clear();
        }

        /// <summary>
        /// Writes an already-converted WEM's data into the Milan AFC and builds its prefetch fragment, populating
        /// <see cref="streamedWemCache"/>. Used both for freshly batch-converted WEMs and for on-disk cache hits.
        /// </summary>
        private static void FinalizeStreamedWem(uint id, MELocalization loc, byte[] convertedBytes, string afcName = null)
        {
            var afcKey = GetAFCName(afcName ?? MilanAFCBaseName, loc);
            var newOffset = WriteWEM(afcName ?? MilanAFCBaseName, loc, convertedBytes);
            var fragment = PrefetchBuilder.BuildFragment(convertedBytes);

            streamedWemCache[id] = new StreamedWemInfo
            {
                AfcKey = afcKey,
                Offset = newOffset,
                Size = convertedBytes.Length,
                PrefetchFragment = fragment
            };
        }

        /// <summary>
        /// Gets the AFC name to be used for a given base name and localization. If the localization is not None, it appends the localization to the base name.
        /// </summary>
        /// <param name="baseAFCName"></param>
        /// <param name="loc"></param>
        /// <returns></returns>
        private static string GetAFCName(string baseAFCName, MELocalization loc)
        {
            if (loc != MELocalization.None)
            {
                return baseAFCName.SetUnrealLocalization(MEGame.LE3, loc);
            }
            else
            {
                // Use _SFX because otherwise unreal localization ruins it
                return baseAFCName.StripUnrealLocalization() + "_SFX";
            }
        }

        /// <summary>
        /// Writes a converted WEM to its bank
        /// </summary>
        /// <param name="baseAFCName"></param>
        /// <param name="loc"></param>
        /// <param name="wemData"></param>
        /// <returns></returns>
        public static long WriteWEM(string baseAFCName, MELocalization loc, byte[] wemData)
        {
            var key = GetAFCName(baseAFCName, loc);
            var keyLock = convertedAFCLocks.GetOrAdd(key, _ => new Lock());

            long outputOffset;
            lock (keyLock)
            {
                if (!convertedAFCMap.TryGetValue(key, out var stream))
                {
                    // Not opened yet. Create it and map it.
                    var audioFolder = Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", "Audio");
                    Directory.CreateDirectory(audioFolder);
                    var outPath = Path.Combine(audioFolder, key + ".afc");
                    stream = File.OpenWrite(outPath);
                    convertedAFCMap[key] = stream;
                }

                outputOffset = stream.Position;
                stream.Write(wemData);
            }
            return outputOffset;
        }

        /// <summary>
        /// Reads an ME3 WEM file from AFC
        /// </summary>
        /// <param name="baseAFCName"></param>
        /// <param name="loc"></param>
        /// <param name="offset"></param>
        /// <param name="length"></param>
        /// <returns></returns>
        /// <exception cref="InvalidOperationException"></exception>
        public static byte[] ReadWEM(string baseAFCName, MELocalization loc, long offset, int length)
        {
            var key = baseAFCName;
            if (loc != MELocalization.None && key.GetUnrealLocalization() != loc)
            {
                key = key.SetUnrealLocalization(MEGame.LE3, loc);
            }

            var keyLock = sourceAFCLocks.GetOrAdd(key, _ => new Lock());
            lock (keyLock)
            {
                if (!sourceAFCMap.TryGetValue(key, out var stream))
                {
                    var path = Path.Combine(ME3Directory.CookedPCPath, key + ".afc");
                    if (!File.Exists(path))
                    {
                        // Find the AFC in ME3's direct access cache that occurred earlier.
                        path = Path.Combine(MilanShared.GetME3DirectAccessCache(), key + ".afc");
                    }
                    stream = File.OpenRead(path);
                    sourceAFCMap[key] = stream;
                }

                stream.Seek(offset, SeekOrigin.Begin);
                byte[] buffer = new byte[length];
                int bytesRead = stream.Read(buffer, 0, length);
                if (bytesRead != length)
                {
                    throw new InvalidOperationException($"Could not read the expected number of bytes from AFC {key}. Expected {length}, got {bytesRead}.");
                }

                // An AFC is just WEMs concatenated back-to-back, each self-delimited by its own RIFF header (see
                // BankConverter.Bnk.AfcConverter.ParseEntries, which does the same check scanning an AFC end-to-end).
                // DataOffset/DataSize should therefore always land exactly on a RIFF header whose declared size
                // matches what we read - if it doesn't, we're reading from the wrong offset or the wrong AFC file.
                if (buffer.Length < 8 || buffer[0] != (byte)'R' || buffer[1] != (byte)'I' || buffer[2] != (byte)'F' || buffer[3] != (byte)'F')
                {
                    throw new InvalidOperationException($"WEM read from AFC {key} @ {offset} (length {length}) does not start with 'RIFF' - wrong offset or wrong AFC file.");
                }

                var declaredRiffSize = BitConverter.ToUInt32(buffer, 4);
                var expectedRiffSize = (uint)(length - 8);
                if (declaredRiffSize != expectedRiffSize)
                {
                    throw new InvalidOperationException($"WEM read from AFC {key} @ {offset} declares RIFF size {declaredRiffSize}, expected {expectedRiffSize} for a {length}-byte read - wrong offset or wrong AFC file.");
                }

                return buffer;
            }
        }

        /// <summary>
        /// Re-encodes every pending WEM (registered by <see cref="GatherBank"/> via <see cref="pendingStreamedSources"/>/
        /// <see cref="pendingEmbeddedRaw"/>) from ME3-era (v56) to LE3-era (v134), in chunks of <see cref="BatchSize"/> -
        /// a handful of WwiseCLI invocations instead of one per WEM. Deliberately sequential (not parallelized): running
        /// multiple WwiseCLI instances concurrently against the same Wwise project isn't something to rely on being safe,
        /// and the whole point of batching is to spend less time spinning up CLI processes in the first place. Raw and
        /// converted bytes for a chunk are only held for the duration of that chunk's conversion.
        /// </summary>
        public static void BatchConvertPending()
        {
            var allIds = pendingStreamedSources.Keys.Concat(pendingEmbeddedRaw.Keys).Distinct().ToList();
            if (allIds.Count == 0) return;

            MilanLog.Information($"Batch re-encoding {allIds.Count} unique WEM(s) in chunks of {BatchSize}", customPrefix: LOG_CATEGORY);

            var totalToConvert = allIds.Count;
            var decodedCount = 0;
            var convertedCount = 0;

            // Decoding (ww2ogg+ffmpeg) is a process-pair-per-file loop with no batching, so it's normally where most
            // of the wall-clock time - and, without this, most of the silent stretches - goes for a large batch.
            void ReportDecoded(string _)
            {
                var count = Interlocked.Increment(ref decodedCount);
                if (count % ProgressLogInterval == 0 || count == totalToConvert)
                {
                    MilanLog.Information($"Decoded {count}/{totalToConvert} WEM(s)", customPrefix: LOG_CATEGORY);
                }
            }

            void ReportConverted(string _)
            {
                var count = Interlocked.Increment(ref convertedCount);
                if (count % ProgressLogInterval == 0 || count == totalToConvert)
                {
                    MilanLog.Information($"Converted {count}/{totalToConvert} WEM(s)", customPrefix: LOG_CATEGORY);
                }
            }

            foreach (var chunk in allIds.Chunk(BatchSize))
            {
                var wemsById = new Dictionary<string, byte[]>();
                foreach (var id in chunk)
                {
                    byte[] rawWem;
                    if (pendingEmbeddedRaw.TryGetValue(id, out var embeddedRaw))
                    {
                        rawWem = embeddedRaw;
                    }
                    else if (pendingStreamedSources.TryGetValue(id, out var srcLoc))
                    {
                        try
                        {
                            rawWem = ReadWEM(srcLoc.SourceAfcName, srcLoc.Loc, srcLoc.Offset, srcLoc.Size);
                        }
                        catch (Exception e)
                        {
                            MilanLog.Exception(e, $"Failed to read source WEM for id {id} ({srcLoc.SourceAfcName} @ {srcLoc.Offset})", customPrefix: LOG_CATEGORY);
                            continue;
                        }
                    }
                    else
                    {
                        continue; // shouldn't happen - id came from one of the two dictionaries we just read it out of
                    }

                    wemsById[id.ToString()] = rawWem;
                }

                if (wemsById.Count == 0) continue;

                var workDir = CreateChunkWorkDir();
                WemReencodeResult result;
                try
                {
                    result = WemReencoder.ReencodeBatch(wemsById, workDir, ReencodeOptions, onItemDecoded: ReportDecoded, onItemConverted: ReportConverted);
                }
                finally
                {
                    if (KeepConversionWorkDirs)
                    {
                        MilanLog.Information($"Kept conversion work dir for review: {workDir}", customPrefix: LOG_CATEGORY);
                    }
                    else
                    {
                        try { Directory.Delete(workDir, true); } catch { /* best-effort cleanup */ }
                    }
                }

                foreach (var (idStr, reason) in result.Failed)
                {
                    MilanLog.Error($"Failed to re-encode WEM id {idStr}: {reason}", customPrefix: LOG_CATEGORY);
                }

                foreach (var (idStr, convertedBytes) in result.Converted)
                {
                    var id = uint.Parse(idStr);
                    WriteDiskCachedWem(id, convertedBytes);

                    if (pendingStreamedSources.TryGetValue(id, out var srcLoc))
                    {
                        FinalizeStreamedWem(id, srcLoc.Loc, convertedBytes, srcLoc.SourceAfcName);
                    }
                    else
                    {
                        embeddedWemCache[id] = convertedBytes;
                    }
                }
            }

            pendingStreamedSources.Clear();
            pendingEmbeddedRaw.Clear();
        }

        /// <summary>
        /// Discovers the listed bank's streaming and embedded WEM audio and registers whatever isn't already
        /// converted/pending into <see cref="pendingStreamedSources"/>/<see cref="pendingEmbeddedRaw"/> for
        /// <see cref="BatchConvertPending"/> to pick up. Does NOT convert anything itself, and does NOT patch the
        /// bank's exports - see <see cref="PatchBank"/> for that, which must run after a <see cref="BatchConvertPending"/>
        /// call has resolved everything gathered here.
        /// </summary>
        /// <param name="bankExport"></param>
        public static bool GatherBank(ExportEntry bankExport)
        {
            // Audio embedded directly in this bank's own DIDX/DATA. PrefetchStreaming-type sources are skipped here -
            // their full audio comes from a WwiseStream (typically a sibling under the same parent);
            // if it's genuinely never found anywhere, that's caught as a "missing" WEM during bank body conversion.
            var bankBin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(bankExport);
            if (bankBin.BnkFile.Length == 0) return false; // 0-byte banks are a known bug in the source data; nothing to do

            using (var versionStream = new MemoryStream(bankBin.BnkFile, writable: false))
            {
                if (WwiseBankParser.GetWwiseBankVersion(versionStream) != 56) return false; // already converted (or not ours to touch) - nothing to extract with the v56 reader
            }

            MilanLog.Information($"Gathering WwiseBank {bankExport.InstancedFullPath}", customPrefix: LOG_CATEGORY);

            var loc = bankExport.FileRef.Localization;
            var foundWork = false;

            // Find all streaming audio exports via the wwise events.
            var parent = bankExport.Parent;
            foreach (var evt in bankExport.FileRef.Exports.Where(x => x.Parent == parent && x.ClassName == "WwiseEvent"))
            {
                var evtBin = ObjectBinary.From<WwiseEvent>(evt);
                foreach (var link in evtBin.Links.SelectMany(x => x.WwiseStreams))
                {
                    var streamExport = evt.FileRef.GetUExport(link);
                    if (streamExport.ClassName != "WwiseStream") continue;

                    var streamBin = ObjectBinary.From<WwiseStream>(streamExport);
                    if (streamBin.DataSize == 0) continue; // PCC-embedded or otherwise nothing external to convert here

                    var afcNameProp = streamExport.GetProperty<NameProperty>("Filename");
                    if (afcNameProp == null) continue;

                    var id = (uint)streamBin.Id;
                    if (streamedWemCache.ContainsKey(id) || pendingStreamedSources.ContainsKey(id)) continue;

                    var diskCached = TryGetDiskCachedWem(id);
                    if (diskCached != null)
                    {
                        FinalizeStreamedWem(id, loc, diskCached);
                        continue;
                    }

                    pendingStreamedSources.TryAdd(id, new StreamSourceLocation
                    {
                        SourceAfcName = afcNameProp.Value.Instanced,
                        Loc = loc,
                        Offset = streamBin.DataOffset,
                        Size = streamBin.DataSize
                    });
                    foundWork = true;
                }
            }

            var parsedBank = BankFile.ReadV56(bankBin.BnkFile);
            if (parsedBank.Didx == null || parsedBank.Data == null) return foundWork;

            var embedded = WemExtractor.Extract(parsedBank);
            if (embedded.Count == 0) return foundWork;

            var streamTypes = parsedBank.HircRaw != null
                ? HircChunk.ScanSourceStreamTypes(parsedBank.HircRaw)
                : new Dictionary<uint, SourceStreamType>();

            foreach (var (id, rawBytes) in embedded)
            {
                if (streamedWemCache.ContainsKey(id) || embeddedWemCache.ContainsKey(id)) continue;
                if (pendingStreamedSources.ContainsKey(id) || pendingEmbeddedRaw.ContainsKey(id)) continue;
                if (streamTypes.TryGetValue(id, out var type) && type == SourceStreamType.PrefetchStreaming) continue;

                var diskCached = TryGetDiskCachedWem(id);
                if (diskCached != null)
                {
                    embeddedWemCache[id] = diskCached;
                    continue;
                }

                pendingEmbeddedRaw.TryAdd(id, rawBytes);
                foundWork = true;
            }

            return foundWork;
        }

        /// <summary>
        /// Patches the listed bank's streaming WwiseStream exports to point at their converted audio in the Milan
        /// AFCs. Must be called after <see cref="BatchConvertPending"/> has resolved everything <see cref="GatherBank"/>
        /// found - performs lookups only, never triggers conversion itself.
        /// </summary>
        /// <param name="bankExport"></param>
        public static bool PatchBank(ExportEntry bankExport)
        {
            var bankBin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank>(bankExport);
            if (bankBin.BnkFile.Length == 0) return false;

            using (var versionStream = new MemoryStream(bankBin.BnkFile, writable: false))
            {
                if (WwiseBankParser.GetWwiseBankVersion(versionStream) != 56) return false;
            }

            var parent = bankExport.Parent;
            var modified = false;

            var events = bankExport.FileRef.Exports.Where(x => x.Parent == parent && x.ClassName == "WwiseEvent").ToList();
            var eventBins = events.ToDictionary(evt => evt, evt => ObjectBinary.From<WwiseEvent>(evt));

            // LE3's retail banks link every event under a bank to every WwiseStream used anywhere in that bank,
            // unlike v56 where each event only links the streams it actually plays. Replicate that by unioning
            // every event's (still-narrow, v56-sourced) links before patching them below.
            var allStreamLinks = eventBins.Values
                .SelectMany(evtBin => evtBin.Links.SelectMany(x => x.WwiseStreams))
                .Distinct()
                .ToList();

            foreach (var (evt, evtBin) in eventBins)
            {
                foreach (var link in evtBin.Links.SelectMany(x => x.WwiseStreams))
                {
                    var streamExport = evt.FileRef.GetUExport(link);
                    if (streamExport.ClassName != "WwiseStream") continue;

                    var streamBin = ObjectBinary.From<WwiseStream>(streamExport);
                    if (streamBin.DataSize == 0) continue;

                    var id = (uint)streamBin.Id;
                    if (!streamedWemCache.TryGetValue(id, out var info))
                    {
                        MilanLog.Error($"Skipping WwiseStream {streamExport.InstancedFullPath} - no converted WEM available for id {id}", customPrefix: LOG_CATEGORY);
                        continue;
                    }

                    streamBin.DataOffset = (int)info.Offset;
                    streamBin.DataSize = info.Size;
                    streamExport.WriteBinary(streamBin); // Commit back to export
                    streamExport.WriteProperty(new NameProperty(info.AfcKey, "Filename"));
                    modified = true;
                }

                if (!evtBin.Links[0].WwiseStreams.SequenceEqual(allStreamLinks))
                {
                    evtBin.Links[0].WwiseStreams = new List<int>(allStreamLinks);
                    evt.WriteBinary(evtBin);
                    modified = true;
                }
            }

            return modified;
        }

        /// <summary>
        /// Snapshots the pre-built prefetch fragments (small header+margin slices) for every streamed WEM converted so
        /// far, keyed by ID. Intended to be called once, after <see cref="BatchConvertPending"/> has resolved every
        /// WEM gathered across the whole game, and the result reused for every bank body conversion
        /// (<see cref="BankFile.ConvertToV134"/>'s prefetchFragments parameter) rather than re-snapshotted per bank.
        /// </summary>
        public static Dictionary<uint, byte[]> SnapshotPrefetchFragments()
        {
            var result = new Dictionary<uint, byte[]>();
            foreach (var kvp in streamedWemCache)
            {
                result[kvp.Key] = kvp.Value.PrefetchFragment;
            }
            return result;
        }

        /// <summary>
        /// Snapshots the fully-embedded (Data-type) converted WEM bytes for every ID converted so far. See
        /// <see cref="SnapshotPrefetchFragments"/> for intended usage (once, reused for every bank body conversion, as
        /// <see cref="BankFile.ConvertToV134"/>'s wemReplacements parameter).
        /// </summary>
        public static Dictionary<uint, byte[]> SnapshotEmbeddedReplacements()
        {
            return new Dictionary<uint, byte[]>(embeddedWemCache);
        }

        /// <summary>
        /// Closes all streams
        /// </summary>
        public static void CloseHandler()
        {
            foreach (var stream in convertedAFCMap.Values)
            {
                stream.Close();
            }
            convertedAFCMap.Clear();
            convertedAFCLocks.Clear();

            foreach (var stream in sourceAFCMap.Values)
            {
                stream.Close();
            }
            sourceAFCMap.Clear();
            sourceAFCLocks.Clear();
        }
    }
}
