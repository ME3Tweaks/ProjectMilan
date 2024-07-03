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
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Collections;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Newtonsoft.Json;
using ProjectMilan.Pipelines.Startups;

namespace ProjectMilan.Pipelines.Finalize
{
    /// <summary>
    /// Conforms the mod for networking by doing things such as net object counting and building the guid map
    /// </summary>
    internal class Conformance
    {
        private const string LOG_CATEGORY = @"MILAN-Conformance";
        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        /// <summary>
        /// Map of count of unique netindices. Maps linker -> unique object count.
        /// </summary>
        private static CaseInsensitiveDictionary<int> currentNetIndexes = new();


        private static void InternalRunPipeline()
        {
            ConformNetObjects();
            ConformPackagesWithGuidCache();

            // Ensure SFXGame is patched.
            //MPCommon.HackPatchParents(); // No longer needed.
        }

        /// <summary>
        /// Get package file this entry will be nested under in memory. Parent chain should be preferably exports
        /// </summary>
        /// <param name="entry"></param>
        /// <returns></returns>
        public static string GetLinker(IEntry entry)
        {
            if (entry.idxLink == 0)
            {
                if (entry.ClassName == "Package")
                {
                    if (entry is ExportEntry exp && exp.IsForcedExport)
                        return entry.InstancedFullPath; // SFXGameContent
                    if (entry is ImportEntry imp)
                        return entry.InstancedFullPath; // Edge case; this should not occur after resynthesis of a package
                }

                // It's part of the package file itself.
                return entry.FileRef.FileNameNoExtension;
            }

            return GetLinker(entry.Parent);
        }

        private static void ConformNetObjects()
        {
            // Not really sure how this is determined exactly.

            // 1. All package objects must have a generation and it must list the amount of objects under it (including package exports, but not itself)
            //    This count must be done as it the package is not cooked
            // 2. NetIndex seems to be the 4 bytes before properties, but I'm not sure how the order is chosen. It's done by linker though so it will be unique to the package.

            var allPackagesFiles = Directory
                .GetFiles(Program.Settings.OutputModPath, "*.pcc", SearchOption.AllDirectories).ToList();

            // The nested dictionary is for perf only. the value is not used.

            MilanLog.Information("Pass 1: Build map of linkers", customPrefix: LOG_CATEGORY);

            //var packageExportMap = new CaseInsensitiveDictionary<CaseInsensitiveDictionary<int>>();
            //foreach (var p in allPackagesFiles)
            //{
            //    using var package = MEPackageHandler.OpenMEPackage(p);
            //    foreach (var pExp in package.Exports)
            //    {
            //        var linker = GetLinker(pExp);
            //        if (!packageExportMap.TryGetValue(linker, out var exportsForPackage))
            //        {
            //            exportsForPackage = new CaseInsensitiveDictionary<int>();
            //            packageExportMap[linker] = exportsForPackage;
            //        }

            //        exportsForPackage.Add(pExp.InstancedFullPath, 0);
            //    }
            //}


            #region Pass 2: Write out net indexes
            MilanLog.Information("Pass 2: Assign NetIndexes", customPrefix: LOG_CATEGORY);

            foreach (var p in allPackagesFiles)
            {
                using var package = MEPackageHandler.OpenMEPackage(p);
                //if (package.FileNameNoExtension == "BioA_MPThes")
                //    Debugger.Break();
                foreach (var pExp in package.Exports)
                {
                    var existingInfo = MilanShared.LE3ObjectDB.GetInfo(pExp.InstancedFullPath);

                    if (pExp.idxLink == 0 && pExp.ClassName == "Package" && pExp.IsForcedExport)
                    {
                        continue; // Skip these
                    }

                    //if (pExp.InstancedFullPath == "SFXGameContentDLC_CON_MP3.SFXDamageType_HeavyMachinegun")
                    //    Debugger.Break();

                    if (existingInfo != null)
                    {
                        // Previously inventoried
                        pExp.NetIndex = existingInfo.NetIndex;
                    }
                    else
                    {
                        // We are assigning it new
                        var linker = GetLinker(pExp);
                        if (!currentNetIndexes.TryGetValue(linker, out var assigningNetIndex))
                        {
                            MilanLog.Information($"Starting NetIndexing for linker {linker}", customPrefix: LOG_CATEGORY);
                            assigningNetIndex = -1; // Will be incremented before use
                        }

                        currentNetIndexes[linker] = ++assigningNetIndex;

                        pExp.NetIndex = assigningNetIndex;
                        if (linker != pExp.FileRef.FileNameNoExtension)
                        {
                            // Do not cache same-package objects as they will not have the correct IFP
                            MilanShared.RegisterObjectDBObject(pExp);
                        }
                    }
                }

                if (package.IsModified)
                {
                    package.Save();
                }
            }
            #endregion

            #region Pass 3: NetObj counts on root package exports
            MilanLog.Information("Pass 3: Write NetObj counts for root packages", customPrefix: LOG_CATEGORY);
            foreach (var p in allPackagesFiles)
            {
                int localLinkerCount = 0;
                using var package = MEPackageHandler.OpenMEPackage(p);
                foreach (var pExp in package.Exports.Where(x =>
                             x.idxLink == 0 && x.ClassName == "Package" && x.IsForcedExport))
                {
                    // Root packages
                    var existingInfo = MilanShared.LE3ObjectDB.GetInfo(pExp.InstancedFullPath);
                    pExp.NetIndex = -1;

                    if (package.Localization == MELocalization.None)
                    {
                        pExp.PackageFlags = UnrealFlags.EPackageFlags.AllowDownload |
                                            UnrealFlags.EPackageFlags.NoExportsData;
                    }

                    //if (pExp.InstancedFullPath == "GUI_SF_MPReinforcements_DLC")
                    //    Debugger.Break();

                    if (existingInfo != null)
                    {
                        // Already calculated this value.
                        pExp.GenerationNetObjectCount = [existingInfo.GenerationNetObjCount];
                    }
                    else
                    {
                        // Not calculated: Lookup what we counted
                        if (!currentNetIndexes.TryGetValue(pExp.InstancedFullPath, out int netObjCount))
                        {
                            // Was not under package export - find number of objects that are not forced export under the root.
                            localLinkerCount = package.Exports.Count(x => GetLinker(x) == package.FileNameNoExtension && pExp != x);
                            pExp.GenerationNetObjectCount = [localLinkerCount];
                        }
                        else
                        {
                            // Use the count we calculated
                            pExp.GenerationNetObjectCount = [netObjCount];
                        }
                    }
                }

                // Update the same-named package.
                var sameNamedExp = package.FindExport(package.FileNameNoExtension);
                if (sameNamedExp != null)
                {
                    // Same-named package
                    // Count number of objects in this linker
                    sameNamedExp.GenerationNetObjectCount = [localLinkerCount];

                    if (EntryExporter.IsLevelFile(sameNamedExp.InstancedFullPath))
                    {
                        // Set package flags
                        sameNamedExp.PackageFlags = UnrealFlags.EPackageFlags.AllowDownload |
                                                    UnrealFlags.EPackageFlags.NoExportsData |
                                                    UnrealFlags.EPackageFlags.Cooked |
                                                    UnrealFlags.EPackageFlags.Map |
                                                    UnrealFlags.EPackageFlags.DisallowLazyLoading |
                                                    UnrealFlags.EPackageFlags.RequireImportsAlreadyLoaded |
                                                    UnrealFlags.EPackageFlags.Protected;
                        ((MEPackage)package).setFlags(sameNamedExp.PackageFlags);
                    }
                }

                ((MEPackage)package).Gen0NetworkedObjectCount = localLinkerCount;
                ((MEPackage)package).Gen0NameCount = package.Names.Count;
                ((MEPackage)package).Gen0ExportCount = package.Exports.Count;

                if (package.IsModified)
                {
                    package.Save();
                }
            }
            #endregion
        }

        /// <summary>
        /// Checks if the given object is a child of another object
        /// </summary>
        /// <param name="child"></param>
        /// <param name="parent"></param>
        /// <returns></returns>
        /// <exception cref="NotImplementedException"></exception>
        private static bool IsChildObjectOf(IEntry child, IEntry parent)
        {
            if (child == parent)
                return false; // it is not a child of itself

            while (child != null && child != parent)
            {
                child = child.Parent;
                if (child == parent)
                    return true;
            }

            return false;
        }

        public static void BuildGuidMap()
        {
            var outPath = Path.Combine(MilanShared.PipelineRoot, "Finalize", "GuidMap.json");
            var guidMap = new CaseInsensitiveDictionary<Guid>();

            // Basegame guid map is completely wrong. we must calculate our own.

            // LE - inventory all packages
            foreach (var file in MELoadedFiles.GetFilesLoadedInGame(MEGame.LE3))
            {
                if (file.Value == "GuidCache.pcc")
                    continue; // Self
                if (file.Value.GetUnrealLocalization() != MELocalization.None)
                    continue;

                var package = MEPackageHandler.UnsafePartialLoad(file.Value, x => x.ClassName == "Package");
                if (!guidMap.ContainsKey(package.FileNameNoExtension) && package.PackageGuid != Guid.Empty)
                {
                    guidMap[package.FileNameNoExtension] = package.PackageGuid;
                }

                foreach (var packageExport in package.Exports.Where(x => x.ClassName == "Package"))
                {
                    if (packageExport.PackageGUID == Guid.Empty)
                        continue;
                    if (!guidMap.ContainsKey(packageExport.ObjectName)) // Do we need to use instanced? For things like BioD_ProEar_440. how does that work for guids
                    {
                        guidMap[packageExport.ObjectName] = packageExport.PackageGUID;
                    }
                }
            }

            // Now inventory MP from OT. We will use it's guids
            var me3GuidCache = MilanShared.GetME3Package($"GuidCache.pcc");
            var cache = ObjectBinary.From<GuidCache>(me3GuidCache.Exports[0]);
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

            // Save cached guidmap.
            File.WriteAllText(outPath, JsonConvert.SerializeObject(guidMap, Formatting.Indented));

            // Save base GuidCache.pcc
            var guidCache = MEPackageHandler.CreateAndOpenPackage(Path.Combine(MilanShared.PipelineRoot, "Mod", "PrecomputedBASEGAME", "GuidCache.pcc"), MEGame.LE3);
            var gc = new GuidCache
            {
                PackageGuidMap = new UMultiMap<NameReference, Guid>(guidMap.Select(x => new KeyValuePair<NameReference, Guid>(x.Key, x.Value)))
            };
            var exp = ExportCreator.CreateExport(guidCache, "GuidCache", "GuidCache", indexed: false);
            exp.WriteBinary(gc);
            guidCache.Save();

        }

        /// <summary>
        /// Builds the package guid cache which is used with replication. Makes all package guids conform.
        /// </summary>
        private static void ConformPackagesWithGuidCache()
        {
            MilanLog.Information("Conforming packages", customPrefix: LOG_CATEGORY);

            // This is the list of all known Guids in vanilla LE3
            var masterGuidMap = JsonConvert.DeserializeObject<CaseInsensitiveDictionary<Guid>>(File.ReadAllText(Path.Combine(MilanShared.PipelineRoot, "Finalize", "GuidMap.json")));

            // Read basegame guid map so we know what we can skip.
            var basegameGuidCache = MEPackageHandler.OpenMEPackage(Path.Combine(LE3Directory.CookedPCPath, "GuidCache.pcc"));
            var basegameCache = new CaseInsensitiveDictionary<Guid>();
            var cache = ObjectBinary.From<GuidCache>(basegameGuidCache.Exports[0]);
            foreach (var entry in cache.PackageGuidMap)
            {
                basegameCache[entry.Key] = entry.Value;
            }

            // All packages that had a 'source' file in source needs to be in GuidCache,
            // as long as they had at least one net object,
            // so clients know they are in sync with server
            var guidCacheP = MEPackageHandler.CreateAndOpenPackage(Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", $"GuidCache_{MilanShared.DLC_NAME}.pcc"), MEGame.LE3);

            var guidCache = ExportCreator.CreateExport(guidCacheP, "GuidCache", "GuidCache", indexed: false);

            // The dictionary of guids we are building
            var buildingGuidMap = new CaseInsensitiveDictionary<Guid>();

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

                // Does master guid map have our file in it?
                if (masterGuidMap.TryGetValue(package.FileNameNoExtension, out packageGuid))
                {
                    package.PackageGuid = packageGuid; // Assign package guid
                }
                else
                {
                    // Master guid map does not have our package - we are adding a new guid.
                    if (currentNetIndexes.TryGetValue(package.FileNameNoExtension, out var val))
                    {

                        MilanLog.Information($"Package (file) not in guid map, adding now: {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                        // We probably need to make a new guid here...
                        packageGuid = Guid.NewGuid(); // Todo should probably cache these in a file for historical debugging
                        masterGuidMap[package.FileNameNoExtension] = packageGuid; // Assign to master for future lookups
                        if (val > 0)
                        {
                            // Only packages with more than 0 net objects are added to guidcache
                            buildingGuidMap[package.FileNameNoExtension] = packageGuid; // Assign to our new GuidCache
                        }
                        else
                        {
                            MilanLog.Information($"Skipping guidcaching package with no net objects: {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                        }

                        package.PackageGuid = packageGuid; // Assign package guid
                    }
                }

                // Map package file GUID
                var sameNamedExport = package.FindExport(package.FileNameNoExtension, "Package");
                if (sameNamedExport == null)
                {
                    // Generate same-named package export. Unsure if this matters really.
                    // Guid will be updated in an upcoming pass
                    ExportCreator.CreatePackageExport(package, NameReference.FromInstancedString(package.FileNameNoExtension));
                }
                #endregion

                #region All forced-export package exports
                foreach (var exp in package.Exports.Where(x => x.idxLink == 0 && x.ClassName == "Package" && x.IsForcedExport))
                {
                    if (masterGuidMap.TryGetValue(exp.ObjectName.Instanced, out var expGuid))
                    {
                        // We have seen this package before in either master or as package file
                        exp.PackageGUID = expGuid;
                        if (!basegameCache.TryGetValue(exp.ObjectName.Instanced, out _))
                        {
                            masterGuidMap[exp.ObjectName.Instanced] = expGuid; // Assign to master if not seen before
                        }

                        // 01/08/2024 - Observing FindPackageFile() with a GUID seems to indicate it's missing basegame GUIDs for some reason. No idea why.
                        // Late June 2024 - Basegame GUIDCache is totally wrong!
                        buildingGuidMap[exp.ObjectName.Instanced] = expGuid; // Assign to our new GuidCache
                    }
                    else
                    {
                        // We have not seen this package before yet for guids
                        MilanLog.Information($"Package (export) not in guid map, adding now: {exp.ObjectName.Instanced}", customPrefix: LOG_CATEGORY);
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
                // Do net objects matter? // Yes, yes they do

                if (package.IsModified)
                {
                    MilanLog.Information($"Saving conformed package {package.FileNameNoExtension}.pcc", customPrefix: LOG_CATEGORY);
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
                map.TryAddUnique(NameReference.FromInstancedString(mapItem.Key), mapItem.Value);
            }

            GuidCache gc = new GuidCache();
            gc.PackageGuidMap = map;

            guidCache.WriteBinary(gc);
            guidCacheP.Save();
            MilanShared.RefreshMilanFiles = true;
        }
    }
}
