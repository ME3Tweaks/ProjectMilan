using System.Diagnostics;
using ME3TweaksCore.Helpers;

namespace JDiffCS.Test;

/// <summary>
/// Validates JPatch against real ME3TweaksModManager update patches (produced by the
/// actual JDiff-old.exe + lzma.exe pipeline in PatchBuilder.ps1) rather than synthetic or
/// JDiffCS-generated data. These are the literal files the shipped ApplyJPatch call sites
/// consume in production, so this is the closest thing to a field test available.
/// </summary>
[TestClass]
public sealed class JPatchRealWorldPatchesTests
{
    private const string PatchLibraryRoot = @"Z:\ModLibrary\ModManagerPatches";
    private const string BuildsRoot = PatchLibraryRoot + @"\Builds";
    private const string PatchesRoot = PatchLibraryRoot + @"\Patches";
    private const string LzmaExePath = PatchLibraryRoot + @"\lzma.exe";

    private static string FindBuildFile(string md5Hash)
    {
        foreach (var buildNumDir in Directory.GetDirectories(BuildsRoot))
        {
            var candidate = Path.Combine(buildNumDir, md5Hash + ".exe");
            if (File.Exists(candidate)) return candidate;
        }
        return null;
    }

    /// <summary>Build .exe files are ~200-240MB each on a network share and many samples
    /// reuse the same source/dest build, so cache bytes by hash across the whole run
    /// instead of re-reading the same multi-hundred-MB file repeatedly.</summary>
    private static readonly Dictionary<string, byte[]> BuildBytesCache = new();

    private static byte[] GetBuildBytes(string md5Hash)
    {
        if (BuildBytesCache.TryGetValue(md5Hash, out var cached)) return cached;
        var path = FindBuildFile(md5Hash);
        if (path == null) return null;
        var bytes = File.ReadAllBytes(path);
        BuildBytesCache[md5Hash] = bytes;
        return bytes;
    }

    private static byte[] DecompressLzma(string lzmaPath)
    {
        var outPath = Path.Combine(Path.GetTempPath(), $"jpatch_decomp_{Guid.NewGuid():N}.jdf");
        try
        {
            var psi = new ProcessStartInfo
            {
                FileName = LzmaExePath,
                Arguments = $"d \"{lzmaPath}\" \"{outPath}\"",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };
            using var proc = Process.Start(psi);
            proc.WaitForExit();
            Assert.AreEqual(0, proc.ExitCode, $"lzma.exe decode failed for {lzmaPath}");
            return File.ReadAllBytes(outPath);
        }
        finally
        {
            if (File.Exists(outPath)) File.Delete(outPath);
        }
    }

    /// <summary>Picks the single smallest patch from each destination-build folder.
    /// Build .exe files are ~200-240MB apiece on a network share, so keeping the sample
    /// count small (one per build-number folder, ~9 total) and preferring smaller patches
    /// (smaller compressed patch generally correlates with less MOD/INS-dense content,
    /// but every sample still exercises real EQL/MOD/INS/DEL/BKT sequences end-to-end)
    /// keeps this a reasonable smoke test rather than a multi-gigabyte transfer.</summary>
    private static IEnumerable<string> SampleLzmaFiles()
    {
        foreach (var buildNumDir in Directory.GetDirectories(PatchesRoot).OrderBy(x => x))
        {
            var lzmaFiles = new List<string>();
            foreach (var destHashDir in Directory.GetDirectories(buildNumDir))
            {
                lzmaFiles.AddRange(Directory.GetFiles(destHashDir, "*.lzma"));
            }
            if (lzmaFiles.Count == 0) continue;

            yield return lzmaFiles.OrderBy(f => new FileInfo(f).Length).First();
        }
    }

    [TestMethod]
    public void RealPatchLibrary_SampleAppliesCorrectly()
    {
        Assert.IsTrue(Directory.Exists(PatchLibraryRoot), $"Patch library not available: {PatchLibraryRoot}");
        Assert.IsTrue(File.Exists(LzmaExePath), $"lzma.exe not found: {LzmaExePath}");

        // MSTest buffers Console.WriteLine until the whole test method finishes, which
        // hides progress on a multi-minute network-bound run -- mirror it to a plain file
        // too so progress can be tailed live from outside the test process.
        var progressLogPath = Path.Combine(Path.GetTempPath(), "jpatch_realworld_progress.log");
        File.WriteAllText(progressLogPath, string.Empty);
        void Log(string msg)
        {
            Console.WriteLine(msg);
            File.AppendAllText(progressLogPath, msg + Environment.NewLine);
        }

        var samples = SampleLzmaFiles().ToList();
        Assert.IsTrue(samples.Count > 0, "No sample patches found.");
        Log($"Sampled {samples.Count} patches (progress log: {progressLogPath})");

        int tested = 0;
        long totalSourceBytes = 0;
        var sw = Stopwatch.StartNew();
        var failures = new List<string>();

        foreach (var lzmaPath in samples)
        {
            var fileName = Path.GetFileNameWithoutExtension(lzmaPath); // strip .lzma
            var parts = fileName.Split('-');
            // upd-{srcHash}-{destHash}-{lzmaHash}-{timestamp}
            if (parts.Length < 5 || parts[0] != "upd")
            {
                failures.Add($"{Path.GetFileName(lzmaPath)}: unexpected filename format");
                continue;
            }
            var srcHash = parts[1];
            var destHash = parts[2];

            var sourceBytes = GetBuildBytes(srcHash);
            var destBytes = GetBuildBytes(destHash);
            if (sourceBytes == null || destBytes == null)
            {
                failures.Add($"{Path.GetFileName(lzmaPath)}: could not locate source/dest build (src found={sourceBytes != null}, dest found={destBytes != null})");
                continue;
            }

            var patchBytes = DecompressLzma(lzmaPath);
            totalSourceBytes += sourceBytes.Length;

            using var srcStream = new MemoryStream(sourceBytes);
            using var patchStream = new MemoryStream(patchBytes);
            using var outStream = new MemoryStream(destBytes.Length + 16);

            var applySw = Stopwatch.StartNew();
            bool ok = JPatch.ApplyJPatch(srcStream, patchStream, outStream);
            applySw.Stop();

            var result = outStream.ToArray();
            tested++;

            if (!ok || result.Length != destBytes.Length || !result.AsSpan().SequenceEqual(destBytes))
            {
                Log($"FAIL {Path.GetFileName(lzmaPath)}: ok={ok}, resultLen={result.Length}, destLen={destBytes.Length}");
                failures.Add($"{Path.GetFileName(lzmaPath)}: MISMATCH (ok={ok}, resultLen={result.Length}, destLen={destBytes.Length})");
            }
            else
            {
                Log($"OK  {Path.GetFileName(lzmaPath)}  src={sourceBytes.Length:N0}B patch={patchBytes.Length:N0}B  apply={applySw.ElapsedMilliseconds}ms");
            }
        }

        sw.Stop();
        Log($"Tested {tested}/{samples.Count} real-world patches from {PatchLibraryRoot} in {sw.ElapsedMilliseconds}ms total ({totalSourceBytes:N0} source bytes, {BuildBytesCache.Count} unique builds loaded)");

        if (failures.Count > 0)
        {
            Assert.Fail($"{failures.Count}/{tested} real patches failed to apply correctly:\n" + string.Join("\n", failures));
        }
    }

    /// <summary>
    /// The production call site (ProgramUpdateNotification.xaml.cs) reads the source build
    /// from a live on-disk FileStream (File.OpenRead(App.ExecutableLocation)), not a
    /// MemoryStream like the benchmarks above. JojoDiff's BKT opcode moves the source read
    /// cursor backwards to re-sync after a shifted/moved region, which is free on a
    /// MemoryStream but can defeat FileStream's internal read-ahead buffer and force a real
    /// seek+read syscall per EQL run if the access pattern isn't sequential. This test
    /// isolates that variable directly against the same real patch data.
    /// </summary>
    [TestMethod]
    public void RealPatchLibrary_FileStreamVsMemoryStreamSource()
    {
        Assert.IsTrue(Directory.Exists(PatchLibraryRoot), $"Patch library not available: {PatchLibraryRoot}");
        Assert.IsTrue(File.Exists(LzmaExePath), $"lzma.exe not found: {LzmaExePath}");

        // Known-good ~30MB patch confirmed present and correct by the earlier 9-sample
        // run -- reused directly by full path instead of re-scanning all ~200 patch files
        // across the network share for "largest" (that whole-library enumeration is what
        // hung/died last attempt).
        const string KnownLargePatch = PatchesRoot + @"\130\30c98ff45dd5ef832c25b0dc9ff84acb\upd-62a8c616f7f5c09b1247d241434559d7-30c98ff45dd5ef832c25b0dc9ff84acb-4ab7c13539849c896ef8674487f734e1-638280728291932461.lzma";
        Assert.IsTrue(File.Exists(KnownLargePatch), $"Expected patch not found: {KnownLargePatch}");

        var lzmaPath = KnownLargePatch;
        var fileName = Path.GetFileNameWithoutExtension(lzmaPath);
        var parts = fileName.Split('-');
        Assert.IsTrue(parts.Length >= 5 && parts[0] == "upd", $"Unexpected filename format: {fileName}");
        var srcHash = parts[1];
        var destHash = parts[2];

        var sourceBytes = GetBuildBytes(srcHash);
        var destBytes = GetBuildBytes(destHash);
        Assert.IsNotNull(sourceBytes, $"Could not locate source build {srcHash}");
        Assert.IsNotNull(destBytes, $"Could not locate dest build {destHash}");

        var patchBytes = DecompressLzma(lzmaPath);
        Console.WriteLine($"Using {Path.GetFileName(lzmaPath)}: src={sourceBytes.Length:N0}B patch={patchBytes.Length:N0}B dest={destBytes.Length:N0}B");

        // --- MemoryStream source (what the earlier benchmarks measured) ---
        long memMs;
        {
            using var srcStream = new MemoryStream(sourceBytes);
            using var patchStream = new MemoryStream(patchBytes);
            using var outStream = new MemoryStream(destBytes.Length + 16);
            var sw = Stopwatch.StartNew();
            bool ok = JPatch.ApplyJPatch(srcStream, patchStream, outStream);
            sw.Stop();
            memMs = sw.ElapsedMilliseconds;
            Assert.IsTrue(ok);
            Assert.IsTrue(outStream.ToArray().AsSpan().SequenceEqual(destBytes));
        }

        // --- FileStream source (what production actually does), with a callback that
        // actually does something (Console.WriteLine has real formatting + method-dispatch
        // overhead per call, unlike a bare counter increment) so this reflects the cost of
        // the now-throttled callback rather than an artificially free one. ---
        long fileMs;
        int callbackInvocations = 0;
        var tempSourcePath = Path.Combine(Path.GetTempPath(), $"jpatch_source_{Guid.NewGuid():N}.exe");
        try
        {
            File.WriteAllBytes(tempSourcePath, sourceBytes);

            using var srcStream = File.OpenRead(tempSourcePath);
            using var patchStream = new MemoryStream(patchBytes);
            using var outStream = new MemoryStream(destBytes.Length + 16);
            var sw = Stopwatch.StartNew();
            bool ok = JPatch.ApplyJPatch(srcStream, patchStream, outStream, (pos, len) =>
            {
                callbackInvocations++;
                Console.WriteLine($"Patch progress: {pos:N0}/{len:N0}");
            });
            sw.Stop();
            fileMs = sw.ElapsedMilliseconds;
            Assert.IsTrue(ok);
            Assert.IsTrue(outStream.ToArray().AsSpan().SequenceEqual(destBytes));
        }
        finally
        {
            if (File.Exists(tempSourcePath)) File.Delete(tempSourcePath);
        }

        Console.WriteLine($"MemoryStream source: {memMs}ms");
        Console.WriteLine($"FileStream source:   {fileMs}ms  ({callbackInvocations:N0} progress callback invocations, each doing a Console.WriteLine)");
        Console.WriteLine($"Ratio: {(double)fileMs / Math.Max(1, memMs):F1}x");
    }

    /// <summary>
    /// Quantifies, independent of JPatch itself, how much the throttling fix in
    /// ApplyJPatch actually saves in wall time -- using Console.WriteLine as a stand-in
    /// for "a callback that does real, non-trivial work" (like the production callback's
    /// WPF property sets triggering data-binding updates), since a bare counter increment
    /// has no measurable cost at any call count and so can't show the effect at all.
    /// Compares the pre-fix call count actually measured against the real 30MB patch
    /// (5,129,415 invocations, one per opcode operation) against the post-fix throttled
    /// count (188 invocations, ~every 0.5% of the patch file). Console output during the
    /// timed loops is redirected to a null sink -- otherwise printing 5+ million lines to
    /// the real test output would itself dominate the measurement and flood the log.
    /// </summary>
    [TestMethod]
    public void CallbackFrequency_ConsoleWriteLineOverheadComparison()
    {
        const int throttledCount = 188;        // measured post-fix call count for the 30MB patch
        const int unthrottledCount = 5_129_415; // measured pre-fix call count for the same patch

        var realOut = Console.Out;
        long throttledMs, unthrottledMs;
        try
        {
            Console.SetOut(TextWriter.Null);

            var sw1 = Stopwatch.StartNew();
            for (int i = 0; i < throttledCount; i++)
                Console.WriteLine($"Patch progress: {i:N0}/{throttledCount:N0}");
            sw1.Stop();
            throttledMs = sw1.ElapsedMilliseconds;

            var sw2 = Stopwatch.StartNew();
            for (int i = 0; i < unthrottledCount; i++)
                Console.WriteLine($"Patch progress: {i:N0}/{unthrottledCount:N0}");
            sw2.Stop();
            unthrottledMs = sw2.ElapsedMilliseconds;
        }
        finally
        {
            Console.SetOut(realOut);
        }

        Console.WriteLine($"Throttled (post-fix):    {throttledCount:N0} calls in {throttledMs}ms");
        Console.WriteLine($"Unthrottled (pre-fix):   {unthrottledCount:N0} calls in {unthrottledMs}ms");
        Console.WriteLine($"Callback-overhead savings: {unthrottledMs - throttledMs}ms ({(unthrottledMs > 0 ? 100.0 * (unthrottledMs - throttledMs) / unthrottledMs : 0):F1}%)");
    }
}
