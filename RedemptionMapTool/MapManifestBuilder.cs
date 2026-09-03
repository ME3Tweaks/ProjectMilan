using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore;
using ProjectMilan_ExtraContent.Redemption.Levels.MapPack;

namespace RedemptionMapTool
{
    /// <summary>
    /// Builds a change manifest for one BioP_MP*.pcc level master.
    /// </summary>
    internal static class MapManifestBuilder
    {
        public static MapManifest BuildManifest(string masterPath, string cookedDir, Dictionary<Guid, string> vanillaGuidMap, Dictionary<string, MapDisplayInfo> displayInfoByMap)
        {
            var manifest = new MapManifest
            {
                MasterPackage = Path.GetFileNameWithoutExtension(masterPath),
                SourceFile = Path.GetFileName(masterPath)
            };

            if (displayInfoByMap.TryGetValue(manifest.MasterPackage, out var displayInfo))
            {
                manifest.DisplayInfo = displayInfo;
            }
            else
            {
                Console.WriteLine($"  [INFO] {manifest.MasterPackage}: no mastermaplist entry in the original config - likely never added to the selectable map list");
            }

            using var pcc = MEPackageHandler.OpenMEPackage(masterPath);

            manifest.KillZ = pcc.GetBioWorldInfo()?.GetProperty<FloatProperty>("KillZ")?.Value ?? 0;

            // LevelStreamingKismet/BioWorldInfo.StreamingLevels lists every streaming entry ever
            // authored for this master, including leftover/dev ones that don't actually apply to
            // this specific map variant. The set that's actually used is the TIER_Global entry in
            // BioTriggerStream.StreamingStates[].VisibleChunkNames.
            var sublevelPackageNames = new List<string>();
            foreach (var exp in pcc.Exports.Where(x => x.ClassName == "BioTriggerStream"))
            {
                var tierName = exp.GetProperty<NameProperty>("TierName")?.ToString();
                if (tierName != "TIER_Global")
                {
                    continue;
                }

                var streamingStates = exp.GetProperty<ArrayProperty<StructProperty>>("StreamingStates");
                if (streamingStates is null)
                {
                    continue;
                }

                foreach (var state in streamingStates)
                {
                    var visibleChunkNames = state.GetProp<ArrayProperty<NameProperty>>("VisibleChunkNames");
                    if (visibleChunkNames is null)
                    {
                        continue;
                    }

                    foreach (var chunk in visibleChunkNames)
                    {
                        var name = chunk.ToString();
                        if (!string.IsNullOrEmpty(name) && !sublevelPackageNames.Contains(name))
                        {
                            sublevelPackageNames.Add(name);
                        }
                    }
                }
            }

            manifest.Sublevels = sublevelPackageNames;

            for (var i = 0; i < 4; i++)
            {
                var bsl = pcc.FindExport($"TheWorld.PersistentLevel.BioStartLocationMP_{i}");
                if (bsl is null)
                {
                    Console.WriteLine($"  [WARN] {manifest.MasterPackage}: BioStartLocationMP_{i} not found");
                    continue;
                }

                manifest.StartLocations.Add(new StartLocationEntry
                {
                    Index = i,
                    Location = ToVectorDto(CommonStructs.GetVector3(bsl, "location", Vector3.Zero)),
                    Rotation = ToRotatorDto(bsl.GetProperty<StructProperty>("Rotation"))
                });
            }

            foreach (var packageName in sublevelPackageNames)
            {
                var sublevelPath = Path.Combine(cookedDir, packageName + ".pcc");
                if (!File.Exists(sublevelPath))
                {
                    Console.WriteLine($"  [WARN] {manifest.MasterPackage}: sublevel '{packageName}' referenced but not found at {sublevelPath}");
                    continue;
                }

                try
                {
                    using var subPcc = MEPackageHandler.OpenMEPackage(sublevelPath);

                    var sourceFile = Path.GetFileName(sublevelPath);
                    var originalName = ResolveOriginalName(subPcc, vanillaGuidMap);
                    if (originalName != null && !originalName.Equals(packageName, StringComparison.OrdinalIgnoreCase))
                    {
                        Console.WriteLine($"  [INFO] {manifest.MasterPackage}: sublevel '{packageName}' appears to be renamed from '{originalName}'");
                        sourceFile = originalName + ".pcc";
                    }

                    manifest.SublevelData.Add(new SublevelManifest
                    {
                        PackageName = packageName,
                        SourceFile = sourceFile,
                        TriggerVolumes = SublevelScanner.ScanTriggerVolumes(subPcc),
                        ObjectiveSpawnPoints = SublevelScanner.ScanObjectiveSpawnPoints(subPcc),
                        EnemySpawnPoints = SublevelScanner.ScanEnemySpawnPoints(subPcc)
                    });
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"  [WARN] {manifest.MasterPackage}: failed scanning sublevel '{packageName}': {ex.Message}");
                }
            }

            return manifest;
        }

        /// <summary>
        /// Looks up this sublevel's original (pre-rename) package name via its guid, checked against the vanilla
        /// ME3 guid lookup - first by the package's own header guid, then (in case only one of the two survived
        /// whatever tool last saved this file) by its self-referencing "Package" export's guid - i.e. the export
        /// with the same name as the package file itself. A file can contain many other class=Package exports
        /// (forced exports for every other package it references, e.g. shared materials/anim trees) - those
        /// hold THEIR OWN package's guid, not this file's identity, and must not be considered here.
        /// </summary>
        private static string? ResolveOriginalName(IMEPackage pcc, Dictionary<Guid, string> vanillaGuidMap)
        {
            if (vanillaGuidMap.TryGetValue(pcc.PackageGuid, out var byHeader))
            {
                return byHeader;
            }

            var selfExport = pcc.Exports.FirstOrDefault(x =>
                x.ClassName == "Package" && x.Parent == null &&
                x.ObjectName.Instanced.Equals(pcc.FileNameNoExtension, StringComparison.OrdinalIgnoreCase));
            if (selfExport != null && vanillaGuidMap.TryGetValue(selfExport.PackageGUID, out var byExport))
            {
                return byExport;
            }

            return null;
        }

        private static VectorDto ToVectorDto(Vector3 v) => new() { X = v.X, Y = v.Y, Z = v.Z };

        private static RotatorDto ToRotatorDto(StructProperty? rotProp)
        {
            if (rotProp is null) return new RotatorDto();
            var r = CommonStructs.GetRotator(rotProp);
            return new RotatorDto { Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll };
        }
    }
}
