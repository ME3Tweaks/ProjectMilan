using System.Diagnostics;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using LegendaryExplorerCore.UnrealScript.Compiling.Errors;
using ProjectMilan.Pipelines.Startups;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Weapons
{
    /// <summary>
    /// Pipeline for porting MP characters (kits)
    /// </summary>
    internal class SFXWeapons
    {
        private const string LOG_CATEGORY = "MILAN-Weapon";

        /// <summary>
        /// Folder in the mod output that every built weapon package is written to.
        /// </summary>
        private static string OutputFolder => Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", @"DLCWeapons");

        /// <summary>
        /// Replays the process-global state this pipeline publishes - each built weapon package is
        /// registered as a donor (see the AddDonorPackage call in <see cref="CompileWeapon"/>), which
        /// generates its class info and adds it to the object database. Called instead of
        /// <see cref="RunPipeline"/> when a restored checkpoint already contains the weapon packages;
        /// without this, later pipelines (MP4Enemies, Levels) can't resolve the weapon classes.
        /// </summary>
        internal static void RehydrateFromCheckpoint()
        {
            if (!Directory.Exists(OutputFolder))
            {
                // Can happen if the checkpoint was built with RunWeaponsPipeline disabled.
                MilanLog.Warning($"Restored checkpoint has no {Path.GetFileName(OutputFolder)} folder; weapon donors were not rehydrated.", customPrefix: LOG_CATEGORY);
                return;
            }

            var weaponPackages = Directory.GetFiles(OutputFolder, "*.pcc", SearchOption.TopDirectoryOnly);
            MilanLog.Information($"Rehydrating {weaponPackages.Length} checkpointed weapon package(s) as donors", customPrefix: LOG_CATEGORY);

            using var cache = new PackageCache("SFXWeapons checkpoint rehydration cache");
            foreach (var weaponPackage in weaponPackages)
            {
                MilanShared.AddDonorPackage(weaponPackage, cache);
            }
        }

        public static void RunPipeline()
        {
            var vars = new MPWeaponVars();
            InternalRunPipeline(vars);
            var weaponTextures = PortWeaponDataPackage();
            var modTextures = PortWeaponModDataPackage();
            CheckBaseWeaponTexturesAreProvided(weaponTextures, modTextures);
        }

        private static void InternalRunPipeline(MPWeaponVars vars)
        {
            //DotTrace.EnsurePrerequisite();
            //DotTrace.Attach();
            // foreach (var kit in vars.KitPipelines)

            MilanLog.LogDonorMessages = false; // Suppress spam

            // Chained to the long-lived MPCommon tier so files hit repeatedly within this pipeline (but not
            // globally hot enough to be in MPCommon) get promoted here instead of reopened per-weapon. Disposed
            // once every weapon is done, so nothing here outlives the Weapons pipeline.
            using var pipelineCache = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache(canPromoteInto: true, debugName: "SFXWeapons pipeline cache");

            Parallel.ForEach(vars.WeaponPipelines.OrderBy(x => x.ShouldBuild).AsParallel().AsOrdered(), new ParallelOptions() { MaxDegreeOfParallelism = Program.Settings.MaxThreads }, weapon =>
            {
                // Uncomment this to port everything
                if (/*false && */!weapon.ShouldBuild)
                {
                    // This level is not marked for porting currently.
                    MilanLog.Information($"Skipping weapon {weapon.PackageName}, pipeline is not enabled", customPrefix: LOG_CATEGORY);
                    return;
                }

                BeginPorting(weapon, pipelineCache);
            });
            // }

            MilanLog.LogDonorMessages = true; // Restore spam
        }

        /// <summary>
        /// ME3 MP files whose Data (SFXWeaponUIData) export's m_aWeapons array is merged with the shipped LE3
        /// SP weapon UI data by <see cref="PortWeaponDataPackage"/>. SharedSF is deliberately excluded - its
        /// Data export only carries weapon MOD data (m_aMods), not weapons, and is still ported generically
        /// by NonStartupPipeline.
        /// </summary>
        private static readonly string[] MPWeaponUIDataFiles =
        {
            "SFXGUI_WeaponUIDataDLC_CON_MP1SF.pcc",
            "SFXGUI_WeaponUIDataDLC_CON_MP2SF.pcc",
            "SFXGUI_WeaponUIDataDLC_CON_MP3SF.pcc",
            "SFXGUI_WeaponUIDataDLC_CON_MP4SF.pcc",
            "SFXGUI_WeaponUIDataDLC_CON_MP5SF.pcc",
        };

        /// <summary>
        /// Shipped LE3 SP donor files whose Data export's m_aWeapons array supplies higher-res assets/correct
        /// Wwise-backed CookData for the MP weapons that have an SP counterpart.
        /// </summary>
        private static readonly string[] SPWeaponUIDataFiles =
        {
            "SFXGUI_WeaponUIDataSF.pcc",
            "SFXGUI_WeaponUIDataDLC_HEN_PRSF.pcc",
            "SFXGUI_WeaponUIDataDLC_CON_GUN01SF.pcc",
            "SFXGUI_WeaponUIDataDLC_CON_GUN02SF.pcc",
            "SFXGUI_WeaponUIDataDLC_SharedSF.pcc",
        };

        /// <summary>
        /// Name of the package <see cref="PortWeaponDataPackage"/> builds.
        /// </summary>
        private const string MergedWeaponPackageName = "SFXGUI_WeaponUIDataDLC_CON_MPMerged";

        /// <summary>
        /// Name of the package <see cref="PortWeaponModDataPackage"/> builds. Registered in BioUI.xml next to the weapon one.
        /// </summary>
        private const string MergedWeaponModPackageName = "SFXGUI_WeaponUIDataDLC_CON_MPMergedMods";

        /// <summary>
        /// SP donor files whose weapons are kept in the merged weapon package whether or not an MP weapon matches them: the
        /// vanilla SP data and SharedSF, which used to be registered in BioUI.xml themselves (the base game's, and ours) and are
        /// replaced by the merged package. The DLC ones are not - their weapon classes aren't shipped, so a weapon with no MP
        /// counterpart would point at a class that doesn't exist. Order matters: a className already seen wins.
        /// </summary>
        private static readonly string[] SPKeptWeaponUIDataFiles =
        {
            "SFXGUI_WeaponUIDataSF.pcc",
            "SFXGUI_WeaponUIDataDLC_SharedSF.pcc",
        };

        /// <summary>
        /// SP donor files whose weapon mods (m_aMods) go into the merged weapon mod package, in the order that wins: the vanilla
        /// SP mods, then SharedSF's, with higher resolution art. MP5 identities and metadata are restored from MP
        /// donors by <see cref="MergeMPWeaponModData"/> before validating MP catalog coverage.
        /// </summary>
        private static readonly string[] SPWeaponModUIDataFiles =
        {
            "SFXGUI_WeaponUIDataSF.pcc",
            "SFXGUI_WeaponUIDataDLC_SharedSF.pcc",
        };

        /// <summary>
        /// Fields on a m_aWeapons struct entry that are kept from the matching SP donor entry (higher-res
        /// assets, LE3-era Wwise cook data) rather than the MP entry. Everything else on the struct - ClassPath,
        /// className, LoadoutInfo, Stats, and the TLK refs (Name/Description/ShortDescription) - is kept from
        /// the MP entry, since the merged package still loads the MP weapon class with MP balance/unlocks.
        /// </summary>
        private static readonly string[] SPSourcedWeaponFields =
        {
            "CookData", "WeaponModGripColors", "WeaponModBodyColors", "WeaponModEmissiveValues",
            "Image", "IconResource", "IconIndex", "EncumbranceWeight", "Type"
        };

        /// <summary>
        /// Builds a single merged SFXWeaponUIData package for the MP DLC weapons (SFXGUI_WeaponUIDataDLC_CON_MP1-5SF),
        /// pulling the higher-res assets and correctly-converted Wwise banks/events from the shipped LE3 SP version of
        /// each weapon (matched to its MP counterpart by identical Name/Description/ShortDescription TLK refs) while
        /// keeping the MP weapon's own ClassPath/className/LoadoutInfo/Stats/TLK refs, since we aren't shipping the
        /// SP gun classes. Weapons with no SP counterpart (Collector SMG, Collector Sniper Rifle, Spitfire) are kept
        /// entirely as their MP entry.
        ///
        /// Deliberately run here rather than in NonStartupPipeline: NonStartup runs before the checkpoint snapshot
        /// is taken, and the BioUI.xml merge config referencing this package's Package/Resource name is applied by
        /// ModBuilder even earlier. A checkpoint restore skips both ModBuilder and NonStartup, so anything living
        /// there would silently go stale until the checkpoint is invalidated. The Weapons pipeline always runs
        /// after the checkpoint restore point, so this always regenerates fresh.
        /// </summary>
        /// <returns>The object path of every texture the package holds.</returns>
        private static HashSet<string> PortWeaponDataPackage()
        {
            using var cache = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache(canPromoteInto: true, debugName: "PortWeaponDataPackage cache");

            var outputFolder = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", "NonStartup", "GUI");
            Directory.CreateDirectory(outputFolder);
            const string outPackageName = MergedWeaponPackageName;
            var outPath = Path.Combine(outputFolder, outPackageName + ".pcc");

            var destPackage = MEPackageHandler.CreateAndOpenPackage(outPath, MEGame.LE3);
            destPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME);
            var rootPackageExport = destPackage.CreatePackageExport(outPackageName);

            var tempExports = new List<ExportEntry>();

            // Port every SP donor file's Data export into the destination and index its weapons by TLK triple.
            var spWeaponsByTlk = new Dictionary<(int Name, int Description, int ShortDescription), StructProperty>();
            var spKeptWeapons = new List<StructProperty>();
            foreach (var spFile in SPWeaponUIDataFiles)
            {
                var spPackage = MilanShared.GetLE3Package(spFile);
                if (spPackage == null)
                {
                    MilanLog.Warning($"Could not load SP weapon UI data donor {spFile}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                var spData = spPackage.Exports.FirstOrDefault(x => x.ClassName == "SFXWeaponUIData");
                var spWeapons = spData?.GetProperty<ArrayProperty<StructProperty>>("m_aWeapons");
                if (spWeapons == null || spWeapons.Count == 0)
                    continue; // e.g. SharedSF only carries m_aMods, not m_aWeapons

                spData.Parent = null; // Port just this export and its dependencies, not the whole donor package tree
                var spRop = new RelinkerOptionsPackage()
                {
                    Cache = cache,
                    DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                    SourceCustomImportFileResolver = MilanShared.LE3PackageResolver,
                };
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, spData, destPackage, null, true, spRop, out var portedEntry);
                var portedExport = (ExportEntry)portedEntry;
                portedExport.ObjectName = $"TempSPData_{tempExports.Count}";
                tempExports.Add(portedExport);

                var portedWeapons = portedExport.GetProperty<ArrayProperty<StructProperty>>("m_aWeapons");
                foreach (var weapon in portedWeapons)
                {
                    spWeaponsByTlk[GetWeaponTlkKey(weapon)] = weapon;
                    if (SPKeptWeaponUIDataFiles.Contains(spFile, StringComparer.OrdinalIgnoreCase))
                    {
                        spKeptWeapons.Add(weapon);
                    }
                }
            }

            // Port every MP source file's Data export, splicing in the matching SP entry's asset fields where found.
            var mergedWeapons = new ArrayProperty<StructProperty>("m_aWeapons");
            ExportEntry mergedDataExport = null;
            foreach (var mpFile in MPWeaponUIDataFiles)
            {
                var mpPackage = MilanShared.GetME3Package(mpFile);
                if (mpPackage == null)
                {
                    MilanLog.Warning($"Could not load MP weapon UI data source {mpFile}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                var mpData = mpPackage.Exports.FirstOrDefault(x => x.ClassName == "SFXWeaponUIData");
                var mpWeapons = mpData?.GetProperty<ArrayProperty<StructProperty>>("m_aWeapons");
                if (mpWeapons == null)
                    continue;

                mpData.Parent = null;
                var mpRop = new RelinkerOptionsPackage()
                {
                    Cache = cache,
                    TargetGameDonorDB = MilanShared.LE3ObjectDB,
                    PortExportsAsImportsWhenPossible = true,
                    GenerateImportsForGlobalFiles = true,
                    DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                    SourceCustomImportFileResolver = MilanShared.ME3PackageResolver,
                };
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, mpData, destPackage, null, true, mpRop, out var portedEntry);
                var portedExport = (ExportEntry)portedEntry;

                if (mergedDataExport == null)
                {
                    // Reuse the first ported MP Data export as the final merged Data export.
                    mergedDataExport = portedExport;
                    mergedDataExport.ObjectName = "Data";
                    mergedDataExport.Parent = rootPackageExport;
                }
                else
                {
                    portedExport.ObjectName = $"TempMPData_{tempExports.Count}";
                    tempExports.Add(portedExport);
                }

                var portedWeapons = portedExport.GetProperty<ArrayProperty<StructProperty>>("m_aWeapons");
                foreach (var weapon in portedWeapons)
                {
                    var merged = weapon.DeepClone();
                    if (spWeaponsByTlk.TryGetValue(GetWeaponTlkKey(weapon), out var spWeapon))
                    {
                        foreach (var fieldName in SPSourcedWeaponFields)
                        {
                            var spProp = spWeapon.GetProp<Property>(fieldName);
                            if (spProp != null)
                                merged.Properties.AddOrReplaceProp(spProp.DeepClone());
                        }
                    }
                    mergedWeapons.Add(merged);
                }
            }

            if (mergedDataExport == null)
                throw new InvalidOperationException("PortWeaponDataPackage: no MP weapon UI data source packages could be loaded.");

            // The SP weapons that no MP weapon stands in for. The vanilla SP data is no longer installed or registered, so they
            // come from here (an MP weapon with the same class wins)
            var mergedClassNames = mergedWeapons.Select(x => x.GetProp<NameProperty>("className")?.Value.Instanced).ToHashSet();
            int spWeaponsAdded = 0;
            foreach (var weapon in spKeptWeapons)
            {
                var className = weapon.GetProp<NameProperty>("className")?.Value.Instanced;
                if (className != null && mergedClassNames.Add(className))
                {
                    mergedWeapons.Add(weapon.DeepClone());
                    spWeaponsAdded++;
                }
            }
            MilanLog.Information($"Kept {spWeaponsAdded} SP weapon(s) next to the {mergedWeapons.Count - spWeaponsAdded} MP weapon(s)", customPrefix: LOG_CATEGORY);

            OrderUIDataLikeME3(mergedWeapons);
            mergedDataExport.WriteProperty(mergedWeapons);

            // Clean up every temporary donor copy now that we've harvested what we needed from them.
            foreach (var temp in tempExports)
            {
                EntryPruner.TrashEntryAndDescendants(temp);
            }

            // Cloning the donor Data exports' dependencies brought in everything their weapons use, not only the weapons that were
            // kept (the MP weapons an SP one stood in for, the SP DLC weapons). Those leftovers are not needed
            PruneUnreachableExports(destPackage, mergedDataExport);

            // GUI mips are applied to every copy together by AssetFix, before texture processing.

            destPackage.Save();
            MilanLog.Information($"Wrote merged weapon UI data package to {outPath} ({mergedWeapons.Count} weapons)", customPrefix: LOG_CATEGORY);
            return GetTexturePaths(destPackage);
        }

        /// <summary>
        /// Builds the merged SFXWeaponUIData package for weapon mods (m_aMods), the way <see cref="PortWeaponDataPackage"/> does for
        /// weapons: SP donors provide higher resolution art, while the five MP5 mods retain their MP identities and
        /// metadata. Replaces the vanilla SP data and SharedSF, which are no longer registered. Missing or duplicate
        /// MP entries fail the build before the package is saved.
        /// </summary>
        /// <returns>The object path of every texture the package holds.</returns>
        private static HashSet<string> PortWeaponModDataPackage()
        {
            using var cache = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache(canPromoteInto: true, debugName: "PortWeaponModDataPackage cache");

            var outputFolder = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole", "NonStartup", "GUI");
            Directory.CreateDirectory(outputFolder);
            var outPath = Path.Combine(outputFolder, MergedWeaponModPackageName + ".pcc");

            var destPackage = MEPackageHandler.CreateAndOpenPackage(outPath, MEGame.LE3);
            destPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME);
            var rootPackageExport = destPackage.CreatePackageExport(MergedWeaponModPackageName);

            var tempExports = new List<ExportEntry>();
            var mergedMods = new ArrayProperty<StructProperty>("m_aMods");
            var modClassNames = new HashSet<string>();
            ExportEntry mergedDataExport = null;
            foreach (var spFile in SPWeaponModUIDataFiles)
            {
                var spPackage = MilanShared.GetLE3Package(spFile);
                var spData = spPackage?.Exports.FirstOrDefault(x => x.ClassName == "SFXWeaponUIData");
                if (spData?.GetProperty<ArrayProperty<StructProperty>>("m_aMods") is not { Count: > 0 })
                {
                    MilanLog.Warning($"SP weapon UI data donor {spFile} has no weapon mods", customPrefix: LOG_CATEGORY);
                    continue;
                }

                spData.Parent = null; // Port just this export and its dependencies, not the whole donor package tree
                var spRop = new RelinkerOptionsPackage()
                {
                    Cache = cache,
                    DestinationCustomImportFileResolver = MilanShared.LE3PackageResolver,
                    SourceCustomImportFileResolver = MilanShared.LE3PackageResolver,
                };
                EntryImporter.ImportAndRelinkEntries(EntryImporter.PortingOption.CloneAllDependencies, spData, destPackage, null, true, spRop, out var portedEntry);
                var portedExport = (ExportEntry)portedEntry;
                if (mergedDataExport == null)
                {
                    mergedDataExport = portedExport;
                    mergedDataExport.ObjectName = "Data";
                    mergedDataExport.Parent = rootPackageExport;
                }
                else
                {
                    portedExport.ObjectName = $"TempSPData_{tempExports.Count}";
                    tempExports.Add(portedExport);
                }

                foreach (var mod in portedExport.GetProperty<ArrayProperty<StructProperty>>("m_aMods"))
                {
                    var className = GetModClassName(mod);
                    if (className == null || modClassNames.Add(className))
                    {
                        mergedMods.Add(mod.DeepClone());
                    }
                }
            }

            if (mergedDataExport == null)
                throw new InvalidOperationException("PortWeaponModDataPackage: no SP weapon UI data donor with weapon mods could be loaded.");

            var mpMods = new List<StructProperty>();
            foreach (var mpFile in MPWeaponUIDataFiles.Prepend("SFXGUI_WeaponUIDataSF.pcc").Append("SFXGUI_WeaponUIDataDLC_SharedSF.pcc"))
            {
                var mpPackage = MilanShared.GetME3Package(mpFile)
                    ?? throw new InvalidOperationException($"Cannot validate MP weapon mods: missing {mpFile}");
                var mpData = mpPackage.Exports.FirstOrDefault(x => x.ClassName == "SFXWeaponUIData")
                    ?? throw new InvalidOperationException($"Cannot validate MP weapon mods: {mpFile} has no UI data");
                if (mpData.GetProperty<ArrayProperty<StructProperty>>("m_aMods") is { } sourceMods)
                    mpMods.AddRange(sourceMods);
            }
            MergeMPWeaponModData(mergedMods, mpMods);
            var builtPackages = Directory.EnumerateFiles(Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole"), "*.pcc", SearchOption.AllDirectories)
                .ToLookup(Path.GetFileNameWithoutExtension, StringComparer.OrdinalIgnoreCase);
            ValidateWeaponModPreviews(mergedMods, packageName =>
            {
                var builtPath = builtPackages[packageName].FirstOrDefault();
                if (builtPath != null)
                    return MEPackageHandler.OpenMEPackage(builtPath);
                return MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, packageName + ".pcc", out var basePath)
                    ? MEPackageHandler.OpenMEPackage(basePath)
                    : null;
            });

            OrderUIDataLikeME3(mergedMods);
            mergedDataExport.WriteProperty(mergedMods);
            mergedDataExport.RemoveProperty("m_aWeapons"); // The weapons are in the other package

            foreach (var temp in tempExports)
            {
                EntryPruner.TrashEntryAndDescendants(temp);
            }

            PruneUnreachableExports(destPackage, mergedDataExport);

            destPackage.Save();
            MilanLog.Information($"Wrote merged weapon mod UI data package to {outPath} ({mergedMods.Count} mods)", customPrefix: LOG_CATEGORY);
            return GetTexturePaths(destPackage);
        }

        // Explicit pairs: these SP presentation donors use different identities from the MP unlocks.
        private static readonly Dictionary<string, string> MPWeaponModPresentationDonors = new(StringComparer.OrdinalIgnoreCase)
        {
            ["SFXGameContentDLC_CON_MP5.SFXWeaponMod_AssaultRifleUltraLight_MP5"] = "SFXGameContentDLC_EXP_Pack003.SFXWeaponMod_AssaultRifleUltraLight",
            ["SFXGameContentDLC_CON_MP5.SFXWeaponMod_ShotgunUltraLight_MP5"] = "SFXGameContentDLC_EXP_Pack003.SFXWeaponMod_ShotgunUltraLight",
            ["SFXGameContentDLC_CON_MP5.SFXWeaponMod_SniperRifleUltraLight_MP5"] = "SFXGameContentDLC_EXP_Pack003.SFXWeaponMod_SniperRifleUltraLight",
            ["SFXGameContentDLC_CON_MP5.SFXWeaponMod_PistolPowerDamage_MP5"] = "SFXGameContentDLC_EXP_Pack003.SFXWeaponMod_PistolPowerDamage",
            ["SFXGameContentDLC_CON_MP5.SFXWeaponMod_SMGPowerDamage_MP5"] = "SFXGameContentDLC_EXP_Pack003.SFXWeaponMod_SMGPowerDamage",
        };

        /// <summary>
        /// Replace SP substitutes with MP entries, retaining only already-relinked SP UI images.
        /// MP Image/LargeImage references belong to their source packages and must never be copied directly.
        /// Keep the MP CookedPackage/Meshes pair: only the MP preview packages are shipped by NonStartups.
        /// </summary>
        internal static void MergeMPWeaponModData(ArrayProperty<StructProperty> mergedMods, IEnumerable<StructProperty> sourceMods)
        {
            var mpMods = sourceMods.ToArray();
            foreach (var (mpPath, spPath) in MPWeaponModPresentationDonors)
            {
                var sources = mpMods.Where(x => string.Equals(x.GetProp<StrProperty>("ClassPath")?.Value, mpPath, StringComparison.OrdinalIgnoreCase)).ToArray();
                var donors = mergedMods.Where(x => string.Equals(x.GetProp<StrProperty>("ClassPath")?.Value, spPath, StringComparison.OrdinalIgnoreCase)).ToArray();
                if (sources.Length != 1 || donors.Length != 1)
                    throw new InvalidOperationException($"Weapon mod {mpPath} requires exactly one MP source and SP presentation donor {spPath}; found {sources.Length} and {donors.Length}.");

                var merged = sources[0].DeepClone();
                foreach (var field in new[] { "Image", "LargeImage" })
                {
                    var presentation = donors[0].GetProp<Property>(field)
                        ?? throw new InvalidOperationException($"Weapon mod presentation donor {spPath} is missing {field}.");
                    merged.Properties.AddOrReplaceProp(presentation.DeepClone());
                }
                mergedMods[mergedMods.IndexOf(donors[0])] = merged;
            }

            var catalogPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var mod in mergedMods)
            {
                var path = mod.GetProp<StrProperty>("ClassPath")?.Value;
                if (string.IsNullOrWhiteSpace(path) || !catalogPaths.Add(path))
                    throw new InvalidOperationException($"Merged weapon mod catalog has a missing or duplicate ClassPath: {path}");
            }
            foreach (var mod in mpMods)
            {
                var path = mod.GetProp<StrProperty>("ClassPath")?.Value;
                if (string.IsNullOrWhiteSpace(path) || !catalogPaths.Contains(path))
                    throw new InvalidOperationException($"MP weapon mod {path} is missing from the merged weapon mod catalog.");
            }
        }

        /// <summary>
        /// The bench asynchronously loads CookedPackage for every nonempty preview mesh. Check the actual
        /// built/base packages and mesh exports, so an unshipped SP preview cannot pass catalog validation.
        /// Mods without meshes (including ultralights) do not request a preview package
        /// </summary>
        internal static void ValidateWeaponModPreviews(IEnumerable<StructProperty> mods, Func<string, IMEPackage?> openPackage)
        {
            foreach (var group in mods.Where(x => x.GetProp<ArrayProperty<StrProperty>>("Meshes")?.Any(m => !string.IsNullOrEmpty(m.Value)) == true)
                         .GroupBy(x => x.GetProp<StrProperty>("CookedPackage")?.Value, StringComparer.OrdinalIgnoreCase))
            {
                if (string.IsNullOrWhiteSpace(group.Key))
                {
                    throw new InvalidOperationException("Weapon mod with preview meshes has no CookedPackage.");
                }
                using var preview = openPackage(group.Key) ?? throw new InvalidOperationException($"Weapon mod preview package {group.Key} is not shipped by the build or LE3.");
                foreach (var mod in group)
                {
                    foreach (var mesh in mod.GetProp<ArrayProperty<StrProperty>>("Meshes").Where(x => !string.IsNullOrEmpty(x.Value)))
                    {
                        if (preview.FindExport(mesh.Value)?.ClassName != "StaticMesh")
                            throw new InvalidOperationException($"Weapon mod {mod.GetProp<StrProperty>("ClassPath")?.Value} preview {group.Key} is missing StaticMesh {mesh.Value}.");
                    }
                }
            }
        }

        // Keep ME3 ordering. Since we port from SP the order is messed up as they released different order
        private static void OrderUIDataLikeME3(ArrayProperty<StructProperty> entries)
        {
            string[] sourceFiles =
            {
                "SFXGUI_WeaponUIDataSF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP1SF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP2SF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP3SF.pcc",
                "SFXGUI_WeaponUIDataDLC_SharedSF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP4SF.pcc",
                "SFXGUI_WeaponUIDataDLC_CON_MP5SF.pcc",
            };
            var classOrder = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var modNameOrder = new Dictionary<int, int>();
            int rank = 0;
            foreach (var sourceFile in sourceFiles)
            {
                var package = MilanShared.GetME3Package(sourceFile)
                    ?? throw new InvalidOperationException($"Cannot preserve ME3 weapon UI order: missing {sourceFile}");
                var sourceEntries = package.Exports.FirstOrDefault(x => x.ClassName == "SFXWeaponUIData")
                    ?.GetProperty<ArrayProperty<StructProperty>>(entries.Name);
                if (sourceEntries == null)
                    continue; // Most MP donors carry only weapons, not mods.

                foreach (var entry in sourceEntries)
                {
                    var classPath = entry.GetProp<StrProperty>("ClassPath")?.Value;
                    if (classPath != null)
                        classOrder.TryAdd(classPath, rank);
                    // MP5's mods use different class paths in LE3, but retain the same name TLK IDs.
                    if (entries.Name == "m_aMods" && entry.GetProp<StringRefProperty>("Name") is { Value: > 0 } name)
                        modNameOrder.TryAdd(name.Value, rank);
                    rank++;
                }
            }

            // Unmatched LMP additions and equal-ranked entries keep their relative order.
            var ordered = entries.OrderBy(entry =>
            {
                var classPath = entry.GetProp<StrProperty>("ClassPath")?.Value;
                if (classPath != null && classOrder.TryGetValue(classPath, out int classRank))
                    return classRank;
                if (entry.GetProp<StringRefProperty>("Name") is { } name && modNameOrder.TryGetValue(name.Value, out int modRank))
                    return modRank;
                return int.MaxValue;
            }).ToArray();
            entries.Clear();
            foreach (var entry in ordered)
                entries.Add(entry);
        }

        private static string GetModClassName(StructProperty mod) =>
            mod.GetProp<NameProperty>("className")?.Value.Instanced ?? mod.GetProp<NameProperty>("ModClass")?.Value.Instanced;

        private static HashSet<string> GetTexturePaths(IMEPackage package) =>
            package.Exports.Where(x => x.ClassName == "Texture2D").Select(x => x.InstancedFullPath).ToHashSet(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// The vanilla SP weapon UI data (SFXGUI_WeaponUIDataSF) is not installed any more, and some of its textures are loaded by
        /// path from elsewhere (the weapon image packages the base game maps them to, the codex), so everything it held must
        /// be in one of the merged packages. Anything that isn't is reported.
        /// </summary>
        private static void CheckBaseWeaponTexturesAreProvided(HashSet<string> weaponTextures, HashSet<string> modTextures)
        {
            var baseData = MilanShared.GetLE3Package("SFXGUI_WeaponUIDataSF.pcc");
            if (baseData == null)
            {
                MilanLog.Warning("Could not load SFXGUI_WeaponUIDataSF to check its textures are in the merged weapon packages", customPrefix: LOG_CATEGORY);
                return;
            }

            var missing = GetTexturePaths(baseData).Where(x => !weaponTextures.Contains(x) && !modTextures.Contains(x)).Order().ToList();
            foreach (var path in missing)
            {
                MilanLog.Error($"{path} was in SFXGUI_WeaponUIDataSF, which is no longer installed, and is in neither merged weapon package", customPrefix: LOG_CATEGORY);
            }
        }

        /// <summary>
        /// Removes every export that the merged Data export does not reach (through properties, binary, parents, classes and
        /// archetypes). ImportAndRelinkEntries with CloneAllDependencies brings in everything the donor Data exports' weapons
        /// refer to - the images and icon movies of the SP weapons that have no MP counterpart, for example - and trashing the
        /// donor export afterwards only removes the export and its children, leaving those dependencies behind unreferenced.
        /// Left in, they are dead weight, and duplicates of textures that the base game and our other packages already hold.
        /// </summary>
        private static void PruneUnreachableExports(IMEPackage package, ExportEntry dataExport)
        {
            var reachable = package.GetReferencedEntries(true, false, dataExport);
            for (IEntry entry = dataExport; entry != null; entry = entry.Parent)
            {
                reachable.Add(entry.UIndex); // The search starts at the Data export, so it does not add it or the packages above it
            }

            var unreachable = package.Exports.Where(x => !reachable.Contains(x.UIndex)).ToList();
            if (unreachable.Count == 0)
                return;

            var summary = string.Join(", ", unreachable.GroupBy(x => x.ClassName).OrderByDescending(x => x.Count()).Select(x => $"{x.Count()} {x.Key}"));
            EntryPruner.TrashEntriesAndDescendants(unreachable);
            MilanLog.Information($"Pruned {unreachable.Count} export(s) the merged weapon UI data does not reach ({summary})", customPrefix: LOG_CATEGORY);
        }

        private static (int Name, int Description, int ShortDescription) GetWeaponTlkKey(StructProperty weapon)
        {
            return (
                weapon.GetProp<StringRefProperty>("Name")?.Value ?? 0,
                weapon.GetProp<StringRefProperty>("Description")?.Value ?? 0,
                weapon.GetProp<StringRefProperty>("ShortDescription")?.Value ?? 0
            );
        }

        private static object _weaponSyncObj = new object();

        private static void BeginPorting(WeaponSpecificPipeline weaponPipeline, TieredPackageCache pipelineCache)
        {
            weaponPipeline.LogCategory = $"{LOG_CATEGORY}-{weaponPipeline.PackageName}";

            // Initialize cache
            weaponPipeline.Cache = pipelineCache.ChainNewCache(debugName: $"SFXWeapons weapon cache ({weaponPipeline.PackageName})");
            weaponPipeline.Cache.InsertIntoCache(MilanShared.GetLE3GlobalPackages());

            Directory.CreateDirectory(OutputFolder);
            var finalPackagePath = Path.Combine(OutputFolder, weaponPipeline.PackageName + ".pcc");

            // Find modified source text.
            string file;
            lock (_weaponSyncObj) // Prevent multithread enumeration issues 
            {
                file = Directory.GetFiles(Path.Combine(MilanShared.PipelineRoot, "Weapons", "Modified"),
                    $"{weaponPipeline.WeaponClassName}.uc", SearchOption.AllDirectories).First();
            }

            var package = GetPackageName(file);
            var sourceclassText = File.ReadAllText(file);

            var looseClassPackages = new List<UnrealScriptCompiler.LooseClassPackage>();

            // Add main class
            UnrealScriptCompiler.LooseClassPackage lp = new UnrealScriptCompiler.LooseClassPackage(package,
                new List<UnrealScriptCompiler.LooseClass>()
                {
                    new UnrealScriptCompiler.LooseClass(weaponPipeline.WeaponClassName, sourceclassText)
                });
            looseClassPackages.Add(lp);

            var milanBase = Path.Combine(MilanShared.PipelineRoot, "Weapons", "Modified", package, Path.GetFileNameWithoutExtension(file));
            if (Directory.Exists(milanBase))
            {
                // Add custom other classes that we need to compile as well.
                var customClasses = Directory.GetFileSystemEntries(milanBase, "*.uc", SearchOption.AllDirectories);
                foreach (var cc in customClasses)
                {
                    AddClassToCompilation(looseClassPackages, GetPackageName(cc), new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(cc), File.ReadAllText(cc)));
                }
            }

            if (weaponPipeline.LE3PackageName != null)
            {
                var le3SourcePackage = MilanShared.GetLE3Package($"{weaponPipeline.LE3PackageName}.pcc");
                weaponPipeline.BaseObjectPaths.ReplaceAll(le3SourcePackage.Exports
                    .Where(x => x.ClassName == "Package" && x.idxLink == 0)
                    .Select(x => x.InstancedFullPath));
            }

            var me3SourcePackage = MilanShared.GetME3Package($"{weaponPipeline.PackageName}.pcc");
            weaponPipeline.BaseObjectPaths.AddRange(me3SourcePackage.Exports.Where(x => x.ClassName == "Package" && x.idxLink == 0 && !weaponPipeline.BaseObjectPaths.Contains(x.InstancedFullPath))
                .Select(x => x.InstancedFullPath));

            // Should see if we can have it check if inputs (donors) are the same again and if so and it fails it breaks.
            // Otherwise this is an infinite loop.
            while (!CompileWeapon(finalPackagePath, looseClassPackages, weaponPipeline))
            {

            }

            /*
            if (false)
            {
                MilanShared.PortObjectReferencer(kitSourcePackage, weaponDestPackage, weaponPipeline.Cache, weaponPipeline.LogCategory);
            }*/

            weaponPipeline.Cache.Dispose();
        }

        private static void AddClassToCompilation(List<UnrealScriptCompiler.LooseClassPackage> looseClassPackages, string packageName, UnrealScriptCompiler.LooseClass looseClass)
        {
            var classList = looseClassPackages.Find(x => x.PackageName == packageName);
            if (classList == null)
            {
                classList = new UnrealScriptCompiler.LooseClassPackage(packageName, new List<UnrealScriptCompiler.LooseClass>());
                looseClassPackages.Add(classList);
            }
            classList.Classes.Add(looseClass);
        }

        private static bool CompileWeapon(string finalPackagePath, List<UnrealScriptCompiler.LooseClassPackage> classes, WeaponSpecificPipeline pipeline)
        {
            //foreach (string ucFilePath in GetMPCommonClassFiles())
            //{
            //    var overridePath = MilanShared.GetClassOverride(Path.GetFileNameWithoutExtension(ucFilePath));
            //    string source = File.ReadAllText(overridePath ?? ucFilePath);
            //    //files must be named Classname.uc
            //    classes.Add(new UnrealScriptCompiler.LooseClass(Path.GetFileNameWithoutExtension(ucFilePath), source, ucFilePath)); // Always use ucFilePath as it will be in the proper package folder, even if it goes unused.
            //}

            var weaponDestPackage = MEPackageHandler.CreateAndOpenPackage(finalPackagePath, MEGame.LE3);
            weaponDestPackage.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Hint this for importing.
            weaponDestPackage.LECLTagData.IsPostLoadFile = false; // Do not allow using 

            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = pipeline.Cache,
                MissingObjectResolver = MilanShared.MissingObjectResolverExportsAsImports,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                CustomFileResolver = MilanShared.LE3PackageResolver,
                BaseFilesFileLib = LE3FileLibCache.GetBaseFilesFileLibFor(weaponDestPackage),
            };
            // Different forced export packages



            MilanLog.Information($@"Compiling LE3 class package {weaponDestPackage.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
            MessageLog log = UnrealScriptCompiler.CompileLooseClasses(weaponDestPackage, classes, usop);

            if (log.HasErrors)
            {
                if (AttemptToFindMissingClasses(log, pipeline, out var containingPackage, out var lClass))
                {
                    AddClassToCompilation(classes, containingPackage, lClass);
                    return false; // False - forces recomp
                }
                MilanLog.Error("COMPILATION OF CUSTOM CLASSES FAILED: ", customPrefix: LOG_CATEGORY);
                foreach (var error in log.AllErrors)
                {
                    MilanLog.Error($"  {error}", customPrefix: LOG_CATEGORY);
                }

                return false;
            }

            FileLib lib = null;
            foreach (var clsIFP in MilanShared.ClassesToDoubleRecompile)
            {
                var classX = weaponDestPackage.FindExport(clsIFP);
                if (classX == null)
                    continue;

                if (lib == null)
                {
                    lib = new FileLib(weaponDestPackage);
                    if (!lib.Initialize(usop))
                    {
                        MilanShared.LogFailedFileLibInit(lib);
                    }
                }
                MilanLog.Information($"  Double recompiling {classX.ObjectName}", customPrefix: LOG_CATEGORY);
                (_, string text) = UnrealScriptCompiler.DecompileExport(classX, lib, usop);
                UnrealScriptCompiler.CompileClass(weaponDestPackage, text, lib, usop, classX);
            }

            MilanLog.Information(@"Loose class compilation succeeded!", customPrefix: LOG_CATEGORY);

            MilanLog.Information(@"Creating object referencer", customPrefix: LOG_CATEGORY);
            PackageTools.CreateObjectReferencer(weaponDestPackage, false);
            foreach (var classExp in weaponDestPackage.Exports.Where(x => x.IsClass))
            {
                // Yeah this is inefficient. 
                PackageTools.AddToObjectReferencer(classExp);
            }

            if (pipeline.ApplyPostPortingCorrections != null)
            {
                pipeline.ApplyPostPortingCorrections(weaponDestPackage, pipeline);
            }

            weaponDestPackage.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);

            // Register as donor-able
            MilanShared.AddDonorPackage(weaponDestPackage.FilePath, pipeline.Cache);

            return true;
        }

        private static string GetPackageName(string sourceFilePath)
        {
            return Directory.GetParent(sourceFilePath).Name;
        }

        public static string DecompileClass(ExportEntry classExp, FileLib fileLib, PackageCache cache)
        {
            //if (classExp.ObjectName == "DamageType")
            //    Debug.WriteLine("");
            var usingTestPatch = false;
            if (classExp.Game == MEGame.ME3)
            {
                // We must first see if this is in testpatch!!
                var testPatchClass = MilanShared.GetTestPatchClass(classExp);
                if (testPatchClass != null)
                {
                    usingTestPatch = true;
                    classExp = testPatchClass;
                    fileLib = null; // Must re-init
                }
            }


            MilanLog.Information($"Decompiling {classExp.FileRef.Game} {classExp.InstancedFullPath}", shouldLog: MilanLog.LogDonorMessages, customPrefix: LOG_CATEGORY);
            if (usingTestPatch)
            {
                MilanLog.Information($@"  Using DLC_TestPatch version of {classExp.InstancedFullPath}", shouldLog: MilanLog.LogDonorMessages, customPrefix: LOG_CATEGORY);
            }
            UnrealScriptOptionsPackage usop = new UnrealScriptOptionsPackage()
            {
                Cache = cache,
                CustomFileResolver = MilanShared.ME3PackageResolver,
            };

            if (fileLib == null)
            {
                // Initialize filelib if it wasn't.
                try
                {

                    fileLib = new FileLib(classExp.FileRef);
                    if (!fileLib.Initialize(usop))
                    {
                        MilanShared.LogFailedFileLibInit(fileLib);
                    }
                }
                catch
                {
                    //we're not checking if it failed to initialize because we don't really care, since decompilation doesn't actually need an initialized filelib,
                    //it just makes the output a bit nicer (at the time of this writing all it does is resolve some integer literals into enum values)
                }
            }

            (_, string functionText) = UnrealScriptCompiler.DecompileExport(classExp, fileLib, usop);

            // 08/09/2026 TEMP FIX: 
            // Strip out ERROR: log messages as these are being recompiled
            functionText = MilanShared.CleanErrorComments(functionText, out var _);

            return functionText;
            // FUNCTION PATCHES
            //List<string> newFunction = PatchFunction(classExp.ObjectName, functionText);

            // Insert metadata about autogen
            //newFunction.Insert(0, $"// Source: {classExp.FileRef.Game}, {classExp.FileRef.FileNameNoExtension}");
            //newFunction.Insert(1, $"// Decompiled {DateTime.Now}");

            //File.WriteAllLines(ucOutPath, newFunction);
        }

        private static bool AttemptToFindMissingClasses(MessageLog log, WeaponSpecificPipeline pipeline, out string containingPackage, out UnrealScriptCompiler.LooseClass lClass)
        {
            lClass = null;
            containingPackage = null;

            List<string> decompiledClasses = new List<string>();

            // Code: Find class
            foreach (var m in log.AllErrors)
            {

                string className = null;

                // Pull missing class name out of error message
                if (m.Message.StartsWith("No class named '"))
                {
                    className = m.Message.Substring(16);
                }
                else if (m.Message.Contains("Unable to resolve class '"))
                {
                    className = m.Message.Substring(m.Message.IndexOf("Unable to resolve class '") + "Unable to resolve class '".Length);
                }
                else if (m.Message.StartsWith("The type '") && m.Message.Contains("' does not exist in the current scope"))
                {
                    className = m.Message.Substring("The type '".Length);
                }
                else if (m.Message.StartsWith("No type named '") && m.Message.Contains("' exists!"))
                {
                    className = m.Message.Substring("No type named '".Length);
                }
                else if (m.Message.Contains(" has no member named '"))
                {
                    if (m.Message.Contains("SFXWeapon_AssaultRifle_SentryTurret") ||
                        false

                        )
                    {
                        className = m.Message.Substring(m.Message.IndexOf(" has no member named '") + " has no member named '".Length);
                    }
                    else
                    {
                        continue; // Something else...
                    }
                }
                else
                {
                    // It's something else...
                    continue;
                }

                className = className.Substring(0, className.IndexOf('\''));

                if (decompiledClasses.Contains(className))
                    continue; // Already pending recompile

                foreach (var cbp in pipeline.BaseObjectPaths)
                {
                    string ifp;
                    if (cbp == null)
                    {
                        ifp = className;
                    }
                    else
                    {
                        ifp = $"{cbp}.{className}";
                    }

                    // Look in LE3 for donor
                    bool keepSearching = true;
                    var foundObjs = MilanShared.LE3ObjectDB.GetFilesContainingObject(ifp);
                    if (foundObjs != null)
                    {
                        foreach (var foundObj in foundObjs)
                        {
                            if (!keepSearching)
                                break;
                            var sourceFileName = Path.GetFileName(foundObj);
                            var package = MilanShared.GetLE3Package(sourceFileName);

                            // DLC system Milan uses doesn't look in SP files
                            // So if obj database has SP stuff this will fail
                            // Just keep going.
                            if (package != null)
                            {
                                MilanLog.Information($@"Found missing class '{className}' in LE3: {foundObj}", shouldLog: MilanLog.LogDonorMessages, customPrefix: LOG_CATEGORY);
                                var export = package.FindExport(ifp);
                                if (export != null)
                                {
                                    var decomp = DecompileClass(export, null, pipeline.Cache);
                                    containingPackage = export.ParentName;
                                    lClass = new UnrealScriptCompiler.LooseClass(export.ObjectName, decomp, sourceFileName);
                                    keepSearching = false;
                                    continue;
                                }

                                MilanLog.Warning($"Export did not reside in package, perhaps the wrong one was found? Could be overridden by DLC", customPrefix: LOG_CATEGORY);

                            }
                        }
                    }

                    // Looking ME3 for crossgen
                    if (!keepSearching)
                        continue; // Go to next error
                    foundObjs = MilanShared.ME3ObjectDB.GetFilesContainingObject(ifp);
                    if (foundObjs != null)
                    {
                        foreach (var foundObj in foundObjs)
                        {
                            if (!keepSearching)
                                break;
                            var sourceFileName = Path.GetFileName(foundObj);
                            var package = MilanShared.GetME3Package(sourceFileName);

                            // DLC system Milan uses doesn't look in SP files
                            // So if obj database has SP stuff this will fail
                            // Just keep going.
                            if (package != null)
                            {
                                MilanLog.Information($@"Found missing class '{className}' in ME3: {foundObj}", shouldLog: MilanLog.LogDonorMessages, customPrefix: LOG_CATEGORY);
                                var export = package.FindExport(ifp);
                                if (export != null)
                                {
                                    var decomp = DecompileClass(export, null, pipeline.Cache);
                                    containingPackage = export.ParentName;
                                    lClass = new UnrealScriptCompiler.LooseClass(export.ObjectName, decomp, sourceFileName);
                                    keepSearching = false;
                                    continue;
                                }

                                MilanLog.Warning($"Export did not reside in package, perhaps the wrong one was found? Could be overridden by DLC", customPrefix: LOG_CATEGORY);
                            }
                        }
                    }

                }
            }

            return lClass != null;
        }

#if FALSE
        // Used to find weapons
        public static void BuildKitPipelineCode()
        {
            MilanShared.LoadME3DLCTOCs();
            var kits = new List<string>();
            foreach (var f in MilanShared.ME3DLCFileMap)
            {
                if (f.Key.StartsWith("Bio") || !f.Key.RepresentsPackageFilePath())
                    continue;

                MilanLog.Information($"Loading {f.Key}");
                var package = MilanShared.GetME3Package(f.Key);
                var references = package.Exports.Where(x => x.ClassName == "ObjectReferencer");
                foreach (var reference in references)
                {
                    var objRefs = reference.GetProperty<ArrayProperty<ObjectProperty>>("ReferencedObjects");
                    if (objRefs != null)
                    {
                        foreach (var objRef in objRefs)
                        {
                            if (package.TryGetUExport(objRef.Value, out var exp))
                            {
                                if (exp.IsA("SFXPawn_PlayerMP"))
                                {
                                    // Got one
                                    kits.Add($"new KitSpecificPipeline() {{ PackageName = \"{package.FileNameNoExtension}\", Enabled = true}},");
                                }
                            }
                        }
                    }
                }
            }

            foreach (var kit in kits)
            {
                Debug.WriteLine(kit);
            }
        }
#endif
    }



    internal class MPWeaponVars
    {
        public readonly List<WeaponSpecificPipeline> WeaponPipelines = new()
        {
            // MP1
            new WeaponSpecificPipeline()
            {
                // Kishock Harpoon Gun
                WeaponClassName = "SFXWeapon_SniperRifle_Batarian",
                PackageName = "SFXWeapon_SniperRifle_BatarianDLC",
                LE3PackageName = "SFXWeapon_SniperRifle_Batarian_GUN02",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Geth Plasma SMG
                WeaponClassName = "SFXWeapon_SMG_Geth",
                PackageName = "SFXWeapon_SMG_GethDLC",
                LE3PackageName = "SFXWeapon_SMG_Geth_GUN01",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Striker Assault Rifle
                WeaponClassName = "SFXWeapon_AssaultRifle_Krogan",
                PackageName = "SFXWeapon_AssaultRifles_KroganDLC",
                LE3PackageName = "SFXWeapon_AssaultRifle_Krogan_GUN02",
                Enabled  = true
            },

            // MP2
            new WeaponSpecificPipeline()
            { 
                // Cerberus Harrier Assault Rifle
                WeaponClassName = "SFXWeapon_AssaultRifle_Cerberus",
                PackageName = "SFXWeapon_AssaultRifle_CerberusDLC",
                LE3PackageName = "SFXWeapon_AssaultRifle_Cerb_GUN01",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Prothean Particle Rifle
                WeaponClassName = "SFXWeapon_AssaultRifle_Prothean_MP",
                PackageName = "SFXWeapon_AssaultRifle_ProtheanDLC",
                LE3PackageName = "SFXWeapon_AssaultRifles_DLC1",
                Enabled  = true,
                ApplyPostPortingCorrections = ApplyDrellCameraFix
            },
            new WeaponSpecificPipeline()
            { 
                // Reegar Carbine Shotgun
                WeaponClassName = "SFXWeapon_Shotgun_Quarian",
                PackageName = "SFXWeapon_Shotgun_QuarianDLC",
                LE3PackageName = "SFXWeapon_Shotgun_Quarian_GUN01",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Krysae Sniper Rifle
                WeaponClassName = "SFXWeapon_SniperRifle_Turian",
                PackageName = "SFXWeapon_SniperRifle_TurianDLC",
                LE3PackageName = "SFXWeapon_SniperRifle_Turian_GUN01",
                Enabled  = true
            },

            // MP3
            new WeaponSpecificPipeline()
            { 
                // N7 Typhoon
                WeaponClassName = "SFXWeapon_AssaultRifle_LMG",
                PackageName = "SFXWeapon_AssaultRifle_LMGDLC",
                LE3PackageName = "SFXWeapon_AssaultRifle_LMG_GUN02",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // Acolyte Pistol
                WeaponClassName = "SFXWeapon_Pistol_Asari",
                PackageName = "SFXWeapon_Pistol_AsariDLC",
                LE3PackageName = "SFXWeapon_Pistol_Asari_GUN02",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            { 
                // N7 Piranha
                WeaponClassName = "SFXWeapon_Shotgun_Assault",
                PackageName = "SFXWeapon_Shotgun_AssaultDLC",
                LE3PackageName = "SFXWeapon_Shotgun_Assault_GUN02",
                Enabled  = true
            },

            // MP4
            new WeaponSpecificPipeline()
            {
                // Collector SMG
                WeaponClassName = "SFXWeapon_SMG_Collector",
                PackageName = "SFXWeapon_SMG_Collector",
                LE3PackageName = "BioD_CitSim_CllctrB", // There is no direct LE3 version of this package. It uses a _Shared version
                // MUST BE BUILT OR COLLECTOR TROOPER CAN'T BUILD (or at least that's how it used to be)
                Enabled = true
            },
            new WeaponSpecificPipeline()
            {
                // Collector Sniper Rifle
                WeaponClassName = "SFXWeapon_SniperRifle_Collector",
                PackageName = "SFXWeapon_SniperRifle_Collector",
                LE3PackageName = null, // There is no LE3 version of this package.
                Enabled  = true,
                ApplyPostPortingCorrections = ApplyDrellCameraFix
            },

            // MP5
            new WeaponSpecificPipeline()
            {
                // Adas Assault Rifle
                WeaponClassName = "SFXWeapon_AssaultRifle_Adas_MP",
                PackageName = "SFXWeapon_AssaultRifle_Adas_MP",
                LE3PackageName = "SFXWeapon_AssaultRifle_Quarian",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // M-7 Lancer
                WeaponClassName = "SFXWeapon_AssaultRifle_Lancer_MP",
                PackageName = "SFXWeapon_AssaultRifle_Lancer_MP",
                LE3PackageName = "SFXWeapon_AssaultRifle_Lancer",
                Enabled  = true,
                ApplyPostPortingCorrections = ApplyDrellCameraFix
            },
            new WeaponSpecificPipeline()
            {
                // Geth Spitfire
                WeaponClassName = "SFXWeapon_AssaultRifle_Spitfire",
                PackageName = "SFXWeapon_AssaultRifle_Spitfire",
                LE3PackageName = "SFXWeapon_AssaultRifle_Spitfire", // There is no direct LE3 version of this package. It is a heavy weapon version. Looks like maybe it was going to be a normal weapon though
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Bloodpack Executioner
                WeaponClassName = "SFXWeapon_Pistol_Bloodpack_MP",
                PackageName = "SFXWeapon_Pistol_Bloodpack_MP",
                LE3PackageName = "SFXWeapon_Pistol_Bloodpack",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Silencer Pistol
                WeaponClassName = "SFXWeapon_Pistol_Silencer_MP",
                PackageName = "SFXWeapon_Pistol_Silencer_MP",
                LE3PackageName = "SFXWeapon_Pistol_Silencer",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Venom Shotgun
                WeaponClassName = "SFXWeapon_Shotgun_Salarian_MP",
                PackageName = "SFXWeapon_Shotgun_Salarian_MP",
                LE3PackageName = "SFXWeapon_Shotgun_Salarian",
                Enabled  = true
            },
            new WeaponSpecificPipeline()
            {
                // Bloodpack Punisher
                WeaponClassName = "SFXWeapon_SMG_Bloodpack_MP",
                PackageName = "SFXWeapon_SMG_Bloodpack_MP",
                LE3PackageName = "SFXWeapon_SMG_Bloodpack",
                Enabled  = true
            },
        };

        private static void ApplyDrellCameraFix(IMEPackage package, WeaponSpecificPipeline pipeline)
        {
            // Drell have a different camera offset, so these weapons' shared firing animation shifts the camera.
            // we have to track the 'camera' bone during translation or it shifts it

            // It's called reload for the whole animset
            // PPR
            var patchAnim = package.FindExport("BIOG_HMM_CB_HEN_PR.HMM_CB_ProtheanRifleReload_BioAnimSetData", "BioAnimSetData");
            if (patchAnim == null)
            {
                // Lancer
                // they just reused the PPR name too
                patchAnim = package.FindExport("BIOG_DLC_EXP003_HMM_A.HMM_CB_ProtheanRifleReload_BioAnimSetData", "BioAnimSetData");
            }

            if (patchAnim == null)
            {
                // Collector Sniper Rifle
                patchAnim = package.FindExport("BIOG_DLC_MP4_CBT_A.HMM_CB_ProtheanRifleReload_BioAnimSetData", "BioAnimSetData");
            }

            if (patchAnim == null)
            {
                throw new Exception($"Couldn't find drell camera export to fix in {package.FileNameNoExtension}");
            }

            var translation = patchAnim.GetProperty<ArrayProperty<NameProperty>>("UseTranslationBoneNames");
            translation.Add(new NameProperty("Camera"));
            patchAnim.WriteProperty(translation);
        }
    }
}
