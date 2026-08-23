using System.Text;
using System.Text.Json;

namespace ShaderResearchTool;

/// <summary>
/// Recovers the D3DCOMPILE flags BioWare actually used, per shader type, by reading them out of the
/// shipping bytecode.
///
/// The DXBC RDEF chunk records the flags the shader was compiled with, so the correct answer is
/// sitting in every shipping shader — no search required. That replaces ShaderClient's hand-derived
/// GetCompileFlags, which currently guesses PREFER_FLOW_CONTROL from a few shader-type name matches.
/// </summary>
public static class FlagsCommand
{
    /// <summary>The compiler sets NO_PRESHADER in RDEF regardless of what was passed in.</summary>
    private const uint ImplicitFlags = 0x100;

    public static int Run(ToolPaths paths)
    {
        var jobs = DebugPackageCorpus.Enumerate(paths.DebugPackagesDir);
        if (jobs.Count == 0)
        {
            Console.Error.WriteLine($"no debug packages under {paths.DebugPackagesDir}");
            return 1;
        }

        var provider = ReferenceShaderProvider.Load(paths.ObjectDbPath, paths.GameRoot);

        // shaderType -> observed flag value -> count
        var byShaderType = new Dictionary<string, Dictionary<uint, int>>(StringComparer.Ordinal);
        var byVertexFactory = new Dictionary<string, Dictionary<uint, int>>(StringComparer.Ordinal);
        int resolved = 0, done = 0;

        foreach (var group in jobs.GroupBy(j => (j.PackageFile, j.MaterialPath)))
        {
            var packageRoot = Path.GetFileNameWithoutExtension(group.Key.PackageFile);
            var reference = provider.GetShaders([$"{packageRoot}.{group.Key.MaterialPath}", group.Key.MaterialPath]);

            foreach (var job in group)
            {
                done++;
                if (done % 2000 == 0) Console.WriteLine($"  {done}/{jobs.Count}");

                var vfKey = string.IsNullOrEmpty(job.VertexFactory) ? ReferenceShaderSet.NoVertexFactory : job.VertexFactory;
                if (!reference.Shaders.TryGetValue((vfKey, job.ShaderType), out var refShader)) continue;
                if (!TryReadRdefFlags(refShader.ByteCode, out var flags)) continue;

                resolved++;
                var input = flags & ~ImplicitFlags;
                Tally(byShaderType, job.ShaderType, input);
                Tally(byVertexFactory, vfKey, input);
            }

            provider.ReleaseCache();
        }

        Console.WriteLine($"\nread flags from {resolved} shipping shaders");

        // A shader type is only a usable rule if every shipping instance agrees.
        var consistent = byShaderType.Where(kv => kv.Value.Count == 1).ToList();
        var inconsistent = byShaderType.Where(kv => kv.Value.Count > 1).ToList();

        var allValues = byShaderType.SelectMany(kv => kv.Value.Keys).Distinct().OrderBy(x => x).ToList();

        Console.WriteLine();
        Console.WriteLine("=== compile flags from shipping bytecode ===");
        Console.WriteLine($"  shader types seen        {byShaderType.Count,6}");
        Console.WriteLine($"    single flag value      {consistent.Count,6}");
        Console.WriteLine($"    varies by instance     {inconsistent.Count,6}");
        Console.WriteLine($"  distinct flag values     {allValues.Count,6}");
        foreach (var v in allValues)
        {
            int n = byShaderType.Sum(kv => kv.Value.TryGetValue(v, out var c) ? c : 0);
            Console.WriteLine($"    0x{v:X4}  {Describe(v),-60} {n,7} shaders");
        }

        if (inconsistent.Count > 0)
        {
            Console.WriteLine("\n  shader types whose flags are NOT constant (need another discriminator):");
            foreach (var (type, values) in inconsistent.OrderByDescending(kv => kv.Value.Values.Sum()).Take(15))
            {
                var parts = string.Join(", ", values.OrderByDescending(v => v.Value).Select(v => $"0x{v.Key:X4}x{v.Value}"));
                Console.WriteLine($"    {type}: {parts}");
            }
        }

        WriteReport(paths, byShaderType, byVertexFactory);
        return 0;
    }

    private static void Tally(Dictionary<string, Dictionary<uint, int>> map, string key, uint flags)
    {
        if (!map.TryGetValue(key, out var counts))
        {
            counts = [];
            map[key] = counts;
        }
        counts.TryGetValue(flags, out var c);
        counts[flags] = c + 1;
    }

    /// <summary>Reads the flags DWORD from the RDEF chunk of a DXBC container.</summary>
    public static bool TryReadRdefFlags(byte[] code, out uint flags)
    {
        flags = 0;
        if (code.Length < 32 || code[0] != 'D' || code[1] != 'X' || code[2] != 'B' || code[3] != 'C') return false;

        int chunkCount = BitConverter.ToInt32(code, 28);
        for (int i = 0; i < chunkCount; i++)
        {
            int offsetPos = 32 + i * 4;
            if (offsetPos + 4 > code.Length) break;
            int offset = BitConverter.ToInt32(code, offsetPos);
            if (offset + 8 > code.Length) break;

            if (code[offset] != 'R' || code[offset + 1] != 'D' || code[offset + 2] != 'E' || code[offset + 3] != 'F') continue;

            // RDEF data: [0]cbCount [4]cbOffset [8]resCount [12]resOffset [16]minor [17]major
            // [18]programType [20]flags [24]creatorOffset
            int data = offset + 8;
            if (data + 24 > code.Length) return false;
            flags = BitConverter.ToUInt32(code, data + 20);
            return true;
        }
        return false;
    }

    private static readonly (uint Bit, string Name)[] FlagNames =
    [
        (0x1, "DEBUG"), (0x2, "SKIP_VALIDATION"), (0x4, "SKIP_OPTIMIZATION"),
        (0x8, "PACK_MATRIX_ROW_MAJOR"), (0x10, "PACK_MATRIX_COLUMN_MAJOR"),
        (0x20, "PARTIAL_PRECISION"), (0x100, "NO_PRESHADER"),
        (0x200, "AVOID_FLOW_CONTROL"), (0x400, "PREFER_FLOW_CONTROL"),
        (0x800, "ENABLE_STRICTNESS"), (0x1000, "ENABLE_BACKWARDS_COMPATIBILITY"),
        (0x2000, "IEEE_STRICTNESS"), (0x4000, "OPT_LEVEL_BIT0"), (0x8000, "OPT_LEVEL_BIT1")
    ];

    private static string Describe(uint flags)
    {
        var parts = FlagNames.Where(f => (flags & f.Bit) != 0).Select(f => f.Name).ToList();
        return parts.Count == 0 ? "(none)" : string.Join("|", parts);
    }

    private static void WriteReport(
        ToolPaths paths,
        Dictionary<string, Dictionary<uint, int>> byShaderType,
        Dictionary<string, Dictionary<uint, int>> byVertexFactory)
    {
        Directory.CreateDirectory(paths.OutputDir);

        using (var fs = File.Create(Path.Combine(paths.OutputDir, "compile-flags.json")))
        {
            JsonSerializer.Serialize(fs, new
            {
                byShaderType = byShaderType.ToDictionary(
                    kv => kv.Key,
                    kv => kv.Value.ToDictionary(v => $"0x{v.Key:X4}", v => v.Value)),
                byVertexFactory = byVertexFactory.ToDictionary(
                    kv => kv.Key,
                    kv => kv.Value.ToDictionary(v => $"0x{v.Key:X4}", v => v.Value))
            }, new JsonSerializerOptions { WriteIndented = true });
        }

        // Ready-to-paste rule table for the shader types whose flags are unambiguous.
        var sb = new StringBuilder();
        foreach (var (type, values) in byShaderType.Where(kv => kv.Value.Count == 1).OrderBy(kv => kv.Key, StringComparer.Ordinal))
        {
            sb.AppendLine($"{type}\t0x{values.Keys.First():X4}\t{Describe(values.Keys.First())}");
        }
        File.WriteAllText(Path.Combine(paths.OutputDir, "compile-flags-by-shadertype.txt"), sb.ToString());

        Console.WriteLine($"\n  written to {paths.OutputDir}\\compile-flags.json and compile-flags-by-shadertype.txt");
    }
}
