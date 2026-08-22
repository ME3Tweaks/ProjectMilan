using System.Text;

namespace BankConverter.Bnk;

/// <summary>
/// Little-endian binary reader with the primitive types used by the Wwise SoundBank format
/// (mirrors wwiser's field types: u8/u16/u32/s8/s16/s32/f32/var/uni/tid/sid).
/// </summary>
public sealed class BankReader
{
    private readonly byte[] _data;
    public int Position { get; set; }
    public int Length => _data.Length;

    public BankReader(byte[] data)
    {
        _data = data;
    }

    public bool AtEnd => Position >= _data.Length;

    public byte U8() => _data[Position++];
    public sbyte S8() => (sbyte)_data[Position++];

    public ushort U16()
    {
        var v = (ushort)(_data[Position] | (_data[Position + 1] << 8));
        Position += 2;
        return v;
    }

    public short S16() => (short)U16();

    public uint U32()
    {
        var v = (uint)(_data[Position] | (_data[Position + 1] << 8) | (_data[Position + 2] << 16) | (_data[Position + 3] << 24));
        Position += 4;
        return v;
    }

    public int S32() => (int)U32();

    public ulong U64()
    {
        var v = (ulong)U32() | ((ulong)U32() << 32);
        return v;
    }

    public double D64()
    {
        var v = BitConverter.ToDouble(_data, Position);
        Position += 8;
        return v;
    }

    public float F32()
    {
        var v = BitConverter.ToSingle(_data, Position);
        Position += 4;
        return v;
    }

    /// <summary>Union field: raw 4 bytes that are either a float or an int depending on context. Stored as raw bits.</summary>
    public uint Uni() => U32();

    /// <summary>Big-endian-style base-128 variable length quantity (continuation bit 0x80, MSB group first).</summary>
    public uint Var()
    {
        var cur = U8();
        uint value = (uint)(cur & 0x7F);
        var iterations = 0;
        while ((cur & 0x80) != 0 && iterations < 10)
        {
            cur = U8();
            value = (value << 7) | (uint)(cur & 0x7F);
            iterations++;
        }
        return value;
    }

    public string Tag4()
    {
        var s = Encoding.ASCII.GetString(_data, Position, 4);
        Position += 4;
        return s;
    }

    public byte[] Bytes(int count)
    {
        var result = new byte[count];
        Array.Copy(_data, Position, result, 0, count);
        Position += count;
        return result;
    }

    public void Skip(int count) => Position += count;

    public byte PeekU8() => _data[Position];
}
