using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilan.Pipelines.Texture;

/// <summary>
/// Cleans up empty mips
/// </summary>
internal static class EmptyMipCleanup
{
    private static readonly string[] CubeFaceProperties = ["FacePosX", "FaceNegX", "FacePosY", "FaceNegY", "FacePosZ", "FaceNegZ"];

    private sealed class TextureEdit(ExportEntry export, UTexture2D binary)
    {
        public ExportEntry Export { get; } = export;
        public UTexture2D Binary { get; } = binary;
        public int Removed { get; private set; }

        /// <summary>
        /// How many removed mips sat before MipTailBaseIdx, so the tail index can follow its mip.
        /// </summary>
        public int RemovedBeforeTail { get; private set; }

        public void RemoveEmpty()
        {
            var tail = Export.GetProperty<IntProperty>("MipTailBaseIdx")?.Value ?? -1;
            RemovedBeforeTail += Binary.Mips.Take(tail).Count(x => x.StorageType == StorageTypes.empty);
            Removed += Binary.Mips.RemoveAll(x => x.StorageType == StorageTypes.empty);
        }

        /// <summary>
        /// Drops the largest mips so that only X remain.
        /// </summary>
        public void KeepSmallest(int count)
        {
            int drop = Binary.Mips.Count - count;
            if (drop <= 0)
            {
                return;
            }
            Binary.Mips.RemoveRange(0, drop);
            Removed += drop;
            RemovedBeforeTail += drop;
        }
    }

    public static (int Textures, int Mips) Apply(IMEPackage package, Action<string>? report = null)
    {
        var edits = new Dictionary<int, TextureEdit>();
        foreach (var texture in package.Exports.Where(x => x.IsTexture() && !x.IsDefaultObject))
        {
            // Use ObjectBinary.From so subclass data (e.g. LightMapFlags) survives serialization
            var edit = new TextureEdit(texture, (UTexture2D)ObjectBinary.From(texture));
            edit.RemoveEmpty();
            if (edit.Binary.Mips.Count == 0)
            {
                // Something is seriously wrong
                throw new InvalidDataException($"Cannot remove every mip from {texture.InstancedFullPath} in {package.FileNameNoExtension}.");
            }
            edits.Add(texture.UIndex, edit);
        }

        // All six faces have to have the same mip count.
        var changedCubes = new List<(ExportEntry Cube, TextureEdit Face)>();
        foreach (var cube in package.Exports.Where(x => x.ClassName == "TextureCube" && !x.IsDefaultObject))
        {
            var faces = new List<TextureEdit>();
            foreach (var name in CubeFaceProperties)
            {
                if (edits.TryGetValue(cube.GetProperty<ObjectProperty>(name)?.Value ?? 0, out var face))
                {
                    faces.Add(face);
                }
            }
            if (faces.Count != CubeFaceProperties.Length)
            {
                report?.Invoke($"Skipping {cube.InstancedFullPath}: not all faces are textures in this package");
                continue;
            }

            int mipCount = faces.Min(x => x.Binary.Mips.Count);
            faces.ForEach(x => x.KeepSmallest(mipCount));
            if (faces.Any(x => x.Removed > 0))
            {
                changedCubes.Add((cube, faces[0]));
            }
        }

        var changed = edits.Values.Where(x => x.Removed > 0).ToList();
        foreach (var edit in changed)
        {
            var mips = edit.Binary.Mips;
            var props = edit.Export.GetProperties();
            props.AddOrReplaceProp(new IntProperty(mips[0].SizeX, "SizeX"));
            props.AddOrReplaceProp(new IntProperty(mips[0].SizeY, "SizeY"));
            if (props.GetProp<IntProperty>("MipTailBaseIdx") is { Value: >= 0 } tail)
            {
                tail.Value = Math.Clamp(tail.Value - edit.RemovedBeforeTail, 0, mips.Count - 1);
            }
            edit.Export.WriteProperties(props);
            edit.Export.WriteBinary(edit.Binary);
            report?.Invoke($"Removed {edit.Removed} mip(s) from {edit.Export.InstancedFullPath}; {mips.Count} remain, top {mips[0].SizeX}x{mips[0].SizeY}");
        }

        foreach (var (cube, face) in changedCubes)
        {
            var props = cube.GetProperties();
            props.AddOrReplaceProp(new IntProperty(face.Binary.Mips[0].SizeX, "SizeX"));
            props.AddOrReplaceProp(new IntProperty(face.Binary.Mips[0].SizeY, "SizeY"));
            props.AddOrReplaceProp(new IntProperty(face.Binary.Mips.Count, "NumMips"));
            cube.WriteProperties(props);
        }
        return (changed.Count, changed.Sum(x => x.Removed));
    }
}
