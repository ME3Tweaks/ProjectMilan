using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;

namespace ShaderResearchTool;

/// <summary>
/// Given one captured shader job, compiles it and then searches every shipping material sharing the
/// same leaf object name for a bytecode match.
///
/// This exists for the effect materials. BioWare's T3D export is a flat
/// "&lt;package&gt;/&lt;materialname&gt;.t3d" tree, but EffectsMaterials nests its materials under
/// RvrEffectsMaterialUser parents, and the same effect name occurs under dozens of them. Only one
/// file per name survived the export, so the rebuild necessarily binds one arbitrary parent's graph
/// to every parent. If our bytecode matches exactly one shipping parent, the exported data is
/// faithful and merely misattributed -- a very different problem from the data being wrong, and it
/// says which parent the surviving file actually came from.
/// </summary>
public static class MatchParentCommand
{
    public static int Run(ToolPaths paths, string? jsonPath, bool preferEngine, string? prefix = null)
    {
        if (string.IsNullOrWhiteSpace(jsonPath) || !File.Exists(jsonPath))
        {
            Console.Error.WriteLine("pass the path to a debug package json with --job <path>");
            return 1;
        }

        var vfDir = Path.GetDirectoryName(jsonPath)!;
        var materialDir = Path.GetDirectoryName(vfDir)!;
        var packageDir = Path.GetDirectoryName(materialDir)!;
        var vertexFactory = Path.GetFileName(vfDir);
        var material = Path.GetFileName(materialDir);
        var packageFile = Path.GetFileName(packageDir);
        var shaderType = Path.GetFileNameWithoutExtension(jsonPath);
        var leaf = material[(material.LastIndexOf('.') + 1)..];

        var pkg = JobCompiler.Load(jsonPath);
        if (pkg == null)
        {
            Console.Error.WriteLine("could not read debug package");
            return 1;
        }

        var compiler = new JobCompiler(paths, preferEngine);
        var result = compiler.Compile(pkg, shaderType);
        if (!result.Success)
        {
            Console.Error.WriteLine($"compile failed: {result.ErrorMessage}");
            return 1;
        }

        Console.WriteLine($"{packageFile} / {material} / {vertexFactory} / {shaderType}");
        Console.WriteLine($"  our bytecode: {result.ByteCode.Length} bytes");
        Console.WriteLine($"  searching every shipping material named '{leaf}'");

        ObjectInstanceDB db;
        using (var fs = File.OpenRead(paths.ObjectDbPath))
        {
            db = ObjectInstanceDB.Deserialize(MEGame.LE3, fs);
        }

        var candidates = new List<string>();
        foreach (var ifp in db.GetAllObjectPaths(false))
        {
            int dot = ifp.LastIndexOf('.');
            if (dot < 0) continue;
            if (!string.Equals(ifp[(dot + 1)..], leaf, StringComparison.OrdinalIgnoreCase)) continue;
            // Scope to one package when asked: the T3D export is per package, so the loss that
            // matters is between parents inside a package, not across the whole game.
            if (prefix != null && !ifp.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) continue;
            candidates.Add(ifp);
        }
        candidates.Sort(StringComparer.OrdinalIgnoreCase);
        Console.WriteLine($"  {candidates.Count} shipping materials share this name");

        var provider = ReferenceShaderProvider.Load(paths.ObjectDbPath, paths.GameRoot);
        int checkedCount = 0, withShader = 0;
        var exact = new List<string>();
        var groups = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        var sizes = new List<(string Ifp, int Length)>();

        foreach (var candidate in candidates)
        {
            var set = provider.GetShaders(candidate);
            checkedCount++;
            if (!set.Shaders.TryGetValue((vertexFactory, shaderType), out var refShader)) continue;
            withShader++;

            sizes.Add((candidate, refShader.ByteCode.Length));
            var digest = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(refShader.ByteCode))[..16];
            if (!groups.TryGetValue(digest, out var members)) groups[digest] = members = [];
            members.Add(candidate);
            if (refShader.ByteCode.AsSpan().SequenceEqual(result.ByteCode)) exact.Add(candidate);

            if (checkedCount % 20 == 0) provider.ReleaseCache();
        }

        Console.WriteLine($"  {withShader} of them ship this vertex factory / shader type");

        // How much the flat export actually lost: if these materials collapse into a handful of
        // distinct bytecodes, most parents share a graph and only a few variants are missing.
        var ourDigest = Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(result.ByteCode))[..16];
        Console.WriteLine($"  they produce {groups.Count} distinct bytecodes:");
        foreach (var g in groups.OrderByDescending(g => g.Value.Count))
        {
            var mark = g.Key == ourDigest ? "  <== ours" : "";
            Console.WriteLine($"    {g.Value.Count,4} materials  {g.Key}{mark}");
            Console.WriteLine($"          e.g. {g.Value[0]}");
        }
        Console.WriteLine();

        if (exact.Count > 0)
        {
            Console.WriteLine($"=== BYTE-EXACT against {exact.Count} shipping material(s):");
            foreach (var e in exact) Console.WriteLine($"    {e}");
            Console.WriteLine();
            Console.WriteLine("  The exported T3D is faithful data bound to the wrong parent.");
        }
        else
        {
            Console.WriteLine("=== no shipping material of this name matches our bytecode exactly.");
            var ourLen = result.ByteCode.Length;
            var near = sizes.OrderBy(s => Math.Abs(s.Length - ourLen)).Take(8).ToList();
            Console.WriteLine($"  closest by size (ours {ourLen}):");
            foreach (var (ifp, len) in near) Console.WriteLine($"    {len,6}  ({len - ourLen:+#;-#;0})  {ifp}");
            Console.WriteLine();
            Console.WriteLine($"  distinct shipping sizes for this shader: {sizes.Select(s => s.Length).Distinct().Count()}");
        }
        return 0;
    }
}
