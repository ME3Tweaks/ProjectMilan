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
/// Materials the game has too (for example <c>mat_BioticsMode</c>) must stay identical to the game's and are never listed.
/// </summary>
public static class MaterialGraphOverrides
{
    private static readonly HashSet<string> ViewNormalizedUvMaterials = new(StringComparer.OrdinalIgnoreCase)
    {
        "Geth_Vision_post_Mat",
        "Geth_Vision_post_Mat_MP5_",
        "RepairMatrix_Particle_Mat",
        "BloodLust_FB_Mat",
        "Devastator_Particle_Mat",
        "BioticFocus_FB_Particle_Mat"
    };

    /// <summary>True when the material at <paramref name="identity"/> (an instanced full path) has an edited graph.</summary>
    public static bool NeedsRecompile(string identity) => ViewNormalizedUvMaterials.Contains(identity[(identity.LastIndexOf('.') + 1)..]);
}
