using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore.Shaders.OfflineCompiler;

namespace ProjectMilanCore.Tests.OfflineCompiler;

[TestClass]
public sealed class ShaderInstallPlannerTests
{
    private static ShaderInstallPlan Plan(params IMEPackage[] packages) => Plan(null, packages);

    /// <param name="game">The game's copy of each material the game has too. Its shader map counts as in the RefShaderCache.</param>
    private static ShaderInstallPlan Plan(Func<ExportEntry, VanillaMaterialInfo?>? game, params IMEPackage[] packages)
    {
        using var metadata = new PackageTextureMetadataProvider();
        var gameIds = new HashSet<Guid>();
        var planner = new ShaderInstallPlanner(new ShaderInstallPlannerOptions
        {
            ModPackagePaths = packages.Select(p => p.FilePath).ToList(),
            ResolveImport = _ => null,
            TextureMetadata = metadata,
            KeysInRefShaderCache = keys => keys.Where(k => gameIds.Contains(k.BaseMaterialId) && k.NormalParameters.Length == 0).ToHashSet(),
            VanillaMaterial = game == null ? null : material =>
            {
                var info = game(material);
                if (info != null) gameIds.Add(info.ResourceId);
                return info;
            }
        });
        foreach (var package in packages) planner.AddPackage(package);
        return planner.Build();
    }

    private static readonly Guid GameId = new("aaaaaaaa-2222-3333-4444-555555555555");

    /// <summary>A material the game has too, with the game's ID and its one usage flag.</summary>
    private static ExportEntry SharedMaterial(IMEPackage package, Guid? copyId = null)
    {
        var material = WithGraph(Fixtures.Material(package, "Mat", copyId ?? GameId));
        material.WriteProperty(new BoolProperty(true, "bUsedWithSkeletalMesh"));
        return material;
    }

    private static VanillaMaterialInfo? GameCopy(ExportEntry material) =>
        material.ObjectName.Instanced == "Mat" ? new VanillaMaterialInfo(GameId, ["bUsedWithSkeletalMesh"]) : null;

    /// <summary>A static mesh component with a lightmap and these Materials overrides (null leaves a slot to the mesh).</summary>
    private static ExportEntry LightmappedComponent(IMEPackage package, string name, params IEntry?[] materials)
    {
        var component = package.CreateExport(name, "StaticMeshComponent", indexed: false);
        component.WriteProperty(new ArrayProperty<ObjectProperty>(materials.Select(m => new ObjectProperty(m?.UIndex ?? 0)).ToList(), "Materials"));
        var binary = StaticMeshComponent.Create();
        binary.LODData =
        [
            new StaticMeshComponentLODInfo
            {
                ShadowMaps = [], ShadowVertexBuffers = [],
                LightMap = new LightMap_2D { LightMapType = ELightMapType.LMT_2D, LightGuids = [] }
            }
        ];
        component.WriteBinary(binary);
        return component;
    }

    [TestMethod]
    public void MaterialTheGameHasTooIsLeftAloneAndLightmappedSlotsMoveToAUsageVariant()
    {
        using var package = Fixtures.Package("Shared");
        var material = SharedMaterial(package);
        var component = LightmappedComponent(package, "Comp", null, material);

        var plan = Plan(GameCopy, package);

        Assert.IsTrue(plan.CanInstall, string.Join("\n", plan.Errors));
        var m = plan.Materials.Single();
        Assert.IsTrue(m.SharedWithGame);
        Assert.AreEqual(0, m.FlagsToSet.Count, "the game's copies cannot get the flag, so the mod's must not either");
        Assert.IsNull(m.NewResourceId, "the game's instances are keyed to the game's ID");
        Assert.AreEqual(GameId, m.LiveResourceId);
        Assert.IsFalse(m.Compile);
        Assert.IsFalse(m.Rewrite);

        var variant = plan.Variants.Single();
        StringAssert.StartsWith(variant.Identity, "MilanMaterialVariants.Mat_MU");
        Assert.AreEqual(m.Identity, variant.SourceIdentity);
        Assert.AreEqual(0, variant.Swaps.Count);
        CollectionAssert.AreEqual(new[] { "bUsedWithStaticLighting", "bUsedWithVectorLightMaps" }, variant.UsageFlags!.ToArray());
        Assert.AreNotEqual(GameId, variant.ResourceId);
        CollectionAssert.AreEqual(new[] { "Shared.pcc" }, variant.Packages.ToArray());

        var slot = plan.SlotRetargets.Single();
        Assert.AreEqual(component.UIndex, slot.ComponentUIndex);
        Assert.AreEqual(1, slot.Slot);
        Assert.AreEqual(variant.Identity, slot.TargetIdentity);
        Assert.IsFalse(plan.Reports.Any(r => r.Contains("lacks", StringComparison.Ordinal)), string.Join("\n", plan.Reports));
        Assert.AreEqual(plan.Describe(), Plan(GameCopy, package).Describe(), "the plan must be deterministic");
    }

    [TestMethod]
    public void LightmappedSlotDrawingAnInstanceOfASharedMaterialGetsAClonedChain()
    {
        using var package = Fixtures.Package("SharedChain");
        var material = SharedMaterial(package);
        var instance = Fixtures.Instance(package, "Inst", material);
        LightmappedComponent(package, "Comp", instance);

        var plan = Plan(GameCopy, package);

        Assert.IsTrue(plan.CanInstall, string.Join("\n", plan.Errors));
        var variant = plan.Variants.Single();
        var clone = plan.ChainClones.Single();
        Assert.AreEqual(instance.MemoryFullPath, clone.SourceIdentity);
        Assert.AreEqual(variant.Identity, clone.ParentIdentity);
        Assert.AreEqual(clone.Identity, plan.SlotRetargets.Single().TargetIdentity);
        Assert.IsNull(plan.Instances.Single().RetargetParentTo, "the instance itself still draws the game's material for its other users");
    }

    [TestMethod]
    public void CopiesThatDriftedFromTheGamesGoBackToItsIdAndFlags()
    {
        // What an earlier install left behind: the copy re-identified and given the flag.
        using var package = Fixtures.Package("Drifted");
        var material = SharedMaterial(package, new Guid("bbbbbbbb-2222-3333-4444-555555555555"));
        material.WriteProperty(new BoolProperty(true, "bUsedWithVectorLightMaps"));

        var plan = Plan(GameCopy, package);

        Assert.IsTrue(plan.CanInstall, string.Join("\n", plan.Errors));
        var m = plan.Materials.Single();
        Assert.AreEqual(GameId, m.ResourceId);
        Assert.IsNull(m.NewResourceId);
        Assert.IsTrue(m.Rewrite, "its resource carries the wrong ID");
        Assert.IsFalse(m.Compile, "the game's shader map is the one it uses");
        CollectionAssert.AreEqual(new[] { "bUsedWithVectorLightMaps" }, m.FlagsToClear!.ToArray());
        Assert.AreEqual(0, plan.Variants.Count);
    }

    [TestMethod]
    public void UsesThatCannotMoveToAVariantAreReportedAndTheSharedMaterialStays()
    {
        using var package = Fixtures.Package("SharedParticle");
        var material = SharedMaterial(package);
        var decal = package.CreateExport("Decal", "DecalComponent", indexed: false);
        decal.WriteProperty(new ObjectProperty(material.UIndex, "DecalMaterial"));

        var plan = Plan(GameCopy, package);

        Assert.IsTrue(plan.CanInstall, string.Join("\n", plan.Errors));
        Assert.AreEqual(0, plan.Materials.Single().FlagsToSet.Count);
        Assert.AreEqual(0, plan.Variants.Count);
        StringAssert.Contains(plan.Reports.Single(r => r.Contains("lacks", StringComparison.Ordinal)), "bUsedWithDecals");
    }

    [TestMethod]
    public void SlotRetargetPadsTheOverridesAndKeepsTheOtherSlots()
    {
        using var package = Fixtures.Package("Slots");
        var other = Fixtures.Material(package, "Other");
        var component = LightmappedComponent(package, "Comp", other);
        var root = ExportCreator.CreatePackageExport(package, OfflineShaderInstaller.VariantRoot, forcedExport: true);
        var target = package.CreateExport("Mat_MU01234567", "Material", root, indexed: false);

        OfflineShaderInstaller.RetargetSlot(new MeshSlotRetargetPlan("Slots.pcc", component.UIndex, component.InstancedFullPath, 2,
            target.MemoryFullPath), package);

        var overrides = component.GetProperty<ArrayProperty<ObjectProperty>>("Materials")!.Select(o => o.Value).ToArray();
        CollectionAssert.AreEqual(new[] { other.UIndex, 0, target.UIndex }, overrides);
        Assert.ThrowsException<ShaderInstallException>(() => OfflineShaderInstaller.RetargetSlot(
            new MeshSlotRetargetPlan("Slots.pcc", component.UIndex, "Somewhere.Else", 0, target.MemoryFullPath), package));
    }

    private static (IMEPackage Package, ExportEntry Parent, ExportEntry Bc5) NormalSetup(string name)
    {
        var package = Fixtures.Package(name);
        var parent = Fixtures.Material(package, "Parent", new Guid("11111111-2222-3333-4444-555555555555"));
        Fixtures.Parameter(parent, "Blend_Normal", Fixtures.Texture(package, "DefaultNorm", "TC_NormalmapBC7"));
        return (package, parent, Fixtures.Texture(package, "OverrideNorm", "TC_NormalmapBC5"));
    }

    [TestMethod]
    public void UsageAddsFlagsAndGivesTheMaterialADeterministicNewId()
    {
        using var package = Fixtures.Package("Usage");
        var material = WithGraph(Fixtures.Material(package, "Mat"));
        var component = package.CreateExport("SkelComp", "SkeletalMeshComponent", indexed: false);
        component.WriteProperty(new ArrayProperty<ObjectProperty>([new ObjectProperty(material.UIndex)], "Materials"));

        var plan = Plan(package);

        var m = plan.Materials.Single();
        CollectionAssert.AreEqual(new[] { "bUsedWithSkeletalMesh" }, m.FlagsToSet.ToArray());
        Assert.IsNotNull(m.NewResourceId);
        Assert.AreEqual(m.NewResourceId, Plan(package).Materials.Single().NewResourceId, "new IDs must be deterministic");
        Assert.IsTrue(m.Compile);
        Assert.IsTrue(plan.CanInstall, string.Join("\n", plan.Errors));
    }

    [TestMethod]
    public void EditedGraphIsRecompiledUnderANewIdEvenWhenTheGamesCacheHasItsOldId()
    {
        using var package = Fixtures.Package("EditedGraph");
        var material = WithGraph(Fixtures.Material(package, "Mat"));

        ShaderInstallPlan PlanWith(Func<string, bool>? force)
        {
            using var metadata = new PackageTextureMetadataProvider();
            var planner = new ShaderInstallPlanner(new ShaderInstallPlannerOptions
            {
                ModPackagePaths = [package.FilePath],
                ResolveImport = _ => null,
                TextureMetadata = metadata,
                KeysInRefShaderCache = keys => keys.ToHashSet(), // the game already has a map under every ID
                ForceRecompile = force
            });
            planner.AddPackage(package);
            return planner.Build();
        }

        var untouched = PlanWith(null).Materials.Single();
        Assert.IsFalse(untouched.Compile, "a map under the material's ID in the RefShaderCache is reused");
        Assert.IsNull(untouched.NewResourceId);

        var forced = PlanWith(identity => identity.EndsWith("Mat", StringComparison.Ordinal)).Materials.Single();
        Assert.IsTrue(forced.Compile, "the edited graph needs its own shaders");
        Assert.IsNotNull(forced.NewResourceId);
        Assert.AreNotEqual(untouched.ResourceId, forced.NewResourceId);
        Assert.AreEqual(forced.NewResourceId, PlanWith(identity => true).Materials.Single().NewResourceId, "new IDs must be deterministic");
        Assert.IsNotNull(material);
    }

    [TestMethod]
    public void MismatchedOverrideGetsAParentVariantAndIsRetargeted()
    {
        var (package, parent, bc5) = NormalSetup("Variant");
        using var _ = package;
        var instance = Fixtures.Instance(package, "Inst", parent, ("Blend_Normal", bc5));
        Fixtures.StaticNormal(instance, "Other", 1); // gives it a permutation, so it carries a key

        var plan = Plan(package);

        var variant = plan.Variants.Single();
        StringAssert.StartsWith(variant.Identity, "MilanMaterialVariants.Parent_MV");
        Assert.AreEqual("TC_NormalmapBC5", variant.Swaps.Single().Metadata.CompressionSettings);
        var inst = plan.Instances.Single();
        Assert.AreEqual(variant.Identity, inst.RetargetParentTo);
        Assert.AreEqual(variant.ResourceId, inst.Key!.BaseMaterialId, "the permutation is keyed to the variant");
        Assert.IsTrue(inst.Compile);
        CollectionAssert.AreEqual(new[] { "Variant.pcc" }, variant.Packages.ToArray());
    }

    [TestMethod]
    public void OverrideBelowAnIntermediateInstanceClonesTheChain()
    {
        var (package, parent, bc5) = NormalSetup("Chain");
        using var _ = package;
        var mid = Fixtures.Instance(package, "Mid", parent);
        var leaf = Fixtures.Instance(package, "Leaf", mid, ("Blend_Normal", bc5));

        var plan = Plan(package);

        var variant = plan.Variants.Single();
        var clone = plan.ChainClones.Single();
        Assert.AreEqual(mid.MemoryFullPath, clone.SourceIdentity);
        Assert.AreEqual(variant.Identity, clone.ParentIdentity);
        Assert.AreEqual(clone.Identity, plan.Instances.Single(i => i.Identity == leaf.MemoryFullPath).RetargetParentTo);
        Assert.IsNull(plan.Instances.Single(i => i.Identity == mid.MemoryFullPath).RetargetParentTo, "the shared original stays");
    }

    [TestMethod]
    public void StaleStaticNormalIsFixedOnTheInstance()
    {
        using var package = Fixtures.Package("Normals");
        var parent = Fixtures.Material(package, "Parent");
        Fixtures.Parameter(parent, "Base_Normal", Fixtures.Texture(package, "Default", "TC_Normalmap"),
            "MaterialExpressionTextureSampleParameterNormal");
        var instance = Fixtures.Instance(package, "Inst", parent, ("Base_Normal", Fixtures.Texture(package, "Real", "TC_NormalmapBC5")));
        Fixtures.StaticNormal(instance, "Base_Normal", Fixtures.CompressionIndex("TC_Normalmap"));

        var inst = Plan(package).Instances.Single();

        Assert.AreEqual("TC_NormalmapBC5", inst.StaticNormalFixes.Single().CompressionName);
        Assert.AreEqual(Fixtures.CompressionIndex("TC_NormalmapBC5"), inst.Key!.NormalParameters.Single().CompressionSettings);
        Assert.IsNull(inst.RetargetParentTo);
    }

    private static ExportEntry ForcedMaterial(IMEPackage package, float value)
    {
        var root = ExportCreator.CreatePackageExport(package, "Shared");
        var material = package.CreateExport("Mat", "Material", root, indexed: false);
        var binary = LegendaryExplorerCore.Unreal.BinaryConverters.Material.Create();
        binary.SM3MaterialResource.ID = new Guid("99999999-2222-3333-4444-555555555555");
        material.WriteBinary(binary);
        material.WriteProperty(new FloatProperty(value, "OpacityMaskClipValue"));
        return WithGraph(material);
    }

    /// <summary>One expression, so the planner sees a compilable graph.</summary>
    private static ExportEntry WithGraph(ExportEntry material)
    {
        var expression = material.FileRef.CreateExport("MaterialExpressionConstant", "MaterialExpressionConstant", material, indexed: true);
        material.WriteProperty(new ArrayProperty<ObjectProperty>([new ObjectProperty(expression.UIndex)], "Expressions"));
        return material;
    }

    [TestMethod]
    public void IdenticalForcedCopiesAreOneObjectAndDifferingCopiesFail()
    {
        using var a = Fixtures.Package("CopyA");
        using var b = Fixtures.Package("CopyB");
        ForcedMaterial(a, 0.5f);
        var other = ForcedMaterial(b, 0.5f);

        var plan = Plan(a, b);
        var m = plan.Materials.Single();
        Assert.AreEqual("Shared.Mat", m.Identity);
        CollectionAssert.AreEqual(new[] { "CopyA.pcc", "CopyB.pcc" }, m.Packages.ToArray());
        Assert.IsTrue(plan.CanInstall, string.Join("\n", plan.Errors));

        other.WriteProperty(new FloatProperty(0.25f, "OpacityMaskClipValue"));
        var broken = Plan(a, b);
        Assert.IsFalse(broken.CanInstall);
        StringAssert.Contains(broken.Errors.Single(), "Shared.Mat");
    }

    [TestMethod]
    public void CopiesDifferingOnlyInScalarValuesAreReportedNotFailed()
    {
        using var a = Fixtures.Package("ScalarA");
        using var b = Fixtures.Package("ScalarB");
        ForcedMaterial(a, 0.5f);
        var other = ForcedMaterial(b, 0.5f);
        other.WriteProperty(new ArrayProperty<StructProperty>([new StructProperty("ScalarParameterValue",
            [new NameProperty("Glow", "ParameterName"), new FloatProperty(2f, "ParameterValue")])], "ScalarParameterValues"));

        var plan = Plan(a, b);
        Assert.IsTrue(plan.CanInstall, string.Join("\n", plan.Errors));
        StringAssert.Contains(plan.Reports.Single(r => r.StartsWith("copies of", StringComparison.Ordinal)), "Shared.Mat");
    }

    [TestMethod]
    public void EmptyMaterialsAreToldApartFromStrippedOnes()
    {
        using var package = Fixtures.Package("Empty");
        // MPLobby.Black: nothing connected.
        var empty = Fixtures.Material(package, "Black");
        empty.WriteProperty(new StructProperty("ColorMaterialInput", [new ObjectProperty(0, "Expression")], "DiffuseColor"));
        Assert.IsTrue(MaterialChain.IsEmptyByDesign(empty));

        // EngineMaterials.DefaultParticle: cooking nulled the Expression but kept the input's masks.
        var stripped = Fixtures.Material(package, "Stripped");
        stripped.WriteProperty(new StructProperty("ColorMaterialInput",
            [new ObjectProperty(0, "Expression"), new IntProperty(1, "Mask"), new IntProperty(1, "MaskR")], "DiffuseColor"));
        Assert.IsFalse(MaterialChain.IsEmptyByDesign(stripped));

        Assert.IsFalse(MaterialChain.IsEmptyByDesign(WithGraph(Fixtures.Material(package, "Graph"))));
    }

    [TestMethod]
    public void MaterialsWhoseShippedCompileWasEmptyCompileAsAuthored()
    {
        using var package = Fixtures.Package("ShipsEmpty");
        // FakeTurian_01: stripped expressions left behind, nothing connected, and the shipped resource reads nothing.
        var shippedEmpty = WithGraph(Fixtures.Material(package, "FakeTurian"));
        shippedEmpty.WriteProperty(new StructProperty("ColorMaterialInput", [new ObjectProperty(0, "Expression")], "EmissiveColor"));
        Assert.IsTrue(MaterialChain.ShipsEmpty(shippedEmpty));

        // A stripped copy whose shipped compile read something is not empty, connected inputs or not.
        var sampled = Fixtures.Material(package, "Sampled");
        var binary = ObjectBinary.From<Material>(sampled);
        binary.SM3MaterialResource.bUsesVertexColor = true;
        sampled.WriteBinary(binary);
        Assert.IsFalse(MaterialChain.ShipsEmpty(sampled));

        // MPLondon_Sky_MM: cooking nulled EmissiveColor and kept no mask, so it looks authored empty; only its shipped
        // resource (which samples the sky) and its decooked graph say otherwise. Hence ShipsEmpty, not IsEmptyByDesign,
        // is checked before the decooked graph.
        sampled.WriteProperty(new StructProperty("ColorMaterialInput", [new ObjectProperty(0, "Expression")], "EmissiveColor"));
        Assert.IsTrue(MaterialChain.IsEmptyByDesign(sampled));

        var connected = WithGraph(Fixtures.Material(package, "Connected"));
        connected.WriteProperty(new StructProperty("ColorMaterialInput",
            [new ObjectProperty(connected.GetProperty<ArrayProperty<ObjectProperty>>("Expressions")![0].Value, "Expression")], "EmissiveColor"));
        Assert.IsFalse(MaterialChain.ShipsEmpty(connected));
    }

    [TestMethod]
    public void VariantCopiesAreExportsEvenWhereTheOriginalIsImported()
    {
        // Shield_Imp_Mat's variant goes into kit packages whose instances import the original material.
        using var source = Fixtures.Package("SourceFile");
        // Seekfree layout: the original package is a root export, so the path matches the kit's import.
        var group = source.CreateExport("Materials", "Package", source.CreateExport("BioVFX_C_Shield", "Package", indexed: false), indexed: false);
        var original = WithGraph(Fixtures.Material(source, "Shield_Imp_Mat"));
        original.idxLink = group.UIndex;

        using var kit = Fixtures.Package("Kit");
        var importRoot = new ImportEntry(kit, 0, "BioVFX_C_Shield") { ClassName = "Package", PackageFile = "Core" };
        kit.AddImport(importRoot);
        var importGroup = new ImportEntry(kit, importRoot.UIndex, "Materials") { ClassName = "Package", PackageFile = "Core" };
        kit.AddImport(importGroup);
        var imported = new ImportEntry(kit, importGroup.UIndex, "Shield_Imp_Mat") { ClassName = "Material", PackageFile = "Engine" };
        kit.AddImport(imported);
        var instance = Fixtures.Instance(kit, "Shield_INST", imported);
        var root = kit.CreateExport("MilanMaterialVariants", "Package", indexed: false);

        var copy = OfflineShaderInstaller.PortCopy(original, kit, root,
            new LegendaryExplorerCore.Packages.CloningImportingAndRelinking.RelinkerOptionsPackage { PortExportsAsImportsWhenPossible = true });

        Assert.AreEqual(root, copy.Parent);
        Assert.AreEqual(1, kit.Exports.Count(e => e.Parent == copy), "the graph is copied with it");
        Assert.AreEqual("BioVFX_C_Shield.Materials.Shield_Imp_Mat", imported.InstancedFullPath, "the import keeps its name");
        Assert.AreEqual(imported.UIndex, instance.GetProperty<ObjectProperty>("Parent")!.Value);
    }

    [TestMethod]
    public void PlansAreDeterministic()
    {
        var (package, parent, bc5) = NormalSetup("Determinism");
        using var _ = package;
        Fixtures.Instance(package, "Leaf", Fixtures.Instance(package, "Mid", parent), ("Blend_Normal", bc5));

        Assert.AreEqual(Plan(package).Describe(), Plan(package).Describe());
    }
}
