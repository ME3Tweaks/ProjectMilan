namespace BankConverter.Bnk.Hirc;

/// <summary>CAkParameterNode::SetAdvSettingsParams.</summary>
public sealed class AdvSettingsParams
{
    public byte VirtualQueueBehavior;
    public bool KillNewest;
    public bool UseVirtualBehavior;
    public ushort MaxNumInstance;
    public bool IsGlobalLimit; // v56: own byte. v134: bit 2 of the bit vector
    public byte BelowThresholdBehavior;
    public bool IsMaxNumInstOverrideParent; // v56: own byte. v134: bit 3 (bIgnoreParentMaxNumInst)
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
        // v134 folds v56's separate bytes into one bit vector. Bits 2 and 3 were verified by diffing converted
        // objects against the same object IDs in native LE3 banks (v56 kill/global/override 1/1/1 -> native 0x0D,
        // 0/0/1 -> native 0x08). Both used to be dropped, which silently removed every overriding playback limit:
        // a node's MaxNumInstance is only honoured when bit 3 is set, otherwise the parent's (usually none) applies.
        // That is why the MP objective announcer - an ActorMixer limited to 1 instance globally - played every
        // simultaneously-posted MissionIntro line on top of each other instead of keeping only the newest.
        byte bits = 0;
        if (KillNewest) bits |= 1 << 0;
        if (UseVirtualBehavior) bits |= 1 << 1;
        if (IsGlobalLimit) bits |= 1 << 2;
        if (IsMaxNumInstOverrideParent) bits |= 1 << 3; // v134 calls it bIgnoreParentMaxNumInst - same flag
        if (IsVVoicesOptOverrideParent) bits |= 1 << 4;
        w.U8(bits);
        w.U8(VirtualQueueBehavior);
        w.U16(MaxNumInstance);
        w.U8(BelowThresholdBehavior);
        // second bit vector: HDR envelope settings, not present pre-v72 either; default all off
        w.U8(0);
    }
}
