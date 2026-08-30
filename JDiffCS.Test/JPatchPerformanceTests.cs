using System.Diagnostics;
using ME3TweaksCore.Helpers;

namespace JDiffCS.Test;

/// <summary>
/// Timing-only benchmark for JPatch.ApplyJPatch, separate from the correctness suite in
/// JPatchRoundTripTests. Not a pass/fail perf gate -- just prints numbers so before/after
/// comparisons during optimization work are easy to eyeball.
/// </summary>
[TestClass]
public sealed class JPatchPerformanceTests
{
    private const string JTestRoot = @"B:\UserProfile\Desktop\jtest";
    private const string RealSourcePath = JTestRoot + @"\SFXgame.pcc";
    private const string RealDestPath = JTestRoot + @"\SFXGame_mod.pcc";

    private static byte[] RandomBytes(int size, int seed)
    {
        var rnd = new Random(seed);
        var buf = new byte[size];
        rnd.NextBytes(buf);
        return buf;
    }

    private static byte[] Mutate(byte[] source, int seed, double editFraction)
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
                    do { replaced = rnd.Next(0, 256); } while (replaced == source[i]);
                    outBuf.Add((byte)replaced);
                }
            }
            else if (r < editFraction * 0.7)
            {
                int runLen = rnd.Next(1, 16);
                for (int k = 0; k < runLen; k++)
                    outBuf.Add((byte)rnd.Next(0, 256));
            }
            else if (r < editFraction)
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

    private static void BenchmarkApply(byte[] source, byte[] patchBytes, string label, int reps = 3)
    {
        var times = new List<long>();
        for (int i = 0; i < reps; i++)
        {
            using var src = new MemoryStream(source);
            using var patch = new MemoryStream(patchBytes);
            using var outStream = new MemoryStream(source.Length + 16);

            var sw = Stopwatch.StartNew();
            bool ok = JPatch.ApplyJPatch(src, patch, outStream);
            sw.Stop();

            Assert.IsTrue(ok);
            times.Add(sw.ElapsedMilliseconds);
        }

        var msg = $"{label}: {string.Join(", ", times)} ms  (avg {times.Average():F0} ms, min {times.Min()} ms)";
        Console.WriteLine(msg);
        Debug.WriteLine(msg);
    }

    [TestMethod]
    public void Benchmark_RealWorldFiles()
    {
        Assert.IsTrue(File.Exists(RealSourcePath), $"Missing required source file: {RealSourcePath}");
        Assert.IsTrue(File.Exists(RealDestPath), $"Missing required destination file: {RealDestPath}");

        var source = File.ReadAllBytes(RealSourcePath);
        var dest = File.ReadAllBytes(RealDestPath);

        byte[] patchBytes;
        using (var srcStream = new MemoryStream(source))
        using (var dstStream = new MemoryStream(dest))
        using (var patchStream = new MemoryStream())
        {
            JDiffLib.Run(srcStream, dstStream, patchStream, JDiffOptions.Default.Better());
            patchBytes = patchStream.ToArray();
        }

        Console.WriteLine($"Patch size: {patchBytes.Length:N0} bytes for {source.Length:N0} -> {dest.Length:N0} byte files");
        BenchmarkApply(source, patchBytes, "RealWorldFiles (18MB SFXGame.pcc)");
    }

    [TestMethod]
    public void Benchmark_LargeRandomMutations_20MB()
    {
        var source = RandomBytes(20_000_000, seed: 81);
        var dest = Mutate(source, seed: 82, editFraction: 0.005);

        byte[] patchBytes;
        using (var srcStream = new MemoryStream(source))
        using (var dstStream = new MemoryStream(dest))
        using (var patchStream = new MemoryStream())
        {
            JDiffLib.Run(srcStream, dstStream, patchStream, JDiffOptions.Default.Better());
            patchBytes = patchStream.ToArray();
        }

        Console.WriteLine($"Patch size: {patchBytes.Length:N0} bytes for {source.Length:N0} -> {dest.Length:N0} byte files");
        BenchmarkApply(source, patchBytes, "LargeRandomMutations (20MB synthetic)");
    }

    [TestMethod]
    public void Benchmark_DenseModifications_10MB()
    {
        // A much higher edit density than the real-world file case, to specifically
        // stress the MOD/INS literal-byte-copy path in JPatch (as opposed to the
        // long-EQL-run copy path, which dominates the real-world file benchmark).
        var source = RandomBytes(10_000_000, seed: 91);
        var dest = Mutate(source, seed: 92, editFraction: 0.15);

        byte[] patchBytes;
        using (var srcStream = new MemoryStream(source))
        using (var dstStream = new MemoryStream(dest))
        using (var patchStream = new MemoryStream())
        {
            JDiffLib.Run(srcStream, dstStream, patchStream, JDiffOptions.Default.Better());
            patchBytes = patchStream.ToArray();
        }

        Console.WriteLine($"Patch size: {patchBytes.Length:N0} bytes for {source.Length:N0} -> {dest.Length:N0} byte files");
        BenchmarkApply(source, patchBytes, "DenseModifications (10MB, 15% edit density)");
    }
}
