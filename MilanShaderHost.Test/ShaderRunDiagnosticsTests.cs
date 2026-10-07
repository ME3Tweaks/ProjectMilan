namespace MilanShaderHost.Test;

[TestClass]
[DoNotParallelize]
public class ShaderRunDiagnosticsTests
{
    private string root = null!;
    [TestInitialize] public void SetUp() { root = Path.Combine(Path.GetTempPath(), "ShaderRunDiagnostics-" + Guid.NewGuid()); Directory.CreateDirectory(root); }
    [TestCleanup] public void TearDown() { Directory.Delete(root, recursive: true); }

    [TestMethod]
    public void TranslationFailureAndDetailsAreForwardedAndRetainedAcrossLaunches()
    {
        var source = Path.Combine(root, "ShaderClient.log");
        var launched = DateTime.UtcNow.AddSeconds(-1);
        const string failure = "[07:49:09.525 error] (LE3ShaderClient) Material failed to compile: Thessia_MoonMoon";
        const string detail = "[07:49:09.571 warning] (LE3ShaderClient)   TextureSample> Missing input texture";
        File.WriteAllLines(source, ["[07:49:09.000 info] (LE3ShaderClient) Welcome", failure, detail]);
        var output = new StringWriter(); var error = new StringWriter();
        var first = ShaderRunDiagnostics.ArchiveClientLog(root, 1, source, "biot_cerberus", "Compile", 10, launched, output, error);
        Assert.AreEqual(1, first.Errors); Assert.AreEqual(1, first.Warnings); Assert.IsTrue(first.MaterialCompileFailed);
        StringAssert.Contains(error.ToString(), "[biot_cerberus][Compile][PID 10]");
        StringAssert.Contains(error.ToString(), failure); StringAssert.Contains(output.ToString(), detail);
        Assert.IsFalse(output.ToString().Contains("Welcome"));
        File.WriteAllText(source, "[08:00:00.000 info] (LE3ShaderClient) Different launch");
        var second = ShaderRunDiagnostics.ArchiveClientLog(root, 2, source, "biot_cerberus", "Compile", 11, launched, output, error);
        Assert.AreNotEqual(first.Path, second.Path); StringAssert.Contains(File.ReadAllText(first.Path!), failure);
        Assert.IsFalse(second.MaterialCompileFailed); Assert.AreEqual(2, File.ReadAllLines(Path.Combine(root, "client-captures.jsonl")).Length);
    }

    [TestMethod]
    public void StaleLogCannotAttributeAnEarlierFailureToANewPackage()
    {
        var source = Path.Combine(root, "ShaderClient.log");
        File.WriteAllText(source, "[07:49:09.525 error] (LE3ShaderClient) Material failed to compile: Old");
        File.SetLastWriteTimeUtc(source, DateTime.UtcNow.AddMinutes(-5));
        var error = new StringWriter();
        var result = ShaderRunDiagnostics.ArchiveClientLog(root, 1, source, "New", "Compile", 12, DateTime.UtcNow, new StringWriter(), error);
        Assert.IsNull(result.Path); Assert.IsFalse(result.MaterialCompileFailed);
        Assert.IsFalse(error.ToString().Contains("Old")); StringAssert.Contains(error.ToString(), "No fresh client log");
    }

    [TestMethod]
    public void PersistentHostLogIncludesConcurrentStdoutAndStderr()
    {
        var directory = Path.Combine(root, "session");
        string file;
        using (var session = new ShaderRunDiagnostics(directory))
        {
            file = session.LogFilePath;
            Parallel.For(0, 20, i => { Console.Out.WriteLine("OUT-" + i); Console.Error.WriteLine("ERROR-" + i); });
        }
        var lines = File.ReadAllLines(file);
        Assert.AreEqual(20, lines.Count(x => x.Contains(" INF] OUT-")));
        Assert.AreEqual(20, lines.Count(x => x.Contains(" ERR] ERROR-")));
    }
    [TestMethod]
    public void RetainsThreeTimestampedRunsAndTheirClientArchives()
    {
        var directory = Path.Combine(root, "retention");
        Directory.CreateDirectory(directory);
        File.WriteAllText(Path.Combine(directory, "unrelated.log"), "keep");
        var runs = new List<(string Log, string Archive)>();
        for (var i = 0; i < 5; ++i)
        {
            using var session = new ShaderRunDiagnostics(directory, $"20261004T14000{i}0000000Z-{Environment.ProcessId}");
            runs.Add((session.LogFilePath, session.DirectoryPath));
            File.WriteAllText(Path.Combine(session.DirectoryPath, "client.log"), "diagnostics");
            Console.WriteLine("RUN-" + i);
        }
        Assert.AreEqual(3, Directory.GetFiles(directory, "ShaderHost-*.log").Length);
        for (var i = 0; i < 5; ++i)
        {
            Assert.AreEqual(i >= 2, File.Exists(runs[i].Log));
            Assert.AreEqual(i >= 2, Directory.Exists(runs[i].Archive));
        }
        Assert.IsTrue(File.Exists(Path.Combine(directory, "unrelated.log")));
    }

    [TestMethod]
    public void FlushPreservesPartialMessagesAndNativeWarningSeverity()
    {
        string file;
        using (var session = new ShaderRunDiagnostics(Path.Combine(root, "partial")))
        {
            file = session.LogFilePath;
            Console.Write("partial "); Console.Write("{literal}");
            Console.WriteLine(" complete");
            Console.WriteLine("[ShaderClient][Package] [08:00:00.000 warning] Missing input texture");
            Console.Error.Write("unclosed error");
        }
        var content = File.ReadAllText(file);
        StringAssert.Contains(content, " INF] partial {literal} complete");
        StringAssert.Contains(content, " WRN] [ShaderClient][Package]");
        StringAssert.Contains(content, " ERR] unclosed error");
    }

}
