#nullable enable
using System.Buffers.Binary;
using System.ComponentModel;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace ProjectMilanCore
{
    /// <summary>
    /// Keeps Game 3 class vtables consistent after classes are edited. A class's vtable has to be its parent's vtable followed
    /// by the class's own new functions, and EX_NamedFunction calls store an index into it. So adding a function to a class
    /// moves every subclass's own functions up, and the calls to them have to move with them.
    /// </summary>
    [Localizable(false)]
    public static class VTableCascade
    {
        /// <summary>
        /// One vtable entry: the function name, and the memory path of the function that implements it for the class.
        /// </summary>
        public readonly record struct VTableSlot(string Name, string Implementation);

        /// <summary>
        /// A function whose vtable index changed in a class.
        /// </summary>
        public readonly record struct VTableShift(string ClassPath, string Name, int OldIndex, int NewIndex);

        /// <summary>
        /// EX_NamedFunction: [opcode][name index int32][name number int32][vtable index ushort].
        /// </summary>
        private const byte EX_NamedFunction = 0x65;

        /// <summary>
        /// The path an entry has in memory, so an export and the imports of it in other packages compare equal.
        /// </summary>
        public static string GetMemoryPath(IEntry entry) => entry is ExportEntry export ? export.MemoryFullPath : entry.InstancedFullPath;

        public static bool IsInterface(ExportEntry classExport) => classExport.GetBinaryData<UClass>().ClassFlags.Has(UnrealFlags.EClassFlags.Interface);

        /// <summary>
        /// Reads a class's vtable. The class's export data must be loaded.
        /// </summary>
        public static List<VTableSlot> ReadSlots(ExportEntry classExport) => ReadEntries(classExport).Select(ToSlot).ToList();

        /// <summary>
        /// Reads the vtable of every class in a package that isn't an interface, by class memory path. Only class export data needs to be loaded.
        /// </summary>
        public static Dictionary<string, List<VTableSlot>> ReadAllSlots(IMEPackage package)
        {
            var slots = new Dictionary<string, List<VTableSlot>>(StringComparer.OrdinalIgnoreCase);
            foreach (var classExport in package.Exports.Where(x => x.IsClass && !IsInterface(x)))
                slots.TryAdd(classExport.MemoryFullPath, ReadSlots(classExport));
            return slots;
        }

        /// <summary>
        /// Functions whose index in a class's vtable differs between two readings of the same classes. Classes only in one are skipped.
        /// </summary>
        public static IEnumerable<VTableShift> FindShifts(IReadOnlyDictionary<string, List<VTableSlot>> before, IReadOnlyDictionary<string, List<VTableSlot>> after)
        {
            foreach (var (classPath, oldSlots) in before)
            {
                if (after.TryGetValue(classPath, out var newSlots))
                {
                    foreach (var shift in FindShifts(classPath, oldSlots, newSlots))
                        yield return shift;
                }
            }
        }

        /// <summary>
        /// Functions whose index in one class's vtable differs between two readings of it. A function that was removed has a new index of -1.
        /// </summary>
        public static IEnumerable<VTableShift> FindShifts(string classPath, List<VTableSlot> before, List<VTableSlot> after)
        {
            for (int i = 0; i < before.Count; i++)
            {
                int newIndex = after.FindIndex(x => x.Name.Equals(before[i].Name, StringComparison.OrdinalIgnoreCase));
                if (newIndex != i)
                    yield return new VTableShift(classPath, before[i].Name, i, newIndex);
            }
        }

        /// <summary>
        /// A class whose vtable differs between two readings of it, by memory path.
        /// </summary>
        public sealed record ClassChange(string ClassPath, List<VTableSlot> Before, List<VTableSlot> After)
        {
            public string ClassName => ClassPath[(ClassPath.LastIndexOf('.') + 1)..];
        }

        /// <summary>
        /// Classes whose vtable differs between two readings of the same classes. Classes only in one are skipped.
        /// </summary>
        public static List<ClassChange> FindChanges(IReadOnlyDictionary<string, List<VTableSlot>> before, IReadOnlyDictionary<string, List<VTableSlot>> after)
        {
            var changes = new List<ClassChange>();
            foreach (var (classPath, oldSlots) in before)
            {
                if (after.TryGetValue(classPath, out var newSlots) && !oldSlots.SequenceEqual(newSlots))
                    changes.Add(new ClassChange(classPath, oldSlots, newSlots));
            }
            return changes;
        }

        /// <summary>
        /// Looks through packages that weren't rebuilt for script the vtable changes leave stale: classes that are or extend a
        /// changed class (which need the cascade), and EX_NamedFunction calls that still use an index a change moved. Classes are
        /// matched by name, and a call by its function name and old index, so it can list a call whose index was right.
        /// Localized packages have no script and are skipped.
        /// </summary>
        /// <param name="classBaseClasses">Every class of the game's base class, by class name, to find the subclasses of changed classes.</param>
        /// <returns>What's stale, one line per problem, each starting with the package file name.</returns>
        public static List<string> FindStaleScript(IEnumerable<string> packageFiles, IReadOnlyCollection<ClassChange> changes, IReadOnlyDictionary<string, string> classBaseClasses)
        {
            // Every class that is or extends a changed class, with the changed class it is or extends
            var affected = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var subclasses = classBaseClasses.Where(x => x.Value != null).ToLookup(x => x.Value, x => x.Key, StringComparer.OrdinalIgnoreCase);
            var pending = new Queue<string>();
            foreach (var change in changes)
            {
                if (affected.TryAdd(change.ClassName, change.ClassName))
                    pending.Enqueue(change.ClassName);
            }
            while (pending.TryDequeue(out var className))
            {
                foreach (var subclass in subclasses[className])
                {
                    if (affected.TryAdd(subclass, affected[className]))
                        pending.Enqueue(subclass);
                }
            }

            var shifts = changes.SelectMany(x => FindShifts(x.ClassPath, x.Before, x.After)).ToList();

            var problems = new List<string>();
            var files = packageFiles.Where(x => Path.GetFileNameWithoutExtension(x).GetUnrealLocalization() == MELocalization.None).ToList();
            Parallel.ForEach(files, new ParallelOptions { MaxDegreeOfParallelism = Math.Max(1, Environment.ProcessorCount / 2) }, file =>
            {
                var fileName = Path.GetFileName(file);
                var found = new List<string>();
                List<(int NameIndex, VTableShift Shift)> calls;
                using (var header = MEPackageHandler.UnsafePartialLoad(file, _ => false))
                {
                    foreach (var classExport in header.Exports.Where(x => x.IsClass))
                    {
                        var className = classExport.ObjectName.Instanced;
                        if (affected.TryGetValue(className, out var changedClass))
                        {
                            found.Add(changedClass.Equals(className, StringComparison.OrdinalIgnoreCase)
                                ? $"{fileName}: has its own copy of {className}, whose vtable changed"
                                : $"{fileName}: {className} extends {changedClass}, whose vtable changed");
                        }
                    }

                    calls = header.Exports.Any(x => x.ClassName is "Function" or "State")
                        ? shifts.Select(x => (NameIndex: header.findName(x.Name), Shift: x)).Where(x => x.NameIndex >= 0).ToList()
                        : [];
                }

                if (calls.Count > 0)
                {
                    using var script = MEPackageHandler.UnsafePartialLoad(file, x => x.ClassName is "Function" or "State");
                    foreach (var export in script.Exports.Where(x => x.ClassName is "Function" or "State"))
                    {
                        foreach (var (nameIndex, shift) in calls)
                        {
                            if (ContainsNamedFunctionCall(export.DataReadOnly, nameIndex, shift.OldIndex))
                                found.Add($"{fileName}: {export.InstancedFullPath} calls {shift.Name} with vtable index {shift.OldIndex}, {(shift.NewIndex < 0 ? $"which {shift.ClassPath} no longer has" : $"which {shift.ClassPath} now has at {shift.NewIndex}")}");
                        }
                    }
                }

                if (found.Count > 0)
                {
                    lock (problems)
                        problems.AddRange(found);
                }
            });

            problems.Sort(StringComparer.OrdinalIgnoreCase);
            return problems;
        }

        /// <summary>
        /// Rebuilds the vtable of every class in <paramref name="package"/>, parents first, as its parent's current vtable followed by
        /// the class's own entries the parent doesn't have, in their existing order. An inherited slot points at the class's own
        /// function of that name if it has one, otherwise at whatever the parent's slot points at, imported if it's in another package.
        /// </summary>
        /// <param name="resolveClass">Resolves a parent class that's an import. Its vtable is taken as final.</param>
        /// <returns>The classes whose vtable changed.</returns>
        public static List<ExportEntry> Rebuild(IMEPackage package, Func<ImportEntry, ExportEntry?> resolveClass)
        {
            var rebuilder = new Rebuilder(package, resolveClass);
            foreach (var classExport in package.Exports.Where(x => x.IsClass))
                rebuilder.Rebuild(classExport);
            return rebuilder.Changed;
        }

        /// <summary>
        /// Function and state exports whose data contains an EX_NamedFunction naming one of <paramref name="names"/>. This
        /// is a byte search, so it can return exports that don't make such a call; it never misses one that does.
        /// </summary>
        public static List<ExportEntry> FindNamedFunctionCallers(IMEPackage package, IEnumerable<string> names)
        {
            var patterns = new List<byte[]>();
            foreach (var name in names.Distinct(StringComparer.OrdinalIgnoreCase))
            {
                int nameIndex = package.findName(name);
                if (nameIndex < 0)
                    continue;

                var pattern = new byte[5];
                pattern[0] = EX_NamedFunction;
                BinaryPrimitives.WriteInt32LittleEndian(pattern.AsSpan(1), nameIndex);
                patterns.Add(pattern);
            }

            if (patterns.Count == 0)
                return [];

            return package.Exports.Where(x => x.ClassName is "Function" or "State" && patterns.Any(p => x.DataReadOnly.IndexOf(p) >= 0)).ToList();
        }

        /// <summary>
        /// If <paramref name="data"/> contains an EX_NamedFunction call to the name at <paramref name="nameIndex"/> with vtable index <paramref name="vtableIndex"/>.
        /// </summary>
        public static bool ContainsNamedFunctionCall(ReadOnlySpan<byte> data, int nameIndex, int vtableIndex)
        {
            Span<byte> pattern = stackalloc byte[11];
            pattern[0] = EX_NamedFunction;
            BinaryPrimitives.WriteInt32LittleEndian(pattern[1..], nameIndex);
            BinaryPrimitives.WriteInt32LittleEndian(pattern[5..], 0); // Name number
            BinaryPrimitives.WriteUInt16LittleEndian(pattern[9..], (ushort)vtableIndex);
            return data.IndexOf(pattern) >= 0;
        }

        /// <summary>
        /// Rewrites the vtable index of EX_NamedFunction calls in a function or state, in place, so the rest of its bytecode stays
        /// byte for byte the same. The bytecode is parsed into tokens, so only real calls are touched.
        /// </summary>
        /// <param name="fix">Given a call's function name and vtable index, returns the index it should have, or null to leave it.</param>
        /// <returns>The number of calls changed.</returns>
        public static int PatchNamedFunctionCalls(ExportEntry export, Func<string, int, int?> fix)
        {
            var script = (UStruct)ObjectBinary.From(export);
            int changed = 0;
            foreach (var (offset, name, index) in ReadNamedFunctionCalls(export, script))
            {
                if (fix(name, index) is int newIndex && newIndex != index)
                {
                    BinaryPrimitives.WriteUInt16LittleEndian(script.ScriptBytes.AsSpan(offset + 9), (ushort)newIndex);
                    changed++;
                }
            }

            if (changed > 0)
                export.WriteBinary(script);
            return changed;
        }

        /// <summary>
        /// The EX_NamedFunction calls in a function or state's bytecode: function name and vtable index.
        /// </summary>
        public static List<(string Name, int Index)> ReadNamedFunctionCalls(ExportEntry export) =>
            ReadNamedFunctionCalls(export, (UStruct)ObjectBinary.From(export)).Select(x => (x.Name, x.Index)).ToList();

        /// <summary>
        /// The EX_NamedFunction calls in a function or state's bytecode, with the offset of each in the script bytes.
        /// </summary>
        private static List<(int Offset, string Name, int Index)> ReadNamedFunctionCalls(ExportEntry export, UStruct script)
        {
            var calls = new List<(int Offset, string Name, int Index)>();
            var bytes = script.ScriptBytes;
            if (bytes == null || bytes.Length == 0)
                return calls;

            var (statements, tokens) = Bytecode.ParseBytecode(bytes, export);
            var failure = statements.FirstOrDefault(x => x.raw.Length == 0 && x.text != null && (x.text.StartsWith("Exception") || x.text.StartsWith("Final parsing pos")));
            if (failure != null)
                throw new Exception($"Unable to parse the bytecode of {export.InstancedFullPath}: {failure.text}");

            // Token positions count from where the script starts in the export's binary
            int scriptStart = export.IsClass ? 0x18 : 0x20;
            foreach (var token in tokens.Where(x => x.OpCode == EX_NamedFunction))
            {
                int offset = token.StartPos - scriptStart;
                var name = new NameReference(export.FileRef.GetNameEntry(BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(offset + 1))),
                    BinaryPrimitives.ReadInt32LittleEndian(bytes.AsSpan(offset + 5)));
                calls.Add((offset, name.Instanced, BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(offset + 9))));
            }
            return calls;
        }

        /// <summary>
        /// The new index of each function whose vtable index moved, keyed by upper-case name and old index, for
        /// <see cref="PatchNamedFunctionCalls"/>. A name and old index that moved to different places in different
        /// classes, or that a class no longer has, can't be fixed from the index alone and is left out.
        /// </summary>
        public static Func<string, int, int?> GetMoves(IEnumerable<VTableShift> shifts)
        {
            var moves = new Dictionary<(string Name, int OldIndex), int>();
            var unfixable = new HashSet<(string Name, int OldIndex)>();
            foreach (var shift in shifts)
            {
                var key = (shift.Name.ToUpperInvariant(), shift.OldIndex);
                if (shift.NewIndex < 0 || (moves.TryGetValue(key, out var existing) && existing != shift.NewIndex))
                    unfixable.Add(key);
                else
                    moves[key] = shift.NewIndex;
            }
            foreach (var key in unfixable)
                moves.Remove(key);

            return (name, index) => moves.TryGetValue((name.ToUpperInvariant(), index), out var newIndex) ? newIndex : null;
        }

        private static VTableSlot ToSlot(IEntry entry) => new(entry.ObjectName.Instanced, GetMemoryPath(entry));

        private static List<IEntry> ReadEntries(ExportEntry classExport)
        {
            var vtable = classExport.GetBinaryData<UClass>().VirtualFunctionTable ?? [];
            var entries = new List<IEntry>(vtable.Length);
            foreach (int uIndex in vtable)
            {
                entries.Add(classExport.FileRef.GetEntry(uIndex)
                    ?? throw new Exception($"{classExport.MemoryFullPath} has an invalid vtable entry {uIndex}"));
            }
            return entries;
        }

        private sealed class Rebuilder
        {
            private readonly IMEPackage package;
            private readonly Func<ImportEntry, ExportEntry?> resolveClass;

            /// <summary>Entries of this package by memory path, for reusing what's already there.</summary>
            private readonly Dictionary<string, IEntry> entriesByPath = new(StringComparer.OrdinalIgnoreCase);

            /// <summary>Each class's own functions by name, by class UIndex.</summary>
            private readonly Dictionary<int, Dictionary<string, ExportEntry>> functionsByClass = new();

            /// <summary>Final vtable of each class of this package that's been rebuilt.</summary>
            private readonly Dictionary<ExportEntry, List<IEntry>> rebuilt = new();

            public readonly List<ExportEntry> Changed = new();

            public Rebuilder(IMEPackage package, Func<ImportEntry, ExportEntry?> resolveClass)
            {
                this.package = package;
                this.resolveClass = resolveClass;

                foreach (var export in package.Exports)
                {
                    entriesByPath.TryAdd(export.MemoryFullPath, export);
                    if (export.ClassName == "Function" && export.Parent is ExportEntry { IsClass: true } owner)
                    {
                        if (!functionsByClass.TryGetValue(owner.UIndex, out var functions))
                            functionsByClass[owner.UIndex] = functions = new Dictionary<string, ExportEntry>(StringComparer.OrdinalIgnoreCase);
                        functions.TryAdd(export.ObjectName.Instanced, export);
                    }
                }
                foreach (var import in package.Imports)
                    entriesByPath.TryAdd(import.InstancedFullPath, import);
            }

            /// <summary>
            /// Returns the final vtable of a class, rebuilding it first if it's in this package. A class in another package is taken as final.
            /// </summary>
            public List<IEntry> Rebuild(ExportEntry classExport)
            {
                if (classExport.FileRef != package)
                    return ReadEntries(classExport);
                if (rebuilt.TryGetValue(classExport, out var done))
                    return done;

                var current = ReadEntries(classExport);
                if (classExport.SuperClass == null || IsInterface(classExport))
                {
                    rebuilt[classExport] = current;
                    return current;
                }

                var parent = classExport.SuperClass as ExportEntry ?? resolveClass((ImportEntry)classExport.SuperClass)
                    ?? throw new Exception($"Unable to resolve {classExport.MemoryFullPath}'s parent class {classExport.SuperClass.InstancedFullPath}");
                var parentEntries = Rebuild(parent);
                var ownFunctions = functionsByClass.GetValueOrDefault(classExport.UIndex) ?? new Dictionary<string, ExportEntry>();

                var entries = new List<IEntry>(Math.Max(current.Count, parentEntries.Count));
                var parentNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (var parentEntry in parentEntries)
                {
                    var name = parentEntry.ObjectName.Instanced;
                    parentNames.Add(name);
                    entries.Add(ownFunctions.TryGetValue(name, out var own) ? own : GetOrAddEntry(parentEntry));
                }

                foreach (var entry in current)
                {
                    if (parentNames.Contains(entry.ObjectName.Instanced))
                        continue;
                    if (entry.Parent != classExport)
                        throw new Exception($"{classExport.MemoryFullPath}'s vtable has {GetMemoryPath(entry)}, which is neither in its parent {parent.MemoryFullPath}'s vtable nor one of its own functions");
                    entries.Add(entry);
                }

                if (!entries.Select(x => x.UIndex).SequenceEqual(current.Select(x => x.UIndex)))
                {
                    var uClass = classExport.GetBinaryData<UClass>();
                    uClass.VirtualFunctionTable = entries.Select(x => x.UIndex).ToArray();
                    classExport.WriteBinary(uClass);
                    Changed.Add(classExport);
                }

                rebuilt[classExport] = entries;
                return entries;
            }

            /// <summary>
            /// Returns this package's entry for <paramref name="source"/>, which may be in another package, importing it if it's not here yet.
            /// </summary>
            private IEntry GetOrAddEntry(IEntry source)
            {
                var path = GetMemoryPath(source);
                if (entriesByPath.TryGetValue(path, out var existing))
                    return existing;

                IEntry? parent = null;
                if (source.Parent != null)
                    parent = GetOrAddEntry(source.Parent);
                else if (source is ExportEntry { IsForcedExport: false })
                    parent = GetOrAddPackage(path.Split('.')[0]); // A non-forced export's outermost package is its file

                var import = new ImportEntry(package, parent?.UIndex ?? 0, source.ObjectName)
                {
                    ClassName = source.ClassName,
                    PackageFile = source switch
                    {
                        ImportEntry sourceImport => sourceImport.PackageFile,
                        ExportEntry { Class: { } sourceClass } => GetMemoryPath(sourceClass).Split('.')[0],
                        _ => "Core" // A class
                    }
                };
                package.AddImport(import);
                entriesByPath[path] = import;
                return import;
            }

            private IEntry GetOrAddPackage(string name)
            {
                if (entriesByPath.TryGetValue(name, out var existing))
                    return existing;

                var import = new ImportEntry(package, 0, NameReference.FromInstancedString(name)) { ClassName = "Package", PackageFile = "Core" };
                package.AddImport(import);
                entriesByPath[name] = import;
                return import;
            }
        }
    }
}
