using System.Diagnostics;

namespace UDKLevelSelect;

/// <summary>
/// Lets the user pick one of the levels under ProjectMilan/Pipelines/StaticLighting/Levels, copies
/// its maps into the Milan UDK install (wiping any other maps first), and boots UDK on it.
/// </summary>
internal static class Program
{
    private const string UdkPathEnvVar = "MILAN_UDK_PATH";

    // Where the Milan pipelines keep the UDK install on the dev machines, tried when nothing else is given.
    private static readonly string[] KnownUdkPaths = [@"S:\Milan\UDK", @"E:\Milan\UDK"];

    private static int Main(string[] args)
    {
        try
        {
            var levelsRoot = FindLevelsRoot();
            if (levelsRoot == null)
                return Fail("Could not find ProjectMilan\\Pipelines\\StaticLighting\\Levels above the executable.");

            var udkRoot = ResolveUdkRoot(args);
            if (udkRoot == null)
                return Fail($"Could not find the Milan UDK. Pass its path as the first argument or set {UdkPathEnvVar}.");

            var levels = Directory.GetDirectories(levelsRoot)
                .Select(d => new DirectoryInfo(d).Name)
                .Where(name => File.Exists(Path.Combine(levelsRoot, name, name + ".udk")))
                .OrderBy(name => name, StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (levels.Count == 0)
                return Fail($"No levels with a master .udk found in {levelsRoot}");

            var level = PromptForLevel(levels);
            if (level == null)
                return 0;

            LoadLevel(levelsRoot, udkRoot, level);
            return 0;
        }
        catch (Exception ex)
        {
            return Fail(ex.Message);
        }
    }

    private static int Fail(string message)
    {
        Console.Error.WriteLine($"Error: {message}");
        return 1;
    }

    /// <summary>Walks up from the executable until the repo's StaticLighting/Levels folder turns up.</summary>
    private static string? FindLevelsRoot()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir != null; dir = dir.Parent)
        {
            var candidate = Path.Combine(dir.FullName, "ProjectMilan", "Pipelines", "StaticLighting", "Levels");
            if (Directory.Exists(candidate))
                return candidate;
        }
        return null;
    }

    private static string? ResolveUdkRoot(string[] args)
    {
        var candidates = new List<string?> { args.FirstOrDefault(), Environment.GetEnvironmentVariable(UdkPathEnvVar) };
        candidates.AddRange(KnownUdkPaths);
        return candidates.FirstOrDefault(c => !string.IsNullOrWhiteSpace(c) && IsUdkRoot(c!));
    }

    private static bool IsUdkRoot(string path) => File.Exists(Path.Combine(path, "Binaries", "Win64", "UDK.exe"));

    private static string? PromptForLevel(List<string> levels)
    {
        while (true)
        {
            Console.WriteLine("Select a level to load in UDK:");
            for (int i = 0; i < levels.Count; i++)
                Console.WriteLine($"  {i + 1,2}. {levels[i]}");
            Console.Write("Number (blank to quit): ");

            var input = Console.ReadLine()?.Trim();
            if (string.IsNullOrEmpty(input))
                return null;
            if (int.TryParse(input, out var choice) && choice >= 1 && choice <= levels.Count)
                return levels[choice - 1];

            Console.WriteLine($"'{input}' is not a number between 1 and {levels.Count}.{Environment.NewLine}");
        }
    }

    private static void LoadLevel(string levelsRoot, string udkRoot, string level)
    {
        // Files in Maps are locked while UDK is running, and it would be holding the old maps open anyway.
        foreach (var running in Process.GetProcessesByName("UDK"))
        {
            Console.WriteLine($"Closing running UDK (pid {running.Id})...");
            running.Kill();
            running.WaitForExit(10_000);
        }

        // Wipe the whole Maps folder, not just this level's subfolder - a leftover level sitting alongside
        // it is what trips UDK's "ambiguous packages" error.
        var mapsPath = Path.Combine(udkRoot, "UDKGame", "Content", "Maps");
        Directory.CreateDirectory(mapsPath);
        foreach (var file in Directory.GetFiles(mapsPath))
            File.Delete(file);
        foreach (var dir in Directory.GetDirectories(mapsPath))
            Directory.Delete(dir, recursive: true);

        var destination = Directory.CreateDirectory(Path.Combine(mapsPath, level)).FullName;
        var maps = Directory.GetFiles(Path.Combine(levelsRoot, level), "*.udk");
        foreach (var map in maps)
        {
            Console.WriteLine($"Copying {Path.GetFileName(map)}");
            File.Copy(map, Path.Combine(destination, Path.GetFileName(map)), overwrite: true);
        }

        Console.WriteLine($"Starting UDK on {level}");
        Process.Start(new ProcessStartInfo
        {
            FileName = Path.Combine(udkRoot, "Binaries", "Win64", "UDK.exe"),
            Arguments = $"editor {level}.udk -log",
            WorkingDirectory = Path.Combine(udkRoot, "Binaries", "Win64"),
        });
    }
}
