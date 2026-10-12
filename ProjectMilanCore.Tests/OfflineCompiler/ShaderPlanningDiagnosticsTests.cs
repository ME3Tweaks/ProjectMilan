using ProjectMilanCore.Shaders.OfflineCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

[TestClass]
public sealed class ShaderPlanningDiagnosticsTests
{
    [TestMethod]
    public void DiagnosticLoggingDoesNotChangeShaderPlanningDecisions()
    {
        using var package = Fixtures.Package("Diagnostics");
        var material = Fixtures.Material(package, "Mat");
        Fixtures.Parameter(material, "Diffuse", Fixtures.Texture(package, "Diffuse"));
        Fixtures.Instance(package, "Instance", material);
        var messages = new List<string>();

        ShaderInstallPlan Plan(ShaderPlanningDiagnostics? diagnostics)
        {
            using var metadata = new PackageTextureMetadataProvider();
            var planner = new ShaderInstallPlanner(new ShaderInstallPlannerOptions
            {
                ModPackagePaths = [package.FilePath], ResolveImport = _ => null,
                TextureMetadata = metadata, KeysInRefShaderCache = _ => new HashSet<LegendaryExplorerCore.Unreal.BinaryConverters.StaticParameterSet>(), Diagnostics = diagnostics
            });
            diagnostics?.BeginPackage(package.FilePath);
            planner.AddPackage(package);
            diagnostics?.CompletePackage();
            var plan = planner.Build();
            diagnostics?.CompletePlan();
            return plan;
        }

        var baseline = Plan(null);
        var instrumented = Plan(new ShaderPlanningDiagnostics(messages.Add));
        Assert.AreEqual(baseline.Describe(), instrumented.Describe());
        Assert.IsTrue(messages.Any(m => m.Contains("usage scan", StringComparison.Ordinal)));
        Assert.IsTrue(messages.Any(m => m.Contains("lightmapped mesh-slot scan", StringComparison.Ordinal)));
        Assert.IsTrue(messages.Any(m => m.Contains("Planning package finished", StringComparison.Ordinal)));
        Assert.IsTrue(messages.Any(m => m.Contains("Planning diagnostics total", StringComparison.Ordinal)));
    }
}
