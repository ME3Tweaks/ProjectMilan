using System.Text;

namespace BankConverter.Bnk.Chunks;

public sealed class StidEntry
{
    public uint BankId;
    public string FileName = "";
}

/// <summary>STID (string/bank-name mapping) chunk. Format is identical between v56 and v134.</summary>
public sealed class StidChunk
{
    public uint Type;
    public List<StidEntry> Entries = new();

    public static StidChunk Read(BankReader r)
    {
        var c = new StidChunk { Type = r.U32() };
        var count = r.U32();
        for (var i = 0; i < count; i++)
        {
            var bankId = r.U32();
            var len = r.U8();
            var name = len > 0 ? Encoding.UTF8.GetString(r.Bytes(len)) : "";
            c.Entries.Add(new StidEntry { BankId = bankId, FileName = name });
        }
        return c;
    }

    public byte[] Write()
    {
        var w = new BankWriter();
        w.U32(Type);
        w.U32((uint)Entries.Count);
        foreach (var e in Entries)
        {
            w.U32(e.BankId);
            var bytes = Encoding.UTF8.GetBytes(e.FileName);
            w.U8((byte)bytes.Length);
            w.Bytes(bytes);
        }
        return w.ToArray();
    }
}
