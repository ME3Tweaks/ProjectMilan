using System.Diagnostics;

namespace UDKLevelSelect;

/// <summary>
/// Lets the user pick one of the baked levels under ProjectMilan/Pipelines/StaticLighting/Levels - and, when a
/// level has been baked with both Lightmass versions, which bake (UE3 or UE4) - copies its maps into the
/// Milan UDK install (wiping any other maps first), and boots UDK on it.
///
/// Usage: UDKLevelSelect [UDK path] [--lightmass UE3|UE4]
/// </summary>
internal static class Program
{
    private const string UdkPathEnvVar = "MILAN_UDK_PATH";

    // Where the Milan pipelines keep the UDK install on the dev machines, tried when nothing else is given.
    private static readonly string[] KnownUdkPaths = [@"S:\Milan\UDK", @"E:\Milan\UDK"];

    // The Lightmass versions Milan keeps bakes for (ProjectMilan's StaticLightingCache), one subfolder of Levels each.
    private static readonly string[] LightmassVersions = ["UE3", "UE4"];

    /// <summary>A baked level: its name, and the folder of its maps for each Lightmass that has baked it.</summary>
    private sealed record Level(string Name, SortedDictionary<string, string> Bakes);

    private static int Main(string[] args)
    {
        try
        {
            string? udkPathArg = null, lightmassArg = null;
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i].Equals("--lightmass", StringComparison.OrdinalIgnoreCase))
                {
                    if (i + 1 >= args.Length)
                        return Fail("--lightmass needs a value (UE3 or UE4)");
                    lightmassArg = args[++i];
                }
                else if (args[i].StartsWith("--"))
                    return Fail($"Unknown option {args[i]}");
                else
                    udkPathArg ??= args[i];
            }

            var levelsRoot = FindLevelsRoot();
            if (levelsRoot == null)
                return Fail("Could not find ProjectMilan\\Pipelines\\StaticLighting\\Levels above the executable.");

            var udkRoot = ResolveUdkRoot(udkPathArg);
            if (udkRoot == null)
                return Fail($"Could not find the Milan UDK. Pass its path as the first argument or set {UdkPathEnvVar}.");

            var levels = FindLevels(levelsRoot);
            if (lightmassArg != null)
                levels = levels.Where(l => l.Bakes.ContainsKey(lightmassArg)).ToList();
            if (levels.Count == 0)
                return Fail($"No levels with a master .udk found in {levelsRoot}" + (lightmassArg != null ? $" baked with {lightmassArg} Lightmass" : ""));

            var level = PromptForLevel(levels);
            if (level == null)
                return 0;

            var lightmass = lightmassArg ?? PromptForLightmass(level);
            if (lightmass == null)
                return 0;

            LoadLevel(level.Bakes[lightmass], udkRoot, level.Name, lightmass);
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

    /// <summary>
    /// Levels\&lt;UE3|UE4&gt;\&lt;level&gt;\&lt;level&gt;.udk. A level folder directly under Levels is the layout from before
    /// UE3 bakes were kept too, which Milan moves into UE4 on its next run; it is listed as UE4 until then.
    /// </summary>
    private static List<Level> FindLevels(string levelsRoot)
    {
        var levels = new Dictionary<string, Level>(StringComparer.OrdinalIgnoreCase);
        void AddFrom(string folder, string lightmass)
        {
            if (!Directory.Exists(folder))
                return;
            foreach (var dir in Directory.GetDirectories(folder))
            {
                var name = new DirectoryInfo(dir).Name;
                if (!File.Exists(Path.Combine(dir, name + ".udk")))
                    continue;
                if (!levels.TryGetValue(name, out var level))
                    levels[name] = level = new Level(name, new SortedDictionary<string, string>(StringComparer.OrdinalIgnoreCase));
                level.Bakes.TryAdd(lightmass, dir);
            }
        }

        foreach (var lightmass in LightmassVersions)
            AddFrom(Path.Combine(levelsRoot, lightmass), lightmass);
        AddFrom(levelsRoot, "UE4");
        return levels.Values.OrderBy(l => l.Name, StringComparer.OrdinalIgnoreCase).ToList();
    }

    private static string? ResolveUdkRoot(string? explicitPath)
    {
        var candidates = new List<string?> { explicitPath, Environment.GetEnvironmentVariable(UdkPathEnvVar) };
        candidates.AddRange(KnownUdkPaths);
        return candidates.FirstOrDefault(c => !string.IsNullOrWhiteSpace(c) && IsUdkRoot(c!));
    }

    private static bool IsUdkRoot(string path) => File.Exists(Path.Combine(path, "Binaries", "Win64", "UDK.exe"));

    private static Level? PromptForLevel(List<Level> levels)
    {
        var width = levels.Max(l => l.Name.Length);
        var index = Prompt("Select a level to load in UDK:",
            levels.Select(l => $"{l.Name.PadRight(width)}  [{string.Join(", ", l.Bakes.Keys)}]").ToList());
        return index == null ? null : levels[index.Value];
    }

    /// <summary>Asks which bake to load when the level has more than one.</summary>
    private static string? PromptForLightmass(Level level)
    {
        var bakes = level.Bakes.Keys.ToList();
        if (bakes.Count == 1)
            return bakes[0];

        Console.WriteLine();
        var index = Prompt($"{level.Name} has more than one lighting bake. Select one:",
            bakes.Select(b => $"{b} Lightmass  (baked {Directory.GetLastWriteTime(Path.Combine(level.Bakes[b], level.Name + ".udk")):yyyy-MM-dd HH:mm})").ToList());
        return index == null ? null : bakes[index.Value];
    }

    /// <summary>Numbered menu; returns the chosen index, or null when the user enters nothing.</summary>
    private static int? Prompt(string title, List<string> options)
    {
        while (true)
        {
            Console.WriteLine(title);
            for (int i = 0; i < options.Count; i++)
                Console.WriteLine($"  {i + 1,2}. {options[i]}");
            Console.Write("Number (blank to quit): ");

            var input = Console.ReadLine()?.Trim();
            if (string.IsNullOrEmpty(input))
                return null;
            if (int.TryParse(input, out var choice) && choice >= 1 && choice <= options.Count)
                return choice - 1;

            Console.WriteLine($"'{input}' is not a number between 1 and {options.Count}.{Environment.NewLine}");
        }
    }

    private static void LoadLevel(string levelFolder, string udkRoot, string level, string lightmass)
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
        var maps = Directory.GetFiles(levelFolder, "*.udk");
        foreach (var map in maps)
        {
            Console.WriteLine($"Copying {Path.GetFileName(map)}");
            File.Copy(map, Path.Combine(destination, Path.GetFileName(map)), overwrite: true);
        }

        Console.WriteLine($"Starting UDK on {level} ({lightmass} Lightmass bake)");
        Process.Start(new ProcessStartInfo
        {
            FileName = Path.Combine(udkRoot, "Binaries", "Win64", "UDK.exe"),
            Arguments = $"editor {level}.udk -log",
            WorkingDirectory = Path.Combine(udkRoot, "Binaries", "Win64"),
        });
    }
}
