using System.Diagnostics;
using ME3TweaksCore.Helpers;

namespace JDiffCS.Test;

/// <summary>
/// Round-trips synthetic and real-world datasets through JDiffCS (diff) and JPatch
/// (patch) and verifies the patched output reproduces the destination data exactly.
/// </summary>
[TestClass]
public sealed class JPatchRoundTripTests
{
    private const string JTestRoot = @"B:\UserProfile\Desktop\jtest";
    private const string JDiffExePath = JTestRoot + @"\JDiff.exe";
    private const string RealSourcePath = JTestRoot + @"\SFXgame.pcc";
    private const string RealDestPath = JTestRoot + @"\SFXGame_mod.pcc";

    // ---------------------------------------------------------------
    // Data generation helpers
    // ---------------------------------------------------------------

    private static byte[] RandomBytes(int size, int seed, int minByte = 0, int maxByteExclusive = 256)
    {
        var rnd = new Random(seed);
        var buf = new byte[size];
        for (int i = 0; i < size; i++)
            buf[i] = (byte)rnd.Next(minByte, maxByteExclusive);
        return buf;
    }

    /// <summary>
    /// Produces a mutated copy of <paramref name="source"/> with randomly interspersed
    /// modify/insert/delete runs, leaving the rest byte-identical. <paramref name="editFraction"/>
    /// is the rough probability, per source byte considered, that an edit run starts there.
    /// </summary>
    private static byte[] Mutate(byte[] source, int seed, double editFraction = 0.02,
                                  bool allowInsertDelete = true, int minByte = 0, int maxByteExclusive = 256)
    {
        var rnd = new Random(seed);
        var outBuf = new List<byte>(source.Length + source.Length / 8 + 16);
        int i = 0;
        while (i < source.Length)
        {
            double r = rnd.NextDouble();
            if (r < editFraction * 0.4)
            {
                int runLen = rnd.Next(1, 8);
                for (int k = 0; k < runLen && i < source.Length; k++, i++)
                {
                    int replaced;
                    do { replaced = rnd.Next(minByte, maxByteExclusive); } while (replaced == source[i]);
                    outBuf.Add((byte)replaced);
                }
            }
            else if (allowInsertDelete && r < editFraction * 0.7)
            {
                int runLen = rnd.Next(1, 16);
                for (int k = 0; k < runLen; k++)
                    outBuf.Add((byte)rnd.Next(minByte, maxByteExclusive));
            }
            else if (allowInsertDelete && r < editFraction)
            {
                int runLen = rnd.Next(1, 16);
                i = Math.Min(source.Length, i + runLen);
            }
            else
            {
                outBuf.Add(source[i]);
                i++;
            }
        }
        return outBuf.ToArray();
    }

    /// <summary>Builds a buffer by tiling a fixed-size random pattern, to encourage repeated
    /// hash matches (and thus backtracking / BKT opcodes) in the diff search.</summary>
    private static byte[] TiledPattern(int totalSize, int patternSize, int seed)
    {
        var pattern = RandomBytes(patternSize, seed);
        var buf = new byte[totalSize];
        for (int i = 0; i < totalSize; i++)
            buf[i] = pattern[i % patternSize];
        return buf;
    }

    // ---------------------------------------------------------------
    // Round-trip assertion
    // ---------------------------------------------------------------

    private static void AssertRoundTrip(byte[] source, byte[] dest, JDiffOptions options, string label)
    {
        byte[] patchBytes;
        using (var srcStream = new MemoryStream(source))
        using (var dstStream = new MemoryStream(dest))
        using (var patchStream = new MemoryStream())
        {
            JDiffLib.Run(srcStream, dstStream, patchStream, options);
            patchBytes = patchStream.ToArray();
        }

        using var applySrc = new MemoryStream(source);
        using var applyPatch = new MemoryStream(patchBytes);
        using var outStream = new MemoryStream(dest.Length + 16);

        bool ok = JPatch.ApplyJPatch(applySrc, applyPatch, outStream);
        Assert.IsTrue(ok, $"[{label}] JPatch.ApplyJPatch returned false");

        var result = outStream.ToArray();

        if (result.Length != dest.Length)
        {
            Assert.Fail($"[{label}] Output length mismatch: expected {dest.Length}, got {result.Length} " +
                        $"(source {source.Length} bytes, patch {patchBytes.Length} bytes)");
        }

        if (!result.AsSpan().SequenceEqual(dest))
        {
            int firstDiff = -1;
            for (int i = 0; i < dest.Length; i++)
            {
                if (result[i] != dest[i]) { firstDiff = i; break; }
            }
            Assert.Fail($"[{label}] Output content mismatch at byte {firstDiff}: " +
                        $"expected 0x{dest[firstDiff]:X2}, got 0x{result[firstDiff]:X2} " +
                        $"(source {source.Length} bytes, dest {dest.Length} bytes, patch {patchBytes.Length} bytes)");
        }
    }

    private static readonly JDiffOptions[] OptionVariants =
    {
        JDiffOptions.Default,
        JDiffOptions.Default.Better(),
        JDiffOptions.Default.Faster(),
    };

    private static string VariantLabel(JDiffOptions o, int idx) => idx switch
    {
        0 => "Default",
        1 => "Better",
        2 => "Faster",
        _ => $"Variant{idx}"
    };

    // ---------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------

    [TestMethod]
    public void IdenticalFiles()
    {
        foreach (int size in new[] { 0, 1, 17, 4096, 500_000 })
        {
            var data = RandomBytes(size, seed: 1000 + size);
            for (int v = 0; v < OptionVariants.Length; v++)
                AssertRoundTrip(data, data, OptionVariants[v], $"IdenticalFiles size={size} {VariantLabel(OptionVariants[v], v)}");
        }
    }

    [TestMethod]
    public void EmptyFileEdgeCases()
    {
        var nonEmpty = RandomBytes(2048, seed: 5);

        for (int v = 0; v < OptionVariants.Length; v++)
        {
            AssertRoundTrip(Array.Empty<byte>(), Array.Empty<byte>(), OptionVariants[v], $"EmptyToEmpty {VariantLabel(OptionVariants[v], v)}");
            AssertRoundTrip(Array.Empty<byte>(), nonEmpty, OptionVariants[v], $"EmptyToNonEmpty {VariantLabel(OptionVariants[v], v)}");
            AssertRoundTrip(nonEmpty, Array.Empty<byte>(), OptionVariants[v], $"NonEmptyToEmpty {VariantLabel(OptionVariants[v], v)}");
        }
    }

    [TestMethod]
    public void CompletelyDifferent_SameSize()
    {
        var source = RandomBytes(200_000, seed: 11);
        var dest = RandomBytes(200_000, seed: 12);

        for (int v = 0; v < OptionVariants.Length; v++)
            AssertRoundTrip(source, dest, OptionVariants[v], $"CompletelyDifferent {VariantLabel(OptionVariants[v], v)}");
    }

    [TestMethod]
    public void RandomMutations_Small()
    {
        var source = RandomBytes(50_000, seed: 21);
        foreach (double frac in new[] { 0.001, 0.01, 0.05, 0.2 })
        {
            var dest = Mutate(source, seed: 100 + (int)(frac * 1000), editFraction: frac);
            for (int v = 0; v < OptionVariants.Length; v++)
                AssertRoundTrip(source, dest, OptionVariants[v], $"RandomMutations frac={frac} {VariantLabel(OptionVariants[v], v)}");
        }
    }

    [TestMethod]
    public void Insertions_MakeDestLonger()
    {
        var source = RandomBytes(100_000, seed: 31);
        var dest = Mutate(source, seed: 32, editFraction: 0.15, allowInsertDelete: true);

        for (int v = 0; v < OptionVariants.Length; v++)
            AssertRoundTrip(source, dest, OptionVariants[v], $"Insertions {VariantLabel(OptionVariants[v], v)}");
    }

    [TestMethod]
    public void Deletions_MakeDestShorter()
    {
        var source = RandomBytes(100_000, seed: 41);
        // Build dest by deleting chunks only (no inserts), guaranteeing dest is shorter.
        var rnd = new Random(42);
        var outBuf = new List<byte>();
        int i = 0;
        while (i < source.Length)
        {
            if (rnd.NextDouble() < 0.03)
            {
                i += rnd.Next(1, 200);
            }
            else
            {
                outBuf.Add(source[i]);
                i++;
            }
        }
        var dest = outBuf.ToArray();
        Assert.IsTrue(dest.Length < source.Length);

        for (int v = 0; v < OptionVariants.Length; v++)
            AssertRoundTrip(source, dest, OptionVariants[v], $"Deletions {VariantLabel(OptionVariants[v], v)}");
    }

    [TestMethod]
    public void RepeatedPatternsForceBacktracking()
    {
        // Tiling a small pattern produces many equally-good hash matches, which stresses
        // the search/backtrack (BKT) path much harder than purely random data does.
        var source = TiledPattern(300_000, patternSize: 37, seed: 51);
        var dest = Mutate(source, seed: 52, editFraction: 0.03);

        for (int v = 0; v < OptionVariants.Length; v++)
            AssertRoundTrip(source, dest, OptionVariants[v], $"RepeatedPatterns {VariantLabel(OptionVariants[v], v)}");
    }

    [TestMethod]
    public void OpcodeByteValuesStressEscaping()
    {
        // Constrain the byte alphabet to a narrow band straddling the 0xA2-0xA7 opcode
        // range so both files are dense with bytes that must be escaped in the patch stream.
        var source = RandomBytes(150_000, seed: 61, minByte: 0x9E, maxByteExclusive: 0xAC);
        var dest = Mutate(source, seed: 62, editFraction: 0.08, minByte: 0x9E, maxByteExclusive: 0xAC);

        for (int v = 0; v < OptionVariants.Length; v++)
            AssertRoundTrip(source, dest, OptionVariants[v], $"OpcodeStress {VariantLabel(OptionVariants[v], v)}");
    }

    [TestMethod]
    public void AllBytesAreEscapeValue()
    {
        // Pathological: every byte in both files is exactly 0xA7 (ESC), except for a
        // handful of forced mismatches so a diff is actually produced.
        var source = new byte[20_000];
        Array.Fill(source, (byte)0xA7);
        var dest = (byte[])source.Clone();
        dest[10] = 0x01;
        dest[5000] = 0x02;
        dest[19_999] = 0x03;

        for (int v = 0; v < OptionVariants.Length; v++)
            AssertRoundTrip(source, dest, OptionVariants[v], $"AllEscapeValue {VariantLabel(OptionVariants[v], v)}");
    }

    [TestMethod]
    public void LengthEncodingBoundaries()
    {
        // UfPutLen/getJLength switch encoding width at 252, 508, and 0x10000. Build an
        // exact-length equal run bracketed by mismatches at each boundary so the diff
        // is forced to emit that exact EQL length.
        foreach (int runLen in new[] { 1, 2, 3, 251, 252, 253, 507, 508, 509, 65535, 65536, 65537, 200_000 })
        {
            var prefix = RandomBytes(64, seed: 71 + runLen);
            var run = RandomBytes(runLen, seed: 72 + runLen);
            var suffix = RandomBytes(64, seed: 73 + runLen);

            var source = prefix.Concat(run).Concat(suffix).ToArray();

            var destPrefix = (byte[])prefix.Clone();
            destPrefix[0] ^= 0xFF; // force a leading mismatch
            var destSuffix = (byte[])suffix.Clone();
            destSuffix[^1] ^= 0xFF; // force a trailing mismatch

            var dest = destPrefix.Concat(run).Concat(destSuffix).ToArray();

            for (int v = 0; v < OptionVariants.Length; v++)
                AssertRoundTrip(source, dest, OptionVariants[v], $"LengthBoundary runLen={runLen} {VariantLabel(OptionVariants[v], v)}");
        }
    }

    [TestMethod]
    public void LargeRandomMutations_20MB()
    {
        var source = RandomBytes(20_000_000, seed: 81);
        var dest = Mutate(source, seed: 82, editFraction: 0.005);

        // Only exercise Default and Better here -- three full 20MB passes per variant
        // is not worth the wall-clock time for this particular case.
        AssertRoundTrip(source, dest, JDiffOptions.Default, "Large20MB Default");
        AssertRoundTrip(source, dest, JDiffOptions.Default.Better(), "Large20MB Better");
    }

    [TestMethod]
    public void RealWorldFiles()
    {
        Assert.IsTrue(File.Exists(RealSourcePath), $"Missing required source file: {RealSourcePath}");
        Assert.IsTrue(File.Exists(RealDestPath), $"Missing required destination file: {RealDestPath}");

        var source = File.ReadAllBytes(RealSourcePath);
        var dest = File.ReadAllBytes(RealDestPath);

        AssertRoundTrip(source, dest, JDiffOptions.Default.Better(), "RealWorld SFXGame.pcc Better");
    }

    /// <summary>
    /// Cross-validates JPatch against a patch produced by the actual JDiff.exe binary
    /// (the tool JPatch was originally written and tested against), not JDiffCS's own
    /// output. This closes the blind spot where JOutBin and JPatch could theoretically
    /// share a matching misunderstanding of the format and still round-trip with each
    /// other while both silently diverging from the real spec.
    /// </summary>
    [TestMethod]
    public void RealWorldFiles_PatchFromActualJDiffExe()
    {
        Assert.IsTrue(File.Exists(JDiffExePath), $"Missing required executable: {JDiffExePath}");
        Assert.IsTrue(File.Exists(RealSourcePath), $"Missing required source file: {RealSourcePath}");
        Assert.IsTrue(File.Exists(RealDestPath), $"Missing required destination file: {RealDestPath}");

        var exePatchPath = Path.Combine(Path.GetTempPath(), $"jdiffexe_patch_{Guid.NewGuid():N}.jdf");
        try
        {
            using (var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = JDiffExePath,
                    Arguments = $"-j -b \"{RealSourcePath}\" \"{RealDestPath}\" \"{exePatchPath}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            })
            {
                Assert.IsTrue(process.Start(), "Failed to start JDiff.exe process.");
                process.WaitForExit();
                Assert.AreEqual(1, process.ExitCode, "JDiff.exe exited with unexpected code.");
            }

            var source = File.ReadAllBytes(RealSourcePath);
            var dest = File.ReadAllBytes(RealDestPath);
            var patchBytes = File.ReadAllBytes(exePatchPath);

            using var applySrc = new MemoryStream(source);
            using var applyPatch = new MemoryStream(patchBytes);
            using var outStream = new MemoryStream(dest.Length + 16);

            bool ok = JPatch.ApplyJPatch(applySrc, applyPatch, outStream);
            Assert.IsTrue(ok, "JPatch.ApplyJPatch returned false");

            var result = outStream.ToArray();
            Assert.AreEqual(dest.Length, result.Length, $"Output length mismatch (patch {patchBytes.Length} bytes)");
            Assert.IsTrue(result.AsSpan().SequenceEqual(dest), "Output content mismatch against JDiff.exe-produced patch");
        }
        finally
        {
            if (File.Exists(exePatchPath)) File.Delete(exePatchPath);
        }
    }
}
