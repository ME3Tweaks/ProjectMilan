namespace BankConverter.Bnk.Hirc;

/// <summary>CAkParameterNodeBase::SetAuxParams.</summary>
public sealed class AuxParams
{
    public bool OverrideGameAuxSends;
    public bool UseGameAuxSends;
    public bool OverrideUserAuxSends;
    public bool HasAux;
    public uint[] AuxIds = Array.Empty<uint>();

    public static AuxParams ReadV56(BankReader r)
    {
        var p = new AuxParams
        {
            OverrideGameAuxSends = r.U8() != 0,
            UseGameAuxSends = r.U8() != 0,
            OverrideUserAuxSends = r.U8() != 0,
        };
        p.HasAux = r.U8() != 0;
        if (p.HasAux)
        {
            p.AuxIds = new uint[4];
            for (var i = 0; i < 4; i++) p.AuxIds[i] = r.U32();
        }
        return p;
    }

    public void WriteV134(BankWriter w)
    {
        byte bits = 0;
        if (OverrideGameAuxSends) bits |= 1 << 0;
        if (UseGameAuxSends) bits |= 1 << 1;
        if (OverrideUserAuxSends) bits |= 1 << 2;
        if (HasAux) bits |= 1 << 3;
        w.U8(bits);
        if (HasAux)
        {
            for (var i = 0; i < 4; i++) w.U32(i < AuxIds.Length ? AuxIds[i] : 0);
        }
    }
}
