using System.Buffers.Binary;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilanCore;

/// <summary>Read-only checks of external texture mip references. Reuses TFC handles across packages.</summary>
public sealed class TextureReferenceVerifier : IDisposable
{
    private readonly Dictionary<string, string> files;
    private readonly Dictionary<string, FileStream> streams = new(StringComparer.OrdinalIgnoreCase);

    public TextureReferenceVerifier(IDictionary<string, string> availableFiles)
    {
        files = new Dictionary<string, string>(availableFiles, StringComparer.OrdinalIgnoreCase);
    }

    public IEnumerable<string> VerifyPackage(IMEPackage package)
    {
        foreach (var texture in package.Exports.Where(x => !x.IsDefaultObject && (x.IsTexture() || x.IsA("Texture2D"))))
        {
            UTexture2D binary;
            string? cache;
            string? parseError = null;
            try
            {
                binary = texture.GetBinaryData<UTexture2D>();
                cache = texture.GetProperty<NameProperty>("TextureFileCacheName")?.Value.Name;
            }
            catch (Exception ex)
            {
                binary = null!;
                cache = null;
                // Iterator methods cannot yield from a catch block.
                parseError = ex.Message;
            }

            if (binary == null)
            {
                yield return $"{package.FileNameNoExtension}: {texture.InstancedFullPath}: cannot read texture mips: {parseError}";
                continue;
            }

            for (int i = 0; i < binary.Mips.Count; i++)
            {
                var mip = binary.Mips[i];
                if (mip.StorageType == StorageTypes.empty || ((StorageFlags)mip.StorageType & StorageFlags.externalFile) == 0)
                    continue;
                var error = VerifyMip(cache, mip.DataOffset, mip.CompressedSize, mip.UncompressedSize, mip.StorageType);
                if (error != null)
                    yield return $"{package.FileNameNoExtension}: {texture.InstancedFullPath}, mip {i}: {error}";
            }
        }
    }

    public string? VerifyMip(string? cacheName, int offset, int compressedSize, int uncompressedSize, StorageTypes storage)
    {
        if (string.IsNullOrWhiteSpace(cacheName) || cacheName.Equals("None", StringComparison.OrdinalIgnoreCase))
            return "external mip has no TextureFileCacheName";
        string filename = cacheName + ".tfc";
        if (!files.TryGetValue(filename, out var path) || !File.Exists(path))
            return $"missing referenced TFC file: {filename}";
        try
        {
            if (!streams.TryGetValue(path, out var stream))
                streams[path] = stream = File.OpenRead(path);
            bool compressed = storage != StorageTypes.extUnc;
            long size = compressed ? compressedSize : uncompressedSize;
            if (offset < 16 || size <= 0 || uncompressedSize <= 0 || (long)offset + size > stream.Length)
                return $"invalid range in {filename}: offset={offset}, size={size}, file size={stream.Length}";
            if (compressed)
            {
                if (size < 16) return $"compressed mip is too short in {filename} at {offset}";
                Span<byte> header = stackalloc byte[16];
                stream.Position = offset;
                stream.ReadExactly(header);
                if (BinaryPrimitives.ReadUInt32LittleEndian(header) != 0x9E2A83C1)
                    return $"invalid compressed mip header in {filename} at {offset}";
                int blockSize = storage == StorageTypes.extOodle ? 0x40000 : 0x20000;
                long blocks = ((long)uncompressedSize + blockSize - 1) / blockSize;
                if (BinaryPrimitives.ReadInt32LittleEndian(header[4..]) != blockSize ||
                    (long)BinaryPrimitives.ReadInt32LittleEndian(header[8..]) + 16 + blocks * 8 != size)
                    return $"invalid compressed mip sizes in {filename} at {offset}";
                if (BinaryPrimitives.ReadInt32LittleEndian(header[12..]) != uncompressedSize)
                    return $"compressed mip uncompressed size does not match in {filename} at {offset}";
            }
            return null;
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return $"cannot read {filename}: {ex.Message}";
        }
    }

    public void Dispose()
    {
        foreach (var stream in streams.Values) stream.Dispose();
        streams.Clear();
    }
}
