using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;
using Image = LegendaryExplorerCore.Textures.Image;

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
            InventoryUpscales();
            UpdateTextures();

            // Commented out: Not reliable right now
            // Bring over all textures to TFC
            MoveNonLightingTexturesToExternalTFC(MilanShared.DLC_NAME); // Non-lighting
            MilanShared.MoveTexturesToTFC(@"Lighting", MilanShared.DLC_NAME, true, @"MILAN-TFC"); // Lighting
        }

        private static Dictionary<string, string> ifpToFileMap = new Dictionary<string, string>();

        private static void InventoryUpscales()
        {
            var upscales = Path.Combine(Program.Settings.InputSyncPath, "upscales");
            foreach (var upscale in Directory.GetFiles(upscales))
            {
                var fname = Path.GetFileNameWithoutExtension(upscale);
                var ifp = fname.Substring(0, fname.IndexOf("_0x"));
                ifpToFileMap[ifp] = upscale;
            }
        }


        /// <summary>
        /// Updates texture formats that only work in ME3 to LE3, installs upscales, strip material permutations on broken materials if it will fix them.
        /// </summary>
        private static void UpdateTextures()
        {
            // ME3 V8U8 norms don't work in LE3, it seems V8U8 support was removed, they appear as black
            // Convert them all to BC7

            var inputFolder = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole");
            using TieredPackageCache cache = TieredPackageCache.GetGlobalPackageCache(MEGame.LE3, debugName: "TFCBuild global LE3 root").ChainNewCache(debugName: "TFCBuild UpdateTextures cache");
            foreach (var pf in Directory.GetFiles(inputFolder, "*.pcc", SearchOption.AllDirectories))
            {
                MilanLog.Information($"Checking package {Path.GetFileName(pf)}", customPrefix: LOG_CATEGORY);
                var p = MEPackageHandler.OpenMEPackage(pf);

                foreach (var obj in p.Exports.Where(x => x.IsTexture() || x.IsA("MaterialInstanceConstant")))
                {
                    if (obj.IsA("MaterialInstanceConstant"))
                    {
                        if (obj.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true && ShaderCacheManipulator.IsMaterialBroken(obj))
                        {
                            var parent = obj.GetProperty<ObjectProperty>("Parent")?.ResolveToExport(p, cache);
                            if (parent != null && !ShaderCacheManipulator.IsMaterialBroken(parent))
                            {
                                MilanLog.Information($"  Fixing broken material due to permutation {obj.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                                obj.RemoveProperty("bHasStaticPermutationResource");
                                obj.WriteBinary([]);
                            }
                        }

                        continue;
                    }
                    else
                    {
                        var format = obj.GetProperty<EnumProperty>("Format");
                        if (format.Value == "PF_V8U8")
                        {
                            // Needs converted
                            MilanLog.Information(
                                $"  Converting texture {obj.InstancedFullPath} from {format.Value} to BC7",
                                customPrefix: LOG_CATEGORY);
                            try
                            {
                                ConvertTexture(obj, PixelFormat.BC7);
                            }
                            catch (Exception ex)
                            {
                                // This may be expected in a few cases. For example if TFC for texture data cannot be found.
                                // This may happen during dev as textures will be broken on and off
                                MilanLog.Error($"  Unable to convert texture: {ex.Message}");
                            }
                        }
                    }

                    if (ifpToFileMap.TryGetValue(obj.InstancedFullPath, out var upscaleFile))
                    {
                        MilanLog.Information($"  Installing upscaled texture {obj.InstancedFullPath}", customPrefix: LOG_CATEGORY);
                        Texture2D t2d = new Texture2D(obj);
                        var image = Image.LoadFromFile(upscaleFile, getFormat(upscaleFile));
                        t2d.Replace(image, t2d.Export.GetProperties(), isPackageStored: true); // Put into package
                    }
                }

                if (p.IsModified)
                {
                    MilanLog.Information($"  Saving package", customPrefix: LOG_CATEGORY);
                    p.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
                    MilanShared.RefreshMilanFiles = true;
                }
            }
        }

        private static PixelFormat getFormat(string upscaleFile)
        {
            // texture_0xdfd(ARGB).png
            var fname = Path.GetFileNameWithoutExtension(upscaleFile);
            var parenIdx = fname.IndexOf('(');
            if (parenIdx == -1)
                return PixelFormat.ARGB;
            fname = fname.Substring(parenIdx + 1);
            fname = fname.Trim(')');
            if (Enum.TryParse<PixelFormat>(fname, out var format))
            {
                return format;
            }
            return PixelFormat.ARGB;
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
        public static void MoveNonLightingTexturesToExternalTFC(string dlcName)
        {
            MilanShared.MoveTexturesToTFC("Textures", dlcName, false, @"MILAN-TFC");

            // Step 2: TFC Compactor
            var inputFolder = Path.Combine(Program.Settings.OutputModPath, @"CookedPCConsole");
            var staging = Directory.CreateDirectory(Path.Combine(inputFolder, "Staging")).FullName;
            TFCCompactorInfoPackage info = new TFCCompactorInfoPackage()
            {
                Game = MEGame.LE3,
                BaseCompactionPath = inputFolder,
                DLCName = MilanShared.DLC_NAME,
                GamePath = LE3Directory.DefaultGamePath,
                TFCsToCompact = new List<string>()
                {
                    $"Textures_{MilanShared.DLC_NAME}",
                    "Textures_DLC_CON_GUN01",
                    "Textures_DLC_CON_GUN02",
                    "Textures_DLC_HEN_PR",
                    "Textures_DLC_EXP_Pack001",
                    "Textures_DLC_EXP_Pack002",
                    "Textures_DLC_EXP_Pack003",
                    "Textures_DLC_EXP_Pack003_Base",
                },
                UseIndexing = false,
                StagingPath = staging,
                TFCType = "Textures",
                RootTexturesOnly = false, // Name says non-lighting: root (lightmap) textures are handled separately below via plain MoveTexturesToTFC, not compacted here.
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
        }
    }
}
