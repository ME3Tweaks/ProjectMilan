using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Packages;
using ProjectMilan;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.UnrealScript;
using static ProjectMilan_ExtraContent.Rejects.RejectsPipeline;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Shared
{
    public class PortingAsset
    {
        /// <summary>
        /// File source is in.
        /// </summary>
        public string SourceFile { get; set; }

        /// <summary>
        /// IFP of the asset to port.
        /// </summary>
        public string AssetIFP { get; set; }

        /// <summary>
        /// Called before asset is ported into target package, called on source package
        /// </summary>
        public Action<RejectVars, IMEPackage> PrePortingDelegate { get; set; }

        /// <summary>
        /// Called once asset is ported into the target package
        /// </summary>
        public Action<RejectVars, ExportEntry> PostPortingDelegate { get; set; }
    }

    internal class SharedECPipelines
    {
        private const string LOG_CATEGORY = @"MILAN-ECShared";

        private const string ROOT_FOLDER_NAME = @"ProjectMilan_ExtraContent";
        private static string _ecPipelineRoot;
        public static string ECPipelineRoot
        {
            get
            {
                if (_ecPipelineRoot != null) return _ecPipelineRoot;
                var dir = Directory.GetCurrentDirectory();
                while (Path.GetFileName(dir) != ROOT_FOLDER_NAME)
                {
                    dir = Directory.GetParent(dir).FullName;
                }

                _ecPipelineRoot = dir;
                return _ecPipelineRoot;
            }
        }

        public static void PortAsset(RejectVars vars, PortingAsset asset, IMEPackage destPackage)
        {
            if (!vars.LoadedFiles.TryGetValue(asset.SourceFile, out var path))
            {
                if (File.Exists(asset.SourceFile))
                {
                    // Its full path.
                    path = asset.SourceFile;
                }
                else
                {
                    MilanLog.Error($@"Could not find asset asset package: {asset.SourceFile}", customPrefix: LOG_CATEGORY);
                    return;
                }
            }

            var package = MEPackageHandler.OpenMEPackage(path);
            var archetype = package.FindExport(asset.AssetIFP);
            if (archetype == null)
            {
                MilanLog.Error($@"Could not find asset IFP {asset.AssetIFP} in {asset.SourceFile}", customPrefix: LOG_CATEGORY);
                return;
            }

            asset.PrePortingDelegate?.Invoke(vars, package);

            MilanLog.Information($"Porting {asset.AssetIFP} into {destPackage.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
            EntryExporter.ExportExportToPackage(archetype, destPackage, out var export, vars.Cache, new RelinkerOptionsPackage() { Cache = vars.Cache, PortImportsMemorySafe = true, PortLocalizationImportsMemorySafe = false });

            asset.PostPortingDelegate?.Invoke(vars, export as ExportEntry);
        }

        /// <summary>
        /// Compiles a class from the pipeline asset folder over the top of an existing export.
        /// </summary>
        /// <param name="targetObj">Class object to compile over</param>
        /// <param name="className">Name of file to compile in assets/classes. If null, the name of the passed in object is used</param>
        /// <param name="cache"></param>
        /// <param name="content"></param>
        public static void CompileClassOn(ExportEntry targetObj, string className, PackageCache cache, EExtraContent content, string subfolderName)
        {
            if (className == null)
                className = targetObj.ObjectName.Name; // Use 
            var asset = Path.Combine(ECPipelineRoot, content.ToString(), "Assets", "Classes", subfolderName, $"{className}.uc");
            var classText = File.ReadAllText(asset);

            var usop = new UnrealScriptOptionsPackage() { Cache = cache };
            FileLib lib = new FileLib(targetObj.FileRef);
            if (!lib.Initialize(usop))
            {
                MilanShared.LogFailedFileLibInit(lib);
                return;
            }

            MilanLog.Information($"Compiling class {className} in {targetObj.FileRef.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
            var results = UnrealScriptCompiler.CompileClass(targetObj.FileRef, classText, lib, usop, targetObj);
            if (results.log.HasErrors)
            {
                MilanLog.LogUSCErrors(results.log);
            }
        }

        public static string GetDLCFolderName(EExtraContent content) => content switch
        {
            EExtraContent.Rejects => MilanShared.REJECTS_DLC_NAME,
            EExtraContent.Redemption => MilanShared.REDEMPTION_DLC_NAME,
            _ => throw new Exception($"Unknown content: {content}")
        };

        /// <summary>
        /// Gets developer DLC mount priority
        /// </summary>
        /// <param name="content"></param>
        /// <returns></returns>
        /// <exception cref="NotImplementedException"></exception>
        public static int GetMountPriority(EExtraContent content) => content switch
        {
            EExtraContent.Rejects => 12556,
            EExtraContent.Redemption => 12557,
            _ => 0,
        };

        /// <summary>
        /// Gets developer DLC TLK ID
        /// </summary>
        /// <param name="content"></param>
        /// <returns></returns>
        public static int GetTLKID(EExtraContent content) => content switch
        {
            // Random.
            EExtraContent.Rejects => 46578962,
            EExtraContent.Redemption => 58765561,
            _ => 0,
        };
    }
}