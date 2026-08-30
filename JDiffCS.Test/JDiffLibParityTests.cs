using System.Diagnostics;

namespace JDiffCS.Test;

[TestClass]
public sealed class JDiffLibParityTests
{
    private const string JTestRoot = @"B:\UserProfile\Desktop\jtest";
    private const string JDiffExePath = JTestRoot + @"\JDiff.exe";
    private const string SourceFilePath = JTestRoot + @"\SFXgame.pcc";
    private const string DestFilePath = JTestRoot + @"\SFXGame_mod.pcc";

    [TestMethod]
    public void BetterMode_OutputMatchesJDiffExe_ByteForByte()
    {
        Assert.IsTrue(File.Exists(JDiffExePath), $"Missing required executable: {JDiffExePath}");
        Assert.IsTrue(File.Exists(SourceFilePath), $"Missing required source file: {SourceFilePath}");
        Assert.IsTrue(File.Exists(DestFilePath), $"Missing required destination file: {DestFilePath}");

        var managedPatchPath = Path.Combine(Path.GetTempPath(), $"jdifflib_{Guid.NewGuid():N}.jdf");
        var exePatchPath = Path.Combine(Path.GetTempPath(), $"jdiffexe_{Guid.NewGuid():N}.jdf");

        try
        {
            using var instream1 = new MemoryStream(File.ReadAllBytes(SourceFilePath));
            using var instream2 = new MemoryStream(File.ReadAllBytes(DestFilePath));

            var managedStopwatch = Stopwatch.StartNew();
            var result = JDiffLib.Run(instream1, instream2, managedPatchPath, JDiffOptions.Default.Better());
            managedStopwatch.Stop();

            var managedMessage = $"JDiffLib execution time: {managedStopwatch.ElapsedMilliseconds} ms";
            Console.WriteLine(managedMessage);
            Debug.WriteLine(managedMessage);

            Assert.IsTrue(result.FilesAreDifferent, "Expected input files to differ for diff generation.");

            var processStopwatch = Stopwatch.StartNew();
            using var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = JDiffExePath,
                    Arguments = $"-j -b \"{SourceFilePath}\" \"{DestFilePath}\" \"{exePatchPath}\"",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    CreateNoWindow = true
                }
            };

            var started = process.Start();
            Assert.IsTrue(started, "Failed to start JDiff.exe process.");

            process.WaitForExit();
            processStopwatch.Stop();

            var processMessage = $"JDiff.exe execution time: {processStopwatch.ElapsedMilliseconds} ms";
            Console.WriteLine(processMessage);
            Debug.WriteLine(processMessage);

            var comparisonMessage = $"Performance difference: JDiffLib was {(processStopwatch.ElapsedMilliseconds - managedStopwatch.ElapsedMilliseconds > 0 ? "faster" : "slower")} by {Math.Abs(processStopwatch.ElapsedMilliseconds - managedStopwatch.ElapsedMilliseconds)} ms";
            Console.WriteLine(comparisonMessage);
            Debug.WriteLine(comparisonMessage);

            var stdOut = process.StandardOutput.ReadToEnd();
            var stdErr = process.StandardError.ReadToEnd();

            Assert.AreEqual(1, process.ExitCode, $"JDiff.exe exited with unexpected code {process.ExitCode}.\nSTDOUT:\n{stdOut}\nSTDERR:\n{stdErr}");
            Assert.IsTrue(File.Exists(exePatchPath), $"JDiff.exe did not produce expected patch file: {exePatchPath}");
            Assert.IsTrue(File.Exists(managedPatchPath), $"JDiffLib did not produce expected patch file: {managedPatchPath}");

            var managedBytes = File.ReadAllBytes(managedPatchPath);
            var exeBytes = File.ReadAllBytes(exePatchPath);

            Assert.IsTrue(
                managedBytes.SequenceEqual(exeBytes),
                $"Patch output mismatch. Managed patch bytes: {managedBytes.Length}, exe patch bytes: {exeBytes.Length}");
        }
        finally
        {
            if (File.Exists(managedPatchPath))
            {
                File.Delete(managedPatchPath);
            }

            if (File.Exists(exePatchPath))
            {
                File.Delete(exePatchPath);
            }
        }
    }

    [TestMethod]
    public void ProgressChanged_ReportsMonotonicFractionsEndingAtOne()
    {
        Assert.IsTrue(File.Exists(SourceFilePath), $"Missing required source file: {SourceFilePath}");
        Assert.IsTrue(File.Exists(DestFilePath), $"Missing required destination file: {DestFilePath}");

        var patchPath = Path.Combine(Path.GetTempPath(), $"jdifflib_prg_{Guid.NewGuid():N}.jdf");
        var reported = new List<double>();

        try
        {
            using var instream1 = new MemoryStream(File.ReadAllBytes(SourceFilePath));
            using var instream2 = new MemoryStream(File.ReadAllBytes(DestFilePath));

            var options = JDiffOptions.Default.Better();
            options.ProgressChanged = f => reported.Add(f);

            var result = JDiffLib.Run(instream1, instream2, patchPath, options);

            Assert.IsTrue(result.FilesAreDifferent);
            Assert.IsTrue(reported.Count > 1, "Expected multiple progress callbacks for an 18MB pair.");

            for (int i = 1; i < reported.Count; i++)
            {
                Assert.IsTrue(reported[i] >= reported[i - 1],
                    $"Progress went backwards at index {i}: {reported[i - 1]} -> {reported[i]}");
            }

            Assert.IsTrue(reported[0] >= 0.0 && reported[0] <= 1.0);
            Assert.AreEqual(1.0, reported[^1], "Final progress callback should report completion.");
        }
        finally
        {
            if (File.Exists(patchPath))
            {
                File.Delete(patchPath);
            }
        }
    }
}
