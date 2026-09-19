namespace BankConverter.Bnk.Chunks;

/// <summary>Extracts embedded WEM media from a v56 bank's DIDX+DATA chunks, keyed by media (source) ID.</summary>
public static class WemExtractor
{
    public static Dictionary<uint, byte[]> Extract(BankFile bank)
    {
        var result = new Dictionary<uint, byte[]>();
        if (bank.Didx == null || bank.Data == null) return result;

        foreach (var m in bank.Didx.Media)
        {
            if (m.Offset + m.Size > bank.Data.Data.Length) continue;
            var bytes = new byte[m.Size];
            Array.Copy(bank.Data.Data, m.Offset, bytes, 0, m.Size);
            result[m.Id] = bytes;
        }

        return result;
    }

    /// <summary>
    /// Extracts embedded media straight out of a bank's raw bytes by walking its top-level chunks, with no
    /// version-specific parse. DIDX/DATA are format-stable across v56 and v134, so this reads either - which is
    /// what lets an already-converted (v134) bank donate its media back for a HIRC-only re-conversion.
    /// </summary>
    public static Dictionary<uint, byte[]> ExtractRaw(byte[] bankBytes)
    {
        var result = new Dictionary<uint, byte[]>();
        if (bankBytes is not { Length: > 8 }) return result;

        List<MediaHeader>? media = null;
        byte[]? data = null;

        var r = new BankReader(bankBytes);
        while (r.Position + 8 <= r.Length)
        {
            var tag = r.Tag4();
            var size = r.U32();
            if (size > r.Length - r.Position) break;
            switch (tag)
            {
                case "DIDX":
                    media = DidxChunk.Read(r, size).Media;
                    break;
                case "DATA":
                    data = DataChunk.Read(r, size).Data;
                    break;
                default:
                    r.Skip((int)size);
                    break;
            }
        }

        if (media == null || data == null) return result;

        foreach (var m in media)
        {
            if (m.Offset + m.Size > data.Length) continue;
            var bytes = new byte[m.Size];
            Array.Copy(data, m.Offset, bytes, 0, m.Size);
            result[m.Id] = bytes;
        }

        return result;
    }
}
