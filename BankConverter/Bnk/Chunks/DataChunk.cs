namespace BankConverter.Bnk.Chunks;

/// <summary>DATA (raw media bytes) chunk. Opaque payload, passed through unchanged.</summary>
public sealed class DataChunk
{
    public byte[] Data = Array.Empty<byte>();

    public static DataChunk Read(BankReader r, uint chunkSize)
    {
        return new DataChunk { Data = r.Bytes((int)chunkSize) };
    }

    public byte[] Write() => Data;
}
