namespace BankConverter.Bnk.Hirc;

public sealed class FxChunkEntry
{
    public byte FxIndex;
    public uint FxId;
    public bool IsShareSet;
    public bool IsRendered;
}

/// <summary>NodeInitialFxParams. Identical shape between v56 and v134.</summary>
public sealed class InitialFxParams
{
    public bool IsOverrideParentFx;
    public bool BitsFxBypass; // single byte in the original; we don't have per-fx bypass bits used here, treat as byte
    public byte BitsFxBypassRaw;
    public List<FxChunkEntry> Fx = new();

    public static InitialFxParams Read(BankReader r)
    {
        var p = new InitialFxParams { IsOverrideParentFx = r.U8() != 0 };
        var count = r.U8();
        if (count > 0)
        {
            p.BitsFxBypassRaw = r.U8();
            for (var i = 0; i < count; i++)
            {
                var e = new FxChunkEntry
                {
                    FxIndex = r.U8(),
                    FxId = r.U32(),
                    IsShareSet = r.U8() != 0,
                    IsRendered = r.U8() != 0,
                };
                p.Fx.Add(e);
            }
        }
        return p;
    }

    public void Write(BankWriter w)
    {
        w.U8((byte)(IsOverrideParentFx ? 1 : 0));
        w.U8((byte)Fx.Count);
        if (Fx.Count > 0)
        {
            w.U8(BitsFxBypassRaw);
            foreach (var e in Fx)
            {
                w.U8(e.FxIndex);
                w.U32(e.FxId);
                w.U8((byte)(e.IsShareSet ? 1 : 0));
                w.U8((byte)(e.IsRendered ? 1 : 0));
            }
        }
    }
}
