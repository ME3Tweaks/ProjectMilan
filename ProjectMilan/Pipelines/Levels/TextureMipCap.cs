using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels
{
    /// <summary>
    /// Caps a ported texture at the resolution ME3 actually drew it at, by dropping its larger mips.
    /// </summary>
    /// <remarks>
    /// Porting swaps in LE3's remastered copy of a texture when one exists. That is usually what we want, but some ME3
    /// materials were tuned against a texture BioWare shipped tiny: BioT_Thessia.Env_Textures.Gravel_Norm in
    /// BioA_MPThes_110 only had mips up to 32x32 stored in ME3, and BioT_MPThes.Waving_Flag2 sums two stretched copies of
    /// it and multiplies the normal's XY by 5. On LE3's 2048x2048 copy that turns the banners into dark streaks.
    /// Each level package carries its own copy of the texture export, so a cap here only affects that level.
    /// </remarks>
    internal static class TextureMipCap
    {
        /// <summary>
        /// Drops every mip of <paramref name="texturePath"/> in <paramref name="package"/> larger than
        /// <paramref name="maxSize"/> in either dimension, along with any empty mip entries.
        /// </summary>
        /// <returns>True if the texture was found and changed.</returns>
        public static bool Apply(IMEPackage package, string texturePath, int maxSize, string logCategory)
        {
            var texture = package.FindExport(texturePath, "Texture2D");
            if (texture == null)
                return false;

            var bin = ObjectBinary.From<UTexture2D>(texture);
            var originalTop = bin.Mips.FirstOrDefault(x => x.StorageType != StorageTypes.empty);
            if (bin.Mips.RemoveAll(x => x.StorageType == StorageTypes.empty || x.SizeX > maxSize || x.SizeY > maxSize) == 0)
                return false;
            if (bin.Mips.Count == 0)
                throw new InvalidOperationException($"{texturePath} in {package.FileNameNoExtension} has no mips at or below {maxSize}");

            var top = bin.Mips[0];
            var props = texture.GetProperties();
            props.AddOrReplaceProp(new IntProperty(top.SizeX, "SizeX"));
            props.AddOrReplaceProp(new IntProperty(top.SizeY, "SizeY"));
            props.AddOrReplaceProp(new IntProperty(top.SizeX, "OriginalSizeX"));
            props.AddOrReplaceProp(new IntProperty(top.SizeY, "OriginalSizeY"));
            props.AddOrReplaceProp(new IntProperty(bin.Mips.Count - 1, "MipTailBaseIdx"));

            if (bin.Mips.All(x => x.StorageType == StorageTypes.pccUnc))
            {
                // Nothing left to stream: keep it package resident like vanilla package-stored textures, which carry no TFC
                // reference. MoveTexturesToTFC skips NeverStream textures, so the TFC build leaves it alone too.
                props.AddOrReplaceProp(new BoolProperty(true, "NeverStream"));
                props.RemoveNamedProperty("TextureFileCacheName");
                props.RemoveNamedProperty("TFCFileGuid");
                props.RemoveNamedProperty("TFCFileGuidHiRes");
            }

            texture.WriteProperties(props);
            texture.WriteBinary(bin);
            MilanLog.Information($"Capped {texturePath} in {package.FileNameNoExtension} at {top.SizeX}x{top.SizeY} (was {originalTop?.SizeX}x{originalTop?.SizeY})", customPrefix: logCategory);
            return true;
        }
    }
}
