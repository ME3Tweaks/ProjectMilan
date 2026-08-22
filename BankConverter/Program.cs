using BankConverter.Bnk;
using BankConverter.Bnk.Chunks;

namespace BankConverter
{
    // This project (BankConverter) was written by Claude using a mix of binary analysis of ME3, LE3, source code from Wwiser and Wwiser.NET, analysis
    // of the Wwise SDK, as well as in-game tracing for audio-related issues.
    // It is used solely for the purpose of converting v56 Banks to v134 and should not be used for any other purpose.
    internal class Program
    {
        static void Main(string[] args)
        {
            if (args.Length > 0 && args[0] == "test-roundtrip")
            {
                TestRoundTrip(args[1]);
                return;
            }

            if (args.Length > 1 && args[0] == "convert")
            {
                Convert(args[1], args[2], args.Length > 3 ? args[3] : null);
                return;
            }

            if (args.Length > 1 && args[0] == "extract-wems")
            {
                ExtractWems(args[1], args[2]);
                return;
            }

            if (args.Length > 2 && args[0] == "reencode-wems")
            {
                ReencodeWems(args[1], args[2], args[3], args.Length > 4 ? args[4] : null);
                return;
            }

            if (args.Length > 2 && args[0] == "convert-afc")
            {
                ConvertAfc(args[1], args[2], args[3], args.Length > 4 ? args[4] : null, args.Length > 5 ? args[5] : null);
                return;
            }

            Console.WriteLine("Usage: BankConverter test-roundtrip <folder>");
            Console.WriteLine("       BankConverter convert <inFolder> <outFolder> [wemReplacementsFolder]");
            Console.WriteLine("       BankConverter extract-wems <inFolder> <outFolder>");
            Console.WriteLine("       BankConverter reencode-wems <inFolder> <outFolder> <wprojPath> [conversionPresetName]");
            Console.WriteLine("           Converts every ME3-era (v56) .wem in inFolder to a new LE3-era (v134) .wem in outFolder.");
            Console.WriteLine("           Input files are matched by filename (e.g. <id>.wem); output files keep the same name.");
            Console.WriteLine("           Requires ww2ogg + the aoTuV 6.03 codebooks (bundled under Tools/ww2ogg), ffmpeg on PATH,");
            Console.WriteLine("           and Wwise's WwiseCLI.exe (found via the WWISEROOT environment variable by default).");
            Console.WriteLine("       BankConverter convert-afc <inFile.afc> <outFile.afc> <wprojPath> [mappingJsonPath] [conversionPresetName]");
            Console.WriteLine("           An AFC is just concatenated WEMs (each self-delimited by its own RIFF size field, no");
            Console.WriteLine("           padding). Converts every WEM in inFile.afc to v134 and rebuilds a new AFC in the same");
            Console.WriteLine("           order, then writes an old-offset -> new-offset/size JSON mapping (default: <outFile>.map.json)");
            Console.WriteLine("           for rebuilding package files that reference the old offsets.");
        }

        static void ReencodeWems(string inFolder, string outFolder, string wprojPath, string? conversionPresetName)
        {
            Directory.CreateDirectory(outFolder);
            var wems = new Dictionary<string, byte[]>();
            foreach (var f in Directory.GetFiles(inFolder, "*.wem"))
            {
                wems[Path.GetFileNameWithoutExtension(f)] = File.ReadAllBytes(f);
            }
            Console.WriteLine($"Found {wems.Count} .wem file(s) in {inFolder}");

            var options = new WemReencodeOptions { WwiseProjectPath = wprojPath };
            if (!string.IsNullOrEmpty(conversionPresetName)) options.ConversionPresetName = conversionPresetName;

            var workDir = Path.Combine(Path.GetTempPath(), "BankConverter_wem_reencode_" + Guid.NewGuid().ToString("N"));
            try
            {
                var result = WemReencoder.ReencodeBatch(wems, workDir, options);
                foreach (var (id, bytes) in result.Converted)
                {
                    File.WriteAllBytes(Path.Combine(outFolder, id + ".wem"), bytes);
                }
                Console.WriteLine($"Converted: {result.Converted.Count} ok, {result.Failed.Count} failed");
                if (result.Failed.Count > 0)
                {
                    Console.WriteLine("Failures (first 20) - these are typically truncated prefetch fragments (only a partial");
                    Console.WriteLine("stream is embedded/extracted; the rest streams from elsewhere) rather than real errors:");
                    foreach (var (id, reason) in result.Failed.Take(20))
                    {
                        Console.WriteLine($"  {id}: {reason}");
                    }
                }
            }
            finally
            {
                try { Directory.Delete(workDir, true); } catch { /* best-effort cleanup */ }
            }
        }

        static void ConvertAfc(string inFile, string outFile, string wprojPath, string? mappingJsonPath, string? conversionPresetName)
        {
            mappingJsonPath ??= outFile + ".map.json";

            var afcBytes = File.ReadAllBytes(inFile);
            Console.WriteLine($"Read {inFile} ({afcBytes.Length:N0} bytes)");

            var options = new WemReencodeOptions { WwiseProjectPath = wprojPath };
            if (!string.IsNullOrEmpty(conversionPresetName)) options.ConversionPresetName = conversionPresetName;

            var workDir = Path.Combine(Path.GetTempPath(), "BankConverter_afc_" + Guid.NewGuid().ToString("N"));
            try
            {
                var result = AfcConverter.Convert(afcBytes, workDir, options);

                Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outFile))!);
                File.WriteAllBytes(outFile, result.NewAfcBytes);
                AfcConverter.WriteMappingJson(result, mappingJsonPath);

                var convertedCount = result.Entries.Count(e => e.Converted);
                var failedCount = result.Entries.Count - convertedCount;
                Console.WriteLine($"Entries: {result.Entries.Count} total, {convertedCount} converted, {failedCount} failed (kept original bytes)");
                Console.WriteLine($"New AFC: {outFile} ({result.NewAfcBytes.Length:N0} bytes)");
                Console.WriteLine($"Offset mapping: {mappingJsonPath}");

                if (failedCount > 0)
                {
                    Console.WriteLine();
                    Console.WriteLine("############################################################");
                    Console.WriteLine("!! WARNING: SOME AFC ENTRIES NOT RE-ENCODED - LIKELY PLAYBACK CRASH !!");
                    Console.WriteLine("############################################################");
                    Console.WriteLine($"{failedCount} entrie(s) failed re-encoding and were passed through unchanged (still");
                    Console.WriteLine("v56-era Vorbis, which the v134 runtime cannot decode). Reasons (first 20):");
                    foreach (var (id, reason) in result.FailedReasons.Take(20))
                    {
                        Console.WriteLine($"  offset {id}: {reason}");
                    }
                    Console.WriteLine("############################################################");
                }
            }
            finally
            {
                try { Directory.Delete(workDir, true); } catch { /* best-effort cleanup */ }
            }
        }

        static void ExtractWems(string inFolder, string outFolder)
        {
            Directory.CreateDirectory(outFolder);
            var files = Directory.GetFiles(inFolder, "*.bnk");
            var seen = new HashSet<uint>();
            int written = 0, banks = 0;
            foreach (var f in files)
            {
                var name = Path.GetFileName(f);
                if (string.Equals(name, "Init.bnk", StringComparison.OrdinalIgnoreCase)) continue;
                var bytes = File.ReadAllBytes(f);
                if (bytes.Length == 0) continue;
                try
                {
                    var bank = BankFile.ReadV56(bytes);
                    var wems = WemExtractor.Extract(bank);
                    if (wems.Count == 0) continue;
                    banks++;
                    foreach (var (id, data) in wems)
                    {
                        if (!seen.Add(id)) continue; // same media may appear in multiple banks; dedupe by ID
                        File.WriteAllBytes(Path.Combine(outFolder, $"{id}.wem"), data);
                        written++;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"ERROR: {name}: {ex.Message}");
                }
            }
            Console.WriteLine($"Extracted {written} unique embedded WEM(s) from {banks} bank(s) with embedded media.");
        }

        static void Convert(string inFolder, string outFolder, string? wemReplacementsFolder)
        {
            Directory.CreateDirectory(outFolder);
            var files = Directory.GetFiles(inFolder, "*.bnk");
            var stats = new HircConversionStats();
            var missingWems = new List<uint>();

            Dictionary<uint, byte[]>? wemReplacements = null;
            if (wemReplacementsFolder != null)
            {
                wemReplacements = new Dictionary<uint, byte[]>();
                foreach (var f in Directory.GetFiles(wemReplacementsFolder, "*.wem"))
                {
                    if (uint.TryParse(Path.GetFileNameWithoutExtension(f), out var id))
                    {
                        wemReplacements[id] = File.ReadAllBytes(f);
                    }
                }
                Console.WriteLine($"Loaded {wemReplacements.Count} replacement WEM(s) from {wemReplacementsFolder}");
            }

            int ok = 0, fail = 0, skippedInit = 0, skippedNoData = 0;
            foreach (var f in files)
            {
                var name = Path.GetFileName(f);
                if (string.Equals(name, "Init.bnk", StringComparison.OrdinalIgnoreCase))
                {
                    skippedInit++;
                    continue;
                }
                var bytes = File.ReadAllBytes(f);
                if (bytes.Length == 0)
                {
                    skippedNoData++;
                    continue;
                }
                try
                {
                    var bank = BankFile.ReadV56(bytes);
                    var converted = bank.ConvertToV134(stats, wemReplacements, missingWems);
                    File.WriteAllBytes(Path.Combine(outFolder, name), converted);
                    ok++;
                }
                catch (Exception ex)
                {
                    fail++;
                    Console.WriteLine($"ERROR: {name}: {ex.Message}");
                }
            }
            Console.WriteLine($"Converted: {ok} ok, {fail} failed, {skippedInit} Init.bnk skipped, {skippedNoData} empty skipped");
            Console.WriteLine($"HIRC objects total: {stats.Total}");
            if (stats.PrefetchFragmentsBuilt > 0)
            {
                Console.WriteLine($"Prefetch fragments built: {stats.PrefetchFragmentsBuilt} (saved {stats.PrefetchBytesSaved:N0} bytes vs full embed)");
            }
            Console.WriteLine("Converted by type: " + string.Join(", ", stats.Converted.Select(kv => $"0x{kv.Key:X2}={kv.Value}")));
            Console.WriteLine("Skipped by type: " + string.Join(", ", stats.Skipped.Select(kv => $"0x{kv.Key:X2}={kv.Value}")));
            if (stats.Errors.Count > 0)
            {
                Console.WriteLine($"Errors ({stats.Errors.Count}), first 20:");
                foreach (var e in stats.Errors.Take(20)) Console.WriteLine("  " + e);
            }

            if (wemReplacements != null && missingWems.Count > 0)
            {
                var distinct = missingWems.Distinct().Count();
                Console.WriteLine();
                Console.WriteLine("############################################################");
                Console.WriteLine("!! WARNING: EMBEDDED AUDIO NOT RE-ENCODED - LIKELY PLAYBACK CRASH !!");
                Console.WriteLine("############################################################");
                Console.WriteLine($"{distinct} distinct embedded media ID(s) had no replacement WEM supplied and were");
                Console.WriteLine($"passed through unchanged ({missingWems.Count} reference(s) total). v56 Vorbis audio");
                Console.WriteLine("references a codebook library the v134 codec cannot decode - untouched audio");
                Console.WriteLine("WILL crash on playback. Run extract-wems + the re-encode pipeline first.");
                Console.WriteLine("############################################################");
            }

            if (BusRemap.FallbackUses.Count > 0)
            {
                var totalUses = BusRemap.FallbackUses.Values.Sum();
                Console.WriteLine();
                Console.WriteLine("############################################################");
                Console.WriteLine("!! WARNING: BUS REMAP FALLBACK USED - LOUD/UNMIXED AUDIO RISK !!");
                Console.WriteLine("############################################################");
                Console.WriteLine($"{BusRemap.FallbackUses.Count} distinct ME3 bus ID(s) had no known v134 mapping and were");
                Console.WriteLine("routed to the raw, unattenuated Master Audio Bus so the bank would still");
                Console.WriteLine($"load ({totalUses} reference(s) total). This is a release blocker - either add");
                Console.WriteLine("real mappings to BusRemap.cs or manually review the affected content.");
                Console.WriteLine("Unmapped ME3 bus IDs (occurrence count):");
                foreach (var (id, count) in BusRemap.FallbackUses.OrderByDescending(kv => kv.Value))
                {
                    Console.WriteLine($"  {id}: {count}x");
                }
                Console.WriteLine("############################################################");
            }
        }

        static void TestRoundTrip(string folder)
        {
            var files = Directory.GetFiles(folder, "*.bnk");
            int ok = 0, fail = 0;
            foreach (var f in files)
            {
                var name = Path.GetFileName(f);
                if (string.Equals(name, "Init.bnk", StringComparison.OrdinalIgnoreCase)) continue;
                var original = File.ReadAllBytes(f);
                try
                {
                    var bank = BankFile.ReadV56(original);
                    var rebuilt = bank.WriteV56ChunksRoundTrip();
                    if (rebuilt.AsSpan().SequenceEqual(original))
                    {
                        ok++;
                    }
                    else
                    {
                        fail++;
                        Console.WriteLine($"MISMATCH: {name} (orig={original.Length}, rebuilt={rebuilt.Length})");
                        var minLen = Math.Min(original.Length, rebuilt.Length);
                        for (var i = 0; i < minLen; i++)
                        {
                            if (original[i] != rebuilt[i])
                            {
                                Console.WriteLine($"  first diff at byte {i} (orig=0x{original[i]:X2}, rebuilt=0x{rebuilt[i]:X2})");
                                break;
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    fail++;
                    Console.WriteLine($"ERROR: {name}: {ex.Message}");
                }
            }
            Console.WriteLine($"Round-trip: {ok} ok, {fail} failed (of {files.Length - 1})");
        }
    }
}
