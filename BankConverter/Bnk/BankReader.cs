using System.Text;
using System.Buffers.Binary;

namespace BankConverter.Bnk;

/// <summary>
/// Binary reader (little-endian by default) with the primitive types used by the Wwise SoundBank format
/// (mirrors wwiser's field types: u8/u16/u32/s8/s16/s32/f32/var/uni/tid/sid).
/// </summary>
public sealed class BankReader
{
    private readonly byte[] _data;
    private readonly bool _bigEndian;
    public int Position { get; set; }
    public int Length => _data.Length;

    public BankReader(byte[] data, bool bigEndian = false)
    {
        _data = data;
        _bigEndian = bigEndian;
    }

    public bool AtEnd => Position >= _data.Length;

    public byte U8() => _data[Position++];
    public sbyte S8() => (sbyte)_data[Position++];

    public ushort U16()
    {
        var v = _bigEndian ? BinaryPrimitives.ReadUInt16BigEndian(_data.AsSpan(Position, 2))
            : BinaryPrimitives.ReadUInt16LittleEndian(_data.AsSpan(Position, 2));
        Position += 2;
        return v;
    }

    public short S16() => (short)U16();

    public uint U32()
    {
        var v = _bigEndian ? BinaryPrimitives.ReadUInt32BigEndian(_data.AsSpan(Position, 4))
            : BinaryPrimitives.ReadUInt32LittleEndian(_data.AsSpan(Position, 4));
        Position += 4;
        return v;
    }

    public int S32() => (int)U32();

    public ulong U64()
    {
        var first = U32();
        var second = U32();
        return _bigEndian ? ((ulong)first << 32) | second : first | ((ulong)second << 32);
    }

    public double D64()
    {
        return BitConverter.Int64BitsToDouble(unchecked((long)U64()));
    }

    public float F32()
    {
        return BitConverter.UInt32BitsToSingle(U32());
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
