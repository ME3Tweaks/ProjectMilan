using System.Text;

namespace BankConverter.Bnk.Hirc;

public sealed class MusicMarker
{
    public uint Id;
    public double Position;
    public string Name = "";
}

/// <summary>CAkMusicSegment / eHircType 0x0A.</summary>
public sealed class MusicSegment
{
    public uint Id;
    public MusicNodeParams NodeParams = null!;
    public double Duration;
    public List<MusicMarker> Markers = new();

    public static MusicSegment ReadV56(BankReader r)
    {
        var s = new MusicSegment { Id = r.U32() };
        s.NodeParams = MusicNodeParams.ReadV56(r);
        s.Duration = r.D64();

        var markerCount = r.U32();
        for (var i = 0; i < markerCount; i++)
        {
            // v56 (<=62): id+fPosition only, no name string at all (that's added at >62, which v134 has).
            var m = new MusicMarker { Id = r.U32(), Position = r.D64() };
            s.Markers.Add(m);
        }

        return s;
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId, Func<uint, bool>? isFxSupported = null)
    {
        var w = new BankWriter();
        w.U32(Id);
        NodeParams.WriteV134(w, remapBusId, isFxSupported);
        w.D64(Duration);

        w.U32((uint)Markers.Count);
        foreach (var m in Markers)
        {
            w.U32(m.Id);
            w.D64(m.Position);
            if (string.IsNullOrEmpty(m.Name))
            {
                w.U32(0);
            }
            else
            {
                var bytes = Encoding.UTF8.GetBytes(m.Name + "\0");
                w.U32((uint)bytes.Length);
                w.Bytes(bytes);
            }
        }

        return w.ToArray();
    }
}
