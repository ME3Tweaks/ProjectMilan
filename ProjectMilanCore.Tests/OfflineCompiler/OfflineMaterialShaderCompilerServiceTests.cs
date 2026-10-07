using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore.Shaders.OfflineCompiler;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

[TestClass]
public sealed class OfflineMaterialShaderCompilerServiceTests
{
    private static readonly OfflineShaderCompilerOptions Enabled = new() { CompilationEnabled = true };

    private static (OfflineMaterialShaderCompilerService Service, FakeBackend Backend, MaterialShaderCompileRequest Request, IMEPackage Package)
        Setup(OfflineShaderCompilerOptions? options = null, LE3ShaderSourceSession? sources = null)
    {
        var package = Fixtures.Package("ServiceTest");
        var material = Fixtures.Material(package, "Mat");
        var backend = new FakeBackend();
        var service = new OfflineMaterialShaderCompilerService(options ?? Enabled, backend: backend);
        var request = new MaterialShaderCompileRequest(material, sources ?? LE3ShaderSourceSession.FromSnapshot(Fixtures.Sources()),
            new SpyMetadataProvider());
        return (service, backend, request, package);
    }

    [TestMethod]
    public void ProductionDefaultIsDisabled()
    {
        Assert.IsFalse(OfflineShaderCompilerOptions.Production.CompilationEnabled);
        Assert.IsFalse(new OfflineShaderCompilerOptions().CompilationEnabled);
    }

    [TestMethod]
    public async Task DisabledStopsBeforeResolutionSourcesMetadataAndBackend()
    {
        var sources = LE3ShaderSourceSession.FromDirectory(@"Z:\Milan\DoesNotExist\Shaders", 1252);
        var (service, backend, request, package) = Setup(OfflineShaderCompilerOptions.Production, sources);
        using var _ = package;
        var resolver = new ThrowingResolver();
        var gated = new OfflineMaterialShaderCompilerService(OfflineShaderCompilerOptions.Production, resolver, backend);

        foreach (var outcome in new[] { gated.CompileMaterial(request), await gated.CompileMaterialAsync(request), gated.CompileMaterial(null!) })
        {
            Assert.AreEqual(MaterialShaderCompileStatus.Disabled, outcome.Status);
            Assert.AreEqual(MaterialShaderCompilePhase.ActivationGate, outcome.Phase);
            Assert.IsFalse(outcome.IsSuccess);
            Assert.IsNull(outcome.Fragment);
        }
        Assert.IsFalse(gated.IsCompilationEnabled);
        Assert.IsFalse(sources.IsCaptured);
        Assert.AreEqual(0, resolver.Calls);
        Assert.AreEqual(0, backend.Contexts.Count);
        Assert.AreEqual(0, ((SpyMetadataProvider)request.TextureMetadata).Calls);
    }

    [TestMethod]
    public void SuccessKeepsWarningsTextureOrderAndFalseCompleteness()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        var progress = new ListProgress<MaterialShaderCompileProgress>();

        var outcome = service.CompileMaterial(request, progress);

        Assert.AreEqual(MaterialShaderCompileStatus.SucceededFragment, outcome.Status, string.Join("; ", outcome.Errors));
        Assert.AreEqual(MaterialShaderCompilePhase.Completed, outcome.Phase);
        Assert.IsNotNull(outcome.Fragment);
        Assert.IsFalse(outcome.IsCompleteShaderSet);
        CollectionAssert.AreEqual(new[] { 7, 3 }, outcome.UniformExpressionTextures.ToArray());
        CollectionAssert.AreEqual(new[] { "warning X0", "warning X1" }, outcome.Jobs.Select(j => j.Diagnostics).ToArray());
        Assert.AreEqual(2, outcome.Decisions.Count);
        CollectionAssert.AreEqual(new[] { "Translate", "Plan", "Compile0", "Compile1", "Assemble" }, backend.LastSession!.Calls);
        CollectionAssert.AreEqual(new[] { 0, 1, 2 }, progress.Reports.Select(p => p.CompletedJobs).ToArray());
        Assert.IsTrue(progress.Reports.All(p => p.TotalJobs == 2));
    }

    [TestMethod]
    public void EveryPhaseGetsTheSameSnapshotAcrossRequests()
    {
        var session = LE3ShaderSourceSession.FromSnapshot(Fixtures.Sources());
        var (service, backend, request, package) = Setup(sources: session);
        using var _ = package;

        service.CompileMaterial(request);
        service.CompileMaterial(request);

        Assert.AreEqual(2, backend.Contexts.Count);
        Assert.AreSame(session.GetSnapshot(), backend.Contexts[0].Sources);
        Assert.AreSame(backend.Contexts[0].Sources, backend.Contexts[1].Sources);
    }

    [TestMethod]
    public void ResourceIdentityStaysSeparateFromTheStaticKey()
    {
        var resourceId = Guid.NewGuid();
        using var package = Fixtures.Package("IdentityTest");
        var material = Fixtures.Material(package, "IdentityMat", resourceId);
        var backend = new FakeBackend();
        var service = new OfflineMaterialShaderCompilerService(Enabled, backend: backend);

        var outcome = service.CompileMaterial(new MaterialShaderCompileRequest(material,
            LE3ShaderSourceSession.FromSnapshot(Fixtures.Sources()), new SpyMetadataProvider()));

        var compilation = backend.Contexts.Single().Compilation;
        Assert.AreSame(compilation, outcome.Compilation);
        Assert.AreEqual(resourceId, compilation.MaterialResourceId);
        Assert.AreEqual(resourceId, compilation.Resource.ID);
        Assert.AreEqual("IdentityMat", compilation.FriendlyName);
        Assert.AreSame(material, compilation.Input.BaseMaterial);
        Assert.IsNull(compilation.Input.RequestedMaterialInstance);
        // A base material compiles its authored defaults; no static key is invented for it.
        Assert.IsNull(compilation.Input.GetStaticParametersSnapshot());
    }

    [TestMethod]
    public void WrongGameIsUnsupported()
    {
        using var package = Fixtures.Package("ME3Material", LegendaryExplorerCore.Packages.MEGame.ME3);
        var material = package.CreateExport("Mat", "Material", indexed: false);
        var backend = new FakeBackend();
        var outcome = new OfflineMaterialShaderCompilerService(Enabled, backend: backend).CompileMaterial(
            new MaterialShaderCompileRequest(material, LE3ShaderSourceSession.FromSnapshot(Fixtures.Sources()), new SpyMetadataProvider()));

        Assert.AreEqual(MaterialShaderCompileStatus.Unsupported, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Resolution, outcome.Phase);
        StringAssert.Contains(outcome.Errors.Single(), "Only LE3");
        Assert.AreEqual(0, backend.Contexts.Count);
    }

    [TestMethod]
    public void InstancesAndMaterialSubclassesAreUnsupportedNotCompiledAsTheirParent()
    {
        using var package = Fixtures.Package("InstanceTest");
        var parent = Fixtures.Material(package, "Parent");
        var instance = Fixtures.Instance(package, "Inst", parent);
        var decal = Fixtures.Material(package, "Decal", className: "DecalMaterial");
        var backend = new FakeBackend();
        var service = new OfflineMaterialShaderCompilerService(Enabled,
            new MaterialCompilationResolver(e => e as ExportEntry), backend);
        var sources = LE3ShaderSourceSession.FromSnapshot(Fixtures.Sources());

        var instanceOutcome = service.CompileMaterial(new MaterialShaderCompileRequest(instance, sources, new SpyMetadataProvider()));
        var decalOutcome = service.CompileMaterial(new MaterialShaderCompileRequest(decal, sources, new SpyMetadataProvider()));

        Assert.AreEqual(MaterialShaderCompileStatus.Unsupported, instanceOutcome.Status);
        StringAssert.Contains(instanceOutcome.Errors.Single(), "MaterialInstance compilation is not implemented");
        Assert.IsNotNull(instanceOutcome.Resolution?.InstanceEncoding, "The read-only encoding analysis is attached.");
        Assert.AreEqual(MaterialShaderCompileStatus.Unsupported, decalOutcome.Status);
        StringAssert.Contains(decalOutcome.Errors.Single(), "DecalMaterial");
        Assert.AreEqual(0, backend.Contexts.Count);
    }

    [TestMethod]
    public void MissingResourceIdFailsResolution()
    {
        using var package = Fixtures.Package("NoIdTest");
        var material = package.CreateExport("Mat", "Material", indexed: false);
        material.WriteBinary(LegendaryExplorerCore.Unreal.BinaryConverters.Material.Create());
        var outcome = new OfflineMaterialShaderCompilerService(Enabled, backend: new FakeBackend()).CompileMaterial(
            new MaterialShaderCompileRequest(material, LE3ShaderSourceSession.FromSnapshot(Fixtures.Sources()), new SpyMetadataProvider()));

        Assert.AreEqual(MaterialShaderCompileStatus.Failed, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Resolution, outcome.Phase);
        StringAssert.Contains(outcome.Errors.Single(), "no material resource ID");
    }

    [TestMethod]
    public void SourceCaptureFailureIsAFailedOutcomeWithTheException()
    {
        var (service, backend, request, package) = Setup(sources: LE3ShaderSourceSession.FromDirectory(@"Z:\Milan\DoesNotExist\Shaders", 1252));
        using var _ = package;

        var outcome = service.CompileMaterial(request);

        Assert.AreEqual(MaterialShaderCompileStatus.Failed, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.SourceCapture, outcome.Phase);
        Assert.IsNotNull(outcome.Exception);
        Assert.AreEqual(0, backend.Contexts.Count);
    }

    [TestMethod]
    public void ReportedTranslationErrorsStopBeforePlanning()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        backend.NewSession = () => new FakeSession { OnTranslate = () => new(false, ["Unsupported expression: Foo", "Second error"]) };

        var outcome = service.CompileMaterial(request);

        Assert.AreEqual(MaterialShaderCompileStatus.Failed, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Translation, outcome.Phase);
        CollectionAssert.AreEqual(new[] { "Unsupported expression: Foo", "Second error" }, outcome.Errors.ToArray());
        Assert.IsNull(outcome.Exception, "Returned errors are not exceptions.");
        CollectionAssert.AreEqual(new[] { "Translate" }, backend.LastSession!.Calls);
    }

    [TestMethod]
    public void ThrownTranslationIsReportedAsAnExceptionNotAMaterialError()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        backend.NewSession = () => new FakeSession { OnTranslate = () => throw new IOException("metadata callback failed") };

        var outcome = service.CompileMaterial(request);

        Assert.AreEqual(MaterialShaderCompileStatus.Failed, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Translation, outcome.Phase);
        Assert.IsInstanceOfType<IOException>(outcome.Exception);
        StringAssert.Contains(outcome.Errors.Single(), "IOException during Translation");
    }

    [TestMethod]
    public void MissingNativeBackendIsDistinctFromMaterialFailure()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        backend.CreateThrows = new ShaderCompilerBackendUnavailableException("d3dcompiler_47 missing");
        var atCreation = service.CompileMaterial(request);

        backend.CreateThrows = null;
        backend.NewSession = () => new FakeSession { OnCompile = _ => throw new ShaderCompilerBackendUnavailableException("SharpDX missing") };
        var atCompile = service.CompileMaterial(request);

        Assert.AreEqual(MaterialShaderCompileStatus.BackendUnavailable, atCreation.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.BackendCreation, atCreation.Phase);
        Assert.AreEqual(MaterialShaderCompileStatus.BackendUnavailable, atCompile.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Compilation, atCompile.Phase);
        Assert.AreEqual(FakeSession.First, atCompile.FailedTarget);
    }

    [TestMethod]
    public void UnresolvedPlanCompilesNothingButKeepsDecisions()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        var decisions = new[]
        {
            new ShaderCompileDecision(FakeSession.First, ShaderCompileDisposition.Eligible, ShaderCompileGate.Registration, "ok"),
            new ShaderCompileDecision(FakeSession.Second, ShaderCompileDisposition.Excluded, ShaderCompileGate.ShaderTypeShouldCache, "not needed"),
            new ShaderCompileDecision(Fixtures.Target("TFogShader", null), ShaderCompileDisposition.Unresolved, ShaderCompileGate.MaterialResourceShouldCache, "unknown")
        };
        backend.NewSession = () => new FakeSession { OnPlan = () => new(false, ["1 candidate unresolved"], [], decisions) };

        var outcome = service.CompileMaterial(request);

        Assert.AreEqual(MaterialShaderCompileStatus.Failed, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Planning, outcome.Phase);
        CollectionAssert.AreEqual(decisions, outcome.Decisions.ToArray());
        Assert.AreEqual(0, outcome.PlannedJobs.Count);
        CollectionAssert.AreEqual(new[] { "Translate", "Plan" }, backend.LastSession!.Calls);
    }

    [TestMethod]
    public void ZeroJobPlanIsItsOwnOutcome()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        var excluded = new ShaderCompileDecision(FakeSession.First, ShaderCompileDisposition.Excluded, ShaderCompileGate.ShaderTypeShouldCache, "excluded");
        backend.NewSession = () => new FakeSession { OnPlan = () => new(true, [], [], [excluded]) };

        var outcome = service.CompileMaterial(request);

        Assert.AreEqual(MaterialShaderCompileStatus.EmptyPlan, outcome.Status);
        Assert.IsFalse(outcome.IsSuccess);
        Assert.IsNull(outcome.Fragment);
        Assert.AreEqual(excluded, outcome.Decisions.Single());
        CollectionAssert.DoesNotContain(backend.LastSession!.Calls, "Assemble");
    }

    [TestMethod]
    public void FailedJobStopsTheRequestAndNamesTheTarget()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        backend.NewSession = () => new FakeSession { OnCompile = i => new(FakeSession.First, false, "error X3004: undeclared identifier", 0) };

        var outcome = service.CompileMaterial(request);

        Assert.AreEqual(MaterialShaderCompileStatus.Failed, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Compilation, outcome.Phase);
        Assert.AreEqual(FakeSession.First, outcome.FailedTarget);
        StringAssert.Contains(outcome.Errors.Single(), "X3004");
        Assert.AreEqual(1, outcome.Jobs.Count);
        CollectionAssert.AreEqual(new[] { "Translate", "Plan", "Compile0" }, backend.LastSession!.Calls);
    }

    [TestMethod]
    public void AssemblyErrorsWithholdTheFragment()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        backend.NewSession = () => new FakeSession { OnAssemble = () => new(false, ["CRC failure"], null, [], false) };

        var outcome = service.CompileMaterial(request);

        Assert.AreEqual(MaterialShaderCompileStatus.Failed, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Assembly, outcome.Phase);
        Assert.IsNull(outcome.Fragment);
        Assert.AreEqual(2, outcome.Jobs.Count, "Successful job diagnostics are kept.");
    }

    [TestMethod]
    public void CancellationIsCheckedBetweenJobs()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        using var cts = new CancellationTokenSource();
        backend.NewSession = () => new FakeSession
        {
            OnCompile = i =>
            {
                cts.Cancel(); // An in-flight compile finishes; the next job must not start.
                return new(FakeSession.First, true, null, 1);
            }
        };

        var outcome = service.CompileMaterial(request, null, cts.Token);

        Assert.AreEqual(MaterialShaderCompileStatus.Cancelled, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Compilation, outcome.Phase);
        Assert.AreEqual(FakeSession.Second, outcome.FailedTarget);
        Assert.AreEqual(1, outcome.Jobs.Count);
        CollectionAssert.AreEqual(new[] { "Translate", "Plan", "Compile0" }, backend.LastSession!.Calls);
    }

    [TestMethod]
    public void CancellationBeforeStartTouchesNothing()
    {
        var (service, backend, request, package) = Setup();
        using var _ = package;
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        var outcome = service.CompileMaterial(request, null, cts.Token);

        Assert.AreEqual(MaterialShaderCompileStatus.Cancelled, outcome.Status);
        Assert.AreEqual(MaterialShaderCompilePhase.Resolution, outcome.Phase);
        Assert.AreEqual(0, backend.Contexts.Count);
    }

    private sealed class ThrowingResolver : IMaterialCompilationResolver
    {
        public int Calls;
        public MaterialResolutionOutcome Resolve(MaterialShaderCompileRequest request)
        {
            Calls++;
            throw new AssertFailedException("The resolver must not run while disabled.");
        }
    }
}
