using System.Text;

namespace BankConverter.Bnk;

/// <summary>One WEM's position within an AFC file, before and after conversion.</summary>
public sealed class AfcEntry
{
    public uint OldOffset;
    public uint OldSize;
    public uint NewOffset;
    public uint NewSize;

    /// <summary>False if re-encoding failed and the original (still ME3-era, playback-incompatible) bytes were kept as a size-preserving fallback.</summary>
    public bool Converted;
}

public sealed class AfcConvertResult
{
    public byte[] NewAfcBytes = Array.Empty<byte>();
    public List<AfcEntry> Entries = new();
    public Dictionary<string, string> FailedReasons = new(); // keyed by old offset (as string)
}

/// <summary>
/// An AFC (Audio File Cache) is nothing but WEM files concatenated back-to-back with zero padding -
/// each entry's size is read from its own RIFF header (bytes 4..8, little-endian, + 8 for the RIFF
/// tag/size fields themselves). Confirmed against a real ME3 AFC: sequential RIFF-header scanning
/// consumes the file exactly, no gaps.
/// </summary>
public static class AfcConverter
{
    /// <summary>Scans an AFC byte buffer and returns each entry's (offset, size), in file order.</summary>
    public static List<(uint Offset, uint Size)> ParseEntries(byte[] afcBytes)
    {
        var entries = new List<(uint, uint)>();
        var pos = 0u;
        while (pos + 8 <= afcBytes.Length)
        {
            if (afcBytes[pos] != (byte)'R' || afcBytes[pos + 1] != (byte)'I' ||
                afcBytes[pos + 2] != (byte)'F' || afcBytes[pos + 3] != (byte)'F')
            {
                throw new InvalidDataException($"Expected 'RIFF' at AFC offset {pos}, found something else - the file may be corrupt, or use a different layout than plain WEM concatenation.");
            }

            var riffSize = BitConverter.ToUInt32(afcBytes, (int)pos + 4);
            var entrySize = riffSize + 8;
            if (pos + entrySize > afcBytes.Length)
            {
                throw new InvalidDataException($"Entry at AFC offset {pos} declares size {entrySize}, which runs past the end of the file ({afcBytes.Length} bytes total).");
            }

            entries.Add((pos, entrySize));
            pos += entrySize;
        }
        return entries;
    }

    /// <summary>
    /// Converts every WEM in an AFC to v134 and rebuilds a new AFC with them concatenated in the same
    /// order. Entries that fail to re-encode (e.g. truncated prefetch fragments - shouldn't occur in a
    /// real AFC, which stores full streams, but handled defensively) fall back to their original bytes
    /// so the AFC stays structurally valid; check FailedReasons/Entries[i].Converted for any that did.
    /// </summary>
    public static AfcConvertResult Convert(byte[] afcBytes, string workDir, WemReencodeOptions options)
    {
        var parsed = ParseEntries(afcBytes);

        var wemsById = new Dictionary<string, byte[]>();
        foreach (var (offset, size) in parsed)
        {
            var bytes = new byte[size];
            Array.Copy(afcBytes, offset, bytes, 0, size);
            wemsById[offset.ToString()] = bytes;
        }

        var reencodeResult = WemReencoder.ReencodeBatch(wemsById, workDir, options);

        var result = new AfcConvertResult();
        result.FailedReasons = reencodeResult.Failed;

        using var newAfc = new MemoryStream();
        foreach (var (offset, size) in parsed)
        {
            var key = offset.ToString();
            var entry = new AfcEntry { OldOffset = offset, OldSize = size, NewOffset = (uint)newAfc.Position };

            if (reencodeResult.Converted.TryGetValue(key, out var newBytes))
            {
                newAfc.Write(newBytes);
                entry.NewSize = (uint)newBytes.Length;
                entry.Converted = true;
            }
            else
            {
                // Fallback: keep the original (still v56-codec, still playback-incompatible) bytes so
                // the rebuilt AFC is at least structurally complete. This should be rare/never for a
                // real AFC (unlike bank-embedded prefetch fragments, AFC entries are full streams).
                newAfc.Write(wemsById[key]);
                entry.NewSize = size;
                entry.Converted = false;
            }

            result.Entries.Add(entry);
        }

        result.NewAfcBytes = newAfc.ToArray();
        return result;
    }

    /// <summary>Writes the old-offset -> new-offset/size mapping as simple JSON: {"<oldOffset>": {"NewOffset":N,"NewSize":N,"OldSize":N,"Converted":bool}, ...}</summary>
    public static void WriteMappingJson(AfcConvertResult result, string path)
    {
        var sb = new StringBuilder();
        sb.Append("{\n");
        for (var i = 0; i < result.Entries.Count; i++)
        {
            var e = result.Entries[i];
            sb.Append($"  \"{e.OldOffset}\": {{ \"NewOffset\": {e.NewOffset}, \"NewSize\": {e.NewSize}, \"OldSize\": {e.OldSize}, \"Converted\": {(e.Converted ? "true" : "false")} }}");
            sb.Append(i < result.Entries.Count - 1 ? ",\n" : "\n");
        }
        sb.Append("}\n");
        File.WriteAllText(path, sb.ToString());
    }
}
