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
}
