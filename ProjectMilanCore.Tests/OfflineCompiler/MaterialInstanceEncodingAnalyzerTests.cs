using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore.Shaders.OfflineCompiler;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

[TestClass]
public sealed class MaterialInstanceEncodingAnalyzerTests
{
    private static MaterialInstanceEncodingReport Analyze(ExportEntry instance, PackageTextureMetadataProvider provider)
        => MaterialInstanceEncodingAnalyzer.Analyze(instance, e => e as ExportEntry, provider);

    [TestMethod]
    public void PlainParameterOverrideWithDifferentMetadataIsAParentVariantCandidate()
    {
        using var package = Fixtures.Package("PlainOverride");
        var parent = Fixtures.Material(package, "Parent");
        var bc7 = Fixtures.Texture(package, "DefaultNorm", "TC_NormalmapBC7");
        var bc5 = Fixtures.Texture(package, "OverrideNorm", "TC_NormalmapBC5");
        Fixtures.Parameter(parent, "Blend_Normal", bc7);
        var instance = Fixtures.Instance(package, "Inst", parent, ("Blend_Normal", bc5));
        using var provider = new PackageTextureMetadataProvider();

        var report = Analyze(instance, provider);

        var finding = report.Findings.Single();
        Assert.AreEqual(TextureEncodingRequirement.ParentVariantCandidate, finding.Requirement, finding.Reason);
        Assert.AreEqual(instance.InstancedFullPath, finding.OverriddenBy);
        Assert.AreEqual(bc5.InstancedFullPath, finding.EffectiveTexture);
        Assert.IsTrue(report.NeedsParentVariant);
        Assert.IsFalse(report.NeedsStaticNormalChanges);
        Assert.IsTrue(report.IsComplete);
    }

    [TestMethod]
    public void OverrideWithSameMetadataOrNoOverrideNeedsNothing()
    {
        using var package = Fixtures.Package("SameOverride");
        var parent = Fixtures.Material(package, "Parent");
        Fixtures.Parameter(parent, "Diffuse", Fixtures.Texture(package, "DefaultDiff"));
        Fixtures.Parameter(parent, "Spec", Fixtures.Texture(package, "DefaultSpec"));
        var instance = Fixtures.Instance(package, "Inst", parent, ("Diffuse", Fixtures.Texture(package, "OtherDiff")));
        using var provider = new PackageTextureMetadataProvider();

        var report = Analyze(instance, provider);

        Assert.IsTrue(report.Findings.All(f => f.Requirement == TextureEncodingRequirement.None));
        Assert.AreEqual(2, report.Findings.Count);
        Assert.IsTrue(report.IsComplete);
    }

    [TestMethod]
    public void NormalParameterIsFixedOnTheInstancesStaticParameter()
    {
        using var package = Fixtures.Package("NormalParam");
        var parent = Fixtures.Material(package, "Parent");
        Fixtures.Parameter(parent, "Base_Normal", Fixtures.Texture(package, "Placeholder", "TC_Normalmap"),
            "MaterialExpressionTextureSampleParameterNormal");
        var bc5 = Fixtures.Texture(package, "RealNorm", "TC_NormalmapBC5");
        var stale = Fixtures.Instance(package, "Stale", parent, ("Base_Normal", bc5));
        Fixtures.StaticNormal(stale, "Base_Normal", Fixtures.CompressionIndex("TC_Normalmap"));
        var current = Fixtures.Instance(package, "Current", parent, ("Base_Normal", bc5));
        Fixtures.StaticNormal(current, "Base_Normal", Fixtures.CompressionIndex("TC_NormalmapBC5"));
        using var provider = new PackageTextureMetadataProvider();

        var staleFinding = Analyze(stale, provider).Findings.Single();
        var currentFinding = Analyze(current, provider).Findings.Single();

        Assert.AreEqual(TextureEncodingRequirement.StaticNormalCompression, staleFinding.Requirement, staleFinding.Reason);
        Assert.AreEqual("TC_Normalmap", staleFinding.StoredNormalCompression);
        Assert.AreEqual(TextureEncodingRequirement.None, currentFinding.Requirement, currentFinding.Reason);
    }

    [TestMethod]
    public void NormalOverrideWithoutAPermutationNeedsOne()
    {
        using var package = Fixtures.Package("NormalNoPermutation");
        var parent = Fixtures.Material(package, "Parent");
        Fixtures.Parameter(parent, "Base_Normal", Fixtures.Texture(package, "Placeholder", "TC_Normalmap"),
            "MaterialExpressionTextureSampleParameterNormal");
        var instance = Fixtures.Instance(package, "Inst", parent, ("Base_Normal", Fixtures.Texture(package, "RealNorm", "TC_NormalmapBC5")));
        using var provider = new PackageTextureMetadataProvider();

        var finding = Analyze(instance, provider).Findings.Single();

        Assert.AreEqual(TextureEncodingRequirement.StaticNormalCompression, finding.Requirement, finding.Reason);
        Assert.IsNull(finding.StoredNormalCompression);
    }

    [TestMethod]
    public void NearestOverrideWinsAndNullOverridesFallThrough()
    {
        using var package = Fixtures.Package("Chain");
        var parent = Fixtures.Material(package, "Parent");
        Fixtures.Parameter(parent, "Blend_Normal", Fixtures.Texture(package, "Default", "TC_NormalmapBC7"));
        var bc5 = Fixtures.Texture(package, "MidNorm", "TC_NormalmapBC5");
        var mid = Fixtures.Instance(package, "Mid", parent, ("Blend_Normal", bc5));
        var leaf = Fixtures.Instance(package, "Leaf", mid, ("Blend_Normal", null));
        using var provider = new PackageTextureMetadataProvider();

        var report = Analyze(leaf, provider);

        var finding = report.Findings.Single();
        CollectionAssert.AreEqual(new[] { leaf.InstancedFullPath, mid.InstancedFullPath, parent.InstancedFullPath }, report.ParentChain.ToArray());
        Assert.AreEqual(mid.InstancedFullPath, finding.OverriddenBy);
        Assert.AreEqual(TextureEncodingRequirement.ParentVariantCandidate, finding.Requirement);
        StringAssert.Contains(finding.Reason, "assumed to fall through");
    }

    [TestMethod]
    public void AmbiguousOverrideIsUnresolvedAndTheReportIncomplete()
    {
        using var package = Fixtures.Package("Ambiguous");
        var parent = Fixtures.Material(package, "Parent");
        Fixtures.Parameter(parent, "Diffuse", Fixtures.Texture(package, "Default"));
        var instance = Fixtures.Instance(package, "Inst", parent,
            ("Diffuse", Fixtures.Texture(package, "A")), ("diffuse", Fixtures.Texture(package, "B")));
        using var provider = new PackageTextureMetadataProvider();

        var report = Analyze(instance, provider);

        Assert.AreEqual(TextureEncodingRequirement.Unresolved, report.Findings.Single().Requirement);
        Assert.IsFalse(report.IsComplete);
    }

    [TestMethod]
    public void StrippedParentAndUnresolvableParentAreErrors()
    {
        using var package = Fixtures.Package("Stripped");
        var stripped = Fixtures.Material(package, "BootResident");
        var onStripped = Fixtures.Instance(package, "OnStripped", stripped);
        var import = new ImportEntry(package, 0, "Elsewhere") { ClassName = "Material", PackageFile = "Engine" };
        package.AddImport(import);
        var onImport = Fixtures.Instance(package, "OnImport", import);
        using var provider = new PackageTextureMetadataProvider();

        var strippedReport = Analyze(onStripped, provider);
        var importReport = MaterialInstanceEncodingAnalyzer.Analyze(onImport, _ => null, provider);

        StringAssert.Contains(strippedReport.Errors.Single(), "no expression graph");
        StringAssert.Contains(importReport.Errors.Single(), "Could not resolve parent");
        Assert.IsFalse(strippedReport.IsComplete);
        Assert.IsFalse(importReport.IsComplete);
    }
}

[TestClass]
public sealed class ParentVariantIdentityTests
{
    private static readonly Guid ParentId = Guid.Parse("0f6c2b1e-4c4d-4b8c-9a55-5b0d9f3f6a10");
    private static readonly TextureCompilationMetadata Bc5 = new(TextureDimension.Texture2D, "TC_NormalmapBC5");
    private static readonly TextureCompilationMetadata Bc7 = new(TextureDimension.Texture2D, "TC_NormalmapBC7");

    [TestMethod]
    public void SameInputsGiveTheSameIdentityRegardlessOfOrderOrCase()
    {
        var a = ParentVariantIdentity.Create("Pkg.Parent", "Parent", ParentId, [("Blend_Normal", Bc5), ("Detail", Bc7)]);
        var b = ParentVariantIdentity.Create("PKG.parent", "Parent", ParentId, [("detail", Bc7), ("BLEND_NORMAL", Bc5)]);

        Assert.AreEqual(a, b);
        StringAssert.StartsWith(a.ObjectName, "Parent_MV");
        Assert.AreNotEqual(Guid.Empty, a.MaterialResourceId);
        Assert.AreNotEqual(ParentId, a.MaterialResourceId);
    }

    [TestMethod]
    public void DifferentDefaultsOrParentsGiveDifferentIdentities()
    {
        var bc5 = ParentVariantIdentity.Create("Pkg.Parent", "Parent", ParentId, [("Blend_Normal", Bc5)]);
        var bc7 = ParentVariantIdentity.Create("Pkg.Parent", "Parent", ParentId, [("Blend_Normal", Bc7)]);
        var otherParent = ParentVariantIdentity.Create("Pkg.Other", "Parent", ParentId, [("Blend_Normal", Bc5)]);
        var unpack = ParentVariantIdentity.Create("Pkg.Parent", "Parent", ParentId,
            [("Blend_Normal", new TextureCompilationMetadata(TextureDimension.Texture2D, "TC_NormalmapBC5", new System.Numerics.Vector4(-1)))]);

        Assert.AreEqual(4, new[] { bc5, bc7, otherParent, unpack }.Select(v => v.MaterialResourceId).Distinct().Count());
        Assert.AreEqual(4, new[] { bc5, bc7, otherParent, unpack }.Select(v => v.ObjectName).Distinct().Count());
    }

    [TestMethod]
    public void InvalidInputsThrow()
    {
        Assert.ThrowsException<ArgumentException>(() => ParentVariantIdentity.Create("Pkg.Parent", "Parent", ParentId, []));
        Assert.ThrowsException<ArgumentException>(() => ParentVariantIdentity.Create("Pkg.Parent", "Parent", Guid.Empty, [("A", Bc5)]));
        Assert.ThrowsException<ArgumentException>(() => ParentVariantIdentity.Create("Pkg.Parent", "Parent", ParentId, [("A", Bc5), ("a", Bc7)]));
    }
}
