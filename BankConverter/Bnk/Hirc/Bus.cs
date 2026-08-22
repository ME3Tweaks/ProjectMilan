namespace BankConverter.Bnk.Hirc;

public sealed class DuckInfo
{
    public uint BusId;
    public float DuckVolume;
    public int FadeOutTime, FadeInTime;
    public byte FadeCurve;
    public byte TargetProp; // v134 only; no v56 source, default 0 (Volume)
}

public sealed class BusFxEntry
{
    public byte FxIndex;
    public uint FxId;
    public bool IsShareSet, IsRendered;
}

/// <summary>
/// CAkBus / eHircType 0x08. Does NOT go through the shared NodeBaseParams pipeline (Bus has its own,
/// unrelated BusInitialValues/BusInitialParams shape). v56's fixed VolumeMain/LFEVolumeMain/PitchMain/LPFMain
/// floats move into a v134 AkPropBundle (same as everywhere else); v134 additionally carries a
/// PositioningParams + AuxParams block inside BusInitialParams that v56 simply doesn't have (written with
/// defaults), a per-duck TargetProp byte, and a mandatory trailing fxID_0/bIsShareSet_0 pair.
/// </summary>
public sealed class Bus
{
    public uint Id;
    public uint OverrideBusId; // parent bus id (own Bus->Bus tree, not the generic NodeBaseParams field)

    public float VolumeMain, LfeVolumeMain, PitchMain, LpfMain;
    public bool KillNewest, UseVirtualBehavior;
    public ushort MaxNumInstance;
    public bool IsMaxNumInstOverrideParent;
    public ushort ChannelConfig;
    public bool IsEnvBus;

    public int RecoveryTime;
    public float MaxDuckVolume;
    public List<DuckInfo> Ducks = new();

    public byte FxBitsBypass;
    public List<BusFxEntry> Fx = new();
    public bool IsEnvironmentalForFx;

    public RtpcList Rtpc = null!;
    public StateChunk States = null!;

    public static Bus ReadV56(BankReader r)
    {
        var b = new Bus { Id = r.U32() };
        b.OverrideBusId = r.U32();

        b.VolumeMain = r.F32();
        b.LfeVolumeMain = r.F32();
        b.PitchMain = r.F32();
        b.LpfMain = r.F32();
        b.KillNewest = r.U8() != 0;
        b.UseVirtualBehavior = r.U8() != 0;
        b.MaxNumInstance = r.U16();
        b.IsMaxNumInstOverrideParent = r.U8() != 0;
        b.ChannelConfig = r.U16();
        r.U8(); r.U8(); // _unused x2
        b.IsEnvBus = r.U8() != 0;
        b.IsEnvironmentalForFx = b.IsEnvBus;

        b.RecoveryTime = r.S32();
        b.MaxDuckVolume = r.F32();

        var duckCount = r.U32();
        for (var i = 0; i < duckCount; i++)
        {
            b.Ducks.Add(new DuckInfo
            {
                BusId = r.U32(),
                DuckVolume = r.F32(),
                FadeOutTime = r.S32(),
                FadeInTime = r.S32(),
                FadeCurve = r.U8(),
            });
        }

        var fxCount = r.U8();
        var readFx = fxCount > 0 || b.IsEnvironmentalForFx;
        if (readFx)
        {
            b.FxBitsBypass = r.U8();
            for (var i = 0; i < fxCount; i++)
            {
                b.Fx.Add(new BusFxEntry
                {
                    FxIndex = r.U8(),
                    FxId = r.U32(),
                    IsShareSet = r.U8() != 0,
                    IsRendered = r.U8() != 0,
                });
            }
        }

        b.Rtpc = RtpcList.ReadV56(r);
        b.States = StateChunk.ReadV56(r);

        return b;
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId)
    {
        var w = new BankWriter();
        w.U32(Id);
        var remappedParent = remapBusId(OverrideBusId);
        w.U32(remappedParent);
        if (remappedParent == 0)
        {
            w.U32(0); // idDeviceShareset: default to "System" device (0 = no override in practice would need a real id, but no v56 source exists)
        }

        // BusInitialParams
        var props = new PropBundle();
        props.SetFloat(PropIdV134.Volume, VolumeMain);
        props.SetFloat(PropIdV134.Lfe, LfeVolumeMain);
        props.SetFloat(PropIdV134.Pitch, PitchMain);
        props.SetFloat(PropIdV134.Lpf, LpfMain);
        props.WriteProps(w);

        // PositioningParams: no v56 source data for Bus; default to "not overridden".
        w.U8(0);
        // AuxParams: no v56 source data for Bus; default to "no aux sends".
        w.U8(0);

        byte bits1 = 0;
        if (KillNewest) bits1 |= 1 << 0;
        if (UseVirtualBehavior) bits1 |= 1 << 1;
        w.U8(bits1);
        w.U16(MaxNumInstance);
        w.U32(ChannelConfig); // uNumChannels/eConfigType/uChannelMask packed; raw passthrough (same physical bit layout source)
        w.U8(0); // bIsHdrBus/bHdrReleaseModeExponential: no v56 source, default off

        w.S32(RecoveryTime);
        w.F32(MaxDuckVolume);

        w.U32((uint)Ducks.Count);
        foreach (var d in Ducks)
        {
            w.U32(remapBusId(d.BusId));
            w.F32(d.DuckVolume);
            w.S32(d.FadeOutTime);
            w.S32(d.FadeInTime);
            w.U8(d.FadeCurve);
            w.U8(d.TargetProp);
        }

        // BusInitialFxParams
        w.U8((byte)Fx.Count);
        var readFx = Fx.Count > 0;
        if (readFx)
        {
            w.U8(FxBitsBypass);
            foreach (var fx in Fx)
            {
                w.U8(fx.FxIndex);
                w.U32(fx.FxId);
                w.U8((byte)(fx.IsShareSet ? 1 : 0));
                w.U8((byte)(fx.IsRendered ? 1 : 0));
            }
        }
        w.U32(0); // fxID_0 (mandatory at v134, no v56 equivalent slot; 0 = none)
        w.U8(0);  // bIsShareSet_0

        w.U8(0); // bOverrideAttachmentParams: no v56 source, default false

        Rtpc.WriteV134(w);
        States.WriteV134(w);

        return w.ToArray();
    }
}
