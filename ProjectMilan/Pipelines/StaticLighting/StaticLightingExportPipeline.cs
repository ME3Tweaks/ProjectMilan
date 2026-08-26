using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore;
using ProjectMilan.MilanUDK;
using ProjectMilan.Utility;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using ProjectMilan.Pipelines.Levels;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Pipeline for exporting levels to UDK for static lighting build
    /// </summary>
    public static class StaticLightingExport
    {
        private const string LOG_CATEGORY = @"MILAN-StaticLightingExport";


        /// <summary>
        /// Gets the path where UDK will output its map files that have lighting baked into them
        /// </summary>
        /// <param name="mapName"></param>
        /// <returns></returns>
        public static string GetMapOutputPath(string mapName)
        {
            return Directory.CreateDirectory(Path.Combine(UDKDirectory.MapsPath, mapName)).FullName;
        }

        public static string GetAssetsOutputPath(string mapName)
        {
            return Directory.CreateDirectory(Path.Combine(UDKDirectory.SharedPath, "Assets", mapName)).FullName;
        }

        public static bool ExportLevelToUDK(LevelSpecificPipeline level)
        {
            var levelMaster = level.LE3BioP;

            // Set UDK paths so we don't have to change LEC code. This doesn't persist.
            UDKDirectory.DefaultGamePath = Program.Settings.MilanUDKPath;
            LegendaryExplorerCoreLibSettings.Instance.UDKCustomDirectory = Program.Settings.MilanUDKPath;

            string persistentLevelFileName = levelMaster.FileNameNoExtension;

            var mapOutputPath = GetMapOutputPath(persistentLevelFileName);
            var assetOutputPath = GetAssetsOutputPath(persistentLevelFileName);

            MilanLog.Information($"Converting {persistentLevelFileName} to UDK", customPrefix: LOG_CATEGORY);
            Utilities.DeleteFilesAndFoldersRecursively(mapOutputPath, deleteDirectoryItself: false);
            Utilities.DeleteFilesAndFoldersRecursively(assetOutputPath, deleteDirectoryItself: false);
            var decookedMaterialsDir = UDKSetup.GetMilanDecookedMaterialsDirectory();

            // This is kind of a hack. This is just so we can pass the delegates through 
            // without having to change stuff in LEC right now.
            RelinkerOptionsPackage delegatesROP = new RelinkerOptionsPackage();
            delegatesROP.CustomRelinkUIndex = UDKSetupT3D.ImportOutsideOfPackageRelink;
            delegatesROP.SourceCustomImportFileResolver = MilanShared.LE3PackageResolver;

            string persistentPath = ConvertToUDK.GenerateUDKFileForLevel(levelMaster, mapOutputPath, assetOutputPath, decookedMaterialsDir);
            var levelFiles = new List<string>();
            if (levelMaster is MEPackage mePackage)
            {
                var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(levelMaster.Game);
                foreach (string additionalPackage in mePackage.AdditionalPackagesToCook)
                {
                    if (level.IgnoredLightingLevels != null && level.IgnoredLightingLevels.Contains(additionalPackage, StringComparer.OrdinalIgnoreCase))
                    {
                        // This also will make it not populate into levelfiles so UDK won't build it either there.
                        MilanLog.Information($"Ignoring sublevel {additionalPackage} for UDK conversion", customPrefix: LOG_CATEGORY);
                        continue;
                    }

                    if (loadedFiles.TryGetValue($"{additionalPackage}.pcc", out string filePath))
                    {
                        MilanLog.Information($"Converting sublevel {additionalPackage} to UDK", customPrefix: LOG_CATEGORY);
                        using IMEPackage levPcc = MEPackageHandler.OpenMEPackage(filePath);
                        levelFiles.Add(ConvertToUDK.GenerateUDKFileForLevel(levPcc, mapOutputPath, assetOutputPath, decookedMaterialsDir, delegatesROP));
                        continue;
                    }

                    // Not found; try local directory for master
                    var masterFolder = Directory.GetParent(levelMaster.FilePath).FullName;
                    var testFile = Path.Combine(masterFolder, additionalPackage + ".pcc");
                    if (File.Exists(testFile))
                    {
                        MilanLog.Information($"Converting sublevel {additionalPackage} to UDK", customPrefix: LOG_CATEGORY);
                        using IMEPackage levPcc = MEPackageHandler.OpenMEPackage(testFile);
                        levelFiles.Add(ConvertToUDK.GenerateUDKFileForLevel(levPcc, mapOutputPath, assetOutputPath, decookedMaterialsDir, delegatesROP));
                        continue;
                    }

                    MilanLog.Error($"Sublevel file not found: {additionalPackage}, skipping...", customPrefix: LOG_CATEGORY);
                }

                using IMEPackage persistentUDK = MEPackageHandler.OpenUDKPackage(persistentPath);
                IEntry levStreamingClass = persistentUDK.GetEntryOrAddImport("Engine.LevelStreamingAlwaysLoaded", "Class");
                IEntry theWorld = persistentUDK.Exports.First(exp => exp.ClassName == "World");
                int i = 1;
                int firstLevStream = persistentUDK.ExportCount;
                foreach (string fileName in levelFiles.Select(Path.GetFileNameWithoutExtension))
                {
                    persistentUDK.AddExport(new ExportEntry(persistentUDK, theWorld, new NameReference("LevelStreamingAlwaysLoaded", i), properties:
                    [
                        new NameProperty(fileName, "PackageName"),
                        CommonStructs.ColorProp(System.Drawing.Color.FromArgb(255, (byte)(i % 256), (byte)((255 - i) % 256), (byte)(i * 7 % 256)), "DrawColor")
                    ])
                    {
                        Class = levStreamingClass
                    });
                    i++;
                }

                var streamingLevelsProp = new ArrayProperty<ObjectProperty>("StreamingLevels");
                for (int j = firstLevStream; j < persistentUDK.ExportCount; j++)
                {
                    streamingLevelsProp.Add(new ObjectProperty(j));
                }

                persistentUDK.Exports.First(exp => exp.ClassName == "WorldInfo").WriteProperty(streamingLevelsProp);
                persistentUDK.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            }

            // Enumerate each package and verify imports can resolve.
            MELoadedFiles.InvalidateCaches();
            var packages = Directory.GetFiles(mapOutputPath, "*.udk", SearchOption.TopDirectoryOnly).Concat(Directory.GetFiles(assetOutputPath, "*.udk", SearchOption.TopDirectoryOnly));

            var packageCache = level.Cache.ChainNewCache();
            var gameFiles = MELoadedFiles.GetFilesLoadedInGame(MEGame.UDK);
            bool allImportsResolved = true;

            // Base UDK engine content (Engine, EngineMaterials, EngineDebugMaterials, etc.) ships outside UDKGame, in <udkdirectory>\Engine\Content.
            // It never shows up in gameFiles, and we can't retarget a mis-targeted import into it anyway (it's stock, unmodifiable content), so
            // precompute the set of its package basenames once so we can skip imports linked into it.
            var engineContentPath = Path.Combine(UDKDirectory.DefaultGamePath, "Engine", "Content");
            var engineContentPackageNames = Directory.Exists(engineContentPath)
                ? new HashSet<string>(Directory.EnumerateFiles(engineContentPath, "*.upk", SearchOption.AllDirectories).Select(Path.GetFileNameWithoutExtension), StringComparer.OrdinalIgnoreCase)
                : new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var packageP in packages)
            {
                var package = MEPackageHandler.OpenMEPackage(packageP);

                // Must be .ToList(); corrections of materials will modify it
                foreach(var imp in package.Imports.ToList())
                {
                    if (imp.GetLinker() == "Engine")
                    {
                        // This is native only; UDK doesn't seem to have an Engine.upk file so this will never resolve.
                        continue;
                    }

                    if (!imp.HasParent)
                    {
                        // Root-level import (e.g. `import Package 'Engine'`) - this is a reference to the package file itself, not an
                        // object within it, so there's nothing to resolve. Just confirm the file actually exists somewhere in the game.
                        if (!gameFiles.ContainsKey($"{imp.ObjectName.Instanced}.upk") && !engineContentPackageNames.Contains(imp.ObjectName.Instanced))
                        {
                            MilanLog.Fatal($"UDKPackage: Root package import {imp.ObjectName} in package {package.FileNameNoExtension} does not exist as a file in the game.", customPrefix: LOG_CATEGORY);
                            allImportsResolved = false;
                        }
                        continue;
                    }

                    if (engineContentPackageNames.Contains(imp.GetLinker()))
                    {
                        // Linked into stock UDK engine content - we can't fix these, so don't bother checking.
                        continue;
                    }

                    var import = EntryImporter.ResolveImport(imp, packageCache);
                    if (import == null)
                    {
                        // Resolve failed!
                        // See if the target resolution package (the linker of the import, should be in the cache) has a same-class same-name export anywhere in the package - and if it's the only copy there.
                        // If it does, we should retarget to that - this is a workaround for T3D, and might yield incorrect results, but it's better than failing to build the level in UDK.
                        ExportEntry misplacedExport = null;
                        IMEPackage targetPackage = null;
                        if (gameFiles.TryGetValue($"{imp.GetLinker()}.upk", out var targetPackagePath))
                        {
                            targetPackage = packageCache.GetCachedPackage(targetPackagePath);
                            if (targetPackage != null)
                            {
                                var candidates = targetPackage.Exports.Where(x => x.ClassName == imp.ClassName && x.ObjectName == imp.ObjectName).ToList();
                                if (candidates.Count == 1)
                                {
                                    misplacedExport = candidates[0];
                                }
                            }
                        }

                        if (misplacedExport != null)
                        {
                            // Rebuild the import's outer chain locally to match where the object actually lives in the target package,
                            // since T3D conversion can guess the wrong outer for an otherwise correctly-named/classed import.
                            imp.Parent = misplacedExport.HasParent
                                ? package.GetEntryOrAddImport(misplacedExport.Parent.MemoryFullPath, misplacedExport.Parent.ClassName, targetPackage.FileNameNoExtension)
                                : null;
                            MilanLog.Warning($"UDKPackage: Import {imp.InstancedFullPath} ({imp.ClassName}) in package {package.FileNameNoExtension} did not resolve at its expected path; adjusted import to match {misplacedExport.MemoryFullPath}", customPrefix: LOG_CATEGORY);
                        }
                        else
                        {
                            // If we can't find that at all, we should log it here
                            MilanLog.Fatal($"UDKPackage: Import {imp.InstancedFullPath} ({imp.ClassName}) in package {package.FileNameNoExtension} could not be resolved in the known target packages.", customPrefix: LOG_CATEGORY);
                            allImportsResolved = false;
                        }
                    }
                }

                if (package.IsModified)
                {
                    package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                }
            }

            return allImportsResolved;
        }
    }
}
