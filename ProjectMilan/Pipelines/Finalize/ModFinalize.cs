using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using CommandLine;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Collections;
using Newtonsoft.Json;
using ProjectMilan.Pipelines.Startups;

namespace ProjectMilan.Pipelines.Finalize
{
    /// <summary>
    /// Finalizes the mod by doing things such as package conformance and building the guid cache.
    /// </summary>
    internal class ModFinalize
    {
        private const string LOG_CATEGORY = @"MILAN-Finalize";
        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            ConformPackagesWithGuidCache();
            // AssignNetIndexes(); // No idea how to do this.

            // Ensure SFXGame is patched.
            // MPCommon.HackPatchParents(); // No longer needed.
        }

        public static void BuildGuidMap()
        {
            var outPath = Path.Combine(MilanShared.PipelineRoot, "Finalize", "GuidMap.json");
            var guidMap = new CaseInsensitiveDictionary<Guid>();

            // Load default guid map
            var guidCache = MEPackageHandler.OpenMEPackage(Path.Combine(LE3Directory.CookedPCPath, "GuidCache.pcc"));
            var cache = ObjectBinary.From<GuidCache>(guidCache.Exports[0]);
            foreach (var map in cache.PackageGuidMap)
            {
                guidMap[map.Key] = map.Value;
            }

            // LE - inventory packages (we could just use it's GUIDCaches...)
            foreach (var dlc in LE3Directory.OfficialDLC)
            {
                var dlcPath = Path.Combine(LE3Directory.DLCPath, dlc);
                foreach (var pack in Directory.GetFileSystemEntries(dlcPath, "*.pcc", SearchOption.AllDirectories))
                {
                    if (pack.GetUnrealLocalization() != MELocalization.None)
                        continue;

                    var package = MEPackageHandler.UnsafePartialLoad(pack, x => x.ClassName == "Package");
                    if (!guidMap.ContainsKey(package.FileNameNoExtension) && package.PackageGuid != Guid.Empty)
                    {
                        guidMap[package.FileNameNoExtension] = package.PackageGuid;
                    }

                    foreach (var packageExport in package.Exports.Where(x => x.ClassName == "Package"))
                    {
                        if (packageExport.PackageGUID == Guid.Empty)
                            continue;
                        if (!guidMap.ContainsKey(packageExport.ObjectName)) // Do we need to use instanced?
                        {
                            guidMap[packageExport.ObjectName] = packageExport.PackageGUID;
                        }
                    }
                }
            }

            // Now inventory MP from OT
            var me3GuidCache = MilanShared.GetME3Package($"GuidCache.pcc");
            cache = ObjectBinary.From<GuidCache>(me3GuidCache.Exports[0]);
            foreach (var map in cache.PackageGuidMap)
            {
                if (!guidMap.ContainsKey(map.Key))
                {
                    guidMap[map.Key] = map.Value;
                }
            }

            var i = 1;
            while (i <= 5)
            {
                var dlcName = $"DLC_CON_MP{i}";
                me3GuidCache = MilanShared.GetME3Package($"GuidCache_{dlcName}.pcc");
                cache = ObjectBinary.From<GuidCache>(me3GuidCache.Exports[0]);
                foreach (var map in cache.PackageGuidMap)
                {
                    if (!guidMap.ContainsKey(map.Key))
                    {
                        guidMap[map.Key] = map.Value;
                    }
                }

                i++;
            }

            File.WriteAllText(outPath, JsonConvert.SerializeObject(guidMap, Formatting.Indented));
        }

        /// <summary>
        /// Builds the package guid cache which is used with replication. Makes all package guids conform.
        /// </summary>
        private static void ConformPackagesWithGuidCache()
        {
            MilanLog.Information("Conforming packages", customPrefix: LOG_CATEGORY);

            // This is the list of all known Guids in vanilla LE3
            var masterGuidMap = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<Guid>>(
                File.ReadAllText(Path.Combine(MilanShared.PipelineRoot, "Finalize", "GuidMap.json")));

            // Read basegame guid map so we know what we can skip.
            var basegameGuidCache = MEPackageHandler.OpenMEPackage(Path.Combine(LE3Directory.CookedPCPath, "GuidCache.pcc"));
            var basegameCache = new CaseInsensitiveDictionary<Guid>();
            var cache = ObjectBinary.From<GuidCache>(basegameGuidCache.Exports[0]);
            foreach (var entry in cache.PackageGuidMap)
            {
                basegameCache[entry.Key] = entry.Value;
            }

            // All packages that had a 'source' file in source needs to be in GuidCache
            // so clients know they are in sync with server
            var guidCacheP = MEPackageHandler.CreateAndOpenPackage(
                Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole",
                    $"GuidCache_{MilanShared.DLC_NAME}.pcc"), MEGame.LE3);

            var guidCache = ExportCreator.CreateExport(guidCacheP, "GuidCache", "GuidCache", indexed: false);
            var buildingGuidMap = new Dictionary<string, Guid>();

            var allPackagesFiles = Directory.GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories).ToList();

            // Step 1: Ensure all packages have guids that are not LOC files.
            foreach (var p in allPackagesFiles)
            {
                if (p.GetUnrealLocalization() != MELocalization.None)
                    continue;

                using var package = (MEPackage)MEPackageHandler.OpenMEPackage(p);
                if (package.FileNameNoExtension.StartsWith("GuidCache"))
                    continue; // never update or inventory these

                #region Package and Package Export
                var packageGuid = package.PackageGuid;
                if (masterGuidMap.TryGetValue(package.FileNameNoExtension, out packageGuid))
                {
                    package.PackageGuid = packageGuid;
                }
                else
                {
                    MilanLog.Error($"Package (file) not in guid map, adding now: {package.FileNameNoExtension}");
                    // We probably need to make a new guid here...
                    packageGuid = Guid.NewGuid();
                    masterGuidMap[package.FileNameNoExtension] = packageGuid; // Assign to master
                    buildingGuidMap[package.FileNameNoExtension] = packageGuid; // Assign to our new GuidCache
                    package.PackageGuid = packageGuid;
                }

                // Map package file GUID
                var sameNamedExport = package.FindExport(package.FileNameNoExtension);
                if (sameNamedExport == null)
                {
                    // Generate it?
                    ExportCreator.CreatePackageExport(package, NameReference.FromInstancedString(package.FileNameNoExtension));
                }
                #endregion

                #region All package exports
                foreach (var exp in package.Exports.Where(x => x.idxLink == 0 && x.ClassName == "Package" && x.IsForcedExport))
                {
                    if (masterGuidMap.TryGetValue(exp.ObjectName.Instanced, out var expGuid))
                    {
                        exp.PackageGUID = expGuid;
                        if (!basegameCache.TryGetValue(exp.ObjectName.Instanced, out _))
                        {
                            masterGuidMap[exp.ObjectName.Instanced] = expGuid; // Assign to master
                        }

                        // 01/08/2024 - Observing FindPackageFile() with a GUID seems to indicate it's missing basegame GUIDs for some reason. No idea why.
                        buildingGuidMap[exp.ObjectName.Instanced] = expGuid; // Assign to our new GuidCache
                    }
                    else
                    {
                        MilanLog.Information($"Package (export) not in guid map, adding now: {exp.ObjectName.Instanced}");
                        expGuid = Guid.NewGuid();
                        masterGuidMap[exp.ObjectName.Instanced] = expGuid; // Assign to master
                        buildingGuidMap[exp.ObjectName.Instanced] = expGuid; // Assign to our new GuidCache
                        exp.PackageGUID = expGuid;

                        // Dunno if these are required fully but we're gonna put em here anyways cause that's how most of vanilla looks
                        exp.PackageFlags |= UnrealFlags.EPackageFlags.AllowDownload;
                        exp.PackageFlags |= UnrealFlags.EPackageFlags.NoExportsData;
                    }
                }
                #endregion

                // Todo: Do package flags matter? AllowDownload Script
                // Do net objects matter?

                if (package.IsModified)
                {
                    MilanLog.Information($"Saving conformed package {package.FileNameNoExtension}.pcc");
                    package.Save();
                    MilanShared.RefreshMilanFiles = true;

                }
            }

            // This is from ME3Explorer experiment for redemption
            // Need to find GUIDs for all forced export packages
            // Need to also figure out how to know if it needs guid or not
            // e.g. WwiseBank (loc) folders don't have guids.
            // Do nothing in LOCs have a guid?


            //foreach (var file in allPackages)
            //{
            //    if (file.Contains("_LOC_"))
            //    {
            //        Debug.WriteLine($"--> Skipping {file}");
            //        continue; //skip localizations
            //    }

            //    Debug.WriteLine(Path.GetFileName(file));
            //    bool hasPackageNamingItself = false;
            //    using (var package = MEPackageHandler.OpenMEPackage(file))
            //    {
            //        foreach (ExportEntry exp in package.Exports)
            //        {
            //            if (exp.ClassName == "Package" && exp.idxLink == 0 &&
            //                !filesToSkip.Contains(exp.ObjectName.Name))
            //            {
            //                if (string.Equals(exp.ObjectName.Name, fname,
            //                    StringComparison.InvariantCultureIgnoreCase))
            //                {
            //                    hasPackageNamingItself = true;
            //                }

            //                Guid guid = exp.PackageGUID;
            //                if (guid != Guid.Empty)
            //                {
            //                    GuidPackageMap.TryGetValue(guid, out string packagename);
            //                    if (packagename != null && packagename != exp.ObjectName.Name)
            //                    {
            //                        Debug.WriteLine(
            //                            $"-> {exp.UIndex} {exp.ObjectName.Name} has a guid different from already found one ({packagename})! {guid}");
            //                    }

            //                    if (packagename == null)
            //                    {
            //                        GuidPackageMap[guid] = exp.ObjectName.Name;
            //                    }
            //                }
            //            }
            //        }
            //    }

            //    if (!hasPackageNamingItself)
            //    {
            //        Debug.WriteLine("----HAS NO SELF NAMING EXPORT");
            //    }
            //}

            //foreach (KeyValuePair<Guid, string> entry in GuidPackageMap)
            //{
            //    // do something with entry.Value or entry.Key
            //    Debug.WriteLine($"  {entry.Value} {entry.Key}");
            //}

            // Build guid map.
            var map = new UMultiMap<NameReference, Guid>();
            foreach (var mapItem in buildingGuidMap)
            {
                map.TryAddUnique(mapItem.Key, mapItem.Value);
            }

            GuidCache gc = new GuidCache();
            gc.PackageGuidMap = map;

            guidCache.WriteBinary(gc);
            guidCacheP.Save();
            MilanShared.RefreshMilanFiles = true;
        }
    }
}
