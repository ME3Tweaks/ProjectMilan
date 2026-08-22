namespace BankConverter.Bnk.Hirc;

public sealed class AttenCurve
{
    public byte Scaling;
    public List<RtpcCurvePoint> Points = new();
}

/// <summary>
/// CAkAttenuation / eHircType 0x0E. v56 has 5 curveToUse slots; v134 has 7 (2 new curve types added
/// between versions with no v56 source - written as -1/"unused"). ConeParams gains a HiPass float at v134.
/// </summary>
public sealed class Attenuation
{
    public uint Id;
    public bool IsConeEnabled;
    public float ConeInsideDegrees, ConeOutsideDegrees, ConeOutsideVolume, ConeLoPass;

    public sbyte[] CurveToUse = new sbyte[5];
    public List<AttenCurve> Curves = new();
    public RtpcList Rtpc = null!;

    public static Attenuation ReadV56(BankReader r)
    {
        var a = new Attenuation { Id = r.U32() };
        var coneFlags = r.U8();
        a.IsConeEnabled = (coneFlags & 1) != 0;
        if (a.IsConeEnabled)
        {
            a.ConeInsideDegrees = r.F32();
            a.ConeOutsideDegrees = r.F32();
            a.ConeOutsideVolume = r.F32();
            a.ConeLoPass = r.F32();
        }

        for (var i = 0; i < 5; i++) a.CurveToUse[i] = r.S8();

        var numCurves = r.U8();
        for (var i = 0; i < numCurves; i++)
        {
            var c = new AttenCurve { Scaling = r.U8() };
            var size = r.U16();
            for (var p = 0; p < size; p++)
            {
                c.Points.Add(new RtpcCurvePoint { From = r.F32(), To = r.F32(), Interp = r.U32() });
            }
            a.Curves.Add(c);
        }

        a.Rtpc = RtpcList.ReadV56(r);
        return a;
    }

    public byte[] WriteV134()
    {
        var w = new BankWriter();
        w.U32(Id);
        w.U8((byte)(IsConeEnabled ? 1 : 0));
        if (IsConeEnabled)
        {
            w.F32(ConeInsideDegrees);
            w.F32(ConeOutsideDegrees);
            w.F32(ConeOutsideVolume);
            w.F32(ConeLoPass);
            w.F32(0f); // HiPass: no v56 source, default 0 (no filtering)
        }

        // v134 CurveToUse slot meaning, confirmed against the real engine (ComputeVolumeRays_Template fetches
        // slots 0/1/2 as Dry/GameAux/UserAux gain; ComputeFiltering3D_Template fetches slot 3 as LPF and slot
        // 4 as HPF). v56 (ME3 2012) only ever had 5 raw slots and NEVER had a real HPF concept at all - every
        // pristine v134 Attenuation object sampled has slot 4 unused (-1) and v56's old 5th slot value sitting
        // at v134 slot 5 instead. A straight 1:1 passthrough of v56's 5 slots (the previous approach here)
        // therefore dumps v56's 5th-slot data into v134's HPF slot by coincidence of position, applying a
        // bogus high-pass "radio" filter to nearly everything with a distance curve - confirmed as a real
        // regression once this got fixed. Correct mapping: v56[0..3] -> v134[0..3] unchanged, v134[4] (HPF)
        // always unused, v56[4] -> v134[5].
        //
        // Separately: every real v134 Attenuation object also duplicates the GameAux curve (slot 1) into
        // UserAux (slot 2), even though v56 never set slot 2 at all - without this the UserAux/environment
        // send has no distance falloff while the dry signal correctly fades, making a 3D-positioned sound
        // sound louder/closer than it should from a distance (the send becomes relatively more prominent as
        // the dry path attenuates). Mirror slot 1 into slot 2 to match.
        var v56 = CurveToUse;
        sbyte[] curveToUse = [v56[0], v56[1], v56[2] != -1 ? v56[2] : v56[1], v56[3], -1, v56[4], -1];

        for (var i = 0; i < 7; i++) w.S8(curveToUse[i]);

        w.U8((byte)Curves.Count);
        foreach (var c in Curves)
        {
            w.U8(c.Scaling);
            w.U16((ushort)c.Points.Count);
            foreach (var p in c.Points)
            {
                w.F32(p.From);
                // v56 stores a dB_96_3-scaled curve's Y-value as a raw decibel figure (e.g. -95.337); v134
                // stores the same curve pre-normalized as a fraction of the -96.3dB floor (e.g. -0.99).
                // Confirmed empirically against a pristine v134 bank (ratio == 96.3 to float precision on
                // every sampled point) and against the real v56 source bytes (which read back as the raw,
                // un-normalized dB figure) - this is a real wire-format difference between Wwise SDK eras,
                // not a value ProjectMilan/BankConverter ever transformed correctly before. Only dB_96_3
                // (byte value 2) needs this; None-scaled curves matched byte-for-byte with no transform.
                //
                // Log (byte value 3) needs the same log10 transform as RtpcList.WriteV134 - see that method's
                // doc comment for the full Ghidra-confirmed derivation (CAkConversionTable::ApplyCurveScaling
                // -> AkMath::ScalingFromLog -> FastPow10, i.e. the v134 engine computes 10^storedValue at
                // runtime, so the correct stored value is log10(v56's raw value)). Attenuation curves go
                // through the exact same CAkConversionTable/ApplyCurveScaling engine code as RTPC curves -
                // the Scaling byte and its runtime meaning aren't RTPC-specific.
                w.F32(c.Scaling switch
                {
                    2 => p.To / 96.3f,
                    3 => p.To > 0 ? MathF.Log10(p.To) : 0f,
                    _ => p.To
                });
                w.U32(p.Interp);
            }
        }

        Rtpc.WriteV134(w);
        return w.ToArray();
    }
}
