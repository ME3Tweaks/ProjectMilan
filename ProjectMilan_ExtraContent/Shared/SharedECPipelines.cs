using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Packages;
using ProjectMilan;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.UnrealScript;
using static ProjectMilan_ExtraContent.Rejects.RejectsPipeline;
using ProjectMilanCore;
using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.Coalesced;
using System.Reflection.Metadata;
using LegendaryExplorerCore.TLK.ME2ME3;
using LegendaryExplorerCore.TLK;
using Serilog;
using System.Xml.Linq;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal.Classes;

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


        internal static void MergeTLK(EExtraContent content)
        {
            MilanLog.Information($"Merging TLK data", customPrefix: LOG_CATEGORY);
            var locFileDir = Path.Combine(SharedECPipelines.ECPipelineRoot, content.ToString(), "TLK");
            var locFiles = Directory.GetFiles(locFileDir, "*.xml");
            foreach (var locFile in locFiles)
            {
                if (!Enum.TryParse<MELocalization>(Path.GetFileNameWithoutExtension(locFile), out var loc))
                {
                    MilanLog.Error($"Not a localized XML in TLK folder: {Path.GetFileName(locFile)}", customPrefix: LOG_CATEGORY);
                    continue;
                }

                // Find matching TLK.
                var destTLKPath = Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole", $"{Path.GetFileName(BaseBuildSettings.OutputModPath)}_{loc}.tlk");
                if (!File.Exists(destTLKPath))
                {
                    MilanLog.Warning($"Destination TLK does not exist, will not merge into it: {destTLKPath}");
                    continue;
                }

                MilanLog.Information($"  Merging {Path.GetFileName(destTLKPath)}", customPrefix: LOG_CATEGORY);

                var destTlk = new ME2ME3TalkFile(destTLKPath);
                var newStrings = GetStringRefsFromXml(locFile);

                // Overwrite strings.
                foreach (var str in newStrings)
                {
                    // Very slow... really need a dictionary for this
                    var existing = destTlk.StringRefs.FirstOrDefault(x => x.StringID == str.StringID);
                    if (existing != null)
                    {
                        existing.Data = str.Data;
                    }
                    else
                    {
                        destTlk.StringRefs.Add(str);
                    }
                }

                HuffmanCompression.SaveToTlkFile(destTLKPath, destTlk.StringRefs);
            }

        }

        // From M3.
        private static List<TLKStringRef> GetStringRefsFromXml(string xmlfile)
        {
            List<TLKStringRef> strings = new List<TLKStringRef>();

            XDocument doc = XDocument.Load(xmlfile);
            var substrings = doc.Root.Descendants(@"String");
            var position = 0;
            foreach (var substr in substrings)
            {
                var id = int.Parse(substr.Attribute(@"id").Value);
                var data = substr.Value;
                if (id > 0) data += '\0';
                strings.Add(new TLKStringRef(id, data));
                position++;
            }

            return strings;
        }


        internal static void MergeConfig(EExtraContent content, string subfolder = null)
        {
            MilanLog.Information($"Merging config file", customPrefix: LOG_CATEGORY);
            var configDest = Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole", $"Default_{Path.GetFileName(BaseBuildSettings.OutputModPath)}.bin"); // Points to output directory .bin, could be milan or R2
            var configSourceF = Path.Combine(SharedECPipelines.ECPipelineRoot, content.ToString(), "Config");
            if (subfolder != null)
            {
                configSourceF = Path.Combine(configSourceF, subfolder);
            }
            var configSourceManifest = Path.Combine(configSourceF, $"Default_{GetDLCFolderName(content)}.xml"); // Always will be R2/R3 data
            var ms = new MemoryStream();
            CoalescedConverter.ConvertToBin(configSourceManifest, null, outStream: ms);
            ms.Position = 0;
            var sourceAssetBundle = ConfigAssetBundle.FromSingleStream(MEGame.LE3, ms);
            var destAssetBundle = ConfigAssetBundle.FromSingleFile(MEGame.LE3, configDest);
            sourceAssetBundle.MergeInto(destAssetBundle);
            destAssetBundle.CommitAssets(configDest, MELocalization.None);
        }

        /// <summary>
        /// Installs textures from a folder to a package.
        /// </summary>
        /// <param name="content"></param>
        /// <param name="type">Folder under 'Textures', such as Enemies or Art.</param>
        /// <param name="category">Folder under type, such as specific items.</param>
        /// <param name="targetPackage"></param>
        internal static void InstallTextures(EExtraContent content, string type, string category, IMEPackage targetPackage, ExportEntry newParentPackage)
        {
            var sourceDir = Path.Combine(ECPipelineRoot, content.ToString(), "Assets", "Textures", type, category);
            if (!Directory.Exists(sourceDir))
                return; // Nothing here

            foreach (var texFile in Directory.GetFiles(sourceDir, "*.png"))
            {
                var name = Path.GetFileNameWithoutExtension(texFile);
                var matchingTexture = targetPackage.Exports.FirstOrDefault(x => x.IsTexture() && x.ObjectName.Instanced.CaseInsensitiveEquals(name));
                if (matchingTexture == null)
                    Debugger.Break(); // Should not happen!

                MilanLog.Information($"Installing new texture {name} into {targetPackage.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
                Image im = Image.LoadFromFile(texFile, PixelFormat.BC7); // Lets just use BC7, I guess.
                Texture2D t2d = new Texture2D(matchingTexture);
                t2d.Replace(im, matchingTexture.GetProperties(), isPackageStored: true); // We will extract textures at a later step
                matchingTexture.idxLink = newParentPackage.UIndex;
            }
        }
    }
}