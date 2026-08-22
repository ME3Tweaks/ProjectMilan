namespace BankConverter.Bnk.Hirc;

/// <summary>
/// CAkAction / eHircType 0x03.
///
/// v56 has two independent timing triples per action: the outer tDelay/tDelayMin/tDelayMax (in
/// ActionInitialValues, always present) and, for most action kinds, an inner TTime/TTimeMin/TTimeMax +
/// fade-curve byte inside the type-specific params (the transition/fade duration). Both fold into v134's
/// PropBundle as DelayTime and TransitionTime respectively.
///
/// v56's "16-byte reserved gap" that follows the TTime wrapper for SetVolume/SetPitch/SetLPF/SetGameParameter
/// is not unused: it's a still-live (eValueMeaning:u32, base/min/max:f32) block wwiser just doesn't decode
/// for this old version (confirmed against real data: bytes 02 00 00 00 | 00 00 40 C1 | 0 | 0 decode as
/// eValueMeaning=2, base=-12.0dB - a plausible mix value, not garbage).
/// </summary>
public enum ActionKind
{
    Empty,          // Break, Trigger, UseState, UnuseState: no wrapper, no specific params at all
    WrappedEmpty,   // Mute, Unmute: TTime wrapper present, but no specific params ever (any version)
    Stop,           // TTime wrapper; v134 adds StopActionSpecificParams (1 byte, no v56 source: defaults 0)
    PauseResume,    // TTime wrapper; v56 b32IsMaster+gap, v134 byBitVector (1 byte, no reliable v56 source: defaults 0)
    Play,           // own wrapper (TTime only at v56, no fade-curve-gated specific block) + bankID
    SetAkProp,      // Volume/Pitch/LPF: TTime wrapper + (eValueMeaning, base, min, max)
    SetGameParameter,
    SetState,       // no wrapper: StateGroupID/TargetStateID only
    SetSwitch,      // no wrapper: SwitchGroupID/SwitchStateID only
    BypassFx,       // no wrapper: bIsBypass/uTargetMask + except
    Seek,           // no wrapper: own fields + except
}

public sealed class AkAction
{
    public uint Id;
    public uint V56ActionType;
    public uint TargetId;
    public int Delay, DelayMin, DelayMax;

    public ActionKind Kind;

    // TTime wrapper (Stop/Mute/PauseResume/SetAkProp/SetGameParameter/Play)
    public int TransitionTime, TransitionTimeMin, TransitionTimeMax;
    public byte FadeCurve;

    // PauseResume (v56 source only; no reliable v134 mapping)
    public bool IsMaster;

    // Play
    public uint BankId;

    // SetAkProp / SetGameParameter
    public byte ValueMeaning;
    public float ValueBase, ValueMin, ValueMax;
    public bool BypassTransition; // SetGameParameter, v134 only; no v56 source, default false

    // SetState
    public uint StateGroupId, TargetStateId;

    // SetSwitch
    public uint SwitchGroupId, SwitchStateId;

    // BypassFX
    public bool IsBypass;
    public byte TargetMask;

    // Seek
    public bool IsSeekRelativeToDuration;
    public float SeekValue, SeekValueMin, SeekValueMax;
    public bool SnapToNearestMarker;

    public bool IsBus => ActionTypeMap.Me3BusIds.Contains(TargetId);

    public static AkAction ReadV56(BankReader r)
    {
        var a = new AkAction { Id = r.U32() };
        a.V56ActionType = r.U32();
        var baseType = a.V56ActionType & 0xFF000;

        a.Kind = baseType switch
        {
            0x01000 => ActionKind.Stop,
            0x02000 or 0x03000 => ActionKind.PauseResume,
            0x04000 or 0x05000 => ActionKind.Play,
            0x06000 or 0x07000 => ActionKind.WrappedEmpty, // Mute/Unmute
            0x08000 or 0x09000 or 0x0A000 or 0x0B000 or 0x0E000 or 0x0F000 => ActionKind.SetAkProp, // Pitch/Volume/LPF
            0x0C000 or 0x0D000 => ActionKind.SetAkProp, // SetLFE: read structurally, dropped at write time (no v134 equivalent)
            0x10000 or 0x11000 => ActionKind.Empty, // UseState/UnuseState
            0x12000 => ActionKind.SetState,
            0x13000 or 0x14000 => ActionKind.SetGameParameter,
            0x60000 => ActionKind.SetSwitch,
            0x70000 or 0x80000 => ActionKind.BypassFx,
            0x90000 or 0xA0000 => ActionKind.Empty, // Break/Trigger
            0xB0000 => ActionKind.Seek,
            _ => ActionKind.Empty,
        };

        a.TargetId = r.U32();
        a.Delay = r.S32();
        a.DelayMin = r.S32();
        a.DelayMax = r.S32();
        var subSize = r.U32();
        var subStart = r.Position;

        if (subSize > 0)
        {
            switch (a.Kind)
            {
                case ActionKind.WrappedEmpty:
                case ActionKind.Stop:
                    a.ReadTTimeWrapper(r);
                    ReadExcept(r);
                    break;
                case ActionKind.PauseResume:
                    a.ReadTTimeWrapper(r);
                    a.IsMaster = r.U32() != 0; // v56 b32IsMaster; no direct v134 equivalent bit
                    r.Skip(0x0C);
                    ReadExcept(r);
                    break;
                case ActionKind.Play:
                    a.TransitionTime = r.S32();
                    a.TransitionTimeMin = r.S32();
                    a.TransitionTimeMax = r.S32();
                    a.FadeCurve = (byte)(r.U8() & 0x1F);
                    r.Skip(0x10); // inner generic specific-params block (always unused padding for Play)
                    ReadExcept(r);
                    a.BankId = r.U32(); // fileID (v56) == bankID
                    break;
                case ActionKind.SetAkProp:
                case ActionKind.SetGameParameter:
                    a.ReadTTimeWrapper(r);
                    a.ValueMeaning = (byte)r.U32();
                    a.ValueBase = r.F32();
                    a.ValueMin = r.F32();
                    a.ValueMax = r.F32();
                    ReadExcept(r);
                    break;
                case ActionKind.SetState:
                    a.StateGroupId = r.U32();
                    a.TargetStateId = r.U32();
                    break;
                case ActionKind.SetSwitch:
                    a.SwitchGroupId = r.U32();
                    a.SwitchStateId = r.U32();
                    break;
                case ActionKind.BypassFx:
                    a.IsBypass = r.U8() != 0;
                    a.TargetMask = r.U8();
                    ReadExcept(r);
                    break;
                case ActionKind.Seek:
                    a.IsSeekRelativeToDuration = r.U8() != 0;
                    a.SeekValue = r.F32();
                    a.SeekValueMin = r.F32();
                    a.SeekValueMax = r.F32();
                    a.SnapToNearestMarker = r.U8() != 0;
                    ReadExcept(r);
                    break;
                case ActionKind.Empty:
                default:
                    break;
            }
        }

        // Defensive resync: framing is authoritative regardless of how many bytes we actually consumed.
        r.Position = subStart + (int)subSize;
        return a;

        void ReadExcept(BankReader rr)
        {
            var count = rr.U32();
            for (var i = 0; i < count; i++) rr.U32(); // ulID (bIsBus byte not present <=65)
        }
    }

    private void ReadTTimeWrapper(BankReader r)
    {
        TransitionTime = r.S32();
        TransitionTimeMin = r.S32();
        TransitionTimeMax = r.S32();
        FadeCurve = (byte)(r.U8() & 0x1F);
    }

    public byte[] WriteV134(Func<uint, uint> remapBusId)
    {
        if (Kind == ActionKind.SetAkProp && (V56ActionType & 0xFF000) is 0x0C000 or 0x0D000)
            throw new NotSupportedException("SetLFE has no v134 equivalent");

        var w = new BankWriter();
        w.U32(Id);

        var v134Type = ActionTypeMap.ConvertType(V56ActionType, IsBus)
            ?? throw new NotSupportedException($"No v134 equivalent for action type 0x{V56ActionType:X}");
        w.U16((ushort)v134Type);

        w.U32(IsBus ? remapBusId(TargetId) : TargetId);
        w.U8((byte)(IsBus ? 1 : 0));

        // DelayTime/TransitionTime are integer-typed (milliseconds) in the real v134 AkPropID table, not
        // float - confirmed against a pristine reference bank via the v134 Ghidra debug build's own reader
        // (StoredAsFloat: False, raw value read back as a clean integer millisecond count). Writing them via
        // SetFloat bit-reinterprets the millisecond count as an IEEE-754 float pattern instead of storing it
        // directly - e.g. Delay=100 (ms) becomes float 100.0's bit pattern 0x42C80000, which the real engine
        // then reads back AS A RAW INTEGER of 1,120,403,456ms (~35 years) - effectively an infinite delay,
        // silently killing any delayed action (Play/Stop/SetAkProp/etc.) with a nonzero v56 delay/transition.
        var props = new PropBundle();
        var ranges = new PropBundle();
        if (Delay != 0) props.SetInt(PropIdV134.DelayTime, Delay);
        if (DelayMin != 0 || DelayMax != 0) ranges.SetRangeInt(PropIdV134.DelayTime, DelayMin, DelayMax);
        if (Kind is ActionKind.Play or ActionKind.WrappedEmpty or ActionKind.Stop or ActionKind.PauseResume or ActionKind.SetAkProp or ActionKind.SetGameParameter)
        {
            if (TransitionTime != 0) props.SetInt(PropIdV134.TransitionTime, TransitionTime);
            if (TransitionTimeMin != 0 || TransitionTimeMax != 0) ranges.SetRangeInt(PropIdV134.TransitionTime, TransitionTimeMin, TransitionTimeMax);
        }
        props.WriteProps(w);
        ranges.WriteRanges(w);

        switch (Kind)
        {
            case ActionKind.WrappedEmpty:
                // byBitVector(eFadeCurve)/specific-params(none)/ExceptParams are unconditional on the
                // wire at both versions; only the leading TTime triple (already folded into props above) is v56-only.
                w.U8(FadeCurve);
                WriteExcept(w);
                break;
            case ActionKind.Stop:
                w.U8(FadeCurve);
                w.U8(0); // StopActionSpecificParams byBitVector: bApplyToStateTransitions/bApplyToDynamicSequence, no v56 source
                WriteExcept(w);
                break;
            case ActionKind.PauseResume:
                w.U8(FadeCurve);
                w.U8(0); // byBitVector: bIncludePendingResume/bIsMasterResume/bApplyToStateTransitions/bApplyToDynamicSequence, no reliable v56 source
                WriteExcept(w);
                break;
            case ActionKind.Play:
                w.U8(FadeCurve);
                w.U32(BankId);
                break;
            case ActionKind.SetAkProp:
                w.U8(FadeCurve);
                w.U8(ValueMeaning);
                w.F32(ValueBase);
                w.F32(ValueMin);
                w.F32(ValueMax);
                WriteExcept(w);
                break;
            case ActionKind.SetGameParameter:
                w.U8(FadeCurve);
                w.U8((byte)(BypassTransition ? 1 : 0));
                w.U8(ValueMeaning);
                w.F32(ValueBase);
                w.F32(ValueMin);
                w.F32(ValueMax);
                WriteExcept(w);
                break;
            case ActionKind.SetState:
                w.U32(StateGroupId);
                w.U32(TargetStateId);
                break;
            case ActionKind.SetSwitch:
                w.U32(SwitchGroupId);
                w.U32(SwitchStateId);
                break;
            case ActionKind.BypassFx:
                w.U8((byte)(IsBypass ? 1 : 0));
                w.U8(TargetMask);
                WriteExcept(w);
                break;
            case ActionKind.Seek:
                w.U8((byte)(IsSeekRelativeToDuration ? 1 : 0));
                w.F32(SeekValue);
                w.F32(SeekValueMin);
                w.F32(SeekValueMax);
                w.U8((byte)(SnapToNearestMarker ? 1 : 0));
                WriteExcept(w);
                break;
            case ActionKind.Empty:
            default:
                break;
        }

        return w.ToArray();

        void WriteExcept(BankWriter ww) => ww.Var(0); // exception lists are always empty in this game's content
    }
}
