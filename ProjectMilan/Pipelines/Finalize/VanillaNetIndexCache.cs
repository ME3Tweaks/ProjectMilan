using System.IO.Compression;
using System.Security.Cryptography;
using System.Text;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.NetIndexing;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Finalize
{
    /// <summary>
    /// What one LE3 linker looks like across the vanilla game, after <see cref="VanillaNetIndexBuilder"/> resolved the
    /// disagreements between files into a single canonical net index per object.
    /// </summary>
    public sealed class VanillaLinkerInfo
    {
        private readonly byte[] _payload;
        private readonly int _objectOffset;
        private readonly int _objectLength;
        private readonly int _objectCount;
        private readonly Lazy<Dictionary<string, int>> _objects;

        internal VanillaLinkerInfo(string name, int maxNetIndex, int maxDeclaredCount,
            IReadOnlyList<(Guid Guid, int Count, DeclarationSource Source)> declarations, bool hasObjectMap,
            byte[] payload, int objectOffset, int objectLength, int objectCount)
        {
            Name = name;
            MaxNetIndex = maxNetIndex;
            MaxDeclaredCount = maxDeclaredCount;
            Declarations = declarations;
            HasObjectMap = hasObjectMap;
            _payload = payload;
            _objectOffset = objectOffset;
            _objectLength = objectLength;
            _objectCount = objectCount;
            _objects = new Lazy<Dictionary<string, int>>(ReadObjects, LazyThreadSafetyMode.ExecutionAndPublication);
        }

        public string Name { get; }

        /// <summary>Highest canonical net index in the linker, after collisions were resolved by moving the losers past the old maximum. -1 if no object has one.</summary>
        public int MaxNetIndex { get; }

        /// <summary>Largest net object count any vanilla declaration of the linker carries, or -1 if none carries one.</summary>
        public int MaxDeclaredCount { get; }

        /// <summary>The distinct (guid, count, where declared) values vanilla files declare this linker with, in a stable order.</summary>
        public IReadOnlyList<(Guid Guid, int Count, DeclarationSource Source)> Declarations { get; }

        /// <summary>
        /// True if the full object to net index map is stored: the linker is declared by a root forced-export Package in at
        /// least one vanilla file. File-only linkers keep the summary only; patch such a file from its own vanilla exports.
        /// </summary>
        public bool HasObjectMap { get; }

        /// <summary>Number of objects in the stored map (0 when <see cref="HasObjectMap"/> is false).</summary>
        public int ObjectCount => _objectCount;

        /// <summary>
        /// Looks up the canonical net index of a linker-qualified object key (see <see cref="NetIndexKeys.GetLinkerQualifiedPath"/>), case-insensitively.
        /// True with -1 for an object vanilla never numbers: it is known, so it must not be allocated an index.
        /// </summary>
        public bool TryGetNetIndex(string key, out int netIndex)
        {
            if (!HasObjectMap)
            {
                netIndex = -1;
                return false;
            }

            return _objects.Value.TryGetValue(key, out netIndex);
        }

        /// <summary>Every (object key, canonical net index; -1 if vanilla never numbers it) of the stored map, in key order.</summary>
        public IEnumerable<KeyValuePair<string, int>> Objects => HasObjectMap ? _objects.Value : [];

        private Dictionary<string, int> ReadObjects()
        {
            var map = new Dictionary<string, int>(_objectCount, StringComparer.OrdinalIgnoreCase);
            if (_objectCount == 0)
                return map;

            using var reader = new BinaryReader(new MemoryStream(_payload, _objectOffset, _objectLength, writable: false), Encoding.UTF8);
            string previous = "";
            for (int i = 0; i < _objectCount; i++)
            {
                int shared = reader.Read7BitEncodedInt();
                string key = string.Concat(previous.AsSpan(0, shared), reader.ReadString());
                map[key] = reader.Read7BitEncodedInt() - 1; // Stored +1 so -1 (never numbered in vanilla) takes one byte.
                previous = key;
            }

            return map;
        }
    }

    /// <summary>
    /// Precomputed canonical net indexes for vanilla LE3 (Pipelines/Finalize/VanillaNetIndex.bin), produced once by
    /// <c>--build-vanilla-netindex-cache</c> from a scan of every package LE3 loads. Builds read it instead of scanning.
    /// Object maps are decoded lazily per linker, so <see cref="Load"/> only pays for the linker summaries.
    /// </summary>
    public sealed class VanillaNetIndexCache
    {
        private static readonly byte[] Magic = "LMNI"u8.ToArray();

        /// <summary>Layout of the .bin. Bump when the encoding changes.</summary>
        public const int FORMAT_VERSION = 2;

        /// <summary>
        /// Bump whenever the resolution rules in <see cref="VanillaNetIndexBuilder"/> change, so an old cache fails to load
        /// instead of silently feeding builds indexes from superseded rules.
        /// </summary>
        public const int RULES_VERSION = 2;

        internal const string FileName = "VanillaNetIndex.bin";
        internal const string OverridesFileName = "VanillaNetIndexOverrides.txt";
        internal const string RegenerateHint = "Regenerate it with --build-vanilla-netindex-cache.";

        internal static string CachePath => Path.Combine(MilanShared.PipelineRoot, "Finalize", FileName);

        private static readonly Lazy<VanillaNetIndexCache> _shared = new(Load, LazyThreadSafetyMode.ExecutionAndPublication);

        /// <summary>
        /// The cache loaded once for the process (BaseDelta and Conformance both read it). Throws the <see cref="Load"/>
        /// exception, with its regenerate message, if the cache is missing or stale.
        /// </summary>
        public static VanillaNetIndexCache Shared => _shared.Value;

        private readonly Dictionary<string, VanillaLinkerInfo> _linkers;
        private readonly HashSet<string> _localizedLinkers;
        private readonly HashSet<string> _localizationFileLinkers;

        private VanillaNetIndexCache(Dictionary<string, VanillaLinkerInfo> linkers, HashSet<string> localizedLinkers,
            HashSet<string> localizationFileLinkers, IReadOnlyList<(string Linker, string Key, int NetIndex)> overrides)
        {
            _linkers = linkers;
            _localizedLinkers = localizedLinkers;
            _localizationFileLinkers = localizationFileLinkers;
            Overrides = overrides;
        }

        /// <summary>Number of packages the cache was generated from.</summary>
        public int SourceFileCount { get; private init; }

        /// <summary>True if the cache was generated from the ME3Tweaks LE3 backup, false for the live install.</summary>
        public bool SourceWasBackup { get; private init; }

        /// <summary>Every non-localized linker. Localized linkers and localization files' own linkers are excluded from index assignment entirely.</summary>
        public IReadOnlyCollection<string> LinkerNames => _linkers.Keys;

        /// <summary>
        /// Every vanilla (linker, key) whose canonical index (always &gt;= 0) differs from the value at least one vanilla file has: files
        /// disagree, some have it unnumbered (-1), or two objects shared an index and the loser was moved past the linker's maximum.
        /// Sorted by linker, then key.
        /// </summary>
        public IReadOnlyList<(string Linker, string Key, int NetIndex)> Overrides { get; }

        public bool TryGetLinker(string linker, out VanillaLinkerInfo info) => _linkers.TryGetValue(linker, out info!);

        /// <summary>
        /// True for a linker with an object flagged RF_LocalizedResource in some vanilla file: it is server-side only and
        /// takes no part in index assignment.
        /// </summary>
        public bool IsLocalizedLinker(string linker) => _localizedLinkers.Contains(linker);

        /// <summary>Every linker <see cref="IsLocalizedLinker"/> is true for.</summary>
        public IReadOnlyCollection<string> LocalizedLinkers => _localizedLinkers;

        /// <summary>True if the linker is a localization file's own linker (<c>SFXPawn_Atlas_LOC_INT</c>): count 0, every object at NetIndex -1.</summary>
        public bool IsLocalizationFileLinker(string linker) => _localizationFileLinkers.Contains(linker);

        /// <summary>
        /// Loads the cache and checks it still matches the LE3 source it was generated from. Throws if it is missing,
        /// from another format or rules version, or the LE3 file set (relative path and size, never contents) changed.
        /// </summary>
        public static VanillaNetIndexCache Load()
        {
            string path = CachePath;
            if (!File.Exists(path))
                throw new FileNotFoundException($"The vanilla net index cache {path} does not exist. {RegenerateHint}", path);

            byte[] file = File.ReadAllBytes(path);
            using var stream = new MemoryStream(file, writable: false);
            using var reader = new BinaryReader(stream, Encoding.UTF8);

            if (file.Length < Magic.Length || !reader.ReadBytes(Magic.Length).AsSpan().SequenceEqual(Magic))
                throw new InvalidDataException($"{path} is not a vanilla net index cache. {RegenerateHint}");

            int format = reader.ReadInt32();
            if (format != FORMAT_VERSION)
                throw new InvalidDataException($"{path} has format version {format}, but this build reads {FORMAT_VERSION}. {RegenerateHint}");

            int rules = reader.ReadInt32();
            if (rules != RULES_VERSION)
                throw new InvalidDataException($"{path} was resolved with rules version {rules}, but this build uses {RULES_VERSION}. {RegenerateHint}");

            byte[] fingerprint = reader.ReadBytes(32);
            int fileCount = reader.ReadInt32();
            bool wasBackup = reader.ReadByte() == 1;
            int payloadLength = reader.ReadInt32();

            var source = ResolveSource();
            byte[] current = ComputeFingerprint(source.Files);
            if (!fingerprint.AsSpan().SequenceEqual(current))
            {
                throw new InvalidDataException(
                    $"{path} was generated from {fileCount} LE3 packages ({(wasBackup ? "backup" : "live install")}), but the LE3 source at {source.Root} " +
                    $"({(source.IsBackup ? "backup" : "live install")}) has {source.Files.Count} packages with different paths or sizes. {RegenerateHint}");
            }

            byte[] payload = new byte[payloadLength];
            using (var brotli = new BrotliStream(new MemoryStream(file, (int)stream.Position, file.Length - (int)stream.Position, writable: false), CompressionMode.Decompress))
            {
                brotli.ReadExactly(payload);
            }

            return Parse(payload, fileCount, wasBackup);
        }

        private static VanillaNetIndexCache Parse(byte[] payload, int fileCount, bool wasBackup)
        {
            using var reader = new BinaryReader(new MemoryStream(payload, writable: false), Encoding.UTF8);

            int linkerCount = reader.Read7BitEncodedInt();
            var names = new string[linkerCount];
            for (int i = 0; i < linkerCount; i++)
                names[i] = reader.ReadString();

            var records = new (int MaxNet, int MaxDeclared, (Guid, int, DeclarationSource)[] Declarations, bool HasMap, int ObjectCount, int ObjectLength)[linkerCount];
            for (int i = 0; i < linkerCount; i++)
            {
                int maxNet = reader.Read7BitEncodedInt() - 1;
                int maxDeclared = reader.Read7BitEncodedInt() - 1;
                var declarations = new (Guid, int, DeclarationSource)[reader.Read7BitEncodedInt()];
                for (int d = 0; d < declarations.Length; d++)
                {
                    var guid = new Guid(reader.ReadBytes(16));
                    int count = reader.Read7BitEncodedInt() - 1;
                    declarations[d] = (guid, count, (DeclarationSource)reader.ReadByte());
                }

                bool hasMap = reader.ReadBoolean();
                int objectCount = 0, objectLength = 0;
                if (hasMap)
                {
                    objectCount = reader.Read7BitEncodedInt();
                    objectLength = reader.Read7BitEncodedInt();
                }

                records[i] = (maxNet, maxDeclared, declarations, hasMap, objectCount, objectLength);
            }

            var localized = ReadNameSet(reader);
            var localizationFiles = ReadNameSet(reader);

            var overrides = new (string Linker, string Key, int NetIndex)[reader.Read7BitEncodedInt()];
            string previousLinker = "", previousKey = "";
            for (int i = 0; i < overrides.Length; i++)
            {
                string linker = names[reader.Read7BitEncodedInt()];
                if (!ReferenceEquals(linker, previousLinker))
                    previousKey = "";
                int shared = reader.Read7BitEncodedInt();
                string key = string.Concat(previousKey.AsSpan(0, shared), reader.ReadString());
                overrides[i] = (linker, key, reader.Read7BitEncodedInt());
                previousLinker = linker;
                previousKey = key;
            }

            // Object blocks follow, one per linker with a map, in linker order.
            int offset = (int)reader.BaseStream.Position;
            var linkers = new Dictionary<string, VanillaLinkerInfo>(linkerCount, StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < linkerCount; i++)
            {
                var r = records[i];
                linkers[names[i]] = new VanillaLinkerInfo(names[i], r.MaxNet, r.MaxDeclared, r.Declarations, r.HasMap, payload, offset, r.ObjectLength, r.ObjectCount);
                offset += r.ObjectLength;
            }

            return new VanillaNetIndexCache(linkers, localized, localizationFiles, overrides)
            {
                SourceFileCount = fileCount,
                SourceWasBackup = wasBackup
            };
        }

        private static HashSet<string> ReadNameSet(BinaryReader reader)
        {
            int count = reader.Read7BitEncodedInt();
            var set = new HashSet<string>(count, StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < count; i++)
                set.Add(reader.ReadString());
            return set;
        }

        // Writing. Everything here is deterministic: sorted inputs, no timestamps, fixed compression level.

        internal static byte[] Serialize(VanillaNetIndexResolution resolution, VanillaSource source)
        {
            byte[] payload = SerializePayload(resolution);

            using var output = new MemoryStream();
            using (var writer = new BinaryWriter(output, Encoding.UTF8, leaveOpen: true))
            {
                writer.Write(Magic);
                writer.Write(FORMAT_VERSION);
                writer.Write(RULES_VERSION);
                writer.Write(ComputeFingerprint(source.Files));
                writer.Write(source.Files.Count);
                writer.Write((byte)(source.IsBackup ? 1 : 0));
                writer.Write(payload.Length);
            }

            using (var brotli = new BrotliStream(output, CompressionLevel.SmallestSize, leaveOpen: true))
            {
                brotli.Write(payload);
            }

            return output.ToArray();
        }

        private static byte[] SerializePayload(VanillaNetIndexResolution resolution)
        {
            var linkers = resolution.Linkers;
            var indexOf = new Dictionary<string, int>(linkers.Count, StringComparer.OrdinalIgnoreCase);

            using var payload = new MemoryStream();
            using var writer = new BinaryWriter(payload, Encoding.UTF8, leaveOpen: true);

            writer.Write7BitEncodedInt(linkers.Count);
            for (int i = 0; i < linkers.Count; i++)
            {
                indexOf[linkers[i].Name] = i;
                writer.Write(linkers[i].Name);
            }

            // Serialize each object block up front: the linker table records its length.
            var blocks = new byte[linkers.Count][];
            for (int i = 0; i < linkers.Count; i++)
            {
                if (!linkers[i].HasObjectMap)
                    continue;

                using var block = new MemoryStream();
                using var blockWriter = new BinaryWriter(block, Encoding.UTF8, leaveOpen: true);
                string previous = "";
                foreach (var (key, netIndex) in linkers[i].Objects)
                {
                    WriteKey(blockWriter, previous, key);
                    blockWriter.Write7BitEncodedInt(netIndex + 1);
                    previous = key;
                }

                blockWriter.Flush();
                blocks[i] = block.ToArray();
            }

            for (int i = 0; i < linkers.Count; i++)
            {
                var linker = linkers[i];
                writer.Write7BitEncodedInt(linker.MaxNetIndex + 1);
                writer.Write7BitEncodedInt(linker.MaxDeclaredCount + 1);
                writer.Write7BitEncodedInt(linker.Declarations.Count);
                foreach (var (guid, count, declarationSource) in linker.Declarations)
                {
                    writer.Write(guid.ToByteArray());
                    writer.Write7BitEncodedInt(count + 1);
                    writer.Write((byte)declarationSource);
                }

                writer.Write(linker.HasObjectMap);
                if (linker.HasObjectMap)
                {
                    writer.Write7BitEncodedInt(linker.Objects.Count);
                    writer.Write7BitEncodedInt(blocks[i].Length);
                }
            }

            WriteNameSet(writer, resolution.LocalizedLinkers);
            WriteNameSet(writer, resolution.LocalizationFileLinkers);

            writer.Write7BitEncodedInt(resolution.Overrides.Count);
            string previousLinker = "", previousKey = "";
            foreach (var o in resolution.Overrides)
            {
                writer.Write7BitEncodedInt(indexOf[o.Linker]);
                if (!string.Equals(o.Linker, previousLinker, StringComparison.OrdinalIgnoreCase))
                    previousKey = "";
                WriteKey(writer, previousKey, o.Key);
                writer.Write7BitEncodedInt(o.NetIndex);
                previousLinker = o.Linker;
                previousKey = o.Key;
            }

            foreach (var block in blocks)
            {
                if (block != null)
                    writer.Write(block);
            }

            writer.Flush();
            return payload.ToArray();
        }

        /// <summary>Front coded: how many leading chars the previous key shares, then the rest.</summary>
        private static void WriteKey(BinaryWriter writer, string previous, string key)
        {
            int shared = 0;
            int max = Math.Min(previous.Length, key.Length);
            while (shared < max && previous[shared] == key[shared])
                shared++;
            writer.Write7BitEncodedInt(shared);
            writer.Write(key.Substring(shared));
        }

        private static void WriteNameSet(BinaryWriter writer, IReadOnlyList<string> names)
        {
            writer.Write7BitEncodedInt(names.Count);
            foreach (string name in names)
                writer.Write(name);
        }

        // Source resolution, shared by the generator and the load-time fingerprint check.

        internal readonly record struct VanillaSourceFile(string RelativePath, string FullPath, long Size);

        internal sealed record VanillaSource(string Root, bool IsBackup, IReadOnlyList<VanillaSourceFile> Files);

        /// <summary>
        /// The LE3 files LE3 would load, one per file name with the highest mounted official DLC copy winning (the way Mod
        /// Manager resolves its copies), from the ME3Tweaks backup when there is one so a modded live install can't poison the
        /// cache. Sorted by relative path.
        /// </summary>
        internal static VanillaSource ResolveSource()
        {
            string? backup = ME3TweaksBackups.GetGameBackupPath(MEGame.LE3);
            bool isBackup = backup != null && Directory.Exists(backup);
            string? root = isBackup ? backup : LE3Directory.DefaultGamePath;
            if (string.IsNullOrEmpty(root) || !Directory.Exists(root))
                throw new DirectoryNotFoundException("Could not find an LE3 backup or install to read the vanilla package set from.");

            var files = MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3, forceReload: true, gameRootOverride: root, includeModDLC: false)
                .Values
                .Where(p => Path.GetExtension(p).ToLowerInvariant() is ".pcc" or ".upk" or ".u")
                .Select(p => new VanillaSourceFile(Path.GetRelativePath(root, p), p, new FileInfo(p).Length))
                .OrderBy(f => f.RelativePath, StringComparer.OrdinalIgnoreCase)
                .ToList();
            return new VanillaSource(root, isBackup, files);
        }

        /// <summary>SHA-256 over the sorted "relativePath|size" lines. Cheap by design: file contents are never read.</summary>
        internal static byte[] ComputeFingerprint(IReadOnlyList<VanillaSourceFile> files)
        {
            using var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256);
            foreach (string line in files
                         .Select(f => $"{f.RelativePath.Replace('\\', '/').ToLowerInvariant()}|{f.Size}\n")
                         .Order(StringComparer.Ordinal))
            {
                hash.AppendData(Encoding.UTF8.GetBytes(line));
            }

            return hash.GetHashAndReset();
        }
    }
}
