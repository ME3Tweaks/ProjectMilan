using System.Text;

namespace UDKInj;


/// <summary>
/// Custom-sized memory block in remote process's memory.
/// </summary>
public sealed class Allocation : IDisposable
{
    readonly ProcessHandle _handle;
    readonly IntPtr _allocation;
    readonly byte[] _debug;
    readonly ulong _size;
    readonly bool _owned;

    /// <summary>
    /// Retrieves the internal remote pointer.
    /// </summary>
    public IntPtr Pointer => _allocation;

    public Allocation(ProcessHandle handle, ulong size)
    {
        if (size > 16 * 1024 * 1024)
            throw new ArgumentException($"bad allocation size: {size}", nameof(size));

        _handle = handle;
        _size = size;
        _owned = true;

        _allocation = _handle.Alloc(_size);
        _debug = new byte[_size];

        Array.Fill<byte>(_debug, 0xAB);
    }

    Allocation(ProcessHandle handle, IntPtr address, ulong size)
    {
        _handle = handle;
        _size = size;
        _owned = false;
        _allocation = address;
        _debug = [];
    }

    /// <summary>
    /// Wraps an already-existing remote address (e.g. a resolved export RVA) as an
    /// <see cref="Allocation"/> without allocating or freeing anything - <see cref="Dispose"/>
    /// on the result is a no-op, so it's safe to keep around and reuse for the life of the
    /// injection rather than re-wrapping per read.
    /// </summary>
    public static Allocation Wrap(ProcessHandle handle, IntPtr address, ulong size) => new(handle, address, size);

    /// <summary>
    /// Fills the allocation with debug byte (<c>0xAB</c>).
    /// </summary>
    public void MemFillDebug()
    {
        _handle.WriteMemoryChecked(_allocation, _debug);
    }

    /// <summary>
    /// Copies some bytes from remote process memory at the given offset.
    /// </summary>
    /// <param name="offset"></param>
    /// <param name="buffer"></param>
    /// <exception cref="ArgumentOutOfRangeException">If given buffer at the given offset would overflow.</exception>
    public void Read(ulong offset, Span<byte> buffer)
    {
        if (offset + (ulong)buffer.Length > _size)
            throw new ArgumentOutOfRangeException();

        _handle.ReadMemoryChecked(_allocation + (IntPtr)offset, buffer);
    }

    /// <summary>
    /// Copies some bytes into remote process memory at the given offset.
    /// </summary>
    /// <param name="offset"></param>
    /// <param name="buffer"></param>
    /// <exception cref="ArgumentOutOfRangeException">If given buffer at the given offset would overflow.</exception>
    public void Write(ulong offset, ReadOnlySpan<byte> buffer)
    {
        if (offset + (ulong)buffer.Length > _size)
            throw new ArgumentOutOfRangeException();

        _handle.WriteMemoryChecked(_allocation + (IntPtr)offset, buffer);
    }


    #region IDisposable implementation.

    private bool _disposed;

    private void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing)
            {
                // TODO: dispose managed state (managed objects)
            }

            if (_owned) _handle.Free(_allocation);
            _disposed = true;
        }
    }

    ~Allocation()
    {
        Dispose(disposing: false);
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }

    #endregion
}


public static class AllocationReadWriteExtensions
{
    #region Reading methods.

    public static byte ReadByte(this Allocation alloc, ulong offset)
    {
        Span<byte> buffer = stackalloc byte[1];
        alloc.Read(offset, buffer);
        return buffer[0];
    }

    public static int ReadInt32(this Allocation alloc, ulong offset)
    {
        Span<byte> buffer = stackalloc byte[4];
        alloc.Read(offset, buffer);
        return BitConverter.ToInt32(buffer);
    }

    /// <summary>
    /// Reads a fixed-size NUL-terminated UTF-16 field (e.g. a wchar_t[N] struct member) and
    /// trims it at the first NUL, or at maxChars if the agent didn't NUL-terminate it.
    /// </summary>
    public static string ReadStringUTF16(this Allocation alloc, ulong offset, int maxChars)
    {
        byte[] buffer = new byte[maxChars * 2];
        alloc.Read(offset, buffer);

        int charCount = 0;
        while (charCount < maxChars && !(buffer[charCount * 2] == 0 && buffer[charCount * 2 + 1] == 0))
            charCount++;

        return Encoding.Unicode.GetString(buffer, 0, charCount * 2);
    }

    #endregion

    #region Writing methods.

    public static void WriteByte(this Allocation alloc, ulong offset, byte value)
    {
        Span<byte> buffer = [value];
        alloc.Write(offset, buffer);
    }

    public static void WriteInt32(this Allocation alloc, ulong offset, int value)
    {
        byte[] buffer = BitConverter.GetBytes(value);
        alloc.Write(offset, buffer);
    }

    public static void WriteStringUTF16(this Allocation alloc, ulong offset, string value)
    {
        if (!value.EndsWith('\0')) value += '\0';
        byte[] buffer = Encoding.Unicode.GetBytes(value);
        alloc.Write(offset, buffer);
    }

    #endregion
}