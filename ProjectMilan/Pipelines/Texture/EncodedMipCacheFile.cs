using System.Text;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal.Classes;

namespace ProjectMilan.Pipelines.Texture
{
    /// <summary>
    /// What a cached encoded mip chain was made from. Every field must match for a file to be used.
    /// </summary>
    internal readonly record struct EncodedMipCacheKey(uint SourceCrc, int Width, int Height, int SourceLength, string SourceFormat, PixelFormat Destination, uint Options);

    /// <summary>
    /// The on-disk format shared by <see cref="StaticLighting.LightmapMipCache"/> and <see cref="TextureEncodeCache"/>: one file
    /// holds one texture's whole encoded mip chain, its key, and a checksum of the data. Anything wrong with a file (cut short,
    /// different key, bad checksum) reads as a miss.
    /// </summary>
    internal static class EncodedMipCacheFile
    {
        private const uint FileMagic = 0x3743424D; // "MBC7"
        private const int FileVersion = 1;
        private const int MaxMips = 16;

        /// <summary>Writes the chain to a temporary file beside <paramref name="path"/> and moves it into place, so a reader never sees half a file.</summary>
        /// <param name="note">Free text for whoever looks at the file; not part of the key.</param>
        public static void WriteAtomic(string path, EncodedMipCacheKey key, PixelFormat format, IReadOnlyList<EncodedMip> mips, string? note)
        {
            var temporary = $"{path}.{Guid.NewGuid():N}.tmp";
            try
            {
                Write(temporary, key, format, mips, note);
                File.Move(temporary, path, overwrite: true);
            }
            finally
            {
                if (File.Exists(temporary))
                    File.Delete(temporary);
            }
        }

        private static void Write(string path, EncodedMipCacheKey key, PixelFormat format, IReadOnlyList<EncodedMip> mips, string? note)
        {
            var payload = new byte[mips.Sum(m => m.Data.Length)];
            int at = 0;
            foreach (var mip in mips)
            {
                mip.Data.CopyTo(payload, at);
                at += mip.Data.Length;
            }

            using var stream = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
            using var writer = new BinaryWriter(stream, Encoding.UTF8);
            writer.Write(FileMagic);
            writer.Write(FileVersion);
            writer.Write((int)format);
            writer.Write(key.SourceCrc);
            writer.Write(key.Width);
            writer.Write(key.Height);
            writer.Write(key.SourceLength);
            writer.Write(key.SourceFormat);
            writer.Write(key.Options);
            writer.Write(note ?? "");
            writer.Write(mips.Count);
            foreach (var mip in mips)
            {
                writer.Write(mip.Width);
                writer.Write(mip.Height);
                writer.Write(mip.Data.Length);
            }

            writer.Write(TextureCRC.Compute(payload));
            writer.Write(payload);
        }

        /// <summary>Reads the chain stored for <paramref name="key"/> (in <see cref="EncodedMipCacheKey.Destination"/>) from <paramref name="path"/>.</summary>
        /// <returns>False if there is no usable file for this key.</returns>
        public static bool TryRead(string path, EncodedMipCacheKey key, out List<EncodedMip> mips)
        {
            mips = null!;
            if (!File.Exists(path))
                return false;

            try
            {
                using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
                using var reader = new BinaryReader(stream, Encoding.UTF8);
                if (reader.ReadUInt32() != FileMagic || reader.ReadInt32() != FileVersion)
                    return false;

                var format = (PixelFormat)reader.ReadInt32();
                if (format != key.Destination
                    || reader.ReadUInt32() != key.SourceCrc
                    || reader.ReadInt32() != key.Width
                    || reader.ReadInt32() != key.Height
                    || reader.ReadInt32() != key.SourceLength
                    || reader.ReadString() != key.SourceFormat
                    || reader.ReadUInt32() != key.Options)
                    return false;

                reader.ReadString(); // the note
                int count = reader.ReadInt32();
                if (count is < 2 or > MaxMips)
                    return false;

                var sizes = new (int Width, int Height, int Length)[count];
                long total = 0;
                for (int i = 0; i < count; i++)
                {
                    sizes[i] = (reader.ReadInt32(), reader.ReadInt32(), reader.ReadInt32());
                    if (sizes[i].Width < 1 || sizes[i].Height < 1 || sizes[i].Length < 1)
                        return false;
                    total += sizes[i].Length;
                }

                uint expectedCrc = reader.ReadUInt32();
                if (total > int.MaxValue || stream.Length - stream.Position != total)
                    return false;

                var payload = reader.ReadBytes((int)total);
                if (payload.Length != total || TextureCRC.Compute(payload) != expectedCrc)
                    return false;

                var result = new List<EncodedMip>(count);
                int at = 0;
                foreach (var (width, height, length) in sizes)
                {
                    result.Add(new EncodedMip(width, height, payload.AsSpan(at, length).ToArray()));
                    at += length;
                }

                mips = result;
                return true;
            }
            catch (Exception ex) when (ex is IOException or EndOfStreamException or InvalidDataException or ArgumentException)
            {
                return false;
            }
        }
    }
}
