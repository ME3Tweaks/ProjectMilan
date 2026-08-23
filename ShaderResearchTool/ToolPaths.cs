using LegendaryExplorerCore.GameFilesystem;

namespace ShaderResearchTool;

/// <summary>
/// Input and output locations. Defaults match the current research layout; every one can be
/// overridden on the command line so the tool is not tied to one machine.
/// </summary>
public sealed class ToolPaths
{
    /// <summary>LE3 game root (the folder containing BioGame and Binaries).</summary>
    public string GameRoot { get; set; } = "";

    /// <summary>Decooked LE3 packages rebuilt from the developer T3D files.</summary>
    public string DecookedDir { get; set; } = @"E:\Decooked\LE3";

    /// <summary>Serialized ObjectInstanceDB for LE3, used to locate shipping objects by IFP.</summary>
    public string ObjectDbPath { get; set; } =
        @"B:\UserProfile\source\repos\ME3Tweaks\ProjectMilan\LEDecooker\supportfiles\LE3.bin";

    /// <summary>ShaderClient debug packages: Package/Material/VertexFactory/ShaderType.json.</summary>
    public string DebugPackagesDir { get; set; } = @"E:\Decooked\DebugPackages\LE3";

    /// <summary>Where reports and cached indexes are written.</summary>
    public string OutputDir { get; set; } = @"E:\Decooked\ShaderResearch";

    public static ToolPaths CreateDefault()
    {
        var paths = new ToolPaths();
        try
        {
            paths.GameRoot = LE3Directory.DefaultGamePath ?? "";
        }
        catch
        {
            // Registry lookup unavailable; caller must pass --game.
        }
        return paths;
    }

    /// <summary>Applies --key value overrides. Returns false if an unknown key is present.</summary>
    public bool ApplyOverrides(IReadOnlyList<string> args, out string? error)
    {
        error = null;
        for (int i = 0; i < args.Count; i++)
        {
            var arg = args[i];
            if (!arg.StartsWith("--", StringComparison.Ordinal)) continue;
            // Valueless flags, consumed by individual commands.
            if (arg is "--rebuild" or "--prefer-engine") continue;

            if (i + 1 >= args.Count)
            {
                error = $"missing value for {arg}";
                return false;
            }

            var value = args[++i];
            switch (arg)
            {
                case "--game": GameRoot = value; break;
                case "--decooked": DecookedDir = value; break;
                case "--object-db": ObjectDbPath = value; break;
                case "--debug-packages": DebugPackagesDir = value; break;
                case "--out": OutputDir = value; break;
                case "--limit": case "--shader-type": case "--job": case "--add-macro": case "--materials":
                case "--name": case "--prefix": case "--vf": case "--grid":
                case "--le3": case "--me3": case "--t3d": break;
                case "--prefer-engine": i--; break; // flag, no value // consumed by individual commands
                default:
                    error = $"unknown option {arg}";
                    return false;
            }
        }
        return true;
    }

    public void Print()
    {
        Console.WriteLine($"  game           {GameRoot}");
        Console.WriteLine($"  decooked       {DecookedDir}");
        Console.WriteLine($"  objectDb       {ObjectDbPath}");
        Console.WriteLine($"  debugPackages  {DebugPackagesDir}");
        Console.WriteLine($"  out            {OutputDir}");
    }
}
