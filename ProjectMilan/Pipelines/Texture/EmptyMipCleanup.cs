using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Pipelines.Texture;

/// <summary>Removes cooked-out mip placeholders independently of whether a texture can be externalized.</summary>
internal static class EmptyMipCleanup
{
    private static readonly string[] CubeFaceProperties = ["FacePosX", "FaceNegX", "FacePosY", "FaceNegY", "FacePosZ", "FaceNegZ"];

    public static (int Textures, int Mips) Apply(IMEPackage package, Action<string>? report = null)
    {
        var changes = new Dictionary<int, (ExportEntry Export, UTexture2D Binary, int Removed)>();
        foreach (var texture in package.Exports.Where(x => x.IsTexture() && !x.IsDefaultObject))
        {
            // Use ObjectBinary.From so subclass data (e.g. LightMapFlags) survives serialization.
            var binary = (UTexture2D)ObjectBinary.From(texture);
            int firstData = binary.Mips.FindIndex(x => x.StorageType != StorageTypes.empty);
            int lastData = binary.Mips.FindLastIndex(x => x.StorageType != StorageTypes.empty);
            if (firstData >= 0 && binary.Mips.Skip(firstData).Take(lastData - firstData + 1).Any(x => x.StorageType == StorageTypes.empty))
                throw new InvalidDataException($"Cannot collapse an interior empty mip in {texture.InstancedFullPath} in {package.FileNameNoExtension}.");
            int removed = binary.Mips.RemoveAll(x => x.StorageType == StorageTypes.empty);
            if (removed == 0)
                continue;
            if (binary.Mips.Count == 0)
                throw new InvalidDataException($"Cannot remove every mip from {texture.InstancedFullPath} in {package.FileNameNoExtension}.");

            // Removing an interior hole must not shift a smaller image into the wrong mip level.
            int width = binary.Mips[0].SizeX, height = binary.Mips[0].SizeY;
            for (int i = 0; i < binary.Mips.Count; i++)
            {
                var mip = binary.Mips[i];
                // Cooked block-compressed tails may serialize 2x2 and 1x1 as 4x4 (as Texture2D's
                // mip reader handles too). Validate logical halving without rewriting those payloads.
                if (width <= 0 || height <= 0 ||
                    (mip.SizeX != width && mip.SizeX != Math.Max(4, width)) ||
                    (mip.SizeY != height && mip.SizeY != Math.Max(4, height)) ||
                    (width == 1 && height == 1 && i != binary.Mips.Count - 1))
                    throw new InvalidDataException($"Empty mip cleanup would leave a discontinuous chain in {texture.InstancedFullPath} in {package.FileNameNoExtension}: {string.Join(",", binary.Mips.Select(x => $"{x.SizeX}x{x.SizeY}"))}.");
                width = Math.Max(1, width / 2);
                height = Math.Max(1, height / 2);
            }
            changes.Add(texture.UIndex, (texture, binary, removed));
        }

        // LE3 UTextureCube::Validate (11.3.2, 0x7ff74ac54640) requires six square faces with
        // matching format, dimensions and mip count; it does not require a fixed number of mips.
        // Check the planned chains before writing any exports, including shared faces.
        var cubes = new List<(ExportEntry Export, UTexture2D Face)>();
        foreach (var cube in package.Exports.Where(x => x.ClassName == "TextureCube" && !x.IsDefaultObject))
        {
            var indices = CubeFaceProperties.Select(name => cube.GetProperty<ObjectProperty>(name)?.Value ?? 0).ToArray();
            if (!indices.Any(changes.ContainsKey))
                continue;
            UTexture2D? first = null;
            string? format = null;
            foreach (int index in indices)
            {
                if (index <= 0 || package.GetEntry(index) is not ExportEntry face || !face.IsTexture() || face.IsDefaultObject)
                    throw new InvalidDataException($"Cannot validate all six local faces of {cube.InstancedFullPath} in {package.FileNameNoExtension} before empty mip cleanup.");
                var binary = changes.TryGetValue(index, out var change) ? change.Binary : (UTexture2D)ObjectBinary.From(face);
                string? faceFormat = face.GetProperty<EnumProperty>("Format")?.Value.Name;
                int faceWidth = changes.ContainsKey(index) ? binary.Mips[0].SizeX : face.GetProperty<IntProperty>("SizeX")?.Value ?? 0;
                int faceHeight = changes.ContainsKey(index) ? binary.Mips[0].SizeY : face.GetProperty<IntProperty>("SizeY")?.Value ?? 0;
                if (binary.Mips.Count == 0 || faceFormat == null || faceWidth != faceHeight || faceWidth <= 0 ||
                    faceWidth != binary.Mips[0].SizeX || binary.Mips.Any(x => x.SizeX != x.SizeY) ||
                    (first != null && (format != faceFormat || !first.Mips.Select(x => (x.SizeX, x.SizeY))
                        .SequenceEqual(binary.Mips.Select(x => (x.SizeX, x.SizeY))))))
                    throw new InvalidDataException($"Empty mip cleanup would leave incompatible faces in {cube.InstancedFullPath} in {package.FileNameNoExtension}.");
                first ??= binary;
                format ??= faceFormat;
            }
            cubes.Add((cube, first!));
        }

        foreach (var (texture, binary, removed) in changes.Values)
        {
            var props = texture.GetProperties();
            props.AddOrReplaceProp(new IntProperty(binary.Mips[0].SizeX, "SizeX"));
            props.AddOrReplaceProp(new IntProperty(binary.Mips[0].SizeY, "SizeY"));
            var tail = props.GetProp<IntProperty>("MipTailBaseIdx");
            if (tail != null && tail.Value >= 0)
            {
                var original = ((UTexture2D)ObjectBinary.From(texture)).Mips;
                int removedBeforeTail = original.Take(tail.Value).Count(x => x.StorageType == StorageTypes.empty);
                tail.Value = Math.Clamp(tail.Value - removedBeforeTail, 0, binary.Mips.Count - 1);
            }
            texture.WriteProperties(props);
            texture.WriteBinary(binary);
            report?.Invoke($"Removed {removed} empty mip(s) from {texture.InstancedFullPath}; {binary.Mips.Count} remain, top {binary.Mips[0].SizeX}x{binary.Mips[0].SizeY}");
        }
        foreach (var (cube, face) in cubes)
        {
            // PostLoad recalculates these from the faces and LOD settings. Keep the saved metadata coherent too.
            var props = cube.GetProperties();
            props.AddOrReplaceProp(new IntProperty(face.Mips[0].SizeX, "SizeX"));
            props.AddOrReplaceProp(new IntProperty(face.Mips[0].SizeY, "SizeY"));
            props.AddOrReplaceProp(new IntProperty(face.Mips.Count, "NumMips"));
            cube.WriteProperties(props);
        }
        return (changes.Count, changes.Values.Sum(x => x.Removed));
    }
}
