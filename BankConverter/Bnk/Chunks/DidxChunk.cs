namespace BankConverter.Bnk.Chunks;

public sealed class MediaHeader
{
    public uint Id;
    public uint Offset;
    public uint Size;
}

/// <summary>DIDX (media index) chunk. Format is identical between v56 and v134.</summary>
public sealed class DidxChunk
{
    public List<MediaHeader> Media = new();

    public static DidxChunk Read(BankReader r, uint chunkSize)
    {
        var c = new DidxChunk();
        var count = chunkSize / 0x0C;
        for (var i = 0; i < count; i++)
        {
            c.Media.Add(new MediaHeader
            {
                Id = r.U32(),
                Offset = r.U32(),
                Size = r.U32(),
            });
        }
        return c;
    }

    public byte[] Write()
    {
        var w = new BankWriter();
        foreach (var m in Media)
        {
            w.U32(m.Id);
            w.U32(m.Offset);
            w.U32(m.Size);
        }
        return w.ToArray();
    }
}
