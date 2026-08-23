using MilanShaderHost;
using Newtonsoft.Json;

namespace ShaderResearchTool;

/// <summary>
/// How a captured job is turned into a compile. Shared by scoreboard, cluster and inspect so they
/// cannot disagree about what "our" bytecode for a shader is — a cluster built from different
/// inputs than the scoreboard measured would describe differences that do not exist.
/// </summary>
public sealed class JobCompiler
{
    private readonly string _includesDir;
    private readonly Dictionary<string, uint> _recoveredFlags;
    private readonly bool _preferEngine;
    private readonly List<(string Name, string Definition)> _extraMacros;

    public JobCompiler(ToolPaths paths, bool preferEngine, IEnumerable<string>? extraMacros = null)
    {
        _includesDir = Path.Combine(paths.GameRoot, "Engine", "Shaders");
        _recoveredFlags = LoadRecoveredFlags(paths);
        _preferEngine = preferEngine;
        _extraMacros = (extraMacros ?? []).Select(ParseMacro).ToList();
    }

    /// <summary>Parses NAME or NAME=VALUE; a bare name defaults to 1.</summary>
    private static (string Name, string Definition) ParseMacro(string spec)
    {
        int eq = spec.IndexOf('=');
        return eq < 0 ? (spec, "1") : (spec[..eq], spec[(eq + 1)..]);
    }

    public int RecoveredFlagCount => _recoveredFlags.Count;
    public bool PreferEngine => _preferEngine;
    public string IncludesDirectory => _includesDir;

    /// <summary>
    /// Flags read out of shipping bytecode, keyed by shader type. Preferred over the value the debug
    /// package recorded, because it comes from the shader being compared against rather than from
    /// the rule under test.
    /// </summary>
    private static Dictionary<string, uint> LoadRecoveredFlags(ToolPaths paths)
    {
        var path = Path.Combine(paths.OutputDir, "compile-flags-by-shadertype.txt");
        var map = new Dictionary<string, uint>(StringComparer.Ordinal);
        if (!File.Exists(path)) return map;

        foreach (var line in File.ReadLines(path))
        {
            var parts = line.Split('\t');
            if (parts.Length < 2) continue;
            if (uint.TryParse(parts[1].AsSpan(2), System.Globalization.NumberStyles.HexNumber, null, out var flags))
            {
                map[parts[0]] = flags;
            }
        }
        return map;
    }

    public static ShaderClientDebugPackage? Load(string jsonPath)
    {
        try
        {
            return JsonConvert.DeserializeObject<ShaderClientDebugPackage>(File.ReadAllText(jsonPath));
        }
        catch
        {
            return null;
        }
    }

    /// <summary>The macro list to compile with, after applying conflict resolution.</summary>
    public List<(string Name, string Definition)> MacrosFor(ShaderClientDebugPackage pkg)
    {
        var macros = (pkg.macros ?? []).Select(m => (Name: m.name, Definition: m.definition)).ToList();

        // Lets a rule change be measured without a fresh capture: the recorded conflicts carry both
        // values, so the engine's side can be substituted after the fact.
        if (_preferEngine && pkg.macroConflicts is { Length: > 0 })
        {
            for (int i = 0; i < macros.Count; i++)
            {
                var conflict = pkg.macroConflicts.FirstOrDefault(c => c.name == macros[i].Name);
                if (conflict != null) macros[i] = (macros[i].Name, conflict.engineValue);
            }
        }

        // Lets a candidate macro be tested against the corpus before it is written into the ASI.
        foreach (var (name, definition) in _extraMacros)
        {
            int existing = macros.FindIndex(m => m.Name == name);
            if (existing >= 0) macros[existing] = (name, definition);
            else macros.Add((name, definition));
        }

        return macros;
    }

    public uint FlagsFor(ShaderClientDebugPackage pkg, string shaderType) =>
        _recoveredFlags.TryGetValue(shaderType, out var known) ? known : pkg.compileFlags;

    public CompileResult Compile(ShaderClientDebugPackage pkg, string shaderType)
    {
        return ShaderCompilerInterop.Compile(
            pkg.sourceFilename,
            pkg.materialHlsl,
            pkg.vertexFactoryShaderFilename,
            _includesDir,
            MacrosFor(pkg),
            pkg.functionName,
            pkg.profile,
            (int)FlagsFor(pkg, shaderType));
    }
}
