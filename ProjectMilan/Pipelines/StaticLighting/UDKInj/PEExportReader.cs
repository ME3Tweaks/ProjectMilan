namespace UDKInj;

/// <summary>
/// Resolves the RVA of a named export straight out of a PE (x64) file's own export directory,
/// read from disk.
///
/// This exists so remotely-injected data (a plain <c>__declspec(dllexport)</c> global, not a
/// function) can be located without calling into the target process at all: the DLL on disk and
/// the DLL loaded into the target are the same bytes, so an RVA computed locally is valid
/// remotely too - add it to the module base <c>LoadLibrary</c> returned (see
/// <see cref="Injector.WrapRemoteExport"/>) and that is the live remote address. No
/// GetProcAddress call, no remote thread.
/// </summary>
internal static class PEExportReader
{
    /// <summary>Looks up <paramref name="exportName"/>'s RVA in <paramref name="dllPath"/>'s export table.</summary>
    /// <exception cref="InvalidOperationException">Not a PE32+ (x64) image, or has no export table.</exception>
    /// <exception cref="KeyNotFoundException">The export doesn't exist in this image.</exception>
    public static uint GetExportRva(string dllPath, string exportName)
    {
        byte[] file = File.ReadAllBytes(dllPath);

        uint ntHeaderOffset = ReadUInt32(file, 0x3C);
        uint fileHeaderOffset = ntHeaderOffset + 4; // skip "PE\0\0"
        ushort numberOfSections = ReadUInt16(file, fileHeaderOffset + 2);
        ushort sizeOfOptionalHeader = ReadUInt16(file, fileHeaderOffset + 16);

        uint optionalHeaderOffset = fileHeaderOffset + 20;
        ushort magic = ReadUInt16(file, optionalHeaderOffset);
        if (magic != 0x20B)
            throw new InvalidOperationException(
                $"'{dllPath}' is not a PE32+ (x64) image (magic 0x{magic:X4}) - PEExportReader only handles x64");

        // DataDirectory[0] (export table) sits at a fixed offset in the PE32+ optional header.
        const uint ExportDataDirectoryOffset = 112;
        uint exportTableRva = ReadUInt32(file, optionalHeaderOffset + ExportDataDirectoryOffset);
        if (exportTableRva == 0)
            throw new InvalidOperationException($"'{dllPath}' has no export table");

        uint sectionHeadersOffset = optionalHeaderOffset + sizeOfOptionalHeader;
        var sections = new (uint VirtualAddress, uint VirtualSize, uint PointerToRawData)[numberOfSections];
        for (int i = 0; i < numberOfSections; i++)
        {
            uint sectionOffset = sectionHeadersOffset + (uint)(i * 40);
            sections[i] = (
                VirtualAddress: ReadUInt32(file, sectionOffset + 12),
                VirtualSize: ReadUInt32(file, sectionOffset + 8),
                PointerToRawData: ReadUInt32(file, sectionOffset + 20));
        }

        uint RvaToFileOffset(uint rva)
        {
            foreach (var section in sections)
            {
                if (rva >= section.VirtualAddress && rva < section.VirtualAddress + section.VirtualSize)
                    return rva - section.VirtualAddress + section.PointerToRawData;
            }
            throw new InvalidOperationException($"RVA 0x{rva:X} in '{dllPath}' doesn't fall inside any section");
        }

        uint exportDirOffset = RvaToFileOffset(exportTableRva);
        uint numberOfNames = ReadUInt32(file, exportDirOffset + 24);
        uint addressOfFunctionsRva = ReadUInt32(file, exportDirOffset + 28);
        uint addressOfNamesRva = ReadUInt32(file, exportDirOffset + 32);
        uint addressOfNameOrdinalsRva = ReadUInt32(file, exportDirOffset + 36);

        uint namesTableOffset = RvaToFileOffset(addressOfNamesRva);
        uint ordinalsTableOffset = RvaToFileOffset(addressOfNameOrdinalsRva);
        uint functionsTableOffset = RvaToFileOffset(addressOfFunctionsRva);

        for (uint i = 0; i < numberOfNames; i++)
        {
            uint nameRva = ReadUInt32(file, namesTableOffset + i * 4);
            string name = ReadAsciiString(file, RvaToFileOffset(nameRva));

            if (name != exportName) continue;

            ushort ordinal = ReadUInt16(file, ordinalsTableOffset + i * 2);
            return ReadUInt32(file, functionsTableOffset + (uint)(ordinal * 4));
        }

        throw new KeyNotFoundException($"'{dllPath}' has no export named '{exportName}'");
    }

    static uint ReadUInt32(byte[] file, uint offset) => BitConverter.ToUInt32(file, (int)offset);
    static ushort ReadUInt16(byte[] file, uint offset) => BitConverter.ToUInt16(file, (int)offset);

    static string ReadAsciiString(byte[] file, uint offset)
    {
        int end = (int)offset;
        while (file[end] != 0) end++;
        return System.Text.Encoding.ASCII.GetString(file, (int)offset, end - (int)offset);
    }
}
