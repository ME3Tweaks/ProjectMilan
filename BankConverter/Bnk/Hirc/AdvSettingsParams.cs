namespace BankConverter.Bnk.Hirc;

/// <summary>CAkParameterNode::SetAdvSettingsParams.</summary>
public sealed class AdvSettingsParams
{
    public byte VirtualQueueBehavior;
    public bool KillNewest;
    public bool UseVirtualBehavior;
    public ushort MaxNumInstance;
    public bool IsGlobalLimit; // v56 only
    public byte BelowThresholdBehavior;
    public bool IsMaxNumInstOverrideParent; // v56 only concept
    public bool IsVVoicesOptOverrideParent;

    public static AdvSettingsParams ReadV56(BankReader r)
    {
        var p = new AdvSettingsParams
        {
            VirtualQueueBehavior = r.U8(),
            KillNewest = r.U8() != 0,
            UseVirtualBehavior = r.U8() != 0,
            MaxNumInstance = r.U16(),
            IsGlobalLimit = r.U8() != 0,
            BelowThresholdBehavior = r.U8(),
            IsMaxNumInstOverrideParent = r.U8() != 0,
            IsVVoicesOptOverrideParent = r.U8() != 0,
        };
        return p;
    }

    public void WriteV134(BankWriter w)
    {
        byte bits = 0;
        if (KillNewest) bits |= 1 << 0;
        if (UseVirtualBehavior) bits |= 1 << 1;
        // bit 3 = bIgnoreParentMaxNumInst: no v56 equivalent, default false
        if (IsVVoicesOptOverrideParent) bits |= 1 << 4;
        w.U8(bits);
        w.U8(VirtualQueueBehavior);
        w.U16(MaxNumInstance);
        w.U8(BelowThresholdBehavior);
        // second bit vector: HDR envelope settings, not present pre-v72 either; default all off
        w.U8(0);
    }
}
