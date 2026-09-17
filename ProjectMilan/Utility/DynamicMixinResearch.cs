using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore;

namespace ProjectMilan.Utility
{
    /// <summary>
    /// One-off harness that inventories ME3Tweaks ModMaker "Dynamic Mixin" byte-offset patches by actually
    /// applying them - the same way ME3TweaksModManager's MixinHandler/JPatch does - to real vanilla ME3
    /// package data, then using LegendaryExplorerCore's PackageDiff to read back exactly which export/property
    /// changed. This exists so ProjectMilan can eventually express these edits as structured property
    /// overrides instead of raw package patches. See the plan this was built from for full context on the
    /// mixin CSV format and why the byte offsets only line up against this exact decompression path.
    /// </summary>
    internal static class DynamicMixinResearch
    {
        private sealed class DynamicMixinRow
        {
            public int Id;
            public string Name = "";
            public string Description = "";
            public string Placeholder = "";
            public string TargetModule = "";
            public string TargetPath = "";
            public long TargetSize;
            public long Offset;
            public int DataType; // 0=int,1=short,2=byte,3=float
            public double DefaultFloatValue;
            public int DefaultIntValue;
            public int DefaultShortValue;
            public int DefaultByteValue;
            public int Category;
            public bool Shared;
        }

        /// <summary>
        /// Parses the ModMaker dynamicmixins DB export (semicolon-delimited, double-quoted strings) into rows.
        /// </summary>
        private static List<DynamicMixinRow> ParseCsv(string csvPath)
        {
            var rows = new List<DynamicMixinRow>();
            var lines = File.ReadAllLines(csvPath);
            if (lines.Length == 0) return rows;

            var header = SplitCsvLine(lines[0]);
            var colIndex = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            for (int i = 0; i < header.Count; i++) colIndex[header[i]] = i;

            string Get(List<string> fields, string col) => colIndex.TryGetValue(col, out var idx) && idx < fields.Count ? fields[idx] : "";

            for (int i = 1; i < lines.Length; i++)
            {
                if (string.IsNullOrWhiteSpace(lines[i])) continue;
                var fields = SplitCsvLine(lines[i]);
                if (fields.Count < header.Count) continue;

                var row = new DynamicMixinRow
                {
                    Id = ParseIntSafe(Get(fields, "id")),
                    Name = Get(fields, "name"),
                    Description = Get(fields, "description"),
                    Placeholder = Get(fields, "placeholder"),
                    TargetModule = Get(fields, "targetmodule"),
                    TargetPath = Get(fields, "targetpath"),
                    TargetSize = ParseLongSafe(Get(fields, "targetsize")),
                    Offset = ParseLongSafe(Get(fields, "offset")),
                    DataType = ParseIntSafe(Get(fields, "datatype")),
                    DefaultFloatValue = ParseDoubleSafe(Get(fields, "defaultfloatvalue")),
                    DefaultIntValue = ParseIntSafe(Get(fields, "defaultintvalue")),
                    DefaultShortValue = ParseIntSafe(Get(fields, "defaultshortvalue")),
                    DefaultByteValue = ParseIntSafe(Get(fields, "defaultbytevalue")),
                    Category = ParseIntSafe(Get(fields, "category")),
                    Shared = Get(fields, "shared") == "1"
                };
                rows.Add(row);
            }

            return rows;
        }

        private static int ParseIntSafe(string s) => int.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0;
        private static long ParseLongSafe(string s) => long.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0;
        private static double ParseDoubleSafe(string s) => double.TryParse(s, NumberStyles.Any, CultureInfo.InvariantCulture, out var v) ? v : 0;

        /// <summary>
        /// Splits one semicolon-delimited CSV line, honoring double-quoted fields (which may contain literal
        /// semicolons, e.g. mixin descriptions).
        /// </summary>
        private static List<string> SplitCsvLine(string line)
        {
            var fields = new List<string>();
            var sb = new StringBuilder();
            bool inQuotes = false;
            for (int i = 0; i < line.Length; i++)
            {
                char c = line[i];
                if (inQuotes)
                {
                    if (c == '"')
                    {
                        if (i + 1 < line.Length && line[i + 1] == '"')
                        {
                            sb.Append('"');
                            i++;
                        }
                        else
                        {
                            inQuotes = false;
                        }
                    }
                    else
                    {
                        sb.Append(c);
                    }
                }
                else
                {
                    if (c == '"')
                    {
                        inQuotes = true;
                    }
                    else if (c == ';')
                    {
                        fields.Add(sb.ToString());
                        sb.Clear();
                    }
                    else
                    {
                        sb.Append(c);
                    }
                }
            }
            fields.Add(sb.ToString());
            return fields;
        }

        private static readonly Regex DlcFolderRegex = new(@"/DLC/([^/]+)/", RegexOptions.Compiled);

        /// <summary>
        /// Resolves the raw, decompressed byte stream for a mixin row's target package, replicating
        /// ME3TweaksModManager's MixinManager.ApplyMixinsToModule behavior:
        /// - BASEGAME: read the loose .pcc from disk, then run it through MEPackage.GetDecompressedPackageStream
        ///   (open+resave, NOT a trivial physical decompress) - this is the exact transform the CSV's basegame
        ///   offsets were computed against.
        /// - DLC / TESTPATCH: pull the entry straight out of the relevant .sfar and physically decompress it
        ///   via DLCPackage.DecompressEntry - no open+resave step, since sfar entries are already stored in a
        ///   layout that matches retail without needing LEC's canonical resave.
        /// Returns null (with a reason) if the file/entry could not be located at all.
        /// </summary>
        private static (MemoryStream? stream, string resolvedFrom, string? failReason) GetDecompressedTargetStream(DynamicMixinRow row, Dictionary<string, DLCPackage> sfarCache)
        {
            var filename = row.TargetPath.Substring(row.TargetPath.LastIndexOf('/') + 1);

            if (row.TargetModule.Equals("BASEGAME", StringComparison.OrdinalIgnoreCase))
            {
                var basegamePath = Path.Combine(MEDirectories.GetCookedPath(LegendaryExplorerCore.Packages.MEGame.ME3), filename);
                if (!File.Exists(basegamePath))
                {
                    return (null, basegamePath, "basegame file not found on disk");
                }

                var rawBytes = File.ReadAllBytes(basegamePath);
                using var rawStream = new MemoryStream(rawBytes);
                var decompressed = MEPackage.GetDecompressedPackageStream(rawStream, includeAdditionalPackagesToCook: false, includeDependencyTable: true);
                return (decompressed, basegamePath, null);
            }

            // DLC or TESTPATCH - resolve the sfar path.
            string sfarPath;
            if (row.TargetModule.Equals("TESTPATCH", StringComparison.OrdinalIgnoreCase))
            {
                sfarPath = Path.Combine(ME3Directory.BioGamePath, "Patches", "PCConsole", "Patch_001.sfar");
            }
            else
            {
                var match = DlcFolderRegex.Match(row.TargetPath);
                if (!match.Success)
                {
                    return (null, row.TargetPath, $"could not extract DLC folder name from targetpath for module {row.TargetModule}");
                }
                var dlcFolder = match.Groups[1].Value;
                sfarPath = Path.Combine(ME3Directory.DLCPath, dlcFolder, LegendaryExplorerCore.Packages.MEGame.ME3.CookedDirName(), "Default.sfar");
            }

            if (!File.Exists(sfarPath))
            {
                return (null, sfarPath, "sfar not found on disk");
            }

            if (!sfarCache.TryGetValue(sfarPath, out var dlcPackage))
            {
                dlcPackage = new DLCPackage(sfarPath);
                sfarCache[sfarPath] = dlcPackage;
            }

            bool MatchesFile(LegendaryExplorerCore.Unreal.DLCPackage.FileEntryStruct f) => f.isActualFile && string.Equals(Path.GetFileName(f.FileName), filename, StringComparison.OrdinalIgnoreCase);
            if (!dlcPackage.Files.Any(MatchesFile))
            {
                return (null, sfarPath, $"'{filename}' not found inside {Path.GetFileName(sfarPath)}");
            }
            var entry = dlcPackage.Files.First(MatchesFile);

            // Confirmed empirically (targetsize matches exactly for every DLC row only with the PLAIN
            // decompressed sfar bytes, and mismatches for ~97 rows once resaved) - unlike BASEGAME, DLC
            // offsets are computed against the plain physically-decompressed sfar entry, not a LEC resave.
            var decompressedEntryStream = dlcPackage.DecompressEntry(entry);
            var ms = decompressedEntryStream as MemoryStream ?? new MemoryStream(((MemoryStream)decompressedEntryStream).ToArray());
            return (ms, $"{sfarPath}!{filename}", null);
        }

        /// <summary>
        /// Overwrites the value at <paramref name="offset"/> in <paramref name="bytes"/> per the row's datatype,
        /// mirroring modmakersource's publisher.php createJPatchData(): float/short/byte are written little-endian
        /// (standard pack("L") on x86), but datatype 0 (int) is explicitly byte-swapped to big-endian in that PHP
        /// code, so we replicate that quirk here rather than assuming all datatypes are little-endian.
        /// </summary>
        private static void WriteValueAtOffset(byte[] bytes, long offset, DynamicMixinRow row, bool probeMode)
        {
            // IMPORTANT: the CSV's "default" value is the value ModMaker's slider resets to - which, for most
            // rows, is simply THE VALUE ALREADY IN THE VANILLA FILE (confirmed empirically: writing
            // defaultfloatvalue back was a true no-op byte-for-byte for the large majority of rows). To
            // reliably detect which property an offset maps to, we must write something GUARANTEED to differ
            // from whatever is already there, not the row's own default. probeMode does that; pass false only
            // if you specifically want to write the row's real default (e.g. for a final apply step).
            byte[] valueBytes = row.DataType switch
            {
                0 => BitConverter.GetBytes(probeMode ? row.DefaultIntValue + 7919 : row.DefaultIntValue),
                1 => BitConverter.GetBytes((short)(probeMode ? row.DefaultShortValue + 7919 : row.DefaultShortValue)),
                2 => new[] { (byte)((probeMode ? row.DefaultByteValue + 111 : row.DefaultByteValue) % 256) },
                3 => BitConverter.GetBytes((float)(probeMode ? row.DefaultFloatValue + 7919.25 : row.DefaultFloatValue)),
                _ => throw new NotSupportedException($"Unknown datatype {row.DataType}")
            };

            if (row.DataType == 0)
            {
                // int: publisher.php swaps this to big-endian before writing.
                Array.Reverse(valueBytes);
            }

            if (offset < 0 || offset + valueBytes.Length > bytes.Length)
            {
                throw new InvalidOperationException($"Offset {offset} + {valueBytes.Length} bytes exceeds file length {bytes.Length}");
            }

            Array.Copy(valueBytes, 0, bytes, offset, valueBytes.Length);
        }

        private static string? FormatPropValue(Property? p)
        {
            return p switch
            {
                null => null,
                FloatProperty fp => fp.Value.ToString(CultureInfo.InvariantCulture),
                IntProperty ip => ip.Value.ToString(CultureInfo.InvariantCulture),
                ByteProperty bp => bp.Value.ToString(CultureInfo.InvariantCulture),
                _ => p.ToString()
            };
        }

        /// <summary>
        /// Flattens a diffed PropertyCollection (produced with structDiff:true) into leaf (dotted-path, old, new)
        /// entries, recursing into StructProperty so e.g. a changed Vector shows up as "Location.Z" with the
        /// actual scalar values rather than as an opaque "Location" struct.
        /// </summary>
        private static void CollectLeafPropertyChanges(PropertyCollection diffed, PropertyCollection afterSiblings, string pathPrefix, List<Dictionary<string, object?>> into, string exportPath, string exportClass)
        {
            foreach (var prop in diffed)
            {
                var path = pathPrefix.Length == 0 ? prop.Name.Instanced : $"{pathPrefix}.{prop.Name.Instanced}";
                if (prop is StructProperty sp)
                {
                    var afterStruct = afterSiblings.GetProp<StructProperty>(prop.Name, prop.StaticArrayIndex);
                    if (afterStruct != null)
                    {
                        // sp.Properties may be the FULL field set (not just changed ones) when the struct is
                        // immutable/atomic (e.g. Vector) - Diff()'s recursive-struct branch only applies to
                        // non-immutable structs, so an immutable struct's whole value gets carried through as-is.
                        // Re-diff explicitly here so only genuinely-changed leaves are reported either way.
                        var innerDiff = sp.Properties.Diff(afterStruct.Properties, structDiff: true);
                        CollectLeafPropertyChanges(innerDiff, afterStruct.Properties, path, into, exportPath, exportClass);
                        continue;
                    }
                }

                var newProp = afterSiblings.GetProp<Property>(prop.Name, prop.StaticArrayIndex);
                into.Add(new Dictionary<string, object?>
                {
                    ["export"] = exportPath,
                    ["class"] = exportClass,
                    ["property"] = path,
                    ["staticArrayIndex"] = prop.StaticArrayIndex,
                    ["oldValue"] = FormatPropValue(prop),
                    ["newValue"] = FormatPropValue(newProp)
                });
            }
        }

        /// <summary>
        /// Runs the full inventory pass across every row in the dynamicmixins CSV export, writing a structured
        /// JSON result file summarizing, per row, which export+property changed (or why it couldn't be
        /// determined). Intended to be run once/interactively from a debug entry point, not as part of the
        /// normal build pipeline.
        /// </summary>
        public static void RunDynamicMixinInventory(string csvPath, string outputJsonPath)
        {
            var rows = ParseCsv(csvPath);
            MilanLog.Information($"Loaded {rows.Count} dynamic mixin rows from {csvPath}");

            var sfarCache = new Dictionary<string, DLCPackage>(StringComparer.OrdinalIgnoreCase);
            var results = new List<Dictionary<string, object?>>();

            int ok = 0, sizeMismatch = 0, notFound = 0, noPropDiff = 0, ambiguous = 0, binaryOnly = 0, errors = 0;

            for (int i = 0; i < rows.Count; i++)
            {
                var row = rows[i];
                if (i % 50 == 0)
                {
                    MilanLog.Information($"Processing row {i + 1}/{rows.Count} (id {row.Id}: {row.Name})");
                }

                var result = new Dictionary<string, object?>
                {
                    ["id"] = row.Id,
                    ["name"] = row.Name,
                    ["targetModule"] = row.TargetModule,
                    ["targetPath"] = row.TargetPath,
                    ["offset"] = row.Offset,
                    ["dataType"] = row.DataType
                };

                try
                {
                    var (stream, resolvedFrom, failReason) = GetDecompressedTargetStream(row, sfarCache);
                    result["resolvedFrom"] = resolvedFrom;

                    if (stream == null)
                    {
                        notFound++;
                        result["status"] = "not_found";
                        result["reason"] = failReason;
                        results.Add(result);
                        continue;
                    }

                    using (stream)
                    {
                        if (stream.Length != row.TargetSize)
                        {
                            sizeMismatch++;
                            result["status"] = "size_mismatch";
                            result["expectedSize"] = row.TargetSize;
                            result["actualSize"] = stream.Length;
                            results.Add(result);
                            continue;
                        }

                        var beforeBytes = stream.ToArray();
                        var afterBytes = (byte[])beforeBytes.Clone();
                        // probeMode:true - see WriteValueAtOffset's doc comment on why we don't just write the
                        // row's own default value here.
                        WriteValueAtOffset(afterBytes, row.Offset, row, probeMode: true);

                        var pkgName = row.TargetPath.Substring(row.TargetPath.LastIndexOf('/') + 1);
                        using var beforePkg = MEPackageHandler.OpenMEPackageFromStream(new MemoryStream(beforeBytes), pkgName);
                        using var afterPkg = MEPackageHandler.OpenMEPackageFromStream(new MemoryStream(afterBytes), pkgName);

                        // Targeted, single-export diff instead of a whole-package PackageDiff: we made exactly
                        // one controlled byte edit at a known offset, so find the one export whose serialized
                        // data range contains that offset and diff ONLY its properties. A whole-package diff was
                        // tried first and empirically produced spurious unrelated changes on some packages
                        // (e.g. particle module structs on completely unrelated exports) while MISSING the real
                        // change - almost certainly an artifact of comparing full entry trees across two
                        // independently-parsed packages, not something specific to our edit. Scoping to the
                        // exact export avoids that entirely and is also far cheaper for large packages.
                        var targetExport = beforePkg.Exports.FirstOrDefault(e => row.Offset >= e.DataOffset && row.Offset < e.DataOffset + e.DataSize);

                        var propChanges = new List<Dictionary<string, object?>>();
                        var binaryChanges = new List<string>();

                        if (targetExport == null)
                        {
                            result["offsetExport"] = null;
                            result["offsetNotInAnyExport"] = true;
                        }
                        else
                        {
                            var afterExport = afterPkg.GetUExport(targetExport.UIndex);
                            result["offsetExport"] = targetExport.InstancedFullPath;
                            result["offsetExportClass"] = targetExport.ClassName;
                            // IsDefaultObject is the key split the user asked for: only a class's literal CDO
                            // (Default__ClassName) reads UnrealScript "config" vars from an ini at load time.
                            // Any other export - an archetype/instance like a placed BioStartLocationMP, or a
                            // subobject like a pawn's MovementData - is NOT affected by marking the property
                            // config, since config only ever initializes the CDO.
                            result["isDefaultObject"] = targetExport.IsDefaultObject;

                            var beforeProps = targetExport.GetProperties();
                            var afterProps = afterExport.GetProperties();
                            var diffedProps = beforeProps.Diff(afterProps, structDiff: true);

                            CollectLeafPropertyChanges(diffedProps, afterProps, "", propChanges, targetExport.InstancedFullPath, targetExport.ClassName);

                            // If no tagged property differs, check whether the raw export data differs at all
                            // (it must - we wrote different bytes into this export's range) to confirm this is a
                            // genuine binary/non-tagged-property patch rather than a bug in export resolution.
                            if (propChanges.Count == 0)
                            {
                                var beforeData = targetExport.DataReadOnly;
                                var afterData = afterExport.DataReadOnly;
                                var rawDiffers = !beforeData.SequenceEqual(afterData);
                                result["rawBytesDiffer"] = rawDiffers;
                                if (rawDiffers)
                                {
                                    // The probe write definitely changed this export's bytes, but no tagged
                                    // property picked it up - genuine binary/non-tagged-property data (e.g. an
                                    // AI tree, sequence, or other ObjectBinary field), not a resolution bug.
                                    binaryChanges.Add(targetExport.InstancedFullPath);
                                }
                            }
                        }

                        result["propertyChanges"] = propChanges;
                        result["binaryOnlyExports"] = binaryChanges;

                        if (propChanges.Count == 1)
                        {
                            ok++;
                            result["status"] = "ok";
                            // The dotted leaf path's first segment is the actual UProperty declared on the
                            // class - what a "set as config" edit would apply to. For a nested struct (e.g.
                            // "location.Z") the user's rule is that the WHOLE struct property becomes config,
                            // not just the changed component.
                            var leafPath = (string)propChanges[0]["property"]!;
                            var topLevel = leafPath.Split('.')[0];
                            result["topLevelProperty"] = topLevel;
                            result["isStructNested"] = leafPath.Contains('.');
                        }
                        else if (propChanges.Count == 0 && binaryChanges.Count > 0)
                        {
                            binaryOnly++;
                            result["status"] = "binary_only";
                        }
                        else if (propChanges.Count == 0 && targetExport != null)
                        {
                            // Even the probe (guaranteed different from the on-disk value) produced no observable
                            // change at all - something is wrong with offset/export resolution for this row, not
                            // a real "no property here" result. Needs investigation, not silent skipping.
                            noPropDiff++;
                            result["status"] = "no_diff_even_with_probe";
                        }
                        else
                        {
                            ambiguous++;
                            result["status"] = "ambiguous";
                        }
                    }
                }
                catch (Exception ex)
                {
                    errors++;
                    result["status"] = "error";
                    result["reason"] = ex.Message;
                }

                results.Add(result);
            }

            var summary = new Dictionary<string, object?>
            {
                ["totalRows"] = rows.Count,
                ["ok"] = ok,
                ["sizeMismatch"] = sizeMismatch,
                ["notFound"] = notFound,
                ["noPropDiff"] = noPropDiff,
                ["ambiguous"] = ambiguous,
                ["binaryOnly"] = binaryOnly,
                ["errors"] = errors,
                ["results"] = results
            };

            var json = JsonSerializer.Serialize(summary, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(outputJsonPath, json);

            MilanLog.Information($"Done. ok={ok} sizeMismatch={sizeMismatch} notFound={notFound} noPropDiff={noPropDiff} ambiguous={ambiguous} binaryOnly={binaryOnly} errors={errors}");
            MilanLog.Information($"Results written to {outputJsonPath}");
        }
    }
}
