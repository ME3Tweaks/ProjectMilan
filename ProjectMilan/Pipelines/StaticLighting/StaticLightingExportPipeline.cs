using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore;
using ProjectMilan.MilanUDK;
using ProjectMilan.Utility;

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

        public static void ExportLevelToUDK(IMEPackage Pcc)
        {
            // Set UDK paths so we don't have to change LEC code. This doesn't persist.
            UDKDirectory.DefaultGamePath = Program.Settings.MilanUDKPath;
            LegendaryExplorerCoreLibSettings.Instance.UDKCustomDirectory = Program.Settings.MilanUDKPath;

            string persistentLevelFileName = Pcc.FileNameNoExtension;

            var mapOutputPath = GetMapOutputPath(persistentLevelFileName);
            var assetOutputPath = GetAssetsOutputPath(persistentLevelFileName);

            MilanLog.Information($"Converting {persistentLevelFileName} to UDK", customPrefix: LOG_CATEGORY);
            Utilities.DeleteFilesAndFoldersRecursively(mapOutputPath, deleteDirectoryItself: false);
            Utilities.DeleteFilesAndFoldersRecursively(assetOutputPath, deleteDirectoryItself: false);
            var decookedMaterialsDir = UDKSetup.GetMilanDecookedMaterialsDirectory();

            string persistentPath = ConvertToUDK.GenerateUDKFileForLevel(Pcc, mapOutputPath, assetOutputPath, decookedMaterialsDir);
            var levelFiles = new List<string>();
            if (Pcc is MEPackage mePackage)
            {
                var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(Pcc.Game);
                foreach (string additionalPackage in mePackage.AdditionalPackagesToCook)
                {
                    if (loadedFiles.TryGetValue($"{additionalPackage}.pcc", out string filePath))
                    {
                        MilanLog.Information($"Converting sublevel {additionalPackage} to UDK", customPrefix: LOG_CATEGORY);
                        using IMEPackage levPcc = MEPackageHandler.OpenMEPackage(filePath); 
                        levelFiles.Add(ConvertToUDK.GenerateUDKFileForLevel(levPcc, mapOutputPath, assetOutputPath, decookedMaterialsDir));
                    }
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
