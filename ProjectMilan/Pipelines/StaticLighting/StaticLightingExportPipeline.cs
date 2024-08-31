using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Helpers;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Pipeline for exporting levels to UDK for static lighting build
    /// </summary>
    public static class StaticLightingExportPipeline
    {
        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            //string udkPath = UDKDirectory.DefaultGamePath;
            //if (udkPath == null || !Directory.Exists(udkPath))
            //{
            //    var udkDlg = new CommonOpenFileDialog(@"Select your UDK\Custom folder");
            //    udkDlg.IsFolderPicker = true;
            //    var result = udkDlg.ShowDialog();

            //    if (result is not CommonFileDialogResult.Ok || string.IsNullOrWhiteSpace(udkDlg.FileName) || !Directory.Exists(udkDlg.FileName))
            //        return;
            //    udkPath = udkDlg.FileName;
            //    LegendaryExplorerCoreLibSettings.Instance.UDKCustomDirectory = udkPath;
            //    UDKDirectory.ReloadDefaultGamePath();
            //}

            //string persistentLevelFileName = Path.GetFileNameWithoutExtension(Pcc.FilePath);

            //pewpf.IsBusy = true;
            //pewpf.BusyText = $"Converting {persistentLevelFileName}";
            //Task.Run(() =>
            //{
            //    string persistentPath = ConvertToUDK.GenerateUDKFileForLevel(Pcc);
            //    var levelFiles = new List<string>();
            //    if (Pcc is MEPackage mePackage)
            //    {
            //        var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(Pcc.Game);
            //        foreach (string additionalPackage in mePackage.AdditionalPackagesToCook)
            //        {
            //            if (loadedFiles.TryGetValue($"{additionalPackage}.pcc", out string filePath))
            //            {
            //                pewpf.BusyText = $"Converting {additionalPackage}";
            //                using IMEPackage levPcc = MEPackageHandler.OpenMEPackage(filePath);
            //                levelFiles.Add(ConvertToUDK.GenerateUDKFileForLevel(levPcc));
            //            }
            //        }

            //        using IMEPackage persistentUDK = MEPackageHandler.OpenUDKPackage(persistentPath);
            //        IEntry levStreamingClass =
            //            persistentUDK.GetEntryOrAddImport("Engine.LevelStreamingAlwaysLoaded", "Class");
            //        IEntry theWorld = persistentUDK.Exports.First(exp => exp.ClassName == "World");
            //        int i = 1;
            //        int firstLevStream = persistentUDK.ExportCount;
            //        foreach (string fileName in levelFiles.Select(Path.GetFileNameWithoutExtension))
            //        {
            //            persistentUDK.AddExport(new ExportEntry(persistentUDK, theWorld, new NameReference("LevelStreamingAlwaysLoaded", i), properties: new PropertyCollection
            //        {
            //                new NameProperty(fileName, "PackageName"),
            //                CommonStructs.ColorProp(System.Drawing.Color.FromArgb(255, (byte)(i % 256), (byte)((255 - i) % 256), (byte)(i * 7 % 256)), "DrawColor")
            //        })
            //            {
            //                Class = levStreamingClass
            //            });
            //            i++;
            //        }

            //        var streamingLevelsProp = new ArrayProperty<ObjectProperty>("StreamingLevels");
            //        for (int j = firstLevStream; j < persistentUDK.ExportCount; j++)
            //        {
            //            streamingLevelsProp.Add(new ObjectProperty(j));
            //        }

            //        persistentUDK.Exports.First(exp => exp.ClassName == "WorldInfo")
            //            .WriteProperty(streamingLevelsProp);
            //        persistentUDK.Save();
            //    }
            //}).ContinueWithOnUIThread(prevTask =>
            //{
            //    if (prevTask.IsFaulted)
            //    {
            //        new ExceptionHandlerDialog(prevTask.Exception).ShowDialog();
            //    }
            //    pewpf.IsBusy = false;
            //});
        }
    }
}
