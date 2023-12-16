using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using static System.Net.Mime.MediaTypeNames;

namespace ProjectMilan.Pipelines.Texture
{
    /// <summary>
    /// Pipeline for extracting audio from ME3 and porting it to LE3 WwiseBanks
    /// </summary>
    internal class TFCBuild
    {
        private const string LOG_CATEGORY = @"MILAN-Texture";
        // Expected pipeline:
        // 1. Go through ME3 package files and find all used Texture2Ds that are not in LE (using object database?). Hopefully things did not get renamed.
        // 2. Make LE3 package file that will be the 'host' for all textures during build (LE1R/LE2R uses this and it works well) - called TFCPackage
        // 3. Stub out all texture exports that will be ported into TFCPackage
        // 4. Extract and port textures - substituting from other sources, such as ALOT, if possible, since these textures will look worse than LE
        //        -> During this step it will build the TFC
        // 5. Run a pass over the compiled DLC and replace all stubbed textures with versions from TFCPackage.
        // This pipeline must be run after level and kit compiler

        public static void RunPipeline()
        {
            InternalRunPipeline();
        }

        private static void InternalRunPipeline()
        {
            ConvertTextures();

            // Todo: Upscaled override

            // Commented out: Not reliable right now
            // Bring over all textures to TFC
            MoveTexturesToExternalTFC(MilanShared.DLC_NAME);
        }

        /// <summary>
        /// Converts texture formats that only work in ME3 to LE3
        /// </summary>
        private static void ConvertTextures()
        {
            var texCategory = $"{LOG_CATEGORY}-Conversion";
            // ME3 V8U8 norms don't work in LE3, it seems V8U8 support was removed, they appear as black
            // Convert them all to BC7
            var inputFolder = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole");

            foreach (var pf in Directory.GetFiles(inputFolder, "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Checking package {Path.GetFileName(pf)}", customPrefix: texCategory);
                var p = MEPackageHandler.OpenMEPackage(pf);

                foreach (var tex in p.Exports.Where(x => x.IsTexture()))
                {
                    var format = tex.GetProperty<EnumProperty>("Format");
                    if (format.Value == "PF_V8U8")
                    {
                        // Needs converted
                        MilanLog.Information($"  Converting texture {tex.InstancedFullPath} from {format.Value} to BC7", customPrefix: texCategory);
                        try
                        {
                            ConvertTexture(tex, PixelFormat.BC7);
                        }
                        catch (Exception ex)
                        {
                            // This may be expected in a few cases. For example if TFC for texture data cannot be found.
                            // This may happen during dev as textures will be broken on and off
                            MilanLog.Error($"  Unable to convert texture: {ex.Message}");
                        }
                    }
                }

                if (p.IsModified)
                {
                    MilanLog.Information($"  Saving package", customPrefix: texCategory);
                    p.Save();
                    MilanShared.RefreshMilanFiles = true;
                }
            }
        }

        private static void ConvertTexture(ExportEntry tex, PixelFormat destFormat)
        {

            var props = tex.GetProperties();
            var texture = new Texture2D(tex);
            var convertedImage = texture.ToImage(destFormat);
            props.AddOrReplaceProp(new EnumProperty($"PF_{destFormat}", "EPixelFormat", MEGame.LE3, "Format"));
            if (destFormat == PixelFormat.BC7)
            {
                props.AddOrReplaceProp(new EnumProperty("TC_NormalmapBC7", "TextureCompressionSettings", MEGame.LE3, "CompressionSettings"));
            }
            else
            {
                // Implement the rest if necessary
                props.AddOrReplaceProp(new EnumProperty("TC_NormalMap", "TextureCompressionSettings", MEGame.LE3, "CompressionSettings"));
            }

            texture.TextureFormat = $"PF_{destFormat}"; // Required for conversion
            texture.Replace(convertedImage, props, isPackageStored: true);
        }


        /// <summary>
        /// This will probably be moved to LEC
        /// </summary>
        public static void MoveTexturesToExternalTFC(string dlcName)
        {
            var inputFolder = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole");
            var tfcName = $"Textures_{dlcName}";
            var tfcPath = Path.Combine(inputFolder, $"{tfcName}.tfc");
            using (var tfcStream = File.Create(tfcPath))
            {
                var guid = Guid.NewGuid();
                tfcStream.WriteGuid(guid);

                foreach (var package in Directory.GetFiles(inputFolder, "*.pcc", SearchOption.AllDirectories))
                {
                    MilanLog.Information($"Checking package {Path.GetFileName(package)}", customPrefix: LOG_CATEGORY);
                    //var me3File = MilanShared.GetME3Package(Path.GetFileName(package));
                    var le3File = MEPackageHandler.OpenMEPackage(package);

                    foreach (var tex in le3File.Exports.Where(x => x.IsTexture()))
                    {
                        if (tex.ObjectName.Name.StartsWith("Cubemap", StringComparison.InvariantCultureIgnoreCase))
                            continue; // These are never moved to TFC as far as I know...

                        var bin = ObjectBinary.From<UTexture2D>(tex);

                        var startedMovingTexture = false;
                        var changedMips = bin.Mips.RemoveAll(x => x.StorageType == StorageTypes.empty);
                        
                        if (bin.Mips.Count <= 6 && changedMips == 0)
                            continue;

                        bool updateTFCName = false;
                        for (int i = 0; i < bin.Mips.Count - 6; i++)
                        {
                            // Move data to external
                            var mip = bin.Mips[i];
                            if (mip.StorageType == StorageTypes.pccUnc)
                            {
                                MilanLog.Information($"  Moving texture to external TFC: {tex.InstancedFullPath}",
                                    !startedMovingTexture, customPrefix: LOG_CATEGORY);
                                startedMovingTexture = true;

                                var compressed = TextureCompression.CompressTexture(mip.Mip, StorageTypes.extOodle);
                                var offset = tfcStream.Position;
                                tfcStream.Write(compressed);
                                mip.StorageType = StorageTypes.extOodle;
                                mip.DataOffset = (int)offset;
                                mip.CompressedSize = compressed.Length;
                                mip.Mip = Array.Empty<byte>();
                                changedMips++;
                                updateTFCName = true;
                            }
                        }

                        if (updateTFCName)
                        {
                            // Update TFC properties
                            var properties = tex.GetProperties();
                            properties.AddOrReplaceProp(new FGuid(guid).ToStructProperty("TFCFileGuid"));
                            properties.AddOrReplaceProp(new NameProperty(tfcName, "TextureFileCacheName"));
                            tex.WriteProperties(properties);
                        }

                        if (changedMips > 0)
                        {
                            tex.WriteBinary(bin);
                        }

                        //var me3Tex = me3File.FindExport(tex.InstancedFullPath);
                        //if (me3Tex != null)
                        //{
                        //    var le3Bin = 
                        //}

                    }

                    if (le3File.IsModified)
                    {
                        MilanLog.Information("  Saving package", customPrefix: LOG_CATEGORY);
                        le3File.Save();
                        MilanShared.RefreshMilanFiles = true;
                    }
                }
            }

            // Step 2: TFC Compactor
            var staging = Directory.CreateDirectory(Path.Combine(inputFolder, "Staging")).FullName;
            TFCCompactorInfoPackage info = new TFCCompactorInfoPackage()
            {
                Game = MEGame.LE3,
                BaseCompactionPath = inputFolder,
                DLCName = MilanShared.DLC_NAME,
                GamePath = LE3Directory.DefaultGamePath,
                TFCsToCompact = new List<string>()
                {
                    $"Textures_{MilanShared.DLC_NAME}"
                },
                UseIndexing = false,
                StagingPath = staging,
                TFCType = "Textures",
            };

            MilanLog.Information("Compacting TFC", customPrefix: LOG_CATEGORY);
            TFCCompactor.CompactTFC(info, x => MilanLog.Error(x, customPrefix: LOG_CATEGORY), (text, done, total) =>
            {
                if (text != null)
                {
                    MilanLog.Information($"  {text}", customPrefix: LOG_CATEGORY);
                }
                if (total > 0)
                {
                    MilanLog.Information($"  Progress: {done}/{total}", customPrefix: LOG_CATEGORY);
                }
                else if (done == -1 && total == -1)
                {

                }
            });

            // Delete staging?
        }
    }
}
