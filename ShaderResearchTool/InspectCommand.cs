using LegendaryExplorerCore.Shaders;
using MilanShaderHost;
using Newtonsoft.Json;

namespace ShaderResearchTool;

/// <summary>
/// Produces everything needed to diagnose one mismatching shader: both bytecodes, both
/// decompilations, the DXBC chunk layout of each, and the first byte where they diverge.
///
/// The chunk layout matters because a difference confined to one container chunk (or to the
/// leading hash) is not a shader-logic problem at all, and chasing it through macros would be
/// wasted effort.
/// </summary>
public static class InspectCommand
{
    public static int Run(ToolPaths paths, string? jsonPath, bool preferEngine, IEnumerable<string>? extraMacros)
    {
        if (string.IsNullOrWhiteSpace(jsonPath) || !File.Exists(jsonPath))
        {
            Console.Error.WriteLine("pass the path to a debug package json with --job <path>");
            return 1;
        }

        // .../<PackageFile>/<MaterialIFP>/<VertexFactory>/<ShaderType>.json
        var vfDir = Path.GetDirectoryName(jsonPath)!;
        var materialDir = Path.GetDirectoryName(vfDir)!;
        var packageDir = Path.GetDirectoryName(materialDir)!;
        var vertexFactory = Path.GetFileName(vfDir);
        var material = Path.GetFileName(materialDir);
        var packageFile = Path.GetFileName(packageDir);
        var shaderType = Path.GetFileNameWithoutExtension(jsonPath);

        var pkg = JobCompiler.Load(jsonPath);
        if (pkg == null)
        {
            Console.Error.WriteLine("could not read debug package");
            return 1;
        }

        var provider = ReferenceShaderProvider.Load(paths.ObjectDbPath, paths.GameRoot);
        var reference = provider.GetShaders([$"{packageFile}.{material}", material]);
        if (!reference.Shaders.TryGetValue((vertexFactory, shaderType), out var refShader))
        {
            Console.Error.WriteLine($"no shipping reference for {vertexFactory}/{shaderType} ({reference.Error})");
            return 1;
        }

        var compiler = new JobCompiler(paths, preferEngine, extraMacros);
        var macros = compiler.MacrosFor(pkg);
        var result = compiler.Compile(pkg, shaderType);

        if (!result.Success)
        {
            Console.Error.WriteLine($"compile failed: {result.ErrorMessage}");
            return 1;
        }

        var outDir = Path.Combine(paths.OutputDir, "inspect", $"{material}.{vertexFactory}.{shaderType}");
        Directory.CreateDirectory(outDir);

        File.WriteAllBytes(Path.Combine(outDir, "ours.dxbc"), result.ByteCode);
        File.WriteAllBytes(Path.Combine(outDir, "reference.dxbc"), refShader.ByteCode);

        var ourHlsl = HLSLDecompiler.DecompileShader(result.ByteCode, false);
        var refHlsl = HLSLDecompiler.DecompileShader(refShader.ByteCode, false);
        File.WriteAllText(Path.Combine(outDir, "ours.hlsl"), ourHlsl);
        File.WriteAllText(Path.Combine(outDir, "reference.hlsl"), refHlsl);

        Console.WriteLine($"{material} / {vertexFactory} / {shaderType}");
        Console.WriteLine($"  entry {pkg.functionName}  profile {pkg.profile}  flags 0x{compiler.FlagsFor(pkg, shaderType):X}"
            + (compiler.PreferEngine ? "  (engine-preferred macros)" : ""));
        Console.WriteLine($"  ours {result.ByteCode.Length} bytes, reference {refShader.ByteCode.Length} bytes");

        Console.WriteLine("\n  ours chunks:");
        PrintChunks(result.ByteCode);
        Console.WriteLine("  reference chunks:");
        PrintChunks(refShader.ByteCode);

        int firstDiff = FirstDifference(result.ByteCode, refShader.ByteCode);
        Console.WriteLine($"\n  first differing byte: {(firstDiff < 0 ? "none" : firstDiff.ToString())}");

        var (onlyOurs, onlyRef) = DiffSignature.Delta(ourHlsl, refHlsl);
        Console.WriteLine($"  normalized HLSL delta: {onlyOurs.Count} lines only in ours, {onlyRef.Count} only in reference");
        foreach (var l in onlyOurs.Take(15)) Console.WriteLine($"    - {l}");
        foreach (var l in onlyRef.Take(15)) Console.WriteLine($"    + {l}");

        Console.WriteLine($"\n  macros ({macros.Count}):");
        foreach (var m in pkg.macros ?? []) Console.WriteLine($"    [{m.source ?? "?"}] {m.name} = {m.definition}");

        if (pkg.macroConflicts is { Length: > 0 })
        {
            Console.WriteLine("  macro conflicts (ours won):");
            foreach (var c in pkg.macroConflicts) Console.WriteLine($"    {c.name}: milan={c.milanValue} engine={c.engineValue}");
        }

        Console.WriteLine($"\n  written to {outDir}");
        return 0;
    }

    /// <summary>
    /// Walks the DXBC container: "DXBC", 16-byte digest, version, total size, chunk count, then
    /// chunk offsets. Each chunk has a 4CC and size.
    /// </summary>
    private static void PrintChunks(byte[] code)
    {
        if (code.Length < 32 || code[0] != 'D' || code[1] != 'X' || code[2] != 'B' || code[3] != 'C')
        {
            Console.WriteLine("    (not a DXBC container)");
            return;
        }

        var digest = Convert.ToHexString(code.AsSpan(4, 16));
        int totalSize = BitConverter.ToInt32(code, 24);
        int chunkCount = BitConverter.ToInt32(code, 28);
        Console.WriteLine($"    digest {digest}  totalSize {totalSize}  chunks {chunkCount}");

        for (int i = 0; i < chunkCount; i++)
        {
            int offsetPos = 32 + i * 4;
            if (offsetPos + 4 > code.Length) break;
            int offset = BitConverter.ToInt32(code, offsetPos);
            if (offset + 8 > code.Length) break;

            var fourCc = System.Text.Encoding.ASCII.GetString(code, offset, 4);
            int size = BitConverter.ToInt32(code, offset + 4);
            Console.WriteLine($"      {fourCc}  {size} bytes @ {offset}");
        }
    }

    private static int FirstDifference(byte[] a, byte[] b)
    {
        int len = Math.Min(a.Length, b.Length);
        for (int i = 0; i < len; i++)
        {
            if (a[i] != b[i]) return i;
        }
        return a.Length == b.Length ? -1 : len;
    }
}
