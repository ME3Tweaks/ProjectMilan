using System.Diagnostics;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore.Shaders.OfflineCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

/// <summary>
/// Opt-in: plans the shader install over a real mod output folder, read-only, and writes the plan.
/// MILAN_SHADER_PLAN_OUTPUT = output folder; MILAN_SHADER_PLAN_GAME, MILAN_SHADER_PLAN_DECOOKED,
/// MILAN_SHADER_PLAN_REPORT override the defaults; MILAN_SHADER_PLAN_FILTER (file name regex) plans a subset.
/// </summary>
[TestClass]
public sealed class ShaderInstallPlanLocalTests
{
    [TestMethod, TestCategory("OfflineLocal")]
    public void PlanRealOutput()
    {
        string? output = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_OUTPUT");
        if (string.IsNullOrEmpty(output)) Assert.Inconclusive("Set MILAN_SHADER_PLAN_OUTPUT to run.");
        string game = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_GAME") is { Length: > 0 } g ? g
            : @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3";
        string decooked = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_DECOOKED") is { Length: > 0 } d ? d : @"E:\Decooked\LE3";
        string report = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_REPORT") is { Length: > 0 } r ? r
            : Path.Combine(Path.GetTempPath(), "milan_shader_plan.txt");

        LegendaryExplorerCore.GameFilesystem.LE3Directory.DefaultGamePath = game;
        // MilanShared finds its project root from the working directory.
        Directory.SetCurrentDirectory(Environment.GetEnvironmentVariable("MILAN_REPO") is { Length: > 0 } repo ? repo
            : @"B:\UserProfile\source\repos\ME3Tweaks\ProjectMilan\ProjectMilan");
        var db = MilanInitShared.LoadObjectDB(LegendaryExplorerCore.Packages.MEGame.LE3);
        var sw = Stopwatch.StartNew();
        string? filter = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_FILTER");
        using var context = new OfflineShaderInstallContext(output, game, decooked, db);
        Console.WriteLine($"Indexed in {sw.Elapsed.TotalSeconds:F0}s");
        var plan = context.Plan(include: string.IsNullOrEmpty(filter) ? null
            : f => System.Text.RegularExpressions.Regex.IsMatch(Path.GetFileName(f), filter, System.Text.RegularExpressions.RegexOptions.IgnoreCase));
        File.WriteAllText(report,
            $"{context.OutputPackages.Count} packages, {sw.Elapsed.TotalMinutes:F1} min\n" +
            $"materials {plan.Materials.Count} (compile {plan.Materials.Count(m => m.Compile)}, flags changed {plan.Materials.Count(m => m.FlagsToSet.Count > 0)})\n" +
            $"instances {plan.Instances.Count} (compile {plan.Instances.Count(i => i.Compile)}, normal fixes {plan.Instances.Count(i => i.StaticNormalFixes.Count > 0)}, retargeted {plan.Instances.Count(i => i.RetargetParentTo != null)})\n" +
            $"variants {plan.Variants.Count}, chain clones {plan.ChainClones.Count}, errors {plan.Errors.Count}, reports {plan.Reports.Count}\n\n" +
            plan.Describe());
        Console.WriteLine("Plan: " + report);
    }

    /// <summary>
    /// Opt-in diagnostic: MILAN_COPYDIFF = "identity|a.pcc|b.pcc[|...]" under MILAN_SHADER_PLAN_OUTPUT. Writes each copy's
    /// fingerprint, one property per line, to %TEMP%\copydiff_<package>.txt for diffing.
    /// </summary>
    [TestMethod, TestCategory("OfflineLocal")]
    public void CopyDiff()
    {
        string? spec = Environment.GetEnvironmentVariable("MILAN_COPYDIFF");
        string? output = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_OUTPUT");
        if (string.IsNullOrEmpty(spec) || string.IsNullOrEmpty(output)) Assert.Inconclusive("Set MILAN_COPYDIFF and MILAN_SHADER_PLAN_OUTPUT to run.");
        var parts = spec.Split('|');
        foreach (var name in parts.Skip(1))
        {
            string path = Directory.EnumerateFiles(output, name, SearchOption.AllDirectories).First();
            using var package = LegendaryExplorerCore.Packages.MEPackageHandler.OpenMEPackage(path, forceLoadFromDisk: true);
            var export = package.Exports.First(e => string.Equals(e.MemoryFullPath, parts[0], StringComparison.OrdinalIgnoreCase));
            string binary = export.IsA("Material")
                ? LegendaryExplorerCore.Unreal.BinaryConverters.ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.Material>(export).SM3MaterialResource.ID.ToString()
                : "instance";
            File.WriteAllText(Path.Combine(Path.GetTempPath(), $"copydiff_{Path.GetFileNameWithoutExtension(name)}.txt"),
                $"{export.InstancedFullPath} uindex {export.UIndex} forced={export.IsForcedExport}\n" +
                ShaderInstallPlanner.CopyFingerprint(export, binary).Replace(";", ";\n"));
        }
    }

    /// <summary>
    /// Opt-in diagnostic: MILAN_FIND = "path[|path...]" under MILAN_SHADER_PLAN_OUTPUT. Writes every export with that
    /// instanced path (class, file, memory path, expression count) to %TEMP%\milan_find.txt.
    /// </summary>
    [TestMethod, TestCategory("OfflineLocal")]
    public void FindExports()
    {
        string? spec = Environment.GetEnvironmentVariable("MILAN_FIND");
        string? output = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_OUTPUT");
        if (string.IsNullOrEmpty(spec) || string.IsNullOrEmpty(output)) Assert.Inconclusive("Set MILAN_FIND and MILAN_SHADER_PLAN_OUTPUT to run.");
        var paths = spec.Split('|').ToHashSet(StringComparer.OrdinalIgnoreCase);
        var lines = new System.Collections.Concurrent.ConcurrentBag<string>();
        Parallel.ForEach(Directory.GetFiles(output, "*.pcc", SearchOption.AllDirectories), new ParallelOptions { MaxDegreeOfParallelism = 8 }, file =>
        {
            using var package = LegendaryExplorerCore.Packages.MEPackageHandler.UnsafePartialLoad(file, e => paths.Contains(e.InstancedFullPath));
            foreach (var e in package.Exports.Where(e => paths.Contains(e.InstancedFullPath)))
                lines.Add($"{e.InstancedFullPath} | {e.ClassName} | {Path.GetFileName(file)} | uindex {e.UIndex} | memory {e.MemoryFullPath} | forced {e.IsForcedExport} | " +
                          $"expressions {(e.IsDataLoaded() ? e.GetProperties().GetProp<LegendaryExplorerCore.Unreal.ArrayProperty<LegendaryExplorerCore.Unreal.ObjectProperty>>("Expressions")?.Count ?? 0 : -1)}");
        });
        File.WriteAllLines(Path.Combine(Path.GetTempPath(), "milan_find.txt"), lines.Order(StringComparer.Ordinal));
    }

    /// <summary>
    /// Opt-in diagnostic: MILAN_COMPILE = "package path|export path[|flag...]" compiles that material as-is (with the listed
    /// bUsed* flags set) through the full translate/plan/compile/assemble path and asserts a complete shader set.
    /// </summary>
    [TestMethod, TestCategory("OfflineLocal")]
    public void CompileMaterial()
    {
        string? spec = Environment.GetEnvironmentVariable("MILAN_COMPILE");
        if (string.IsNullOrEmpty(spec)) Assert.Inconclusive("Set MILAN_COMPILE to run.");
        string game = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_GAME") is { Length: > 0 } g ? g
            : @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3";
        var parts = spec.Split('|');
        using var package = LegendaryExplorerCore.Packages.MEPackageHandler.OpenMEPackage(parts[0], forceLoadFromDisk: true);
        var material = package.FindExport(parts[1]) ?? throw new AssertFailedException($"{parts[1]} not found");
        foreach (var flag in parts.Skip(2)) material.WriteProperty(new LegendaryExplorerCore.Unreal.BoolProperty(true, flag));
        using var metadata = new PackageTextureMetadataProvider();
        var resource = LegendaryExplorerCore.Unreal.BinaryConverters.ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.Material>(material).SM3MaterialResource;
        var compilation = new ResolvedMaterialShaderCompilation(new LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler.ResolvedMaterialCompilationInput(material, null),
            resource, resource.ID, material.ObjectName.Instanced);
        var sources = LegendaryExplorerCore.Shaders.LE3ShaderSourceSnapshot.FromDirectory(Path.Combine(game, "Engine", "Shaders"), 1252);
        var session = new LE3MaterialShaderCompilerBackend().CreateSession(new MaterialShaderCompileSessionContext(compilation, sources,
            e => metadata.GetMetadata(e), false, null, null));
        var translated = session.Translate();
        Assert.IsTrue(translated.Success, string.Join("; ", translated.Errors));
        var planned = session.Plan();
        Assert.IsTrue(planned.Success, string.Join("; ", planned.Errors));
        for (int i = 0; i < planned.Jobs.Count; i++) Assert.IsTrue(session.Compile(i).Success, $"job {i} failed");
        var assembled = session.Assemble();
        Assert.IsTrue(assembled.Success, string.Join("; ", assembled.Errors));
        Assert.IsTrue(assembled.IsCompleteShaderSet, "incomplete shader set");
        Console.WriteLine($"{parts[1]}: {planned.Jobs.Count} jobs compiled; material HLSL length {session.Artifacts!.Translation!.MaterialHlsl?.Length}");
    }

    /// <summary>
    /// Opt-in diagnostic: MILAN_TRANSLATE = "graph package|graph path|instance package|instance path" translates the graph
    /// with the instance's stored permutation key and writes the resulting resource template to %TEMP%\milan_translate.txt.
    /// </summary>
    [TestMethod, TestCategory("OfflineLocal")]
    public void TranslateWithInstanceKey()
    {
        string? spec = Environment.GetEnvironmentVariable("MILAN_TRANSLATE");
        if (string.IsNullOrEmpty(spec)) Assert.Inconclusive("Set MILAN_TRANSLATE to run.");
        string game = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_GAME") is { Length: > 0 } g ? g
            : @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3";
        var parts = spec.Split('|');
        using var graphPackage = MEPackageHandler.OpenMEPackage(parts[0], forceLoadFromDisk: true);
        using var instancePackage = MEPackageHandler.OpenMEPackage(parts[2], forceLoadFromDisk: true);
        var graph = graphPackage.FindExport(parts[1]) ?? throw new AssertFailedException("graph not found");
        var instance = instancePackage.FindExport(parts[3]) ?? throw new AssertFailedException("instance not found");
        var key = LegendaryExplorerCore.Unreal.BinaryConverters.ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.MaterialInstance>(instance).SM3StaticParameterSet;
        using var metadata = new PackageTextureMetadataProvider();
        var resource = LegendaryExplorerCore.Unreal.BinaryConverters.MaterialResource.Create();
        var compilation = new ResolvedMaterialShaderCompilation(new LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler.ResolvedMaterialCompilationInput(graph, key),
            resource, key.BaseMaterialId, graph.ObjectName.Instanced);
        var sources = LegendaryExplorerCore.Shaders.LE3ShaderSourceSnapshot.FromDirectory(Path.Combine(game, "Engine", "Shaders"), 1252);
        var session = new LE3MaterialShaderCompilerBackend().CreateSession(new MaterialShaderCompileSessionContext(compilation, sources,
            e => metadata.GetMetadata(e), false, null, null));
        var translated = session.Translate();
        var sb = new System.Text.StringBuilder($"success={translated.Success} errors={string.Join("; ", translated.Errors)}\n");
        if (translated.Success)
        {
            var translation = session.Artifacts!.Translation!;
            var template = LegendaryExplorerCore.Shaders.LE3MaterialResourceBuilder.Build(translation, Guid.Empty);
            sb.AppendLine($"NumUserTexCoords={template.NumUserTexCoords} MaxDep={template.MaxTextureDependencyLength}");
            sb.AppendLine("textures: " + string.Join(", ", LegendaryExplorerCore.Shaders.LE3MaterialResourceBuilder.GetUniformExpressionTexturePaths(translation)));
            sb.AppendLine("params: " + string.Join(", ", LegendaryExplorerCore.Shaders.LE3MaterialResourceBuilder.GetInstanceTextureParameterOrder(translation)));
            sb.AppendLine("key: " + ShaderInstallPlan.DescribeKey(key));
        }
        File.WriteAllText(Path.Combine(Path.GetTempPath(), "milan_translate.txt"), sb.ToString());
    }

    /// <summary>
    /// Opt-in diagnostic: MILAN_RESOLVE = "package file name|import path" under MILAN_SHADER_PLAN_OUTPUT; writes where the
    /// install context resolves the import, its expression count and connected inputs, and what GraphSource gives.
    /// </summary>
    [TestMethod, TestCategory("OfflineLocal")]
    public void ResolveImportDiagnostic()
    {
        string? spec = Environment.GetEnvironmentVariable("MILAN_RESOLVE");
        string? output = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_OUTPUT");
        if (string.IsNullOrEmpty(spec) || string.IsNullOrEmpty(output)) Assert.Inconclusive("Set MILAN_RESOLVE and MILAN_SHADER_PLAN_OUTPUT to run.");
        string game = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_GAME") is { Length: > 0 } g ? g
            : @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3";
        LegendaryExplorerCore.GameFilesystem.LE3Directory.DefaultGamePath = game;
        var parts = spec.Split('|');
        using var context = new OfflineShaderInstallContext(output, game, @"E:\Decooked\LE3", null);
        using var package = MEPackageHandler.OpenMEPackage(context.OutputPath(parts[0]), forceLoadFromDisk: true);
        var import = package.FindImport(parts[1]) ?? throw new AssertFailedException("import not found");
        var sb = new System.Text.StringBuilder();
        void Describe(string label, ExportEntry? e)
        {
            if (e == null) { sb.AppendLine($"{label}: null"); return; }
            var props = e.GetProperties();
            var connected = props.OfType<StructProperty>().Where(s => s.Properties.GetProp<ObjectProperty>("Expression")?.Value is int v && v != 0)
                .Select(s => s.Name.Instanced).ToList();
            sb.AppendLine($"{label}: {e.ClassName} {e.InstancedFullPath} in {e.FileRef.FilePath}; expressions " +
                          $"{props.GetProp<ArrayProperty<ObjectProperty>>("Expressions")?.Count ?? 0}; connected inputs [{string.Join(", ", connected)}]");
        }
        var resolved = context.ResolveImport(import);
        Describe("resolved", resolved);
        if (resolved != null) Describe("graph source", context.GraphSource(resolved));
        File.WriteAllText(Path.Combine(Path.GetTempPath(), "milan_resolve.txt"), sb.ToString());
    }

    /// <summary>Opt-in diagnostic: MILAN_DUMP = "package path|export path[|...]"; writes each export's properties to %TEMP%\milan_dump.txt.</summary>
    /// <summary>Opt-in diagnostic: MILAN_LIST = "package[|package...]" writes every export (path, class, data size) to %TEMP%\milan_list_N.txt.</summary>
    [TestMethod, TestCategory("OfflineLocal")]
    public void ListExports()
    {
        string? spec = Environment.GetEnvironmentVariable("MILAN_LIST");
        if (string.IsNullOrEmpty(spec)) Assert.Inconclusive("Set MILAN_LIST to run.");
        int n = 0;
        foreach (var file in spec.Split('|'))
        {
            using var package = MEPackageHandler.OpenMEPackage(file, forceLoadFromDisk: true);
            File.WriteAllLines(Path.Combine(Path.GetTempPath(), $"milan_list_{n++}.txt"), package.Exports
                .Select(e => $"{e.InstancedFullPath} | {e.ClassName} | {e.DataSize}").Order(StringComparer.OrdinalIgnoreCase)
                .Concat(package.Imports.Select(i => $"import {i.InstancedFullPath} | {i.ClassName}").Order(StringComparer.OrdinalIgnoreCase)));
        }
    }

    [TestMethod, TestCategory("OfflineLocal")]
    public void DumpExports()
    {
        string? spec = Environment.GetEnvironmentVariable("MILAN_DUMP");
        if (string.IsNullOrEmpty(spec)) Assert.Inconclusive("Set MILAN_DUMP to run.");
        var parts = spec.Split('|');
        using var package = LegendaryExplorerCore.Packages.MEPackageHandler.OpenMEPackage(parts[0], forceLoadFromDisk: true);
        string Ref(int uIndex) => uIndex == 0 ? "null" : $"{package.GetEntry(uIndex)?.ClassName} {package.GetEntry(uIndex)?.InstancedFullPath}";
        string Value(LegendaryExplorerCore.Unreal.Property p) => p switch
        {
            LegendaryExplorerCore.Unreal.ObjectProperty o => Ref(o.Value),
            LegendaryExplorerCore.Unreal.StructProperty s => "{" + string.Join(" ", s.Properties.Select(x => x.Name.Instanced + "=" + Value(x))) + "}",
            LegendaryExplorerCore.Unreal.ArrayPropertyBase a => $"[{a.Count}] " + string.Join(", ", a.Properties.Take(12).Select(Value)),
            LegendaryExplorerCore.Unreal.NameProperty n => n.Value.Instanced,
            LegendaryExplorerCore.Unreal.BoolProperty b => b.Value.ToString(),
            LegendaryExplorerCore.Unreal.IntProperty i => i.Value.ToString(),
            LegendaryExplorerCore.Unreal.FloatProperty f => f.Value.ToString(),
            LegendaryExplorerCore.Unreal.EnumProperty e => e.Value.Instanced,
            _ => p.GetType().Name
        };
        var sb = new System.Text.StringBuilder();
        foreach (var path in parts.Skip(1))
        {
            var export = package.FindExport(path);
            sb.AppendLine($"== {path}: {export?.ClassName ?? "missing"}");
            if (export == null) continue;
            foreach (var p in export.GetProperties()) sb.AppendLine($"  {p.Name.Instanced} = {Value(p)}");
            LegendaryExplorerCore.Unreal.BinaryConverters.MaterialResource? resource = null;
            if (export.IsA("Material"))
                resource = LegendaryExplorerCore.Unreal.BinaryConverters.ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.Material>(export).SM3MaterialResource;
            else if (export.IsA("MaterialInstance") && export.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true)
            {
                var mi = LegendaryExplorerCore.Unreal.BinaryConverters.ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.MaterialInstance>(export);
                sb.AppendLine($"  [key] {ShaderInstallPlan.DescribeKey(mi.SM3StaticParameterSet)}");
                resource = mi.SM3StaticPermutationResource;
            }
            if (resource != null)
            {
                sb.AppendLine($"  [resource] ID={resource.ID} NumUserTexCoords={resource.NumUserTexCoords} UsingTransforms={resource.UsingTransforms} " +
                              $"MaxDep={resource.MaxTextureDependencyLength} SceneColor={resource.bUsesSceneColor} SceneDepth={resource.bUsesSceneDepth} " +
                              $"DynParam={resource.bUsesDynamicParameter} LightmapUVs={resource.bUsesLightmapUVs} WPO={resource.bUsesMaterialVertexPositionOffset} " +
                              $"VertexColor={resource.bUsesVertexColor} Errors={resource.CompileErrors?.Length} Lookups={resource.TextureLookups?.Length} " +
                              $"DepMap={resource.TextureDependencyLengthMap?.Count} Dropped={resource.DummyDroppedFallbackComponents}");
                sb.AppendLine($"  [textures] {string.Join(", ", (resource.UniformExpressionTextures ?? []).Select(t => Ref(t)))}");
                sb.AppendLine($"  [uniforms] vector={resource.UniformPixelVectorExpressions?.Length} scalar={resource.UniformPixelScalarExpressions?.Length} " +
                              $"2D={resource.Uniform2DTextureExpressions?.Length} cube={resource.UniformCubeTextureExpressions?.Length} shipsEmpty={MaterialChain.ShipsEmpty(export)}");
            }
        }
        File.WriteAllText(Path.Combine(Path.GetTempPath(), "milan_dump.txt"), sb.ToString());
    }

    /// <summary>
    /// Opt-in: plans and installs into MILAN_SHADER_INSTALL_OUTPUT, which is modified in place, so point it at a copy.
    /// Logs to %TEMP%\milan_shader_install.txt. MILAN_SHADER_INSTALL_IGNORE_PLAN_ERRORS=1 drops errored objects (diagnostics only).
    /// </summary>
    [TestMethod, TestCategory("OfflineLocal")]
    public void InstallRealOutput()
    {
        string? output = Environment.GetEnvironmentVariable("MILAN_SHADER_INSTALL_OUTPUT");
        if (string.IsNullOrEmpty(output)) Assert.Inconclusive("Set MILAN_SHADER_INSTALL_OUTPUT to run.");
        string game = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_GAME") is { Length: > 0 } g ? g
            : @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3";
        string decooked = Environment.GetEnvironmentVariable("MILAN_SHADER_PLAN_DECOOKED") is { Length: > 0 } d ? d : @"E:\Decooked\LE3";
        string logPath = Path.Combine(Path.GetTempPath(), "milan_shader_install.txt");

        LegendaryExplorerCore.GameFilesystem.LE3Directory.DefaultGamePath = game;
        Directory.SetCurrentDirectory(Environment.GetEnvironmentVariable("MILAN_REPO") is { Length: > 0 } repo ? repo
            : @"B:\UserProfile\source\repos\ME3Tweaks\ProjectMilan\ProjectMilan");
        var db = MilanInitShared.LoadObjectDB(LegendaryExplorerCore.Packages.MEGame.LE3);
        using var log = new StreamWriter(logPath) { AutoFlush = true };
        var sw = Stopwatch.StartNew();
        void Log(string s) { lock (log) log.WriteLine($"[{sw.Elapsed:hh\\:mm\\:ss}] {s}"); }
        using var context = new OfflineShaderInstallContext(output, game, decooked, db);
        var plan = context.Plan();
        Log($"Planned: {plan.Materials.Count} materials, {plan.Instances.Count} instances, {plan.Variants.Count} variants, " +
            $"{plan.ChainClones.Count} clones, {plan.Errors.Count} errors");
        foreach (var e in plan.Errors) Log("PLAN ERROR " + e);
        if (plan.Errors.Count > 0 && Environment.GetEnvironmentVariable("MILAN_SHADER_INSTALL_IGNORE_PLAN_ERRORS") == "1")
        {
            // Diagnostics only: drop the objects that errored so the rest can show compile and install failures.
            var bad = plan.Errors.Select(e => e.StartsWith("copies of ", StringComparison.Ordinal) ? e.Split(' ')[2] : e.Split(' ')[0].TrimEnd(':'))
                .ToHashSet(StringComparer.Ordinal);
            plan = plan with
            {
                Materials = plan.Materials.Where(m => !bad.Contains(m.Identity)).ToList(),
                Instances = plan.Instances.Where(i => !bad.Contains(i.Identity)).ToList(),
                Errors = []
            };
            Log($"Ignoring plan errors: dropped {bad.Count} objects");
        }
        try
        {
            new OfflineShaderInstaller(context, Log).Install(plan, Math.Max(1, Environment.ProcessorCount / 2));
        }
        catch (Exception e)
        {
            Log("INSTALL FAILED " + e);
            throw;
        }
        Log("Install complete");
    }
}
