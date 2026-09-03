using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace RedemptionMapTool
{
    /// <summary>
    /// Builds a package-guid -> original-package-name lookup from vanilla ME3's GuidCache files, so renamed
    /// Redemption mod sublevels can be traced back to the shipping file they were based on. Every DLC (and the
    /// basegame CookedPCConsole folder) ships its own "*GuidCache*.pcc", each holding a GuidCache export whose
    /// binary is a PackageName -> Guid map - reading those is far cheaper than opening every package in the game.
    /// </summary>
    internal static class VanillaGuidLookup
    {
        /// <summary>
        /// Scans <paramref name="biogamePath"/> (a game's BIOGame folder, base + DLC unpacked) for GuidCache
        /// packages and merges them into a single Guid -> package name map. Conflicting guids/names across
        /// caches are reported to the console and the first-seen entry wins.
        /// </summary>
        public static Dictionary<Guid, string> Build(string biogamePath)
        {
            var nameByGuid = new Dictionary<Guid, string>();
            var guidCacheFiles = Directory.GetFiles(biogamePath, "*GuidCache*.pcc", SearchOption.AllDirectories).OrderBy(f => f).ToArray();
            Console.WriteLine($"Found {guidCacheFiles.Length} GuidCache file(s) under {biogamePath}.");

            foreach (var path in guidCacheFiles)
            {
                using var pcc = MEPackageHandler.OpenMEPackage(path);
                var cacheExport = pcc.Exports.FirstOrDefault(x => x.ClassName == "GuidCache");
                if (cacheExport is null)
                {
                    Console.WriteLine($"  [WARN] {Path.GetFileName(path)}: no GuidCache export found, skipping");
                    continue;
                }

                var cache = ObjectBinary.From<GuidCache>(cacheExport);
                foreach (var (packageName, guid) in cache.PackageGuidMap)
                {
                    if (guid == Guid.Empty)
                        continue;

                    if (nameByGuid.TryGetValue(guid, out var existingName))
                    {
                        if (!existingName.Equals(packageName.Instanced, StringComparison.OrdinalIgnoreCase))
                        {
                            Console.WriteLine($"  [WARN] Guid {guid} maps to both '{existingName}' and '{packageName.Instanced}' - keeping '{existingName}'");
                        }
                        continue;
                    }

                    nameByGuid[guid] = packageName.Instanced;
                }
            }

            Console.WriteLine($"Built vanilla guid lookup with {nameByGuid.Count} package(s).");
            return nameByGuid;
        }
    }
}
