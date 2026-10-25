using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// Links from a material instance toward its base UMaterial.
/// <list type="bullet">
/// <item>An instance links through Parent.</item>
/// <item>An effects user (RvrEffectsMaterialUser) links through m_pParentMaterial, else m_pBaseMaterial: getting its
/// material, compiling its permutation and every parameter lookup all forward there, and it holds no parameter values
/// of its own.</item>
/// <item>Its m_pParentMaterial is a multiplexor (RvrMaterialMultiplexor). Allocation, the permutation compile and the
/// static parameter lookups forward to m_pDefaultMaterial. Getting its material picks an m_lstParents effect material
/// by tag only for a tagged instance context; the permutation cache asks with the effects user as the context, which
/// never matches a tag, so that is the default too.</item>
/// </list>
/// So an instance under an effects user compiles its static permutation against the multiplexor's m_pDefaultMaterial,
/// keyed by that material's ID, exactly as this chain resolves. The effect materials are ordinary Materials.
/// </summary>
public static class MaterialChain
{
    public static bool IsLink(ExportEntry export) => export.IsA("MaterialInstance") || IsEffectsLink(export);

    /// <summary>An effects user or its multiplexor: a link the install cannot clone for a parent variant.</summary>
    public static bool IsEffectsLink(ExportEntry export) => export.ClassName is "RvrEffectsMaterialUser" or "RvrMaterialMultiplexor";

    /// <summary>
    /// True for a material authored with no graph (e.g. MPLobby's all-black Black): no expressions, and no material input
    /// records a connection. Cooking that strips a graph nulls the inputs' Expression and often keeps their masks
    /// (EngineMaterials.DefaultParticle: Mask=1), but not always (MPLondon_Sky_MM's EmissiveColor has none), so this is
    /// only a fallback for a material with no decooked graph; <see cref="ShipsEmpty"/> is the stronger evidence.
    /// </summary>
    public static bool IsEmptyByDesign(ExportEntry material)
    {
        var props = material.GetProperties();
        if (props.GetProp<ArrayProperty<ObjectProperty>>("Expressions") is { Count: > 0 }) return false;
        foreach (var input in props.OfType<StructProperty>().Where(s => s.Properties.GetProp<ObjectProperty>("Expression") != null))
        {
            if (input.Properties.GetProp<ObjectProperty>("Expression")!.Value != 0) return false;
            if (input.Properties.OfType<IntProperty>().Any(p => p.Name.Name.StartsWith("Mask", StringComparison.Ordinal) && p.Value != 0)) return false;
        }
        return true;
    }

    /// <summary>
    /// True for a material that still holds the graph it was authored with. It has expressions, none of them null, and a
    /// material input connected to one. Cooking strips a graph either by
    /// removing expressions and nulling the inputs' Expression (LE3), or by nulling the stripped Expressions entries in
    /// place
    /// </summary>
    public static bool HoldsCompleteGraph(ExportEntry material)
    {
        var props = material.GetProperties();
        if (props.GetProp<ArrayProperty<ObjectProperty>>("Expressions") is not { Count: > 0 } expressions || expressions.Any(e => e.Value == 0)) return false;
        return props.OfType<StructProperty>().Any(s => s.Properties.GetProp<ObjectProperty>("Expression") is { Value: not 0 });
    }

    /// <summary>
    /// True when the game's own compile of this cooked copy was empty: no material input is connected and the shipped
    /// resource reads nothing (no uniform expressions or textures, no texture coordinates, vertex color, dynamic parameter,
    /// scene color or depth, offsets or transforms). BioVFX_MP4_Tur_Jets.Materials.FakeTurian_01 ships this way although
    /// its decooked graph connects EmissiveColor (to samplers without textures). Compiling the decooked graph would not be
    /// what the game shipped, so such a material is compiled as authored.
    /// </summary>
    public static bool ShipsEmpty(ExportEntry material)
    {
        var props = material.GetProperties();
        if (props.OfType<StructProperty>().Any(s => s.Properties.GetProp<ObjectProperty>("Expression") is { Value: not 0 })) return false;
        var r = ObjectBinary.From<Material>(material).SM3MaterialResource;
        return r != null && r.ID != Guid.Empty && r.NumUserTexCoords == 0 && r.UsingTransforms == 0 &&
               r.UniformExpressionTextures is not { Length: > 0 } && r.UniformPixelVectorExpressions is not { Length: > 0 } &&
               r.UniformPixelScalarExpressions is not { Length: > 0 } && r.Uniform2DTextureExpressions is not { Length: > 0 } &&
               r.UniformCubeTextureExpressions is not { Length: > 0 } && !r.bUsesSceneColor && !r.bUsesSceneDepth &&
               !r.bUsesDynamicParameter && !r.bUsesMaterialVertexPositionOffset && !r.bUsesVertexColor;
    }

    /// <summary>The UIndex of the next link toward the base, or 0.</summary>
    public static int NextReference(ExportEntry export)
    {
        if (export.IsA("MaterialInstance")) return export.GetProperty<ObjectProperty>("Parent")?.Value ?? 0;
        var props = export.GetProperties();
        switch (export.ClassName)
        {
            case "RvrEffectsMaterialUser":
                int parent = props.GetProp<ObjectProperty>("m_pParentMaterial")?.Value ?? 0;
                return parent != 0 ? parent : props.GetProp<ObjectProperty>("m_pBaseMaterial")?.Value ?? 0;
            case "RvrMaterialMultiplexor":
                return props.GetProp<ObjectProperty>("m_pDefaultMaterial")?.Value ?? 0;
            default:
                return 0;
        }
    }
}

/// <summary>
/// Path lookups that tolerate a material and a texture sharing one object path (cooked packages contain such pairs, e.g.
/// BioApl_Veh_AlliFighterA.AlliFighterA_Text), which a plain FindExport/FindEntry resolves to whichever comes first.
/// </summary>
public static class PathLookup
{
    public static bool IsMaterialObject(IEntry entry) =>
        entry.ClassName.Contains("Material", StringComparison.Ordinal) || entry.ClassName == "RvrMaterialMultiplexor";

    public static bool IsTexture(IEntry entry) => entry.ClassName.Contains("Texture", StringComparison.Ordinal);

    public static ExportEntry? FindExport(IMEPackage package, string path, Func<IEntry, bool> accept)
    {
        var first = package.FindExport(path);
        if (first == null || accept(first)) return first;
        return package.Exports.FirstOrDefault(e => accept(e) && string.Equals(e.InstancedFullPath, path, StringComparison.OrdinalIgnoreCase));
    }

    public static IEntry? FindEntry(IMEPackage package, string path, Func<IEntry, bool> accept)
    {
        var first = package.FindEntry(path);
        if (first == null || accept(first)) return first;
        return package.Exports.Cast<IEntry>().Concat(package.Imports)
            .FirstOrDefault(e => accept(e) && string.Equals(e.InstancedFullPath, path, StringComparison.OrdinalIgnoreCase));
    }
}
