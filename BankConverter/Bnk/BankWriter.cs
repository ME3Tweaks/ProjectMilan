using System.Text;

namespace BankConverter.Bnk;

/// <summary>
/// Little-endian binary writer mirroring <see cref="BankReader"/>.
/// </summary>
public sealed class BankWriter
{
    private readonly List<byte> _data = new();

    public int Position => _data.Count;

    public void U8(byte v) => _data.Add(v);
    public void S8(sbyte v) => _data.Add((byte)v);

    public void U16(ushort v)
    {
        _data.Add((byte)(v & 0xFF));
        _data.Add((byte)((v >> 8) & 0xFF));
    }

    public void S16(short v) => U16((ushort)v);

    public void U32(uint v)
    {
        _data.Add((byte)(v & 0xFF));
        _data.Add((byte)((v >> 8) & 0xFF));
        _data.Add((byte)((v >> 16) & 0xFF));
        _data.Add((byte)((v >> 24) & 0xFF));
    }

    public void S32(int v) => U32((uint)v);

    public void D64(double v)
    {
        var bytes = BitConverter.GetBytes(v);
        _data.AddRange(bytes);
    }

    public void F32(float v)
    {
        var bytes = BitConverter.GetBytes(v);
        _data.AddRange(bytes);
    }

    public void Uni(uint rawBits) => U32(rawBits);

    /// <summary>Big-endian-style base-128 variable length quantity.</summary>
    public void Var(uint value)
    {
        // Split into 7-bit groups, MSB group first, continuation bit 0x80 on all but the last.
        var groups = new List<byte>();
        var v = value;
        groups.Add((byte)(v & 0x7F));
        v >>= 7;
        while (v != 0)
        {
            groups.Add((byte)((v & 0x7F) | 0x80));
            v >>= 7;
        }
        for (var i = groups.Count - 1; i >= 0; i--)
        {
            _data.Add(groups[i]);
        }
    }

    public void Tag4(string tag)
    {
        var bytes = Encoding.ASCII.GetBytes(tag);
        if (bytes.Length != 4) throw new ArgumentException("Tag must be 4 characters", nameof(tag));
        _data.AddRange(bytes);
    }

    public void Bytes(byte[] bytes) => _data.AddRange(bytes);

    /// <summary>Reserves space for a later-patched u32 (e.g. a chunk size field), returns its offset.</summary>
    public int ReserveU32()
    {
        var pos = Position;
        U32(0);
        return pos;
    }

    public void PatchU32(int offset, uint value)
    {
        _data[offset] = (byte)(value & 0xFF);
        _data[offset + 1] = (byte)((value >> 8) & 0xFF);
        _data[offset + 2] = (byte)((value >> 16) & 0xFF);
        _data[offset + 3] = (byte)((value >> 24) & 0xFF);
    }

    public byte[] ToArray() => _data.ToArray();
}
