using ProjectMilan.Pipelines.Weapons;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;
using Path = System.IO.Path;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal.Classes;
using ProjectMilan.Utility;
using CsvHelper.Configuration;
using LegendaryExplorerCore.Gammtek.Extensions.Collections.Generic;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilan.Pipelines.Shared;

namespace ProjectMilan.Pipelines.Materials
{
    /// <summary>
    /// Builds material donors from our source files
    /// </summary>
    public static class DonorBuilderPipeline
    {
        private const string LOG_CATEGORY = "MILAN-MaterialBuild";

        private class DonorBuildVars
        {

        }

        private static CaseInsensitiveDictionary<MilanTextureInfo> DonorTextureInfo = new();

        public static void RunPipeline()
        {
            var vars = new DonorBuildVars();
            InternalRunPipeline(vars);
        }

        private static List<string> DonorObjects = new();

        private static void InventoryDonorPackages()
        {
            var packageOutputFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Build");
            DonorObjects.ReplaceAll(Directory.GetFiles(packageOutputFolder, "*.pcc").Select(Path.GetFileNameWithoutExtension));
        }

        private static void InternalRunPipeline(DonorBuildVars vars)
        {
            // Until we can build material exports from source we will have to use donors for the parents.
            var tempDonors = Path.Combine(MilanShared.PipelineRoot, "Materials", "Parents");
            SharedMaterialDonor.RegisterLocalDonors(tempDonors);
            InventoryDonorPackages();
            BuildDonorPackages(vars);
            SharedMaterialDonor.UnregisterLocalDonors(tempDonors);
        }

        private static void BuildDonorPackages(DonorBuildVars vars)
        {

            var texturesFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Textures");
            foreach (var tex in Directory.GetFiles(texturesFolder, "*.*"))
            {
                var info = GetTextureMetadata(tex);
                DonorTextureInfo[info.ObjectName] = info;
            }


            var instancesFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Instances");
            var packageOutputFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Build");

            // Build instances
            var packageFolders = Directory.GetDirectories(instancesFolder);
            foreach (var biotPackage in packageFolders)
            {
                var biotCache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3).ChainNewCache();
                var biotName = Path.GetFileName(biotPackage);
                foreach (var instPath in Directory.GetFiles(biotPackage, "*.uc"))
                {
                    var instLines = File.ReadAllLines(instPath);
                    var donorFor = instLines[0];
                    if (!donorFor.StartsWith("// DONOR FOR: ", StringComparison.OrdinalIgnoreCase))
                    {
                        MilanLog.Fatal($"Donor uc file {instPath} does not start with // DONOR FOR: ! We don't know how to override a material with this");
                        Environment.Exit(1);
                    }

                    donorFor = donorFor.Substring("// DONOR FOR: ".Length).Trim();


                    // Skip the first line.
                    var instText = string.Join('\n', instLines.Skip(1));

                    var instName = Path.GetFileNameWithoutExtension(instPath);
                    var outName = $"{biotName}.Materials.{instName}";
                    var donorPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(packageOutputFolder, $"{outName}.pcc"), MEGame.LE3);

                    MilanLog.Information($"Building donor package for {outName}", customPrefix: LOG_CATEGORY);

                    var biot = ExportCreator.CreatePackageExport(donorPackage, biotName, cache: biotCache);
                    var biot_materials = ExportCreator.CreatePackageExport(donorPackage, "Materials", cache: biotCache, parent: biot);
                    var biot_textures = ExportCreator.CreatePackageExport(donorPackage, "Textures", cache: biotCache, parent: biot);
                    var matInst = ExportCreator.CreateExport(donorPackage, instName, "MaterialInstanceConstant", biot_materials, indexed: false, cache: biotCache);

                    var usop = new UnrealScriptOptionsPackage() { MissingObjectResolver = DonorBuildResolver, Cache = biotCache };
                    var fileLib = new FileLib(donorPackage);
                    if (!fileLib.Initialize(usop))
                    {
                        MilanShared.LogFailedFileLibInit(fileLib);
                    }

                    var output = UnrealScriptCompiler.CompileDefaultProperties(matInst, instText, fileLib, usop);
                    MilanLog.LogUSCErrors(output.log);

                    CreateObjectRedirector(donorFor, matInst, biotCache);

                    donorPackage.Save();
                }
            }
        }

        private static void CreateObjectRedirector(string originalObject, ExportEntry targetObject, PackageCache cache)
        {
            var parts = originalObject.Split('.');
            IEntry currentParent = null;

            // Determine where we need to start working.
            string composed = "";
            for (int i = 0; i < parts.Length - 1; i++)
            {
                var part = parts[i];
                currentParent = ExportCreator.CreatePackageExport(targetObject.FileRef, part, currentParent, cache: cache);
            }
            var redirector = ExportCreator.CreateExport(targetObject.FileRef, parts.Last(), "ObjectRedirector", currentParent, indexed: false);
            var bin = ObjectRedirector.Create();
            bin.DestinationObject = targetObject.UIndex;
            redirector.WriteBinary(bin);
        }

        private static IEntry DonorBuildResolver(IMEPackage destPackage, string ifp)
        {
            var possibleDonors = MilanShared.LE3ObjectDB.GetFilesContainingObject(ifp, destPackage.Localization);
            if (possibleDonors == null)
            {
                return TryGenerateTexture(destPackage, ifp);
            }
            else
            {
                possibleDonors.Sort(new ObjectSourceTierComparer(MEGame.LE3, destPackage.FilePath));

                foreach (var possibleDonor in possibleDonors)
                {
                    var donorP = MilanShared.LE3MissingObjectCache.GetCachedPackage(Path.Combine(LE3Directory.DefaultGamePath, possibleDonor), openPackageMethod: MilanShared.GetLE3Package);
                    if (donorP != null)
                    {
                        var donorEntry = donorP.FindEntry(ifp);
                        if (donorEntry != null)
                        {
                            MilanLog.Information($"  Using donor object {ifp} from {possibleDonor}", customPrefix: LOG_CATEGORY);
                            return MilanShared.PortDonorIntoPackage(MilanShared.LE3MissingObjectCache, donorEntry, destPackage, LOG_CATEGORY, true);
                        }
                        else
                        {
                            MilanLog.Warning($"  LE3 donor package {possibleDonor} does not contain {ifp}", customPrefix: LOG_CATEGORY);
                        }
                    }
                }
                MilanLog.Error($"Unable to find object {ifp} in {possibleDonors.Count} packages!", customPrefix: LOG_CATEGORY);
            }
            return null;
        }

        private static IEntry TryGenerateTexture(IMEPackage destPackage, string ifp)
        {
            var parentPath = ifp.Substring(0, ifp.LastIndexOf('.'));
            var parent = destPackage.FindEntry(parentPath);
            if (parent == null)
                Debugger.Break();

            var textureName = ifp.Substring(ifp.LastIndexOf('.') + 1);
            if (DonorTextureInfo.TryGetValue(textureName, out var textureInfo))
            {
                MilanLog.Information($"  Generating Milan donor texture export {textureInfo.ObjectName}", customPrefix: LOG_CATEGORY);
                var sizeX = textureInfo.AspectRatioX * 2;
                var sizeY = textureInfo.AspectRatioY * 2;
                
                // Some formats have a minimum size of 4x4
                while (sizeX < 8 && sizeY < 8)
                {
                    sizeX *= 2;
                    sizeY *= 2;
                }
                var tex = Texture2D.CreateTexture(destPackage, textureInfo.ObjectName, sizeX, sizeY, textureInfo.Format, true, parent: parent);
                var inImage = Image.LoadFromFile(textureInfo.FullPath, textureInfo.Format);
                var t2d = new Texture2D(tex);
                t2d.Replace(inImage, tex.GetProperties(), isPackageStored: true, forcedNewFormat: textureInfo.Format);
                return tex;
            }
            Debugger.Break();
            return null;
        }

        private static MilanTextureInfo GetTextureMetadata(string path)
        {
            var name = Path.GetFileNameWithoutExtension(path);

            // Get format.
            var pixelFormatName = name.Substring(name.LastIndexOf("_") + 1);
            var format = Enum.Parse<PixelFormat>(pixelFormatName);
            name = name.Substring(0, name.LastIndexOf("_"));

            // Get aspect ratio
            var aspectRatioStr = name.Substring(name.LastIndexOf("_") + 1);
            int aspX = int.Parse(aspectRatioStr.Substring(0, aspectRatioStr.IndexOf('x')));
            int aspY = int.Parse(aspectRatioStr.Substring(aspectRatioStr.IndexOf('x') + 1));

            // Get actual name
            name = name.Substring(0, name.LastIndexOf("_"));


            return new MilanTextureInfo() { Format = format, ObjectName = name, FullPath = path, AspectRatioX = aspX, AspectRatioY = aspY };
        }

        public static ExportEntry MaterialDonorImporter(IMEPackage dest, ExportEntry source, RelinkerOptionsPackage rop)
        {
            if (DonorObjects.IndexOf(source.InstancedFullPath) == -1)
                return null; // We don't use this for anything we don't have full control over

            var relinkMap = rop.CrossPackageMap; // Cache the relink map. Using it will corrupt the relink operation.
            rop.CustomDonorImporter = null; // Remove this or we will get a stack overflow
            rop.CrossPackageMap = new ListenableDictionary<IEntry, IEntry>();
            EntryExporter.ExportExportToPackage(source, dest, out var newEntry, rop.Cache, rop);

            // Do we need to merge the relink map? Will that cause a double relink?
            rop.CrossPackageMap = relinkMap; // Restore relink map so a relink can later be performed.
            rop.CustomDonorImporter = MaterialDonorImporter; // Restore
            return newEntry as ExportEntry;
        }
    }

    internal class MilanTextureInfo
    {
        public PixelFormat Format { get; set; }
        public string FullPath { get; set; }
        public string ObjectName { get; set; }
        public int AspectRatioX { get; set; }
        public int AspectRatioY { get; set; }
    }
}
