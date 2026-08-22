namespace BankConverter.Bnk.Hirc;

/// <summary>
/// AkPropBundle&lt;AkPropValue,unsigned char&gt; equivalent: a sparse set of (propId -> value) plus
/// a sparse set of (propId -> min/max range). Values are stored as raw 32-bit "Uni" bits: the caller
/// decides whether a given prop is conceptually a float or an int and uses FromFloat/FromInt/AsFloat/AsInt
/// accordingly, matching how Wwise's AkPropValue union works.
/// </summary>
public sealed class PropBundle
{
    public Dictionary<byte, uint> Props = new();
    public Dictionary<byte, (uint Min, uint Max)> Ranges = new();

    public static uint FromFloat(float v) => BitConverter.SingleToUInt32Bits(v);
    public static uint FromInt(int v) => unchecked((uint)v);

    public static float AsFloat(uint bits) => BitConverter.UInt32BitsToSingle(bits);
    public static int AsInt(uint bits) => unchecked((int)bits);

    public void SetFloat(byte id, float value)
    {
        if (value != 0f) Props[id] = FromFloat(value);
    }

    public void SetInt(byte id, int value)
    {
        if (value != 0) Props[id] = FromInt(value);
    }

    public void SetRangeFloat(byte id, float min, float max)
    {
        if (min != 0f || max != 0f) Ranges[id] = (FromFloat(min), FromFloat(max));
    }

    public void SetRangeInt(byte id, int min, int max)
    {
        if (min != 0 || max != 0) Ranges[id] = (FromInt(min), FromInt(max));
    }

    public float GetFloat(byte id) => Props.TryGetValue(id, out var v) ? AsFloat(v) : 0f;
    public int GetInt(byte id) => Props.TryGetValue(id, out var v) ? AsInt(v) : 0;

    public static PropBundle ReadV56(BankReader r)
    {
        var bundle = new PropBundle();
        var count = r.U8();
        var ids = new byte[count];
        for (var i = 0; i < count; i++) ids[i] = r.U8();
        for (var i = 0; i < count; i++) bundle.Props[ids[i]] = r.Uni();
        return bundle;
    }

    public static PropBundle ReadRangedV56(BankReader r)
    {
        var bundle = new PropBundle();
        var count = r.U8();
        var ids = new byte[count];
        for (var i = 0; i < count; i++) ids[i] = r.U8();
        for (var i = 0; i < count; i++)
        {
            var min = r.Uni();
            var max = r.Uni();
            bundle.Ranges[ids[i]] = (min, max);
        }
        return bundle;
    }

    public void WriteProps(BankWriter w)
    {
        w.U8((byte)Props.Count);
        foreach (var id in Props.Keys) w.U8(id);
        foreach (var v in Props.Values) w.Uni(v);
    }

    public void WriteRanges(BankWriter w)
    {
        w.U8((byte)Ranges.Count);
        foreach (var id in Ranges.Keys) w.U8(id);
        foreach (var v in Ranges.Values)
        {
            w.Uni(v.Min);
            w.Uni(v.Max);
        }
    }
}

/// <summary>AkPropID values for the v56 (&lt;=62) source format.</summary>
public static class PropIdV56
{
    public const byte Volume = 0x00;
    public const byte Lfe = 0x01;
    public const byte Pitch = 0x02;
    public const byte Lpf = 0x03;
    public const byte Priority = 0x04;
    public const byte PriorityDistanceOffset = 0x05;
    public const byte Loop = 0x06;
    public const byte PanLr = 0x0A;
    public const byte PanFr = 0x0B;
    public const byte CenterPct = 0x0C;
    public const byte DelayTime = 0x0D;
    public const byte TransitionTime = 0x0E;
    public const byte Probability = 0x0F;
}

/// <summary>AkPropID values for the v134 (128&lt;=..&lt;=134) target format.</summary>
public static class PropIdV134
{
    public const byte Volume = 0x00;
    public const byte Lfe = 0x01;
    public const byte Pitch = 0x02;
    public const byte Lpf = 0x03;
    public const byte Hpf = 0x04;
    public const byte BusVolume = 0x05;
    public const byte MakeUpGain = 0x06;
    public const byte Priority = 0x07;
    public const byte PriorityDistanceOffset = 0x08;
    public const byte MuteRatio = 0x0B;
    public const byte PanLr = 0x0C;
    public const byte PanFr = 0x0D;
    public const byte CenterPct = 0x0E;
    public const byte DelayTime = 0x0F;
    public const byte TransitionTime = 0x10;
    public const byte Probability = 0x11;
    public const byte Loop = 0x3A;
    public const byte InitialDelay = 0x3B;
    public const byte AttenuationId = 0x46;
    public const byte PositioningTypeBlend = 0x47;
}
