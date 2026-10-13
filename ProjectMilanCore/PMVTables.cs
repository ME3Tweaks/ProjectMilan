using LegendaryExplorerCore.Gammtek.IO;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilan;
using System.Diagnostics;

namespace ProjectMilanCore
{
    public static class VTables
    {
        private const string LOG_CATEGORY = "MILAN-VTables";

        /// <summary>
        /// Verifies that the vtable of a class matches its parent class's vtable. Logs errors if mismatches are found.
        /// </summary>
        /// <param name="classExport"></param>
        /// <param name="cache"></param>
        /// <param name="logIfBad"></param>
        /// <returns></returns>
        public static bool VerifyVTable(ExportEntry classExport, PackageCache cache, bool logIfBad = true)
        {
            if (classExport.SuperClass == null)
            {
                return true;
            }
            ExportEntry parent = null;
            if (classExport.SuperClass is ImportEntry imp)
            {
                parent = EntryImporter.ResolveImport(imp, cache, fileResolver: MilanShared.LE3PackageResolver);
            }
            else
            {
                parent = classExport.SuperClass as ExportEntry;
            }

            if (parent == null)
                Debugger.Break();

            bool vTableBad = false;
            var vTable = GetVTable(classExport);
            var parentVTable = GetVTable(parent);

            if (vTable.Count < parentVTable.Count)
            {
                MilanLog.Error($@"  Invalid VTable size detected in {classExport.InstancedFullPath}: local count = {vTable.Count}, parent count = {parentVTable.Count}", shouldLog: logIfBad, customPrefix: LOG_CATEGORY);
                if (!logIfBad)
                    return false; // Don't check the rest if we are not logging the results.
                vTableBad = true;
            }

            // Only run bad check if we haven't already marked as bad
            if (!vTableBad)
            {
                int i = 0;
                for (; i < parentVTable.Count; i++)
                {
                    if (i < vTable.Count && !vTable[i].CaseInsensitiveEquals(parentVTable[i]))
                    {
                        MilanLog.Error($@"  Bad VTable detected in {classExport.InstancedFullPath}: Local[{i}] = {vTable[i]}, Parent[{i}]={parentVTable[i]}", shouldLog: logIfBad, customPrefix: LOG_CATEGORY);
                        if (!logIfBad)
                            return false; // Don't check the rest if we are not logging the results.
                        vTableBad = true;
                    }
                }
            }

            // True = good
            return !vTableBad;
        }


        private static List<string> GetVTable(ExportEntry export)
        {
            var obj = export.GetBinaryData<UClass>();
            return obj.VirtualFunctionTable.Select(uIdx => export.FileRef.GetEntry(uIdx).ObjectName.Name).ToList();
        }

        /// <summary>
        /// Resolves the parent class ExportEntry for the given class export, traversing imports if necessary.
        /// </summary>
        private static ExportEntry ResolveParentClass(ExportEntry classExport, PackageCache cache)
        {
            if (classExport.SuperClass == null) return null;
            if (classExport.SuperClass is ImportEntry imp)
                return EntryImporter.ResolveImport(imp, cache, fileResolver: MilanShared.LE3PackageResolver);
            return classExport.SuperClass as ExportEntry;
        }

        /// <summary>
        /// Reorders the VTable of <paramref name="classExport"/> so that all functions shared with the parent
        /// appear in the same order as the parent's VTable (prefix), with any class-specific additions appended after.
        /// Returns true if the VTable was modified.
        /// </summary>
        public static bool FixVTableOrder(ExportEntry classExport, PackageCache cache, ref FileLib lib)
        {
            if (classExport.SuperClass == null) return false;

            ExportEntry parent = ResolveParentClass(classExport, cache);
            if (parent == null)
            {
                MilanLog.Warning($"Could not resolve parent class for {classExport.InstancedFullPath} - skipping vtable fix", customPrefix: LOG_CATEGORY);
                return false;
            }

            var parentVTableNames = GetVTable(parent);
            if (parentVTableNames.Count == 0) return false;

            var objBin = classExport.GetBinaryData<UClass>();
            if (objBin.VirtualFunctionTable == null || objBin.VirtualFunctionTable.Length == 0) return false;

            // Build a name→UIndex map from the current vtable
            var currentByName = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var uIdx in objBin.VirtualFunctionTable)
            {
                var e = classExport.FileRef.GetEntry(uIdx);
                if (e != null)
                    currentByName.TryAdd(e.ObjectName.Name, uIdx);
            }

            // Build new vtable: parent order first, then class-specific extras
            var newVTable = new List<int>(objBin.VirtualFunctionTable.Length);
            foreach (var name in parentVTableNames)
            {
                if (!currentByName.TryGetValue(name, out int uIdx))
                {
                    // Missing parent function – can't safely reorder this way
                    // We must recompile this class to have it properly set things back up
                    UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
                    {
                        Cache = cache,
                        CustomFileResolver = MilanShared.LE3PackageResolver,
                        BaseFilesFileLib = LE3FileLibCache.GetBaseFilesFileLibFor(classExport.FileRef),
                    };
                    MilanLog.Information($"  Fixing VTable {classExport.InstancedFullPath} ({classExport.FileRef.FileNameNoExtension}) via class recompile", customPrefix: LOG_CATEGORY);
                    if (lib == null)
                    {
                        lib = new FileLib(classExport.FileRef);
                        if (!lib.Initialize(usop))
                        {
                            MilanShared.LogFailedFileLibInit(lib);
                        }
                    }

                    (_, string text) = UnrealScriptCompiler.DecompileExport(classExport, lib, usop);
                    text = MilanShared.CleanErrorComments(text, out _);
                    var (_, compileLog) = UnrealScriptCompiler.CompileClass(classExport.FileRef, text, lib, usop, classExport);
                    if (compileLog.HasErrors || compileLog.HasLexErrors)
                    {
                        // A failed compile leaves the class untouched. Reporting a change here would make the caller save and retry forever.
                        MilanLog.Error($"  Failed to recompile {classExport.InstancedFullPath} ({classExport.FileRef.FileNameNoExtension}) to fix its VTable - skipping it", customPrefix: LOG_CATEGORY);
                        MilanLog.LogUSCErrors(compileLog);
                        return false;
                    }

                    return true; // We return true to force another pass
                }
                newVTable.Add(uIdx);
            }
            foreach (var uIdx in objBin.VirtualFunctionTable)
            {
                var e = classExport.FileRef.GetEntry(uIdx);
                if (e == null) continue;
                if (!parentVTableNames.Any(p => p.CaseInsensitiveEquals(e.ObjectName.Name)))
                    newVTable.Add(uIdx);
            }

            // Check whether anything actually changed
            if (newVTable.Count == objBin.VirtualFunctionTable.Length
                && newVTable.SequenceEqual(objBin.VirtualFunctionTable.Select(x => (int)x)))
                return false;

            MilanLog.Information($"  Fixing VTable order for {classExport.InstancedFullPath}", customPrefix: LOG_CATEGORY);
            objBin.VirtualFunctionTable = newVTable.ToArray();
            classExport.WriteBinary(objBin);
            return true;
        }

        public static void RecompileAllClasses(IMEPackage package, PackageCache cache)
        {
            MilanLog.Information($"Checking {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                CustomFileResolver = MilanShared.LE3PackageResolver,
                BaseFilesFileLib = LE3FileLibCache.GetBaseFilesFileLibFor(package),
            };
            var lib = new FileLib(package);
            if (!lib.Initialize(usop))
            {
                MilanShared.LogFailedFileLibInit(lib);
            }

            var hadRecomp = false;
            foreach (var export in package.Exports.Where(x => x.IsClass))
            {
                // Only scan exports that contain script bytecode
                (_, string text) = UnrealScriptCompiler.DecompileExport(export, lib, usop);
                text = MilanShared.CleanErrorComments(text, out var needsRecompile);
                if (needsRecompile)
                {
                    MilanLog.Information($" Recompiling {export.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                    var (_, compileLog) = UnrealScriptCompiler.CompileClass(package, text, lib, usop, export);
                    if (compileLog.HasErrors || compileLog.HasLexErrors)
                    {
                        MilanLog.Error($"  Failed to recompile {export.InstancedFullPath} in {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                        MilanLog.LogUSCErrors(compileLog);
                    }
                    else
                    {
                        hadRecomp = true;
                    }
                }
            }

            if (hadRecomp)
            {
                MilanLog.Information($"Saving {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                package.Save();
            }
        }

        /// <summary>
        /// Scans all Function, State, and scripted Class exports in <paramref name="package"/> for
        /// EX_NamedFunction (0x65) bytecode tokens whose vtable index no longer matches the correct
        /// position in the owning class's VTable (as determined from the preceding EX_Context token).
        /// Patches any mismatches in-place and returns true if the package was modified.
        /// </summary>
        public static bool FixNamedFunctionVTableRefs(IMEPackage package, PackageCache cache)
        {
            const int EX_NAMED_FUNCTION = 0x65;

            bool packageModified = false;

            foreach (var export in package.Exports)
            {
                // Only scan exports that contain script bytecode
                bool isScriptable = export.ClassName is "Function" or "State" || export.IsClass;
                if (!isScriptable) continue;

                UStruct objBin;
                try { objBin = ObjectBinary.From(export) as UStruct; }
                catch { continue; }
                if (objBin == null) continue;

                if (objBin.ScriptBytes == null || objBin.ScriptBytes.Length == 0) continue;

                List<BytecodeSingularToken> singularTokens;
                try
                {
                    var parsed = Bytecode.ParseBytecode(objBin.ScriptBytes, export);
                    singularTokens = parsed.Item2;
                }
                catch { continue; }

                if (singularTokens == null || singularTokens.Count == 0) continue;

                // ByteCodeStart is the offset of ScriptBytes within the export data
                int byteCodeStart = export.Game is MEGame.UDK
                    ? (export.IsClass ? 0x28 : 0x30)
                    : (export.IsClass ? 0x18 : 0x20);

                bool exportModified = false;

                for (int i = 0; i < singularTokens.Count; i++)
                {
                    if (i == 0xb)
                        Debugger.Break();
                    var token = singularTokens[i];
                    if (token.OpCode != EX_NAMED_FUNCTION) continue;

                    // Position of EX_NamedFunction within ScriptBytes
                    int funcScriptPos = token.StartPos - byteCodeStart;
                    if (funcScriptPos < 5 || funcScriptPos + 10 >= objBin.ScriptBytes.Length) continue;

                    // --- Determine the class whose VTable to validate against ---
                    int unkRefPos = funcScriptPos - 5;
                    int unkRef = EndianReader.ToInt32(objBin.ScriptBytes, unkRefPos, export.FileRef.Endian);

                    // Use the previous token
                    var prevToken = singularTokens[i - 1];
                    switch (prevToken.OpCode)
                    {
                        case 0x62 when export.ClassName == "State": // EX_InstanceObjectVariable - on state
                            {
                                var classParent = export.Parent as ExportEntry;
                                var uclass = ObjectBinary.From<UClass>(classParent);
                                unkRef = uclass.OuterClass;
                            }
                            break;
                        case 0x62: // EX_InstanceObjectVariable - on function
                            {
                                var classParent = export.Parent as ExportEntry;
                                var uclass = ObjectBinary.From<UClass>(classParent);
                                unkRef = uclass.OuterClass;
                            }
                            break;
                        case 0x5E: // EX_LocalVariable
                        case 0x19: // EX_Context
                            unkRefPos = prevToken.StartPos - byteCodeStart + 1;
                            unkRef = EndianReader.ToInt32(objBin.ScriptBytes, unkRefPos, export.FileRef.Endian);
                            break;
                        default:
                            // Shouldn't be anything else... If it is, it means it is a local one
                            // Get the parent if it's function (class)
                            MilanLog.Warning($@"Opcode 0x{prevToken.OpCode:X2} previous to NamedFunction");
                            unkRef = export.ClassName is "Function" or "State" ? export.Parent.UIndex : export.UIndex;
                            break;
                    }


                    if (unkRef == 0) continue;
                    IEntry contextEntry = package.GetEntry(unkRef);
                    if (contextEntry == null) continue;

                    // Resolve the class that owns contextEntry
                    ExportEntry contextClass = ResolveClassFromContextEntry(contextEntry, cache);
                    if (contextClass == null) continue;

                    // Get that class's VTable names
                    List<string> vTableNames;
                    try { vTableNames = GetVTable(contextClass); }
                    catch { continue; }

                    if (vTableNames.Count == 0) continue;

                    // Read the current function name and funcIndex from ScriptBytes
                    // Layout from start of EX_NamedFunction: [opcode:1][nameIdx:4][nameNumber:4][funcIndex:2]
                    int nameIdx = EndianReader.ToInt32(objBin.ScriptBytes, funcScriptPos + 1, export.FileRef.Endian);
                    string funcName = export.FileRef.GetNameEntry(nameIdx);
                    int currentFuncIndex = EndianReader.ToUInt16(objBin.ScriptBytes, funcScriptPos + 9, export.FileRef.Endian);

                    // Find the correct index in the VTable
                    int correctIndex = -1;
                    for (int vi = 0; vi < vTableNames.Count; vi++)
                    {
                        if (vTableNames[vi].CaseInsensitiveEquals(funcName))
                        {
                            correctIndex = vi;
                            break;
                        }
                    }

                    if (correctIndex < 0)
                    {
                        MilanLog.Warning($"  EX_NamedFunction '{funcName}' not found in VTable of {contextClass.InstancedFullPath} in {export.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                        continue;
                    }

                    if (correctIndex == currentFuncIndex) continue;

                    // Patch the 2-byte funcIndex (little-endian; LE3 is always LE)
                    MilanLog.Information($"  Patching EX_NamedFunction '{funcName}' index {currentFuncIndex} → {correctIndex} in {export.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                    objBin.ScriptBytes[funcScriptPos + 9] = (byte)(correctIndex & 0xFF);
                    objBin.ScriptBytes[funcScriptPos + 10] = (byte)((correctIndex >> 8) & 0xFF);
                    exportModified = true;
                }

                if (exportModified)
                {
                    export.WriteBinary(objBin);
                    packageModified = true;
                }
            }

            return packageModified;
        }

        /// <summary>
        /// Given the ExpressionField entry from an EX_Context token, resolves the owning class export.
        /// </summary>
        private static ExportEntry ResolveClassFromContextEntry(IEntry contextEntry, PackageCache cache)
        {
            // If the entry itself is a class, use it directly
            if (contextEntry is ExportEntry exp && exp.IsClass)
                return exp;

            // Otherwise walk up one level (function/property → owning class)
            IEntry parentEntry = contextEntry.FileRef.GetEntry(contextEntry.idxLink);
            if (parentEntry == null) return null;

            if (parentEntry is ExportEntry parentExp && parentExp.IsClass)
                return parentExp;

            if (parentEntry is ImportEntry parentImp)
            {
                var resolved = EntryImporter.ResolveImport(parentImp, cache, fileResolver: MilanShared.LE3PackageResolver);
                if (resolved?.IsClass == true) return resolved;
            }

            return null;
        }

    }
}
