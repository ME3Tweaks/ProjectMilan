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
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Shaders;
using Serilog;
using SharpDX.D3DCompiler;
using SixLabors.ImageSharp.ColorSpaces;

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

        private class MaterialExpressionDonor
        {
            public string Name { get; set; }
            public string PropertiesText { get; set; }
        }

        private class MaterialDonorInfo
        {
            public string DonorFor { get; set; }

            public List<MaterialExpressionDonor> Expressions { get; } = new();
            public string PropertiesText { get; set; }
            public string BinaryText { get; set; }

            // Flags
            /// <summary>
            /// Don't put material in Materials package. Just put under BioT
            /// </summary>
            public bool NoMaterialsPackage { get; set; }


            /// <summary>
            /// Reads a milan material donor info from a .uc file
            /// </summary>
            /// <param name="inputPath"></param>
            /// <param name="cache"></param>
            /// <returns></returns>
            public static MaterialDonorInfo ReadFromFile(string inputPath)
            {
                var biotName = Directory.GetParent(inputPath).Name;

                var instLines = File.ReadAllLines(inputPath).ToList();

                // Skip comment lines.
                // First data block starts with // DONOR FOR: 
                while (!instLines[0].StartsWith("// DONOR FOR: ", StringComparison.OrdinalIgnoreCase))
                {
                    instLines.RemoveAt(0);
                }

                var donorFor = instLines[0];
                donorFor = donorFor.Substring("// DONOR FOR: ".Length).Trim();
                if (string.IsNullOrWhiteSpace(donorFor))
                {
                    MilanLog.Fatal($"MALFORMED 'DONOR FOR:' in file {inputPath}", customPrefix: LOG_CATEGORY);
                    Environment.Exit(1);
                }

                instLines.RemoveAt(0);

                var mdi = new MaterialDonorInfo();
                mdi.DonorFor = donorFor;

                if (instLines[0].StartsWith("// FLAGS: "))
                {
                    var flags = instLines[0].Substring("// FLAGS: ".Length).Split(' ');
                    foreach (var flag in flags)
                    {
                        if (flag == "NoMaterialsPackage")
                            mdi.NoMaterialsPackage = true;
                    }


                    instLines.RemoveAt(0);
                }

                // EXPRESSIONS
                while (instLines[0].StartsWith("// EXPRESSION "))
                {
                    MaterialExpressionDonor med = new MaterialExpressionDonor();
                    med.Name = instLines[0][14..];
                    instLines.RemoveAt(0);
                    var endIdx = 0;
                    while (endIdx < instLines.Count)
                    {
                        if (instLines[endIdx].StartsWith("// "))
                            break;
                        endIdx++;
                    }

                    med.PropertiesText = string.Join('\n', instLines.Take(endIdx));
                    instLines.RemoveRange(0, endIdx);
                    mdi.Expressions.Add(med);
                }

                // PROPERTIES
                var isProperties = instLines[0].StartsWith("// PROPERTIES");
                if (!isProperties)
                    Debugger.Break(); // Not correctly set up! Must have // PROPERTIES before props and // BINARY before Material binary

                var binaryIdx = instLines.IndexOf("// BINARY");
                if (binaryIdx == -1)
                    Debugger.Break(); // Not correctly set up! Must have // PROPERTIES before props and // BINARY before Material binary

                mdi.PropertiesText = string.Join('\n', instLines.Take(binaryIdx));

                // BINARY
                mdi.BinaryText = string.Join('\n', instLines.Skip(binaryIdx + 1));
                return mdi;
            }

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
            DonorObjects.ReplaceAll(Directory.GetFiles(packageOutputFolder, "*.pcc", SearchOption.AllDirectories).Select(Path.GetFileNameWithoutExtension));
        }

        private static void InternalRunPipeline(DonorBuildVars vars)
        {
            // CompileShaders();
            InventoryDonorPackages();
            BuildDonorPackages(vars);
        }

        private static void BuildDonorPackages(DonorBuildVars vars)
        {

            var texturesFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Textures");
            foreach (var tex in Directory.GetFiles(texturesFolder, "*.*"))
            {
                var info = GetTextureMetadata(tex);
                DonorTextureInfo[info.ObjectName] = info;
            }

            // Materials and parents of MICs
            var parentsFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Parents");
            // MICs
            var instancesFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Instances");
            // Output folder that will be used for donors in later pipelines
            var packageOutputFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Build", "Materials");
            if (!Directory.Exists(packageOutputFolder)) Directory.CreateDirectory(packageOutputFolder);

            // Build parents
            var packageFolders = Directory.GetDirectories(parentsFolder);
            foreach (var biotPackage in packageFolders)
            {
                var biotCache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3).ChainNewCache();
                var biotName = Path.GetFileName(biotPackage);
                foreach (var instPath in Directory.GetFiles(biotPackage, "*.uc"))
                {
                    var mdi = MaterialDonorInfo.ReadFromFile(instPath);
                    var matName = Path.GetFileNameWithoutExtension(instPath);
                    var outName = $"{biotName}.Materials.{matName}";
                    var donorPackage = MEPackageHandler.CreateAndOpenPackage(Path.Combine(packageOutputFolder, $"{outName}.pcc"), MEGame.LE3);

                    MilanLog.Information($"Building donor package for {outName}", customPrefix: LOG_CATEGORY);

                    var biot = ExportCreator.CreatePackageExport(donorPackage, biotName, cache: biotCache);

                    ExportEntry biot_materials = biot;
                    if (!mdi.NoMaterialsPackage)
                    {
                        biot_materials = ExportCreator.CreatePackageExport(donorPackage, "Materials", cache: biotCache, parent: biot);
                    }

                    var biot_textures = ExportCreator.CreatePackageExport(donorPackage, "Textures", cache: biotCache, parent: biot); // Create in the event donor tooling needs it
                    var material = ExportCreator.CreateExport(donorPackage, matName, "Material", biot_materials, indexed: false, cache: biotCache);

                    var usop = new UnrealScriptOptionsPackage() { MissingObjectResolver = DonorBuildResolver, Cache = biotCache };
                    var fileLib = new FileLib(donorPackage);
                    if (!fileLib.Initialize(usop))
                    {
                        MilanShared.LogFailedFileLibInit(fileLib);
                    }

                    // EXPRESSIONS
                    // This ensures that expressions are not attempted to be donated when compiling material properties.
                    List<ExportEntry> expressions = new List<ExportEntry>();
                    foreach (var expr in mdi.Expressions)
                    {
                        var exprClass = NameReference.FromInstancedString(expr.Name).Name;
                        var exprExp = ExportCreator.CreateExport(donorPackage, NameReference.FromInstancedString(expr.Name), exprClass, material, indexed: false, cache: biotCache);
                        var output = UnrealScriptCompiler.CompileDefaultProperties(exprExp, expr.PropertiesText, fileLib, usop);
                        MilanLog.LogUSCErrors(output.log);
                        expressions.Add(exprExp);
                    }

                    // PROPERTIES
                    var output2 = UnrealScriptCompiler.CompileDefaultProperties(material, mdi.PropertiesText, fileLib, usop);
                    MilanLog.LogUSCErrors(output2.log);
                    if (expressions.Any())
                    {
                        material.WriteProperty(new ArrayProperty<ObjectProperty>(expressions.Select(x => new ObjectProperty(x)), "Expressions"));
                    }

                    // BINARY
                    var ms = new MemoryStream();
                    var writer = new StreamWriter(ms);
                    writer.Write(mdi.BinaryText);
                    writer.Flush();
                    ms.Position = 0;

                    var mat = Material.JsonDeserialize(ms, donorPackage, DonorBuildResolver);
                    material.WriteBinary(mat);

                    if (!mdi.DonorFor.Contains("NoDonor", StringComparison.OrdinalIgnoreCase))
                    {
                        CreateObjectRedirector(mdi.DonorFor, material, biotCache);
                    }

                    // CUSTOM SHADERS
                    var customShaderDir = Path.Combine(MilanShared.PipelineRoot, "Materials", "Shaders", "Source", material.ObjectName);

                    if (Directory.Exists(customShaderDir))
                    {
                        // Write before access
                        var guid = ShaderCacheManipulator.CopyRefShadersToLocal(material, false);
                        var shaderCacheE = material.FileRef.FindExport("SeekFreeShaderCache");
                        var shaderCache = ObjectBinary.From<ShaderCache>(shaderCacheE);
                        if (shaderCache.MaterialShaderMaps.TryGetValue((StaticParameterSet)guid.Value, out var msm))
                        {
                            msm.FriendlyName = material.ObjectName;
                            foreach (var shaderKey in msm.MeshShaderMaps)
                            {
                                foreach (var shaderRef in shaderKey.Shaders)
                                {
                                    var shader = shaderCache.Shaders[shaderRef.Value.Id];
                                    var shaderFile = Path.Combine(customShaderDir, shaderKey.VertexFactoryType, shader.ShaderType + ".hlsl");
                                    if (File.Exists(shaderFile))
                                    {
                                        MilanLog.Information($"Replacing shader {material.ObjectName} {shader.ShaderType} with custom version", customPrefix: LOG_CATEGORY);
                                        var compiled = CompileShader(shaderFile);
                                        if (compiled == null)
                                        {
                                            MilanLog.Fatal($"Failed to compiled shader! {material.ObjectName} {shader.ShaderType}", customPrefix: LOG_CATEGORY);
                                            Environment.Exit(1);
                                        }

                                        shader.ShaderByteCode = compiled.Data;

                                        // INSTRUCTION COUNT UPDATE
                                        // Get Disassembly
                                        string dissasembledShader = ShaderBytecode.FromStream(new MemoryStream(compiled.Data)).Disassemble();
                                        // Get last line that contains instruction counts
                                        string result = string.Join("", dissasembledShader.Split('\n').Reverse().Take(2).ToArray());
                                        // Get digits from the result
                                        string digits = string.Join("", new String(result.Where(Char.IsDigit).ToArray()));
                                        int instructions = int.Parse(digits);

                                        // Insert new instruction count
                                        shader.InstructionCount = instructions;
                                        compiled.Dispose();
                                    }
                                }
                            }
                        }
                        else
                        {
                            MilanLog.Fatal($"Failed to find material shader map in new local shader cache in donor: {material.ObjectName}", customPrefix: LOG_CATEGORY);
                            Environment.Exit(1);
                        }

                        shaderCacheE.WriteBinary(shaderCache);
                    }

                    donorPackage.Save();
                }
            }

            // Some instances depend on the materials we just built
            // Register them for use
            SharedMaterialDonor.RegisterLocalDonors(packageOutputFolder);

            // Change output directory
            packageOutputFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Build", "Instances");
            if (!Directory.Exists(packageOutputFolder)) Directory.CreateDirectory(packageOutputFolder);

            // Build instances
            packageFolders = Directory.GetDirectories(instancesFolder);
            foreach (var biotPackage in packageFolders)
            {
                var biotCache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3).ChainNewCache();
                var biotName = Path.GetFileName(biotPackage);
                foreach (var instPath in Directory.GetFiles(biotPackage, "*.uc"))
                {
                    var instLines = File.ReadAllLines(instPath).ToList();
                    // Skip comment lines.
                    // First data block starts with // DONOR FOR: 
                    while (!instLines[0].StartsWith("// DONOR FOR: ", StringComparison.OrdinalIgnoreCase))
                    {
                        instLines.RemoveAt(0);
                    }

                    var donorFor = instLines[0];

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

            packageOutputFolder = Path.Combine(MilanShared.PipelineRoot, "Materials", "Build", "Materials");
            SharedMaterialDonor.UnregisterLocalDonors(packageOutputFolder);
        }

        private static ShaderBytecode CompileShader(string sourceFile)
        {
            var isPixelShader = sourceFile.Contains("PixelShader", StringComparison.OrdinalIgnoreCase);
            var shaderByteCode = ShaderBytecode.CompileFromFile(sourceFile, "main", isPixelShader ? "ps_5_0" : "vs_5_0");
            return shaderByteCode?.Bytecode;
        }

        private static void CreateObjectRedirector(string originalObject, ExportEntry targetObject, PackageCache cache)
        {
            var uniqueItems = originalObject.Split(',');
            foreach (var uniqueItem in uniqueItems)
            {
                var parts = uniqueItem.Trim().Split('.');
                IEntry currentParent = null;

                // Determine where we need to start working.
                string composed = "";
                for (int i = 0; i < parts.Length - 1; i++)
                {
                    var part = parts[i];
                    currentParent =
                        ExportCreator.CreatePackageExport(targetObject.FileRef, part, currentParent, cache: cache);
                }

                var redirector = ExportCreator.CreateExport(targetObject.FileRef, parts.Last(), "ObjectRedirector",
                    currentParent, indexed: false);
                var bin = ObjectRedirector.Create();
                bin.DestinationObject = targetObject.UIndex;
                redirector.WriteBinary(bin);
            }
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

        public static IEntry MaterialDonorImporter(IMEPackage dest, ExportEntry source, RelinkerOptionsPackage rop)
        {
            if (!CanDonateViaMDI(source))
            {
                return null;
            }

            var relinkMap = rop.CrossPackageMap; // Cache the relink map. Using it will corrupt the relink operation.
            rop.CustomDonorImporter = null; // Remove this or we will get a stack overflow
            rop.CrossPackageMap = new ListenableDictionary<IEntry, IEntry>();
            EntryExporter.ExportExportToPackage(source, dest, out var newEntry, rop.Cache, rop);

            // Do we need to merge the relink map? Will that cause a double relink?
            rop.CrossPackageMap = relinkMap; // Restore relink map so a relink can later be performed.
            rop.CustomDonorImporter = MaterialDonorImporter; // Restore
            return newEntry;
        }

        private static bool CanDonateViaMDI(ExportEntry source)
        {
            if (source.FileRef.FilePath.Contains(MilanShared.PipelineRoot))
            {
                if (source.FileRef.FilePath.Contains("Meshes") && source.ClassName.CaseInsensitiveEquals("StaticMesh"))
                    return true; // We can donate 
            }

            if (DonorObjects.IndexOf(source.InstancedFullPath) == -1)
                return false; // We don't use this for anything we don't have full control over

            return true;
        }

        ///// <summary>
        ///// Compiles shaders from source
        ///// </summary>
        //private static void CompileShaders()
        //{
        //    var hasFXC = LocateFXC(out var fxc);
        //    if (!hasFXC)
        //    {
        //        Environment.Exit(1); // This is required. The failure will be logged in Locate.
        //    }

        //    var shadersDir = Path.Combine(MilanShared.PipelineRoot, "Materials", "Shaders");
        //    var sourceDir = Path.Combine(shadersDir, "Source");
        //    var compiledDir = Path.Combine(shadersDir, "Compiled");

        //    if (!Directory.Exists(sourceDir))
        //    {
        //        MilanLog.Information($"Skipping shader build, input directory missing: {shadersDir}", customPrefix: LOG_CATEGORY);
        //        return;
        //    }

        //    // Ensure exists
        //    Directory.CreateDirectory(compiledDir);

        //    foreach (var sourceMaterialShaderDir in Directory.GetDirectories(sourceDir))
        //    {
        //        var destMaterialShaderDir = Directory.CreateDirectory(Path.Combine(compiledDir, Path.GetFileName(sourceMaterialShaderDir))).FullName;
        //        foreach (var factory in Directory.GetDirectories(sourceMaterialShaderDir))
        //        {
        //            var destFactory = Directory.CreateDirectory(Path.Combine(destMaterialShaderDir, Path.GetFileName(factory)));
        //            foreach (var hlsl in Directory.GetFiles(factory, "*.hlsl"))
        //            {
        //                var isPixelShader = hlsl.Contains("PixelShader", StringComparison.OrdinalIgnoreCase);
        //                var typeParam = isPixelShader ? "ps_5_0" : "vs_5_0";
        //                MilanLog.Information($"Compiling shader {Path.GetFileName(sourceMaterialShaderDir)} {destFactory.Name} {Path.GetFileNameWithoutExtension(hlsl)}", customPrefix: LOG_CATEGORY);
        //                var process = Process.Start(fxc, $"/nologo /T {typeParam} /Fo \"{Path.Combine(destFactory.FullName, Path.GetFileNameWithoutExtension(hlsl) + ".fxc")}\" \"{hlsl}\"");
        //                process.WaitForExit();
        //                if (process.ExitCode != 0)
        //                {
        //                    MilanLog.Error($"    FXC exit code was not zero: {process.ExitCode}", customPrefix: LOG_CATEGORY);
        //                }
        //            }
        //        }
        //    }
        //}
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
