using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.Classes;

namespace LEDecooker;

/// <summary>
/// Re-encodes two channel (BC5) normal maps that a UDK material instance binds to a texture parameter whose
/// shader decodes three channels.
/// </summary>
/// <remarks>
/// UDK's material compiler picks a texture sample's normal decode from the CompressionSettings of the
/// sampler's *default* texture (UnpackTexture in UDK.exe): TC_NormalmapUncompressed and TC_NormalmapBC5
/// rebuild Z from XY, while TC_Normalmap, TC_NormalmapAlpha and everything that is not a normal map read
/// XYZ. An instance can override the texture but not the decode. So a BC5 map bound under a three channel
/// default reads Z from a channel BC5 does not have, the surface lights black with only its specular left
/// as a sheen, and Lightmass bakes it that way.
///
/// The cooked game has the same problem (BioT_Human_Ext.SimpleBlend_Mat's Normal1 default is a three channel
/// placeholder; White_Panel_Blend01 binds the BC5 White_Panel_Gen_01_Norm), and conversion carries it into
/// UDK unchanged: the BC7 placeholder becomes DXT1 TC_Normalmap and the BC5 texture stays BC5.
///
/// The fix is on the texture side. A DXT1 copy with Z rebuilt decodes correctly under both kinds of sampler,
/// since the two channel decodes only read XY, so no instance or material has to change.
/// TextureSampleParameterNormal is not covered here: its decode comes from the instance's static normal
/// parameter, which <see cref="NormalCompressionMaintenance"/> handles.
/// </remarks>
public static class NormalSamplerMaintenance
{
    private sealed record InstanceInfo(string Path, string? ParentKey, Dictionary<string, string> TextureParameters);

    private sealed record TextureInfo(string Format, string Compression);

    /// <summary>Decodes that rebuild Z from XY. Every other setting makes the shader read all three channels.</summary>
    private static readonly HashSet<string> TwoChannelDecodes = new(StringComparer.OrdinalIgnoreCase)
    {
        "TC_NormalmapUncompressed", "TC_NormalmapBC5"
    };

    private static bool IsMaterialInstance(string className) => className is "MaterialInstanceConstant" or "MaterialInstanceTimeVarying";

    private static bool IsTextureParameterExpression(string className) =>
        className.StartsWith("MaterialExpressionTextureSampleParameter", StringComparison.Ordinal)
        && className is not ("MaterialExpressionTextureSampleParameterNormal" or "MaterialExpressionTextureSampleParameterCube");

    /// <summary>
    /// Finds and re-encodes every affected texture exported by a package in <paramref name="folder"/>. Parents and
    /// textures are looked up across the whole folder, so run this once every package in it has been converted.
    /// Converted textures are no longer BC5, so running it again changes nothing.
    /// </summary>
    /// <returns>False if any package failed to convert or save.</returns>
    public static bool FixFolder(string folder)
    {
        var files = Directory.GetFiles(folder, "*.upk");
        var toConvert = FindBC5NormalsInThreeChannelSamplers(files);
        bool success = true;
        foreach (var fileGroup in toConvert.GroupBy(FileOf, StringComparer.OrdinalIgnoreCase))
        {
            var file = Path.Combine(folder, fileGroup.Key + ".upk");
            var temp = file + ".samplerfix";
            try
            {
                using (var package = MEPackageHandler.OpenMEPackage(file))
                {
                    foreach (var key in fileGroup)
                    {
                        var texture = FindExport(package, key);
                        if (texture == null)
                        {
                            DecookerLog.Warning($"Normal sampler fix: {key} is no longer in {package.FileNameNoExtension}");
                            continue;
                        }
                        ConvertToThreeChannel(texture);
                        DecookerLog.Information($"Normal sampler fix: converted {key} from PF_BC5 to PF_DXT1 with Z rebuilt");
                    }
                    // Save beside the original and swap it in, so a failed save cannot leave a truncated package.
                    package.Save(temp);
                }
                File.Move(temp, file, overwrite: true);
            }
            catch (Exception ex)
            {
                success = false;
                if (File.Exists(temp)) File.Delete(temp);
                DecookerLog.Error($"Normal sampler fix failed for {file}: {ex.Message}");
            }
        }
        return success;
    }

    /// <summary>
    /// Returns the keys (package file name plus path) of every BC5 texture that some material instance in
    /// <paramref name="files"/> binds into a three channel normal sampler.
    /// </summary>
    private static HashSet<string> FindBC5NormalsInThreeChannelSamplers(IReadOnlyList<string> files)
    {
        var baseDefaults = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);
        var instances = new Dictionary<string, InstanceInfo>(StringComparer.OrdinalIgnoreCase);

        static bool Wanted(ExportEntry export) => export.ClassName == "Material" || IsMaterialInstance(export.ClassName)
                                                  || IsTextureParameterExpression(export.ClassName);

        foreach (var file in files)
        {
            using var package = MEPackageHandler.UnsafePartialLoad(file, Wanted);
            foreach (var export in package.Exports.Where(x => !x.IsDefaultObject))
            {
                if (export.ClassName == "Material")
                {
                    var defaults = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    foreach (var expression in package.Exports.Where(x => x.idxLink == export.UIndex && IsTextureParameterExpression(x.ClassName)))
                    {
                        var name = expression.GetProperty<NameProperty>("ParameterName")?.Value.Instanced;
                        var texture = package.GetEntry(expression.GetProperty<ObjectProperty>("Texture")?.Value ?? 0);
                        if (name != null && texture != null) defaults[name] = Key(texture);
                    }
                    baseDefaults[Key(export)] = defaults;
                }
                else if (IsMaterialInstance(export.ClassName))
                {
                    var parameters = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                    foreach (var parameter in export.GetProperty<ArrayProperty<StructProperty>>("TextureParameterValues") ?? Enumerable.Empty<StructProperty>())
                    {
                        var name = parameter.GetProp<NameProperty>("ParameterName")?.Value.Instanced;
                        var texture = package.GetEntry(parameter.GetProp<ObjectProperty>("ParameterValue")?.Value ?? 0);
                        if (name != null && texture != null) parameters[name] = Key(texture);
                    }
                    var parent = package.GetEntry(export.GetProperty<ObjectProperty>("Parent")?.Value ?? 0);
                    instances[Key(export)] = new InstanceInfo(Key(export), parent == null ? null : Key(parent), parameters);
                }
            }
        }

        // Each instance's effective binding for each three channel default, nearest instance winning as at runtime.
        var bindings = new List<(string Instance, string Parameter, string Bound, string Default)>();
        foreach (var instance in instances.Values)
        {
            var effective = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var visited = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            Dictionary<string, string>? defaults = null;
            InstanceInfo? current = instance;
            while (current != null && visited.Add(current.Path))
            {
                foreach (var parameter in current.TextureParameters) effective.TryAdd(parameter.Key, parameter.Value);
                if (current.ParentKey == null || baseDefaults.TryGetValue(current.ParentKey, out defaults)) break;
                current = instances.GetValueOrDefault(current.ParentKey);
            }
            if (defaults == null) continue;
            foreach (var (parameter, defaultTexture) in defaults)
            {
                if (effective.TryGetValue(parameter, out var bound) && !bound.Equals(defaultTexture, StringComparison.OrdinalIgnoreCase))
                    bindings.Add((instance.Path, parameter, bound, defaultTexture));
            }
        }

        var textures = ReadTextureInfo(Path.GetDirectoryName(files.FirstOrDefault() ?? "") ?? "",
            bindings.SelectMany(x => new[] { x.Bound, x.Default }));

        var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var (instance, parameter, bound, defaultTexture) in bindings.OrderBy(x => x.Instance, StringComparer.OrdinalIgnoreCase))
        {
            if (!textures.TryGetValue(bound, out var boundInfo) || boundInfo.Format != "PF_BC5"
                || !textures.TryGetValue(defaultTexture, out var defaultInfo) || TwoChannelDecodes.Contains(defaultInfo.Compression))
                continue;
            result.Add(bound);
            DecookerLog.Information($"Normal sampler fix: {instance} binds BC5 {bound} to '{parameter}', whose shader decodes the "
                                    + $"{defaultInfo.Compression} default {defaultTexture} as three channels");
        }
        DecookerLog.Information($"Normal sampler fix: found {result.Count} BC5 normal map(s) bound into three channel samplers");
        return result;
    }

    /// <summary>
    /// Reads Format and CompressionSettings for the given texture keys without loading their mips, which make
    /// up nearly all of a converted UDK folder.
    /// </summary>
    private static Dictionary<string, TextureInfo> ReadTextureInfo(string folder, IEnumerable<string> keys)
    {
        var result = new Dictionary<string, TextureInfo>(StringComparer.OrdinalIgnoreCase);
        foreach (var fileGroup in keys.Distinct(StringComparer.OrdinalIgnoreCase).GroupBy(FileOf, StringComparer.OrdinalIgnoreCase))
        {
            var file = Path.Combine(folder, fileGroup.Key + ".upk");
            if (!File.Exists(file)) continue; // Engine content and other packages outside the folder.

            using var package = MEPackageHandler.UnsafePartialLoad(file, _ => false);
            var exports = fileGroup.Select(key => (key, export: FindExport(package, key)))
                .Where(x => x.export is { ClassName: "Texture2D" }).Select(x => (x.key, export: x.export!)).ToList();
            if (exports.Count == 0) continue;

            if (package.IsCompressed)
            {
                // Header offsets do not point into a compressed file, so load these exports properly.
                var wanted = exports.Select(x => x.export.UIndex).ToHashSet();
                using var loaded = MEPackageHandler.UnsafePartialLoad(file, x => wanted.Contains(x.UIndex));
                foreach (var (key, export) in exports)
                    result[key] = Describe(loaded.GetUExport(export.UIndex).GetProperties());
                continue;
            }

            using var stream = File.OpenRead(file);
            foreach (var (key, export) in exports)
            {
                // Texture2D properties start after the NetIndex. Every texture property fits well within this.
                var length = Math.Min(export.DataSize - 4, 16 * 1024);
                var buffer = new byte[length];
                stream.Seek(export.DataOffset + 4, SeekOrigin.Begin);
                stream.ReadExactly(buffer);
                result[key] = Describe(PropertyCollection.ReadProps(export, new MemoryStream(buffer), "Texture2D", requireNoneAtEnd: false));
            }
        }
        return result;

        static TextureInfo Describe(PropertyCollection props) => new(
            props.GetProp<EnumProperty>("Format")?.Value.Name ?? "",
            props.GetProp<EnumProperty>("CompressionSettings")?.Value.Name ?? "TC_Default");
    }

    /// <summary>
    /// Re-encodes a BC5 normal map as DXT1 with Z rebuilt from XY, flagged as a normal map.
    /// </summary>
    private static void ConvertToThreeChannel(ExportEntry export)
    {
        var props = export.GetProperties();
        var texture = new Texture2D(export);
        var image = texture.ToImage(PixelFormat.ARGB);

        // BC5 decodes to ARGB with X and Y in lanes 2 and 1 and a constant in lane 0, where a three channel decode
        // reads Z. Only the top mip needs it: correctMips rebuilds the chain from mip 0.
        var data = image.mipMaps[0].data;
        for (var i = 0; i + 3 < data.Length; i += 4)
        {
            var x = data[i + 2] / 255d * 2 - 1;
            var y = data[i + 1] / 255d * 2 - 1;
            var z = Math.Sqrt(Math.Max(0, 1 - (x * x + y * y)));
            data[i] = (byte)Math.Clamp(Math.Round((z + 1) / 2 * 255), 0, 255);
            data[i + 3] = 255;
        }
        image.correctMips(PixelFormat.DXT1);

        props.AddOrReplaceProp(new EnumProperty("PF_DXT1", "EPixelFormat", MEGame.UDK, "Format"));
        props.AddOrReplaceProp(new EnumProperty("TC_Normalmap", "TextureCompressionSettings", MEGame.UDK, "CompressionSettings"));
        texture.TextureFormat = "PF_DXT1";
        texture.Replace(image, props, isPackageStored: true);
    }

    /// <summary>
    /// A folder-wide key for an object: its package file name, then its path. An export's path in a converted
    /// UDK package does not include the file name, an import's does. A package that still has a self-named root
    /// export would otherwise produce the file name twice, so that is collapsed.
    /// </summary>
    private static string Key(IEntry entry)
    {
        var path = entry is ExportEntry ? $"{entry.FileRef.FileNameNoExtension}.{entry.InstancedFullPath}" : entry.InstancedFullPath;
        var first = path.IndexOf('.');
        var second = first < 0 ? -1 : path.IndexOf('.', first + 1);
        if (second > 0 && path.AsSpan(0, first).Equals(path.AsSpan(first + 1, second - first - 1), StringComparison.OrdinalIgnoreCase))
            path = path[(first + 1)..];
        return path;
    }

    private static string FileOf(string key) => key.Contains('.') ? key[..key.IndexOf('.')] : key;

    private static ExportEntry? FindExport(IMEPackage package, string key)
    {
        var path = key[(key.IndexOf('.') + 1)..];
        return package.FindExport(path) ?? package.FindExport(key);
    }
}
