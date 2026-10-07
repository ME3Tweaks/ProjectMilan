using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore.Shaders.OfflineCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

[TestClass]
public sealed class LE3MaterialShaderCompilerBackendTests
{
    private static readonly OfflineShaderCompilerOptions Enabled = new() { CompilationEnabled = true };

    /// <summary>
    /// Runs the real LEC compiler on an in-memory material with a minimal template. Translation needs no
    /// game files; the snapshot has no .usf shaders, so the request must stop with that recorded, not
    /// as a material error and not with a fragment.
    /// </summary>
    [TestMethod]
    public void RealBackendTranslatesFromTheSessionSnapshotAndStopsWithoutShaderSources()
    {
        using var package = Fixtures.Package("RealBackend");
        var material = Fixtures.Material(package, "RealMat");
        var texture = Fixtures.Texture(package, "Diffuse");
        var sample = Fixtures.Parameter(material, "Diffuse", texture);
        material.WriteProperty(new StructProperty("ExpressionInput", new PropertyCollection
        {
            new ObjectProperty(sample.UIndex, "Expression"),
            new BoolProperty(true, "Mask"), new BoolProperty(true, "MaskR"), new BoolProperty(true, "MaskG"),
            new BoolProperty(true, "MaskB"), new BoolProperty(false, "MaskA")
        }, "DiffuseColor"));
        var sources = LE3ShaderSourceSession.FromSnapshot(Fixtures.Sources());
        using var metadata = new PackageTextureMetadataProvider();

        var outcome = new OfflineMaterialShaderCompilerService(Enabled).CompileMaterial(
            new MaterialShaderCompileRequest(material, sources, metadata));

        Console.WriteLine($"{outcome.Status} at {outcome.Phase} ({outcome.PlannedJobs.Count} jobs, {outcome.Decisions.Count} decisions): {string.Join("; ", outcome.Errors)}");
        var translation = outcome.Artifacts?.Translation;
        Assert.IsNotNull(translation, $"{outcome.Status} at {outcome.Phase}: {string.Join("; ", outcome.Errors)}");
        Assert.IsTrue(translation.Success, string.Join("; ", translation.Errors));
        Assert.AreSame(sources.GetSnapshot(), translation.SourceSnapshot);
        CollectionAssert.AreEqual(new[] { texture.UIndex }, translation.UniformExpressionTextures.ToArray());
        Assert.AreEqual(texture.InstancedFullPath, metadata.Resolutions.Single().Reference);
        Assert.IsNull(outcome.Fragment);
        // How far planning gets depends on the compiler's coverage; either way a missing .usf is an
        // input failure with the exception kept, never "backend unavailable" or "unsupported".
        Assert.AreEqual(MaterialShaderCompileStatus.Failed, outcome.Status);
        if (outcome.Phase == MaterialShaderCompilePhase.Compilation)
            Assert.IsInstanceOfType<FileNotFoundException>(outcome.Exception);
    }

    /// <summary>
    /// Opt-in end-to-end compile of one real material on this machine. Skipped unless these are set:
    /// MILAN_OFFLINE_SHADER_TEST_SHADERS (LE3 .usf folder), MILAN_OFFLINE_SHADER_TEST_PACKAGE (an LE3
    /// package with the decooked graph) and MILAN_OFFLINE_SHADER_TEST_MATERIAL (instanced full path).
    /// Imports are looked up in the package's own folder by linker name. Saves and installs nothing.
    /// </summary>
    [TestMethod]
    [TestCategory("OfflineLocal")]
    public void LocalEndToEndCompileOfOneMaterial()
    {
        string? shaders = Environment.GetEnvironmentVariable("MILAN_OFFLINE_SHADER_TEST_SHADERS");
        string? packagePath = Environment.GetEnvironmentVariable("MILAN_OFFLINE_SHADER_TEST_PACKAGE");
        string? materialPath = Environment.GetEnvironmentVariable("MILAN_OFFLINE_SHADER_TEST_MATERIAL");
        if (string.IsNullOrWhiteSpace(shaders) || string.IsNullOrWhiteSpace(packagePath) || string.IsNullOrWhiteSpace(materialPath))
        {
            Assert.Inconclusive("Machine-local test; set the MILAN_OFFLINE_SHADER_TEST_* variables to run it.");
            return;
        }

        using var package = MEPackageHandler.OpenMEPackage(packagePath);
        var material = package.FindExport(materialPath) ?? throw new AssertFailedException($"{materialPath} not found in {packagePath}.");
        string folder = Path.GetDirectoryName(packagePath)!;
        using var metadata = new PackageTextureMetadataProvider(import => [Path.Combine(folder, ((ImportEntry)import).GetLinker() + ".pcc")]);
        var progress = new ListProgress<MaterialShaderCompileProgress>(p => Console.WriteLine($"{p.CompletedJobs}/{p.TotalJobs} {p.CurrentTarget?.ShaderTypeName}"));

        var outcome = new OfflineMaterialShaderCompilerService(Enabled).CompileMaterial(
            new MaterialShaderCompileRequest(material, LE3ShaderSourceSession.FromDirectory(shaders, 1252), metadata), progress);

        Console.WriteLine($"{outcome.Status} at {outcome.Phase}; {outcome.Jobs.Count}/{outcome.PlannedJobs.Count} jobs");
        foreach (var error in outcome.Errors) Console.WriteLine(error);
        Assert.AreEqual(MaterialShaderCompileStatus.SucceededFragment, outcome.Status, string.Join(Environment.NewLine, outcome.Errors));
        Assert.IsFalse(outcome.IsCompleteShaderSet);
    }
}
