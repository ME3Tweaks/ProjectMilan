using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text;

namespace BankConverter.Bnk;

public sealed class WemReencodeOptions
{
    /// <summary>Path to ww2ogg.exe. Defaults to Tools/ww2ogg/ww2ogg.exe next to the running assembly.</summary>
    public string Ww2OggPath { get; set; } = DefaultToolPath("ww2ogg", "ww2ogg.exe");

    /// <summary>Path to the packed Vorbis codebooks file matching the source WEMs' encoder. There are (at least) two
    /// distinct codebook packs in circulation and using the wrong one doesn't fail loudly - ww2ogg "successfully"
    /// produces a structurally valid Ogg Vorbis stream that just decodes to garbage/heavily-clipped noise. Confirmed
    /// empirically against real ME3 WEMs (vs. a vgmstream ground-truth decode): "packed_codebooks_aoTuV_603.bin" is
    /// the wrong one for ME3-era (v56) source audio and produces ~60-75% clipped output; plain "packed_codebooks.bin"
    /// (same one LegendaryExplorerCore's own ME3-era WEM extraction uses - see AudioStreamHelper.ConvertRIFFToWwiseOGG's
    /// useAlternateCodebook param, which is only set true "for LE") is correct here and reproduces the vgmstream
    /// reference decode almost exactly (same peak amplitude, ~0% clipping).</summary>
    public string PackedCodebooksPath { get; set; } = DefaultToolPath("ww2ogg", "packed_codebooks.bin");

    /// <summary>Path to ffmpeg.exe (decodes the recovered Ogg Vorbis to WAV before Wwise re-import). Must be supplied or on PATH.</summary>
    public string FfmpegPath { get; set; } = "ffmpeg";

    /// <summary>Path to WwiseCLI.exe. Defaults to $WWISEROOT/Authoring/x64/Release/bin/WwiseCLI.exe.</summary>
    public string WwiseCliPath { get; set; } = DefaultWwiseCliPath();

    /// <summary>Path to the .wproj used purely as a conversion-settings host (its actual audio content is irrelevant).</summary>
    public string WwiseProjectPath { get; set; } = "";

    /// <summary>Name of the Conversion Settings preset to use (must exist in the project). See "Milan Max Quality" in Conversion Settings/Default Work Unit.wwu.</summary>
    public string ConversionPresetName { get; set; } = "Milan Max Quality";

    /// <summary>How many WEMs are decoded (ww2ogg+ffmpeg) concurrently. Unlike the single batched WwiseCLI
    /// invocation, ww2ogg/ffmpeg are stateless per-file tools with no shared project/license state, so running many
    /// at once is safe. Defaults to the machine's core count.</summary>
    public int DecodeParallelism { get; set; } = Environment.ProcessorCount;

    private static string DefaultToolPath(params string[] relativeParts)
    {
        var baseDir = AppContext.BaseDirectory;
        return Path.Combine(new[] { baseDir, "Tools" }.Concat(relativeParts).ToArray());
    }

    private static string DefaultWwiseCliPath()
    {
        var root = Environment.GetEnvironmentVariable("WWISEROOT");
        if (string.IsNullOrEmpty(root)) return "";
        return Path.Combine(root, "Authoring", "x64", "Release", "bin", "WwiseCLI.exe");
    }
}

public sealed class WemReencodeResult
{
    /// <summary>ID/name -> re-encoded WEM bytes, for every input that decoded and converted successfully.</summary>
    public Dictionary<string, byte[]> Converted { get; } = new();

    /// <summary>ID/name -> failure reason, for every input that could not be converted (e.g. a truncated
    /// prefetch fragment that isn't a complete standalone Vorbis stream).</summary>
    public Dictionary<string, string> Failed { get; } = new();
}

/// <summary>
/// Converts v56 (ME3-era) Wwise Vorbis WEM audio to v134 (LE3-era) WEM audio. This is a full decode +
/// re-encode, not a header rewrite: v56 and v134 Vorbis streams reference disjoint external codebook
/// libraries (confirmed empirically - zero shared codebook hashes across thousands of real samples), so
/// v56 audio is fundamentally undecodable by the v134 runtime as-is. Pipeline per batch:
///   1. ww2ogg (+ the matching ME3-era packed codebook library) recovers standard Ogg Vorbis from each WEM.
///   2. ffmpeg decodes that Ogg to WAV (avoids relying on Wwise's own Ogg import support).
///   3. A single WwiseCLI -ConvertExternalSources invocation re-encodes every WAV to a new v134 WEM via
///      a named Conversion Settings preset (batched for throughput - one WwiseCLI process per call, not one per file).
/// </summary>
public static class WemReencoder
{
    /// <param name="wemsById"></param>
    /// <param name="workDir"></param>
    /// <param name="options"></param>
    /// <param name="onItemDecoded">Invoked once per WEM as soon as its ww2ogg+ffmpeg decode step finishes (success or
    /// failure) - this is a per-process-pair-per-file loop with no batching, so for a large batch it's normally where
    /// most of the wall-clock time (and, without this, most of the silent stretches) goes.</param>
    /// <param name="onItemConverted">Invoked once per WEM as soon as its converted .wem is detected on disk in
    /// WwiseCLI's output folder - polled while the single (possibly large) batch WwiseCLI invocation runs, since this
    /// CLI version prints nothing per-file to stdout to key off instead (confirmed empirically: output is just a
    /// project-load banner and a single "Process completed successfully" line, regardless of batch size).</param>
    public static WemReencodeResult ReencodeBatch(Dictionary<string, byte[]> wemsById, string workDir, WemReencodeOptions options, Action<string>? onItemDecoded = null, Action<string>? onItemConverted = null)
    {
        var result = new WemReencodeResult();
        Directory.CreateDirectory(workDir);
        var wemDir = Path.Combine(workDir, "wem");
        var wavDir = Path.Combine(workDir, "wav");
        var outDir = Path.Combine(workDir, "out");
        Directory.CreateDirectory(wemDir);
        Directory.CreateDirectory(wavDir);
        Directory.CreateDirectory(outDir);

        if (string.IsNullOrEmpty(options.WwiseProjectPath) || !File.Exists(options.WwiseProjectPath))
            throw new InvalidOperationException($"WwiseProjectPath not found: '{options.WwiseProjectPath}'. Set WemReencodeOptions.WwiseProjectPath to a .wproj that defines the '{options.ConversionPresetName}' Conversion Settings preset.");
        if (string.IsNullOrEmpty(options.WwiseCliPath) || !File.Exists(options.WwiseCliPath))
            throw new InvalidOperationException($"WwiseCliPath not found: '{options.WwiseCliPath}'. Set WemReencodeOptions.WwiseCliPath or the WWISEROOT environment variable.");
        if (!File.Exists(options.Ww2OggPath))
            throw new InvalidOperationException($"Ww2OggPath not found: '{options.Ww2OggPath}'.");
        if (!File.Exists(options.PackedCodebooksPath))
            throw new InvalidOperationException($"PackedCodebooksPath not found: '{options.PackedCodebooksPath}'.");

        // 1+2: decode each WEM -> ogg -> wav. Parallelized: unlike the single batched WwiseCLI invocation below,
        // ww2ogg/ffmpeg are stateless per-file tools with no shared project/license state to worry about, and this
        // per-file process-pair loop (no batching possible here) is normally where most of a large batch's
        // wall-clock time goes.
        var decodedIds = new ConcurrentBag<string>();
        var resultLock = new object();

        Parallel.ForEach(wemsById, new ParallelOptions { MaxDegreeOfParallelism = options.DecodeParallelism }, kvp =>
        {
            var (id, bytes) = kvp;
            var wemFile = Path.Combine(wemDir, $"{id}.wem");
            var oggFile = Path.Combine(wavDir, $"{id}.ogg");
            var wavFile = Path.Combine(wavDir, $"{id}.wav");
            File.WriteAllBytes(wemFile, bytes);

            var ww2oggResult = RunProcess(options.Ww2OggPath, $"\"{wemFile}\" -o \"{oggFile}\" --pcb \"{options.PackedCodebooksPath}\"");
            if (ww2oggResult.ExitCode != 0 || !File.Exists(oggFile))
            {
                lock (resultLock) { result.Failed[id] = $"ww2ogg: {Truncate(ww2oggResult.Output, 300)}"; }
                onItemDecoded?.Invoke(id);
                return;
            }

            var ffmpegResult = RunProcess(options.FfmpegPath, $"-y -loglevel error -i \"{oggFile}\" \"{wavFile}\"");
            File.Delete(oggFile);
            if (ffmpegResult.ExitCode != 0 || !File.Exists(wavFile))
            {
                lock (resultLock) { result.Failed[id] = $"ffmpeg: {Truncate(ffmpegResult.Output, 300)}"; }
                onItemDecoded?.Invoke(id);
                return;
            }

            decodedIds.Add(id);
            onItemDecoded?.Invoke(id);
        });

        if (decodedIds.Count == 0) return result;

        // 3: batch re-encode via WwiseCLI
        var xmlPath = Path.Combine(workDir, "external_sources.xml");
        var xml = new StringBuilder();
        xml.AppendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>");
        xml.AppendLine($"<ExternalSourcesList SchemaVersion=\"1\" Root=\"{XmlEscape(wavDir)}\">");
        foreach (var id in decodedIds)
        {
            xml.AppendLine($"  <Source Path=\"{id}.wav\" Conversion=\"{XmlEscape(options.ConversionPresetName)}\" Destination=\"{id}.wem\"/>");
        }
        xml.AppendLine("</ExternalSourcesList>");
        File.WriteAllText(xmlPath, xml.ToString());

        // WwiseCLI writes per-platform subfolders (e.g. "Windows"); newer/older CLI versions may write
        // directly into outDir depending on project settings, so check both.
        var windowsOutDir = Path.Combine(outDir, "Windows");

        // Detect per-file completion by polling for each source's destination .wem showing up on disk, since this
        // CLI version has nothing per-file in its stdout to key off instead (see onItemConverted doc comment).
        var pendingIds = new HashSet<string>(decodedIds, StringComparer.OrdinalIgnoreCase);
        var pendingIdsLock = new object();

        void PollForCompletedOutputs()
        {
            if (onItemConverted == null) return;
            var checkDir = Directory.Exists(windowsOutDir) ? windowsOutDir : outDir;

            List<string>? newlyFound = null;
            lock (pendingIdsLock)
            {
                if (pendingIds.Count == 0) return;
                foreach (var id in pendingIds)
                {
                    if (File.Exists(Path.Combine(checkDir, $"{id}.wem")))
                    {
                        (newlyFound ??= new List<string>()).Add(id);
                    }
                }
                if (newlyFound != null)
                {
                    foreach (var id in newlyFound) pendingIds.Remove(id);
                }
            }

            if (newlyFound != null)
            {
                foreach (var id in newlyFound) onItemConverted(id);
            }
        }

        var wwiseResult = RunProcess(options.WwiseCliPath,
            $"\"{options.WwiseProjectPath}\" -ConvertExternalSources \"{xmlPath}\" -ExternalSourcesOutput \"{outDir}\" -Platform Windows",
            onPollTick: onItemConverted == null ? null : PollForCompletedOutputs);

        // Final catch-up pass in case some outputs landed between the last poll tick and the process actually exiting.
        PollForCompletedOutputs();

        var effectiveOutDir = Directory.Exists(windowsOutDir) ? windowsOutDir : outDir;

        foreach (var id in decodedIds)
        {
            var newWemPath = Path.Combine(effectiveOutDir, $"{id}.wem");
            var producedBytes = File.Exists(newWemPath) ? File.ReadAllBytes(newWemPath) : null;
            if (producedBytes is { Length: > 0 })
            {
                result.Converted[id] = producedBytes;
            }
            else if (producedBytes != null)
            {
                // WwiseCLI exited cleanly and produced the output file, but it's empty - seen for very
                // short source clips (confirmed against a real ~278-byte source WEM, well under 200ms of
                // audio) where the batch's overall exit code stays 0 even though this one item silently
                // failed to encode (this CLI version has no per-file success/failure signal - see the
                // onItemConverted doc comment above). Must NOT be treated as a successful conversion:
                // callers cache Converted results to disk keyed by id, and an empty "success" poisons that
                // cache forever (nothing ever re-attempts a disk-cache hit).
                result.Failed[id] = $"WwiseCLI produced a 0-byte output (exit {wwiseResult.ExitCode}) - likely a source clip too short to re-encode";
            }
            else
            {
                result.Failed[id] = $"WwiseCLI did not produce output (exit {wwiseResult.ExitCode}): {Truncate(wwiseResult.Output, 500)}";
            }
        }

        return result;
    }

    public static byte[]? ReencodeSingle(byte[] wemBytes, string workDir, WemReencodeOptions options)
    {
        var batch = ReencodeBatch(new Dictionary<string, byte[]> { ["single"] = wemBytes }, workDir, options);
        return batch.Converted.TryGetValue("single", out var bytes) ? bytes : null;
    }

    private static string Truncate(string s, int max) => s.Length <= max ? s : s[^max..];

    private static string XmlEscape(string s) => s.Replace("&", "&amp;").Replace("\"", "&quot;").Replace("<", "&lt;").Replace(">", "&gt;");

    private readonly record struct ProcessResult(int ExitCode, string Output);

    /// <param name="fileName"></param>
    /// <param name="arguments"></param>
    /// <param name="onLine">If supplied, invoked for every line of stdout/stderr as it's produced (may be called
    /// concurrently from separate stdout/stderr reader threads - callers that need to mutate shared state from here
    /// must synchronize themselves), instead of only once the whole process has exited.</param>
    /// <param name="onPollTick">If supplied, invoked roughly every <paramref name="pollIntervalMs"/> while the process
    /// is still running (e.g. to poll for output files on disk as a progress signal, for tools that don't print
    /// anything useful per-item to stdout).</param>
    /// <param name="pollIntervalMs"></param>
    private static ProcessResult RunProcess(string fileName, string arguments, Action<string>? onLine = null, Action? onPollTick = null, int pollIntervalMs = 250)
    {
        var psi = new ProcessStartInfo
        {
            FileName = fileName,
            Arguments = arguments,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };

        var output = new StringBuilder();
        var outputLock = new object();

        void HandleLine(string? line)
        {
            if (line == null) return;
            lock (outputLock)
            {
                output.AppendLine(line);
            }
            onLine?.Invoke(line);
        }

        using var process = Process.Start(psi) ?? throw new InvalidOperationException($"Failed to start '{fileName}'");
        process.OutputDataReceived += (_, e) => HandleLine(e.Data);
        process.ErrorDataReceived += (_, e) => HandleLine(e.Data);
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();

        if (onPollTick != null)
        {
            while (!process.WaitForExit(pollIntervalMs))
            {
                onPollTick();
            }
        }
        else
        {
            process.WaitForExit();
        }

        return new ProcessResult(process.ExitCode, output.ToString());
    }
}
