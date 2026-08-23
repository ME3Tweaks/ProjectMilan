using LegendaryExplorerCore;
using LegendaryExplorerCore.Compression;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;

namespace ShaderResearchTool;

internal static class Program
{
    private static int Main(string[] args)
    {
        if (args.Length == 0 || args[0] is "-h" or "--help" or "help")
        {
            PrintUsage();
            return 0;
        }

        LegendaryExplorerCoreLib.InitLib(TaskScheduler.Default, s => Console.Error.WriteLine($"LEC: {s}"));

        // The shared cache keeps every opened package alive. That is right for an editor tool and
        // ruinous for a batch scan of thousands of packages, so opened packages are scoped and freed.
        MEPackageHandler.GlobalSharedCacheEnabled = false;

        var command = args[0];
        var rest = args.Skip(1).ToList();

        var paths = ToolPaths.CreateDefault();
        if (!paths.ApplyOverrides(rest, out var error))
        {
            Console.Error.WriteLine(error);
            PrintUsage();
            return 1;
        }

        if (string.IsNullOrEmpty(paths.GameRoot))
        {
            Console.Error.WriteLine("LE3 game path not found. Pass --game <LE3 root> (the folder containing BioGame).");
            return 1;
        }

        // Make every LEC game-relative lookup use this install.
        LE3Directory.DefaultGamePath = paths.GameRoot;

        // LE packages are Oodle compressed; without this every OpenMEPackage fails.
        if (!OodleHelper.EnsureOodleDll(paths.GameRoot))
        {
            Console.Error.WriteLine($"could not load oodle dll from {paths.GameRoot}");
            return 1;
        }

        bool rebuild = rest.Contains("--rebuild");

        Console.WriteLine($"ShaderResearchTool :: {command}");
        paths.Print();
        Console.WriteLine();

        switch (command)
        {
            case "texture-parity":
                return TextureParityCommand.Run(paths, rebuild);

            case "coverage":
                return CoverageCommand.Run(paths);

            case "plan-capture":
                return PlanCaptureCommand.Run(paths, rebuild);

            case "texture-audit":
                return TextureAuditCommand.Run(paths, GetOption(rest, "--materials"));

            case "collisions":
                return CollisionsCommand.Run(paths, GetOption(rest, "--le3"), GetOption(rest, "--me3"),
                    GetOption(rest, "--t3d"));

            case "effect-algebra":
                return EffectAlgebraCommand.Run(paths, GetOption(rest, "--shader-type"),
                    GetOption(rest, "--vf"), GetIntOption(rest, "--grid"));

            case "match-parent":
                return MatchParentCommand.Run(paths, GetOption(rest, "--job"), rest.Contains("--prefer-engine"),
                    GetOption(rest, "--prefix"));

            case "objects":
                return ObjectsCommand.Run(paths, GetOption(rest, "--name"), GetOption(rest, "--prefix"));

            case "flags":
                return FlagsCommand.Run(paths);

            case "inspect":
                return InspectCommand.Run(paths, GetOption(rest, "--job"), rest.Contains("--prefer-engine"), GetAllOptions(rest, "--add-macro"));

            case "cluster":
                return ClusterCommand.Run(paths, GetIntOption(rest, "--limit"), rest.Contains("--prefer-engine"),
                    GetAllOptions(rest, "--add-macro"));

            case "scoreboard":
                return ScoreboardCommand.Run(paths, GetIntOption(rest, "--limit"), GetOption(rest, "--shader-type"),
                    rest.Contains("--prefer-engine"), GetAllOptions(rest, "--add-macro"));

            default:
                Console.Error.WriteLine($"unknown command: {command}");
                PrintUsage();
                return 1;
        }
    }

    private static string? GetOption(IReadOnlyList<string> args, string name)
    {
        for (int i = 0; i < args.Count - 1; i++)
        {
            if (args[i] == name) return args[i + 1];
        }
        return null;
    }

    private static List<string> GetAllOptions(IReadOnlyList<string> args, string name)
    {
        var values = new List<string>();
        for (int i = 0; i < args.Count - 1; i++)
        {
            if (args[i] == name) values.Add(args[i + 1]);
        }
        return values;
    }

    private static int GetIntOption(IReadOnlyList<string> args, string name) =>
        int.TryParse(GetOption(args, name), out var value) ? value : 0;

    private static void PrintUsage()
    {
        Console.WriteLine("""
            ShaderResearchTool — offline LE3 shader calibration harness

            Commands:
              texture-parity    Compare texture bindings of decooked materials against shipping LE3.
                                Produces the trusted calibration set, the quarantine list (format
                                divergence — bytecode comparison invalid) and the visual-bug list
                                (identity-only divergence — bytecode unaffected).

              coverage          Join the captured debug-package corpus against shipping LE3 shader
                                maps. Reports how much of the corpus has a reference to compare
                                against, and which shipping permutations were never captured.

              plan-capture      Solve which LE3 materials to capture so a calibration run covers
                                every shipping shader permutation with the fewest materials.
                                Writes capture-packages.txt for ShaderHost.

              scoreboard        Recompile every captured job offline and compare to the bytecode LE3
                                ships. Reports the corpus-wide exact-match rate and the shader types
                                with the most mismatches.
                                  --limit N          score only the first N jobs
                                  --shader-type STR  only shader types containing STR
                                  --prefer-engine    resolve recorded macro conflicts the engine's way

              cluster           Group scoreboard mismatches by how they differ, so one diagnosis can
                                fix many shaders. Writes a ranked worklist to clusters.txt.
                                  --limit N          cluster only the first N mismatches
                                  --prefer-engine    must match the scoreboard run being clustered

              texture-audit     For materials whose shaders diverge in a texture-shaped way, recover the
                                textures the decooked material actually bound (from its expression graph,
                                since an uncompiled rebuild has no UniformExpressionTextures) and compare
                                them to the shipping material's, flagging format differences and names
                                that are ambiguous across the game.
                                  --materials <file>  one instanced full path per line
                                                      (default: texture-divergence-materials.tsv)

              flags             Recover the D3DCOMPILE flags BioWare used, per shader type, by reading
                                the RDEF chunk of the shipping bytecode. Ground truth, not a search.

              inspect           Dump both bytecodes, both decompilations, DXBC chunk layouts and the
                                macro set for one shader, for diagnosis.
                                  --job <path to debug package json>
                                  --add-macro NAME[=VALUE]  test a candidate macro (repeatable)

            Options:
              --game <dir>            LE3 game root                (default: from registry)
              --decooked <dir>        Decooked LE3 packages        (default E:\Decooked\LE3)
              --object-db <file>      LE3 ObjectInstanceDB .bin    (default: LEDecooker supportfiles)
              --debug-packages <dir>  ShaderClient debug packages  (default E:\Decooked\DebugPackages\LE3)
              --out <dir>             Report output directory      (default E:\Decooked\ShaderResearch)
              --rebuild               Ignore cached package indexes and rescan

            Note: must be built as WinDebug or WinRelease, otherwise LegendaryExplorerCore
            omits its registry-based game lookup.
            """);
    }
}
