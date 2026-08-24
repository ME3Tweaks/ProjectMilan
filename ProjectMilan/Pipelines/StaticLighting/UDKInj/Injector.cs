using System.Buffers.Binary;
using System.ComponentModel;
using System.Diagnostics;
using System.Text;

using Iced.Intel;
using static Iced.Intel.AssemblerRegisters;

namespace UDKInj;


/// <summary>
/// Exposes simple interface to inject and optionally eject <c>.dll</c> libraries from a process.
/// </summary>
public sealed class Injector : IDisposable
{
    readonly ProcessHandle _processHandle;
    readonly bool _disposeProcessHandle;

    readonly Allocation _inputBufferAllocation;
    readonly Allocation _outputBufferAllocation;
    readonly Allocation _paramStructAllocation;

    readonly Dictionary<string, IntPtr> _loadedLibraries = [];


    /// <summary>Number of bytes allocated for internal parameters buffer.</summary>
    const int InputBufferSize = 1024;
    /// <summary>Number of bytes allocated for internal return value buffer.</summary>
    const int OutputBufferSize = 1024;


    /// <param name="processHandle">Handle to the target process.</param>
    /// <param name="bDisposeProcess">Whether disposing this injector should automatically dispose <c>processHandle</c>.</param>
    public Injector(ProcessHandle processHandle, bool bDisposeProcess)
    {
        _processHandle = processHandle;
        _disposeProcessHandle = bDisposeProcess;

        _inputBufferAllocation = new(_processHandle, InputBufferSize);
        _outputBufferAllocation = new(_processHandle, OutputBufferSize);
        _paramStructAllocation = new(_processHandle, 8 + 8);

        {
            Span<byte> paramStructBytes = stackalloc byte[16];
            BinaryPrimitives.WriteIntPtrLittleEndian(paramStructBytes[0..8], _inputBufferAllocation.Pointer);
            BinaryPrimitives.WriteIntPtrLittleEndian(paramStructBytes[8..16], _outputBufferAllocation.Pointer);

            _paramStructAllocation.Write(0, paramStructBytes);
        }
    }


    /// <summary>
    /// Constructs a new <see cref="Allocation"/>.
    /// </summary>
    public Allocation MakeAllocation(ulong size) => new (_processHandle, size);

    /// <summary>
    /// Wraps a named data export (a plain <c>__declspec(dllexport)</c> global, not a function) of
    /// an already-injected library as a non-owning <see cref="Allocation"/>, resolved by parsing
    /// the DLL's own export table on disk (see <see cref="PEExportReader"/>) rather than calling
    /// <c>GetProcAddress</c> remotely. No allocation, no remote thread.
    /// </summary>
    public Allocation WrapRemoteExport(FileInfo dllFileInfo, string exportName, ulong size) =>
        WrapRemoteExport(dllFileInfo, exportName, fieldOffset: 0, size: size);

    /// <summary>As <see cref="WrapRemoteExport(FileInfo, string, ulong)"/>, but for a sub-field of the export.</summary>
    public Allocation WrapRemoteExport(FileInfo dllFileInfo, string exportName, int fieldOffset, ulong size)
    {
        if (!_loadedLibraries.TryGetValue(dllFileInfo.FullName, out IntPtr moduleBase))
            throw new InvalidOperationException($"library {dllFileInfo.FullName} is not loaded");

        uint rva = PEExportReader.GetExportRva(dllFileInfo.FullName, exportName);
        return Allocation.Wrap(_processHandle, moduleBase + (int)rva + fieldOffset, size);
    }


    /// <summary>
    /// Injects a <c>.dll</c> library found on disk into the target process.
    /// </summary>
    /// <param name="dllFileInfo">File information about the injected <c>.dll</c> library.</param>
    /// <exception cref="InvalidOperationException">If this <c>.dll</c> library has already been loaded and has not been unloaded since.</exception>
    /// <exception cref="ArgumentException">If <c>dllFileInfo</c> is not a real file.</exception>
    /// <exception cref="Win32Exception">If the remote <c>LoadLibraryA</c> call fails.</exception>
    public void Inject(FileInfo dllFileInfo)
    {
        if (_loadedLibraries.ContainsKey(dllFileInfo.FullName))
            throw new InvalidOperationException($"library {dllFileInfo.FullName} is already loaded");

        if (!dllFileInfo.Exists || dllFileInfo.Attributes.HasFlag(FileAttributes.Directory))
            throw new ArgumentException($"library {dllFileInfo.FullName} is not a real file", nameof(dllFileInfo));

        byte[] fullPathBytes = Encoding.ASCII.GetBytes(dllFileInfo.FullName);

        byte[] inputBuffer = new byte[fullPathBytes.Length + 2];
        byte[] outputBuffer = new byte[12 /* sizeof(HMODULE) + sizeof(DWORD) */];

        {
            Array.Fill<byte>(inputBuffer, 0x00);
            Array.Copy(fullPathBytes, inputBuffer, fullPathBytes.Length);
        }

        Execute(inputBuffer, outputBuffer, (asm) =>
        {
            asm.mov(r12, __qword_ptr[rcx]);
            asm.mov(r13, __qword_ptr[rcx + 8]);

            asm.mov(rcx, r12);
            asm.mov(rax, LoadLibraryAddress);
            asm.call(rax);
            asm.mov(__qword_ptr[r13], rax);

            asm.mov(rax, GetLastErrorAddress);
            asm.call(rax);
            asm.mov(__dword_ptr[r13 + 8], eax);
        });

        var dllHandle = BinaryPrimitives.ReadIntPtrLittleEndian(outputBuffer);
        var lastError = BinaryPrimitives.ReadInt32LittleEndian(outputBuffer.AsSpan()[4..8]);
        if (dllHandle == IntPtr.Zero) throw new Win32Exception(lastError);

        _loadedLibraries.Add(dllFileInfo.FullName, dllHandle);
    }

    /// <summary>
    /// Ejects a <c>.dll</c> library previously injected via <see cref="Inject(FileInfo)"/>.
    /// </summary>
    /// <param name="dllFileInfo">File information about the ejected <c>.dll</c> library.</param>
    /// <exception cref="InvalidOperationException">If this <c>.dll</c> library has not been loaded or has already been unloaded.</exception>
    /// <exception cref="Win32Exception">If the remote <c>FreeLibrary</c> call fails.</exception>
    public void Eject(FileInfo dllFileInfo)
    {
        if (!_loadedLibraries.TryGetValue(dllFileInfo.FullName, out IntPtr dllModuleHandle))
            throw new InvalidOperationException($"library {dllFileInfo.FullName} is not loaded");

        byte[] inputBuffer = new byte[8 /* sizeof(HMODULE) */];
        byte[] outputBuffer = new byte[8 /* sizeof(BOOL) + sizeof(DWORD) */];

        BinaryPrimitives.WriteIntPtrLittleEndian(inputBuffer, dllModuleHandle);
        BinaryPrimitives.WriteInt32LittleEndian(outputBuffer, 0);

        Execute(inputBuffer, outputBuffer, (asm) =>
        {
            asm.mov(r12, __qword_ptr[rcx]);
            asm.mov(r13, __qword_ptr[rcx + 8]);

            asm.mov(rcx, __qword_ptr[r12]);
            asm.mov(rax, FreeLibraryAddress);
            asm.call(rax);
            asm.mov(__dword_ptr[r13], eax);

            asm.mov(rax, GetLastErrorAddress);
            asm.call(rax);
            asm.mov(__dword_ptr[r13 + 4], eax);
        });

        var returnValue = BinaryPrimitives.ReadInt32LittleEndian(outputBuffer.AsSpan()[0..4]);
        var lastError = BinaryPrimitives.ReadInt32LittleEndian(outputBuffer.AsSpan()[4..8]);
        if (returnValue == 0) throw new Win32Exception(lastError);

        _loadedLibraries.Remove(dllFileInfo.FullName);
    }


    /// <summary>
    /// Executes an exported procedure within the attached <c>.dll</c> library without any input / output.
    /// </summary>
    /// <param name="dllFileInfo">File information about the injected <c>.dll</c> library.</param>
    /// <param name="exportProcedure">Name of the exported procedure to call.</param>
    /// <exception cref="InvalidOperationException">If this <c>.dll</c> library has not been loaded or has already been unloaded.</exception>
    /// <exception cref="Win32Exception">If the remote <c>GetProcessAddress</c> call fails.</exception>
    public void Call(FileInfo dllFileInfo, string exportProcedure)
    {
        Allocation emptyInput = new(_processHandle, 1);
        Allocation emptyOutput = new(_processHandle, 1);

        CallWithParams(dllFileInfo, exportProcedure, emptyInput, emptyOutput);
    }

    /// <summary>
    /// Executes an exported procedure within the attached <c>.dll</c> library.
    /// </summary>
    /// <param name="dllFileInfo">File information about the injected <c>.dll</c> library.</param>
    /// <param name="exportProcedure">Name of the exported procedure to call.</param>
    /// <param name="inputParams">Remotely-allocated buffer with input stuff, the <c>exportProcedure</c> will receive it in <c>rcx</c>.</param>
    /// <param name="outputParams">Remotely-allocated buffer with output stuff, the <c>exportProcedure</c> will receive it in <c>rdx</c>.</param>
    /// <exception cref="InvalidOperationException">If this <c>.dll</c> library has not been loaded or has already been unloaded.</exception>
    /// <exception cref="Win32Exception">If the remote <c>GetProcessAddress</c> call fails.</exception>
    public void CallWithParams(FileInfo dllFileInfo, string exportProcedure, Allocation inputParams, Allocation outputParams)
    {
        if (!_loadedLibraries.TryGetValue(dllFileInfo.FullName, out IntPtr dllModuleHandle))
            throw new InvalidOperationException($"library {dllFileInfo.FullName} is not loaded");

        var exportProcedureAscii = Encoding.ASCII.GetBytes(exportProcedure);

        byte[] inputBuffer = new byte[24 /* sizeof(HMODULE) x 3 */ + exportProcedureAscii.Length + 1];
        byte[] outputBuffer = new byte[8 /* sizeof(BOOL) + sizeof(DWORD) */];

        BinaryPrimitives.WriteIntPtrLittleEndian(inputBuffer.AsSpan()[0..8], dllModuleHandle);
        BinaryPrimitives.WriteIntPtrLittleEndian(inputBuffer.AsSpan()[8..16], inputParams.Pointer);
        BinaryPrimitives.WriteIntPtrLittleEndian(inputBuffer.AsSpan()[16..24], outputParams.Pointer);
        Array.Copy(exportProcedureAscii, 0, inputBuffer, 24, exportProcedureAscii.Length);
        inputBuffer[^1] = 0;

        BinaryPrimitives.WriteInt32LittleEndian(outputBuffer, 0);

        Execute(inputBuffer, outputBuffer, (asm) =>
        {
            asm.mov(r12, __qword_ptr[rcx]);
            asm.mov(r13, __qword_ptr[rcx + 8]);

            // Call GetProcAddress(module, name).
            asm.mov(rcx, __qword_ptr[r12]);
            asm.lea(rdx, __qword_ptr[r12 + 24]);
            asm.mov(rax, GetProcAddressAddress);
            asm.call(rax);
            asm.mov(r14, rax);

            // Always fill in default result value and GLE.
            asm.mov(__dword_ptr[r13], 0);
            asm.mov(rax, GetLastErrorAddress);
            asm.call(rax);
            asm.mov(__dword_ptr[r13 + 4], eax);

            // Check if GetProcessAddress() failed.
            asm.test(r14, r14);
            asm.jz(asm.@F);

            // Call the returned proc address.
            asm.mov(__dword_ptr[r13], 1);
            asm.mov(rcx, __qword_ptr[r12 + 8]);
            asm.mov(rdx, __qword_ptr[r12 + 16]);
            asm.call(r14);

            asm.AnonymousLabel();
        });

        var returnValue = BinaryPrimitives.ReadInt32LittleEndian(outputBuffer.AsSpan()[0..4]);
        var lastError = BinaryPrimitives.ReadInt32LittleEndian(outputBuffer.AsSpan()[4..8]);
        if (returnValue == 0) throw new Win32Exception(lastError);
    }


    #region Remote code execution.

    static int AlignToMultiple(int value, int align) => (value + align - 1) / align * align;

    static int EstimateAssemblySize(Assembler asm)
    {
        using var stream = new MemoryStream();
        asm.Assemble(new StreamCodeWriter(stream), 0);
        return AlignToMultiple((int)stream.Length, 256);
    }

    static byte[] BuildAssembly(Assembler asm, ulong rip)
    {
        using var stream = new MemoryStream();
        asm.Assemble(new StreamCodeWriter(stream), rip);
        return stream.ToArray();
    }

    /// <summary>Executes a manually-constructed piece of assembly code in a new remote thread, without input or output data.</summary>
    /// <param name="writeAssemblyBody">Callback that generates body of code to execute.</param>
    public void Execute(Action<Assembler> writeAssemblyBody) => Execute([], [], writeAssemblyBody);

    /// <summary>Executes a manually-constructed piece of assembly code in a new remote thread.</summary>
    /// <param name="inputBuffer">Buffer which contains serialized parameters to copy into internal parameter buffer.</param>
    /// <param name="outputBuffer">Buffer which will receive a copy of data from the internal return value buffer.</param>
    /// <param name="writeAssemblyBody">Callback that generates body of code to execute.</param>
    public void Execute(ReadOnlySpan<byte> inputBuffer, Span<byte> outputBuffer, Action<Assembler> writeAssemblyBody)
    {
        if (inputBuffer.Length >= InputBufferSize) throw new ArgumentException("input buffer too large", nameof(inputBuffer));
        if (outputBuffer.Length >= OutputBufferSize) throw new ArgumentException("output buffer too large", nameof(outputBuffer));

        _inputBufferAllocation.MemFillDebug();
        _outputBufferAllocation.MemFillDebug();

        if (!inputBuffer.IsEmpty)
        {
            // Copy input arguments to the process-side input buffer.
            _inputBufferAllocation.Write(0, inputBuffer);
        }

        Assembler localAssembler = new(64);

        localAssembler.mov(rbp, rsp);
        localAssembler.sub(rsp, 32);
        localAssembler.and(rsp, -15);
        writeAssemblyBody(localAssembler);
        localAssembler.xor(rax, rax);
        localAssembler.mov(rsp, rbp);
        localAssembler.ret();

        var alignedLength = (ulong)EstimateAssemblySize(localAssembler);
        var allocatedBuffer = _processHandle.Alloc(alignedLength);

        try
        {
            var assembledBinary = BuildAssembly(localAssembler, (ulong)allocatedBuffer);

            _processHandle.WriteMemoryChecked(allocatedBuffer, assembledBinary);
            _processHandle.ProtectExecutable(allocatedBuffer, alignedLength);

            var remoteThread = _processHandle.CreateThread(allocatedBuffer, _paramStructAllocation.Pointer, out uint remoteThreadId);
            Debug.WriteLine($"created remote thread with id = {remoteThreadId}, will wait until it's done");

            Windows.WaitForSingleObject(remoteThread);
            Windows.CloseHandle(remoteThread);
        }
        finally
        {
            _processHandle.Free(allocatedBuffer);
        }


        if (!outputBuffer.IsEmpty)
        {
            // Extract bytes from the process-side output buffer.
            _outputBufferAllocation.Read(0, outputBuffer);
        }
    }

    #endregion

    #region Kernel32.dll functions discovery.

    IntPtr _loadLibraryAddress = IntPtr.Zero;
    public IntPtr LoadLibraryAddress
    {
        get
        {
            if (_loadLibraryAddress == IntPtr.Zero)
            {
                IntPtr moduleHandle = Invoke.GetModuleHandleA("kernel32.dll");
                Windows.ThrowIf(moduleHandle == IntPtr.Zero, "failed to find kernel32.dll module handle");

                _loadLibraryAddress = Invoke.GetProcAddress(moduleHandle, "LoadLibraryA");
                Windows.ThrowIf(_loadLibraryAddress == IntPtr.Zero, "failed to find LoadLibraryA proc handle");
            }

            return _loadLibraryAddress;
        }
    }

    IntPtr _freeLibraryAddress = IntPtr.Zero;
    public IntPtr FreeLibraryAddress
    {
        get
        {
            if (_freeLibraryAddress == IntPtr.Zero)
            {
                IntPtr moduleHandle = Invoke.GetModuleHandleA("kernel32.dll");
                Windows.ThrowIf(moduleHandle == IntPtr.Zero, "failed to find kernel32.dll module handle");

                _freeLibraryAddress = Invoke.GetProcAddress(moduleHandle, "FreeLibrary");
                Windows.ThrowIf(_freeLibraryAddress == IntPtr.Zero, "failed to find FreeLibrary proc handle");
            }

            return _freeLibraryAddress;
        }
    }

    IntPtr _getLastErrorAddress = IntPtr.Zero;
    public IntPtr GetLastErrorAddress
    {
        get
        {
            if (_getLastErrorAddress == IntPtr.Zero)
            {
                IntPtr moduleHandle = Invoke.GetModuleHandleA("kernel32.dll");
                Windows.ThrowIf(moduleHandle == IntPtr.Zero, "failed to find kernel32.dll module handle");

                _getLastErrorAddress = Invoke.GetProcAddress(moduleHandle, "GetLastError");
                Windows.ThrowIf(_getLastErrorAddress == IntPtr.Zero, "failed to find GetLastError proc handle");
            }

            return _getLastErrorAddress;
        }
    }

    IntPtr _getProcAddressAddress = IntPtr.Zero;
    public IntPtr GetProcAddressAddress
    {
        get
        {
            if (_getProcAddressAddress == IntPtr.Zero)
            {
                IntPtr moduleHandle = Invoke.GetModuleHandleA("kernel32.dll");
                Windows.ThrowIf(moduleHandle == IntPtr.Zero, "failed to find kernel32.dll module handle");

                _getProcAddressAddress = Invoke.GetProcAddress(moduleHandle, "GetProcAddress");
                Windows.ThrowIf(_getProcAddressAddress == IntPtr.Zero, "failed to find GetProcAddress proc handle");
            }

            return _getProcAddressAddress;
        }
    }

    #endregion

    #region IDisposable implementation.
    private bool _disposed;
    private void Dispose(bool disposing)
    {
        if (!_disposed)
        {
            if (disposing)
            {
                if (_disposeProcessHandle)
                    _processHandle.Dispose();

                _inputBufferAllocation.Dispose();
                _outputBufferAllocation.Dispose();
                _paramStructAllocation.Dispose();
            }

            _disposed = true;
        }
    }
    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }
    #endregion
}
