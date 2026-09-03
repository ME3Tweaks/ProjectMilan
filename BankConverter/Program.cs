using BankConverter.Bnk;
using BankConverter.Bnk.Chunks;
using BankConverter.Bnk.Hirc;

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

            if (args.Length > 0 && args[0] == "map-events")
            {
                MapEvents(args[1]);
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

        static void MapEvents(string bankFilePath)
        {
            var bytes = File.ReadAllBytes(bankFilePath);
            var bank = BankFile.ReadV56(bytes);
            if (bank.HircRaw == null)
            {
                Console.WriteLine("No HIRC chunk in this bank.");
                return;
            }

            var r = new BankReader(bank.HircRaw);
            var count = r.U32();

            var events = new Dictionary<uint, Event>();
            var actions = new Dictionary<uint, AkAction>();
            var containerChildren = new Dictionary<uint, List<uint>>(); // RandomSequenceContainer/SwitchContainer/ActorMixer
            var containerTypes = new Dictionary<uint, string>();
            var switchContainers = new Dictionary<uint, SwitchContainer>();
            var layerContainers = new Dictionary<uint, LayerContainer>();
            var sounds = new Dictionary<uint, Sound>();
            var typeCounts = new Dictionary<byte, int>();
            var fxObjects = new Dictionary<uint, FxBase>();
            var nodeFxRefs = new List<(uint nodeId, string nodeType, FxChunkEntry fx)>();
            var directParents = new Dictionary<uint, uint>();

            for (var i = 0; i < count; i++)
            {
                var type = r.U8();
                var sectionSize = r.U32();
                var bodyStart = r.Position;
                var bodyEnd = bodyStart + (int)sectionSize;
                typeCounts[type] = typeCounts.GetValueOrDefault(type) + 1;

                try
                {
                    switch (type)
                    {
                        case 0x02:
                            var s = Sound.ReadV56(r);
                            sounds[s.Id] = s;
                            foreach (var fx in s.NodeBase.Fx.Fx) nodeFxRefs.Add((s.Id, "Sound", fx));
                            directParents[s.Id] = s.NodeBase.DirectParentId;
                            break;
                        case 0x03:
                            var a = AkAction.ReadV56(r);
                            actions[a.Id] = a;
                            break;
                        case 0x04:
                            var e = Event.ReadV56(r);
                            events[e.Id] = e;
                            break;
                        case 0x05:
                            var rsc = RandomSequenceContainer.ReadV56(r);
                            containerChildren[rsc.Id] = rsc.ChildIds;
                            containerTypes[rsc.Id] = $"RandomSequenceContainer(Mode={rsc.Mode}, RandomMode={rsc.RandomMode}, IsContinuous={rsc.IsContinuous})";
                            foreach (var fx in rsc.NodeBase.Fx.Fx) nodeFxRefs.Add((rsc.Id, "RandomSequenceContainer", fx));
                            directParents[rsc.Id] = rsc.NodeBase.DirectParentId;
                            break;
                        case 0x06:
                            var sc = SwitchContainer.ReadV56(r);
                            containerChildren[sc.Id] = sc.ChildIds;
                            containerTypes[sc.Id] = "SwitchContainer";
                            switchContainers[sc.Id] = sc;
                            foreach (var fx in sc.NodeBase.Fx.Fx) nodeFxRefs.Add((sc.Id, "SwitchContainer", fx));
                            directParents[sc.Id] = sc.NodeBase.DirectParentId;
                            break;
                        case 0x07:
                            var am = ActorMixer.ReadV56(r);
                            containerChildren[am.Id] = am.ChildIds;
                            containerTypes[am.Id] = "ActorMixer";
                            foreach (var fx in am.NodeBase.Fx.Fx) nodeFxRefs.Add((am.Id, "ActorMixer", fx));
                            directParents[am.Id] = am.NodeBase.DirectParentId;
                            break;
                        case 0x09:
                            var lc = LayerContainer.ReadV56(r);
                            containerChildren[lc.Id] = lc.ChildIds;
                            containerTypes[lc.Id] = "LayerContainer";
                            layerContainers[lc.Id] = lc;
                            foreach (var fx in lc.NodeBase.Fx.Fx) nodeFxRefs.Add((lc.Id, "LayerContainer", fx));
                            directParents[lc.Id] = lc.NodeBase.DirectParentId;
                            break;
                        case 0x12:
                        case 0x13:
                            var fxb = FxBase.ReadV56(r);
                            fxObjects[fxb.Id] = fxb;
                            break;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"  parse error type=0x{type:X2}: {ex.Message}");
                }

                r.Position = bodyEnd;
            }

            Console.WriteLine("Object type counts: " + string.Join(", ", typeCounts.OrderBy(kv => kv.Key).Select(kv => $"0x{kv.Key:X2}={kv.Value}")));
            Console.WriteLine();

            List<string> ResolveToSources(uint targetId, HashSet<uint> visited)
            {
                var found = new List<string>();
                if (!visited.Add(targetId)) return found; // cycle guard
                if (sounds.TryGetValue(targetId, out var snd))
                {
                    found.Add($"{snd.Source.SourceId} (StreamType={snd.Source.StreamType}, PluginId=0x{snd.Source.PluginId:X})");
                }
                else if (containerChildren.TryGetValue(targetId, out var children))
                {
                    foreach (var child in children) found.AddRange(ResolveToSources(child, visited));
                }
                else
                {
                    found.Add($"UNRESOLVED(target={targetId})");
                }
                return found;
            }

            foreach (var (id, evt) in events.OrderBy(kv => kv.Key))
            {
                Console.WriteLine($"Event {id}:");
                foreach (var actionId in evt.ActionIds)
                {
                    if (!actions.TryGetValue(actionId, out var action))
                    {
                        Console.WriteLine($"  Action {actionId}: NOT FOUND");
                        continue;
                    }
                    var targetType = containerTypes.GetValueOrDefault(action.TargetId, sounds.ContainsKey(action.TargetId) ? "Sound" : "UNKNOWN");
                    Console.WriteLine($"  Action {actionId} (kind={action.Kind}) -> target {action.TargetId} [{targetType}]");
                    var sourceIds = ResolveToSources(action.TargetId, new HashSet<uint>());
                    foreach (var sid in sourceIds)
                    {
                        Console.WriteLine($"    -> SourceId (WEM id): {sid}");
                    }
                }
            }

            if (switchContainers.Count > 0)
            {
                Console.WriteLine();
                Console.WriteLine("=== SwitchContainer details ===");
                foreach (var (id, sc) in switchContainers)
                {
                    Console.WriteLine($"SwitchContainer {id}: GroupType={sc.GroupType}, GroupId={sc.GroupId}, DefaultSwitch={sc.DefaultSwitch}, ChildIds=[{string.Join(",", sc.ChildIds)}]");
                    foreach (var pkg in sc.SwitchList)
                    {
                        Console.WriteLine($"  SwitchValue {pkg.SwitchId} -> nodes [{string.Join(",", pkg.NodeIds)}]");
                    }
                    foreach (var p in sc.Params)
                    {
                        Console.WriteLine($"  NodeParams for {p.NodeId}: IsFirstOnly={p.IsFirstOnly}, ContinuePlayback={p.ContinuePlayback}, OnSwitchMode={p.OnSwitchMode}");
                    }
                }
            }

            if (fxObjects.Count > 0)
            {
                Console.WriteLine();
                Console.WriteLine("=== Fx objects ===");
                foreach (var (id, fx) in fxObjects)
                {
                    Console.WriteLine($"Fx {id}: PluginId=0x{fx.PluginId:X}, ParamBlockLen={fx.ParamBlock?.Length ?? 0}");
                }
                Console.WriteLine();
                Console.WriteLine("=== Node -> Fx references ===");
                foreach (var (nodeId, nodeType, fxRef) in nodeFxRefs)
                {
                    Console.WriteLine($"{nodeType} {nodeId}: slot {fxRef.FxIndex} -> Fx {fxRef.FxId} (ShareSet={fxRef.IsShareSet})");
                }

                Console.WriteLine();
                Console.WriteLine("=== Parent-chain check: does each event's play target inherit a broken Fx? ===");
                var fxByNode = nodeFxRefs.ToLookup(x => x.nodeId);
                foreach (var (id, evt) in events.OrderBy(kv => kv.Key))
                {
                    foreach (var actionId in evt.ActionIds)
                    {
                        if (!actions.TryGetValue(actionId, out var action) || action.Kind != ActionKind.Play) continue;
                        Console.Write($"Event {id} action {actionId} target {action.TargetId}: chain =");
                        var cur = action.TargetId;
                        var seen = new HashSet<uint>();
                        while (cur != 0 && seen.Add(cur))
                        {
                            var fxHere = fxByNode[cur].Select(x => x.fx.FxId).ToList();
                            Console.Write($" {cur}{(fxHere.Count > 0 ? $"[Fx:{string.Join(",", fxHere)}]" : "")} ->");
                            if (!directParents.TryGetValue(cur, out var parent)) break;
                            cur = parent;
                        }
                        Console.WriteLine(" (root)");
                    }
                }
            }

            if (layerContainers.Count > 0)
            {
                Console.WriteLine();
                Console.WriteLine("=== LayerContainer details ===");
                foreach (var (id, lc) in layerContainers)
                {
                    Console.WriteLine($"LayerContainer {id}: ChildIds=[{string.Join(",", lc.ChildIds)}]");
                    foreach (var layer in lc.Layers)
                    {
                        Console.WriteLine($"  Layer {layer.LayerId}: RtpcId={layer.RtpcId}, CrossfadingRtpcDefaultValue={layer.CrossfadingRtpcDefaultValue}, RtpcEntries={layer.Rtpc?.Entries?.Count ?? -1}");
                        foreach (var entry in layer.Rtpc?.Entries ?? new List<RtpcEntry>())
                        {
                            Console.WriteLine($"    RtpcEntry: RtpcId={entry.RtpcId}, ParamId={entry.ParamId}, Points=[{string.Join(";", entry.Points.Select(p => $"{p.From}->{p.To}"))}]");
                        }
                        foreach (var assoc in layer.Assocs)
                        {
                            Console.WriteLine($"    Assoc childId={assoc.ChildId}, curvePoints={assoc.Curve.Count}");
                        }
                    }
                }
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
