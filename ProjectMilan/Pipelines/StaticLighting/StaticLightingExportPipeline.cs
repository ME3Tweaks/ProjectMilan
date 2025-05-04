using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore;
using ProjectMilan.MilanUDK;
using ProjectMilan.Utility;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Pipeline for exporting levels to UDK for static lighting build
    /// </summary>
    public static class StaticLightingExport
    {
        private const string LOG_CATEGORY = @"MILAN-StaticLightingExport";

        public static string GetMapOutputPath(string mapName)
        {
            return Directory.CreateDirectory(Path.Combine(UDKDirectory.MapsPath, mapName)).FullName;
        }

        public static string GetAssetsOutputPath(string mapName)
        {
            return Directory.CreateDirectory(Path.Combine(UDKDirectory.SharedPath, "Assets", mapName)).FullName;
        }

        public static void ExportLevelToUDK(IMEPackage levelMaster)
        {
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

            string persistentPath = ConvertToUDK.GenerateUDKFileForLevel(levelMaster, mapOutputPath, assetOutputPath, decookedMaterialsDir);
            var levelFiles = new List<string>();
            if (levelMaster is MEPackage mePackage)
            {
                var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(levelMaster.Game);
                foreach (string additionalPackage in mePackage.AdditionalPackagesToCook)
                {
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
                persistentUDK.Save();
            }
        }
    }
}
