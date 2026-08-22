namespace BankConverter.Bnk.Hirc;

public sealed class RtpcCurvePoint
{
    public float From, To;
    public uint Interp;
}

public sealed class RtpcEntry
{
    public uint RtpcId;
    public byte RtpcType; // v134 only; default 0 (GameParameter)
    public byte RtpcAccum; // v134 only; default 0 (None)
    public uint ParamId;
    public uint RtpcCurveId;
    public byte Scaling;
    public List<RtpcCurvePoint> Points = new();
}

/// <summary>SetInitialRTPC_CAkParameterNodeBase_.</summary>
public sealed class RtpcList
{
    /// <summary>
    /// v56 (&lt;=65) AkRTPC_ParameterID wire byte -&gt; the same semantic parameter's v134 wire byte.
    /// These are two independently-numbered enumerations of the same concept (confirmed via the real
    /// v56 engine, decompiled: CAkParameterNodeBase::SetInitialRTPC reads ParamId as a raw
    /// ReadBankData&lt;u32&gt;, and ME3Tweaks.Wwiser's own v56 reader truncates that to a byte and maps it
    /// through this exact table) - v134's byte is simply that parameter's ordinal position in the
    /// v134-era enum (ME3Tweaks.Wwiser.Model.Hierarchy.Enums.ParameterId.RtpcParameterId), which is a
    /// DIFFERENT numbering. Passing the raw v56 byte straight through un-translated (the previous
    /// behavior here) silently re-targets the RTPC at whatever v134 parameter happens to share that
    /// numeric ordinal - confirmed against a pristine reference bank on a real object: v56/pristine-v134
    /// both say BypassFX0 (wire byte 0x18=24), but passing 24 straight through made our own v134 output
    /// say Positioning_Divergence_Center_PCT instead (v134's own ordinal 24) - a real semantic RTPC
    /// hijack, not a display quirk.
    /// </summary>
    private static readonly Dictionary<byte, byte> V56ToV134ParamId = new()
    {
        { 0x00, 0 },  // Volume
        { 0x01, 1 },  // LFE
        { 0x02, 2 },  // Pitch
        { 0x03, 3 },  // LPF
        { 0x04, 15 }, // PlayMechanismSpecialTransitionsValue
        { 0x08, 17 }, // Priority
        { 0x09, 16 }, // MaxNumInstances
        { 0x0A, 0x50 }, // Positioning_Radius_LPF
        { 0x0B, 24 }, // Positioning_Divergence_Center_PCT
        { 0x0C, 25 }, // Positioning_Cone_Attenuation_ON_OFF
        { 0x0D, 26 }, // Positioning_Cone_Attenuation
        { 0x0E, 27 }, // Positioning_Cone_LPF
        { 0x14, 18 }, // Position_PAN_X_2D (v56: Position_PAN_RL)
        { 0x15, 19 }, // Position_PAN_Y_2D (v56: Position_PAN_FR)
        { 0x16, 0x51 }, // Positioning_Radius_SIM_ON_OFF
        { 0x17, 0x52 }, // Positioning_Radius_SIM_Attenuation
        { 0x18, 29 }, // BypassFX0
        { 0x19, 30 }, // BypassFX1
        { 0x1A, 31 }, // BypassFX2
        { 0x1B, 32 }, // BypassFX3
        { 0x1C, 33 }, // BypassAllFX
        { 0x1D, 8 },  // FeedbackVolume
        { 0x1E, 9 },  // FeedbackLowpass
        { 0x1F, 10 }, // FeedbackPitch
    };

    public List<RtpcEntry> Entries = new();

    public static RtpcList ReadV56(BankReader r)
    {
        var list = new RtpcList();
        var count = r.U16();
        for (var i = 0; i < count; i++)
        {
            var e = new RtpcEntry
            {
                RtpcId = r.U32(),
                ParamId = r.U32(),
                RtpcCurveId = r.U32(),
                Scaling = r.U8(),
            };
            var pointCount = r.U16();
            for (var p = 0; p < pointCount; p++)
            {
                e.Points.Add(new RtpcCurvePoint { From = r.F32(), To = r.F32(), Interp = r.U32() });
            }
            list.Entries.Add(e);
        }
        return list;
    }

    /// <summary>
    /// translateParamId: true for every RtpcList attached to a CAkParameterNodeBase-derived object
    /// (Sound/ActorMixer/etc via NodeBaseParams, Bus, LayerContainer) or CAkAttenuation - all of these
    /// target the shared AkRTPC_ParameterID node-property enum (Volume/Pitch/LPF/Cone*/etc), which is
    /// numbered differently between v56 and v134 (see V56ToV134ParamId doc above) and must be translated.
    /// Pass false only for CAkFxBase's own RtpcList (FxBase.cs) - an FX's RTPC subscriptions target that
    /// specific plugin's own internal parameter indices (e.g. Parametric EQ's Band1Gain/Freq/Q), a
    /// completely unrelated numbering with no v56/v134 version skew of its own. Running a raw plugin
    /// param index through the node-property translation table silently reassigns it to whatever
    /// unrelated node property happens to share that ordinal - confirmed as the real cause of a
    /// CAkParameterEQFXParams::SetParam "unknown parameter" AKASSERT/crash under the Debug Wwise build.
    /// </summary>
    public void WriteV134(BankWriter w, bool translateParamId = true)
    {
        w.U16((ushort)Entries.Count);
        foreach (var e in Entries)
        {
            w.U32(e.RtpcId);
            w.U8(e.RtpcType);
            w.U8(e.RtpcAccum);
            var v134ParamId = translateParamId && V56ToV134ParamId.TryGetValue((byte)e.ParamId, out var mapped) ? mapped : (byte)e.ParamId;
            w.Var(v134ParamId);
            w.U32(e.RtpcCurveId);
            w.U8(e.Scaling);
            w.U16((ushort)e.Points.Count);
            foreach (var p in e.Points)
            {
                w.F32(p.From);
                // Same dB_96_3 wire-format normalization as Attenuation.cs's curves (v56 stores a raw dB
                // figure, v134 stores it pre-normalized as a fraction of the -96.3dB floor) - RtpcEntry
                // curves share the same Scaling byte/dB_96_3 convention and need the identical transform.
                //
                // Log (byte value 3) needs its own transform, confirmed via the real v134 engine (Ghidra,
                // Debug Wwise build "WwiseHook_ForDecomp.exe"): CAkConversionTable::ConvertInternal
                // interpolates the raw stored curve, then calls ApplyCurveScaling, which for
                // AkCurveScaling_Log calls AkMath::ScalingFromLog -> AkMath::FastPow10 - i.e. the engine
                // computes 10^storedValue at runtime. v56's raw "To" values are meant to be used directly
                // (not exponentiated), so passing them through unconverted makes v134 compute 10^(v56 value)
                // - for values in the thousands that's an astronomically large/NaN-adjacent result, matching
                // a live "pop then total silence" corruption bug (Banshee deathball FX). The correct v134
                // stored value is the inverse of the confirmed runtime formula: log10(v56 value). Validated
                // against 4 independent pristine LE3 reference curves (Harvester/Cerberus Eng/2x Kro001,
                // all Pitch-targeted FxCustom RTPCs) whose neutral/rest point is v56 To=20 in every case -
                // log10(20)=1.30103 matches the pristine stored value exactly in all 4. Peak/extreme points
                // don't match exactly (real remaster-team retuning, unrecoverable without a reference), but
                // this is still the mechanically correct fix - it's provably right at the order-of-magnitude
                // level instead of catastrophically wrong. Guarded against non-positive input (undefined for
                // log10, shouldn't occur for legitimate Log-scaled curve data) by falling back to 0 (-> 10^0=1,
                // a neutral multiplier) rather than emitting NaN/-Infinity into the bank.
                w.F32(e.Scaling switch
                {
                    2 => p.To / 96.3f,
                    3 => p.To > 0 ? MathF.Log10(p.To) : 0f,
                    _ => p.To
                });
                w.U32(p.Interp);
            }
        }
    }
}
