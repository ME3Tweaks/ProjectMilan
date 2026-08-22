namespace BankConverter.Bnk.Hirc;

/// <summary>
/// CAkState / eHircType 0x01. v56 stores 4 fixed floats (AkStdParameters); v134 stores a sparse
/// AkPropBundle&lt;float,u16&gt; (u16 id + plain f32 value - a distinct encoding from the u8-id/uni-value
/// bundle used everywhere else, "despite the generic name... used by CAkState only").
/// </summary>
public sealed class AkState
{
    public uint Id;
    public float Volume, LfeVolume, Pitch, Lpf;

    public static AkState ReadV56(BankReader r)
    {
        var s = new AkState { Id = r.U32() };
        s.Volume = r.F32();
        s.LfeVolume = r.F32();
        s.Pitch = r.F32();
        s.Lpf = r.F32();
        return s;
    }

    public byte[] WriteV134()
    {
        var w = new BankWriter();
        w.U32(Id);

        var props = new List<(ushort id, float value)>();
        if (Volume != 0) props.Add((0, Volume));
        if (LfeVolume != 0) props.Add((1, LfeVolume));
        if (Pitch != 0) props.Add((2, Pitch));
        if (Lpf != 0) props.Add((3, Lpf));

        w.U16((ushort)props.Count);
        foreach (var (id, _) in props) w.U16(id);
        foreach (var (_, value) in props) w.F32(value);

        return w.ToArray();
    }
}
