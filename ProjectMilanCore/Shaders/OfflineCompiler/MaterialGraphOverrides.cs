using System.Security.Cryptography;
using System.Text;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// Mod-owned materials whose decooked graph is edited on purpose, so shaders built from the original graph (including
/// any filed under the same resource ID in the game's RefShaderCache) are wrong for them and they must be recompiled.
/// <para>
/// The edit: full-screen overlay materials (Geth Vision, Repair Matrix, Devastator mode, Blood Lust, biotic focus) sample
/// their mask and pattern textures with the screen-aligned ScreenPosition, which LE builds from the scene render target
/// buffer. That buffer only ever grows, so after a larger menu render target it is bigger than the view and the masks are
/// stretched and shifted. The edited graphs derive the UV from the clip-space position instead (xy / w * (0.5, -0.5) + 0.5),
/// which depends on the view alone. The scene lookups keep the aligned position, which is correct for them.
/// </para>
/// <para>
/// Overlays also get Milan_ tuning parameters, added in code when their decooked graph is opened, for
/// SFXGameContent_MilanBase.MilanScreenOverlaySettings to set on their instances at runtime. The effects animate their own
/// parameters (Krogan rage's framebuffer modules rewrite Intensity every frame), so tuning needs parameters nothing else
/// writes. Each defaults to the authored look.
/// </para>
/// Materials the game has too (for example <c>mat_BioticsMode</c>) must stay identical to the game's and are never listed.
/// </summary>
public static class MaterialGraphOverrides
{
    private const string TuningPrefix = "Milan_";

    private static readonly HashSet<string> ViewNormalizedUvMaterials = new(StringComparer.OrdinalIgnoreCase)
    {
        "Geth_Vision_post_Mat",
        "Geth_Vision_post_Mat_MP5_",
        "RepairMatrix_Particle_Mat",
        "BloodLust_FB_Mat",
        "Devastator_Particle_Mat",
        "BioticFocus_FB_Particle_Mat"
    };

    private static readonly Dictionary<string, Action<ExportEntry>> TuningParameters = new(StringComparer.OrdinalIgnoreCase)
    {
        ["Geth_Vision_post_Mat"] = AddGethVisionParameters,
        ["Geth_Vision_post_Mat_MP5_"] = AddGethVisionParameters,
        ["BloodLust_FB_Mat"] = AddStrengthParameter,
        ["RepairMatrix_Particle_Mat"] = AddStrengthParameter,
        ["KroganBerserk_FB_Mat"] = AddKroganRageParameters,
        ["SLUM_ACID_ASPHALT"] = AddTransitionDiffuseTint
    };

    /// <summary>True when the material at <paramref name="identity"/> (an instanced full path) has an edited graph.</summary>
    public static bool NeedsRecompile(string identity)
    {
        string name = identity[(identity.LastIndexOf('.') + 1)..];
        return ViewNormalizedUvMaterials.Contains(name) || TuningParameters.ContainsKey(name);
    }

    /// <summary>Adds the tuning parameters to every listed material in a decooked package. In memory only; never saved.</summary>
    public static void AddTuningParameters(IMEPackage decooked)
    {
        lock (decooked)
        {
            foreach (var material in decooked.Exports.Where(e => e.ClassName == "Material").ToList())
            {
                if (!TuningParameters.TryGetValue(material.ObjectName.Instanced, out var add)) continue;
                // A package shared between callers is only edited once.
                if (decooked.Exports.Any(e => e.idxLink == material.UIndex && e.ObjectName.Name.StartsWith(TuningPrefix, StringComparison.Ordinal))) continue;
                add(material);
            }
        }
    }

    // Additive scene copy (about 1.7x the scene) and the chromatic aberration: green and blue read the scene at UVs scaled
    // by 0.99 and 0.98 (blue also jittered by a flipbook), red at the screen position. Milan_Aberration blends both toward
    // red's UV, so 0 removes the fringes. Brightness overall is the particle alpha, which the emitter's MaxOutput sets.
    private static void AddGethVisionParameters(ExportEntry material)
    {
        var red = Expression(material, "MaterialExpressionSceneTexture_4");
        BlendInputToward(material, Expression(material, "MaterialExpressionSceneTexture_1"), "Coordinates", red, "Coordinates", "Milan_Aberration");
        BlendInputToward(material, Expression(material, "MaterialExpressionSceneTexture_3"), "Coordinates", red, "Coordinates", "Milan_Aberration");
        ScaleInput(material, Expression(material, "MaterialExpressionAdd_0"), "B", "Milan_SceneAdd");
    }

    // The Rain_Valve=1 branch samples raw diffuse while Rain_Valve=0 applies Diff_tint. The skycar's diffuse is a
    // magenta/blue paint stack, so it must keep its red tint through the transition. Other instances default to 0
    private static void AddTransitionDiffuseTint(ExportEntry material)
    {
        var branch = Expression(material, "MaterialExpressionAdd_28");
        var tinted = Expression(material, "MaterialExpressionAdd_33");
        var blend = Node(material, "Milan_KeepDiffuseTint_Blend", "MaterialExpressionLinearInterpolate",
            AsExpressionInput(Input(branch, "A"), "A"), AsExpressionInput(Input(tinted, "B"), "B"),
            Link(Parameter(material, "Milan_KeepDiffuseTint", 0f), "Alpha"));
        SetInput(branch, "A", blend);
    }

    private static void AddStrengthParameter(ExportEntry material) => ScaleInput(material, material, "EmissiveColor", "Milan_Strength");

    // The final blend lerp(scene, effect, Intensity) runs on 5 * (blurred scene + veins + 0.015)^2, which blows out bright
    // scenes. The framebuffer modules animate Intensity, so Milan_Strength scales it, and Milan_Gain replaces the 5.
    private static void AddKroganRageParameters(ExportEntry material)
    {
        ScaleInput(material, Expression(material, "MaterialExpressionLinearInterpolate_1"), "Alpha", "Milan_Strength");
        SetInput(Expression(material, "MaterialExpressionMultiply_15"), "B", Parameter(material, "Milan_Gain", 5f));
    }

    private static ExportEntry Expression(ExportEntry material, string name) =>
        material.FileRef.FindExport(material.InstancedFullPath + "." + name)
        ?? throw new InvalidOperationException($"{material.InstancedFullPath} has no {name} to add tuning parameters to; update {nameof(MaterialGraphOverrides)}");

    /// <summary>Replaces <paramref name="owner"/>'s input with input * a new parameter (default 1).</summary>
    private static void ScaleInput(ExportEntry material, ExportEntry owner, string input, string parameterName)
    {
        var multiply = Node(material, $"{parameterName}_{owner.ObjectName.Instanced}_{input}", "MaterialExpressionMultiply",
            AsExpressionInput(Input(owner, input), "A"), Link(Parameter(material, parameterName, 1f), "B"));
        SetInput(owner, input, multiply);
    }

    /// <summary>Replaces <paramref name="owner"/>'s input with lerp(toward's input, input, a parameter that defaults to 1).</summary>
    private static void BlendInputToward(ExportEntry material, ExportEntry owner, string input, ExportEntry toward, string towardInput, string parameterName)
    {
        var lerp = Node(material, $"{parameterName}_{owner.ObjectName.Instanced}_{input}", "MaterialExpressionLinearInterpolate",
            AsExpressionInput(Input(toward, towardInput), "A"), AsExpressionInput(Input(owner, input), "B"),
            Link(Parameter(material, parameterName, 1f), "Alpha"));
        SetInput(owner, input, lerp);
    }

    private static StructProperty Input(ExportEntry owner, string input) =>
        owner.GetProperty<StructProperty>(input) is { } s && s.GetProp<ObjectProperty>("Expression") is { Value: > 0 } ? s
            : throw new InvalidOperationException($"{owner.InstancedFullPath}.{input} is not connected; update {nameof(MaterialGraphOverrides)}");

    /// <summary>Points the input at <paramref name="expression"/>, keeping its struct type and dropping its mask.</summary>
    private static void SetInput(ExportEntry owner, string input, ExportEntry expression)
    {
        var props = owner.GetProperties();
        var original = props.GetProp<StructProperty>(input);
        var fields = new PropertyCollection { new ObjectProperty(expression, "Expression") };
        foreach (var field in original?.Properties ?? [])
        {
            if (field.Name.Name != "Expression" && !field.Name.Name.StartsWith("Mask", StringComparison.Ordinal)) fields.Add(field);
        }
        props.AddOrReplaceProp(new StructProperty(original?.StructType ?? "ExpressionInput", fields, input));
        owner.WriteProperties(props);
    }

    /// <summary>An expression input to the same expression and mask as <paramref name="original"/>.</summary>
    private static StructProperty AsExpressionInput(StructProperty original, string name)
    {
        var fields = new PropertyCollection();
        fields.AddRange(original.Properties.Where(f => f.Name.Name == "Expression" || f.Name.Name.StartsWith("Mask", StringComparison.Ordinal)));
        return new StructProperty("ExpressionInput", fields, name);
    }

    private static StructProperty Link(ExportEntry expression, string name) =>
        new("ExpressionInput", new PropertyCollection { new ObjectProperty(expression, "Expression") }, name);

    /// <summary>The material's scalar parameter of this name, created on first use.</summary>
    private static ExportEntry Parameter(ExportEntry material, string parameterName, float defaultValue)
    {
        if (material.FileRef.FindExport(material.InstancedFullPath + "." + parameterName) is { } existing) return existing;
        var hash = MD5.HashData(Encoding.UTF8.GetBytes(material.InstancedFullPath.ToLowerInvariant() + "." + parameterName));
        var guid = new PropertyCollection();
        for (int i = 0; i < 4; i++) guid.Add(new IntProperty(BitConverter.ToInt32(hash, i * 4), ((char)('A' + i)).ToString()));
        return Node(material, parameterName, "MaterialExpressionScalarParameter",
            new FloatProperty(defaultValue, "DefaultValue"), new StructProperty("Guid", guid, "ExpressionGUID", true),
            new NameProperty(parameterName, "ParameterName"));
    }

    private static ExportEntry Node(ExportEntry material, string name, string className, params Property[] properties)
    {
        var node = material.FileRef.CreateExport(name, className, material, indexed: false);
        var nodeProps = new PropertyCollection();
        nodeProps.AddRange(properties);
        node.WriteProperties(nodeProps);
        var props = material.GetProperties();
        props.GetProp<ArrayProperty<ObjectProperty>>("Expressions").Add(new ObjectProperty(node));
        material.WriteProperties(props);
        return node;
    }
}
