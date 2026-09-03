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

    /// <param name="isFxSupported">Optional filter (keyed by <see cref="FxChunkEntry.FxId"/>) - entries for
    /// which this returns false are dropped instead of written. Used to strip references to third-party/
    /// studio-proprietary Wwise plugins (see PluginSupport.IsThirdParty) that ME3 registered itself but LE3's
    /// stock Wwise runtime has no equivalent for - leaving such a reference in would ask LE3 to instantiate a
    /// plugin it doesn't have, which is a much worse failure mode (observed in practice as garbled/glitched
    /// output on the entire mix passing through that effect slot) than simply not applying that effect.</param>
    public void Write(BankWriter w, Func<uint, bool>? isFxSupported = null)
    {
        var effectiveFx = isFxSupported == null ? Fx : Fx.Where(e => isFxSupported(e.FxId)).ToList();

        w.U8((byte)(IsOverrideParentFx ? 1 : 0));
        w.U8((byte)effectiveFx.Count);
        if (effectiveFx.Count > 0)
        {
            w.U8(BitsFxBypassRaw);
            foreach (var e in effectiveFx)
            {
                w.U8(e.FxIndex);
                w.U32(e.FxId);
                w.U8((byte)(e.IsShareSet ? 1 : 0));
                w.U8((byte)(e.IsRendered ? 1 : 0));
            }
        }
    }
}
