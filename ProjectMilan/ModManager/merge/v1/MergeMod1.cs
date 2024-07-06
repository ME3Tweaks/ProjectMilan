using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using ProjectMilan;
using ProjectMilan.Pipelines;
using ProjectMilanCore;

namespace ME3TweaksModManager.modmanager.objects.mod.merge.v1
{
    /// <summary>
    /// Merge Mod V1. Merges properties, objects
    /// </summary>
    public class MergeMod1 : IMergeMod
    {
        private const string ManifestSchemaInternalPath = @"ME3TweaksModManager.modmanager.objects.mod.merge.v1.schema.json";
        private const string MMV1_ASSETMAGIC = @"MMV1";
        [JsonIgnore]
        public string MergeModFilename { get; set; }

        [JsonProperty(@"game")]
        [JsonConverter(typeof(StringEnumConverter))]
        public MEGame Game { get; set; } // Only used for sanity check

        [JsonProperty(@"files")]
        public List<MergeFile1> FilesToMergeInto;

        [JsonIgnore]
        public CaseInsensitiveDictionary<MergeAsset> Assets { get; set; }

        public MergeMod1() { }
        public static MergeMod1 ReadMergeMod(Stream mergeFileStream, string mergeModName, bool loadAssets)
        {
            // Version and magic will already be read by main value
            var manifest = mergeFileStream.ReadUnrealString();

            // This doesn't work since serialization strips some info
            // Just will have to trust devs
            // 06/02/2022: Validate against the known schema to prevent future changes from being able to be 'backported' to unsupported versions
            //var schemaText = new StreamReader(M3Utilities.ExtractInternalFileToStream(ManifestSchemaInternalPath)).ReadToEnd();
            //var messages = JsonSchemaValidator.ValidateSchema(manifest, schemaText);
            //if (messages != null && messages.Any())
            //{
            //    MilanLog.Error($@"Invalid schema for mergemod manifest {mergeModName}:");
            //    foreach (var m in messages)
            //    {
            //        MilanLog.Error($@"  {m}");
            //    }
            //    throw new Exception($"The mergemod {mergeModName} manifest contains an invalid manifest. See the Mod Manager log for details.");
            //}

            var mm = JsonConvert.DeserializeObject<MergeMod1>(manifest);
            mm.MergeModFilename = mergeModName;

            // setup links
            foreach (var ff in mm.FilesToMergeInto)
            {
                ff.SetupParent(mm);
                ff.Validate();
            }

            var assetCount = mergeFileStream.ReadInt32();
            mm.Assets = new CaseInsensitiveDictionary<MergeAsset>(assetCount);
            if (assetCount > 0)
            {
                for (int i = 0; i < assetCount; i++)
                {
                    var assetMag = mergeFileStream.ReadStringASCII(4);
                    if (assetMag != MMV1_ASSETMAGIC)
                    {
                        throw new Exception("Bad magic header!");
                    }

                    MergeAsset ma = new MergeAsset();
                    var assetName = mergeFileStream.ReadUnrealString();
                    ma.FileSize = mergeFileStream.ReadInt32();
                    if (loadAssets)
                    {
                        // Read now
                        ma.ReadAssetBinary(mergeFileStream);
                    }
                    else
                    {
                        // Will load at install time
                        ma.FileOffset = (int)mergeFileStream.Position;
                        mergeFileStream.Skip(ma.FileSize);
                    }

                    mm.Assets[assetName] = ma;
                }
            }

            if (mergeFileStream.Position != mergeFileStream.Length)
            {
                throw new Exception("Serialize size mismatch");
            }
            return mm;
        }

        /// <summary>
        /// Gets the number of files to merge into
        /// </summary>
        /// <returns></returns>
        public int GetMergeCount() => FilesToMergeInto.Sum(x => x.GetMergeCount());
        /// <summary>
        /// Gets the weight of changes for more accurate progress tracking
        /// </summary>
        /// <returns></returns>
        public int GetMergeWeight() => FilesToMergeInto.Sum(x => x.GetMergeWeight());
        public void ExtractToFolder(string outputfolder)
        {
            // scripts and assets
            foreach (var mc in FilesToMergeInto.SelectMany(x => x.MergeChanges))
            {
                if (mc.PropertyUpdates is not null)
                {
                    foreach (PropertyUpdate1 propertyUpdate in mc.PropertyUpdates)
                    {
                        if (!string.IsNullOrEmpty(propertyUpdate.PropertyAsset))
                        {
                            File.WriteAllText(Path.Combine(outputfolder, Path.GetFileName(propertyUpdate.PropertyAsset)), propertyUpdate.PropertyValue);
                            propertyUpdate.PropertyValue = null;
                        }
                    }
                }

                if (mc.ScriptUpdate != null)
                {
                    File.WriteAllText(Path.Combine(outputfolder, Path.GetFileName(mc.ScriptUpdate.ScriptFileName)), mc.ScriptUpdate.ScriptText);
                    mc.ScriptUpdate.ScriptText = null;
                }

                if (mc.AssetUpdate != null)
                {
                    File.WriteAllBytes(Path.Combine(outputfolder, Path.GetFileName(mc.AssetUpdate.AssetName)), Assets[mc.AssetUpdate.AssetName].AssetBinary);
                }

                if (mc.AddToClassOrReplace != null)
                {
                    foreach ((string script, string fileName) in mc.AddToClassOrReplace.Scripts.Zip(mc.AddToClassOrReplace.ScriptFileNames))
                    {
                        File.WriteAllText(Path.Combine(outputfolder, Path.GetFileName(fileName)), script);
                    }
                    mc.AddToClassOrReplace.Scripts = null;
                }
            }

            // assets
            Assets = null;

            // json
            File.WriteAllText(Path.Combine(outputfolder, $@"{Path.GetFileNameWithoutExtension(MergeModFilename)}.json"),
                JsonConvert.SerializeObject(this, Formatting.Indented, new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore,
                    DefaultValueHandling = DefaultValueHandling.Ignore
                }));
        }

        public IEnumerable<string> GetMergeFileTargetFiles()
        {
            List<string> targets = new List<string>();

            return targets;
        }

        public static IList<string> Serialize(Stream outStream, string manifestText, string sourceDir)
        {
            MilanLog.Information($@"M3MCompiler: Beginning M3M V1 serialization");
            MilanLog.Information($@"M3MCompiler: Source json text: {manifestText}", false); // This is as close as I can get...

            // VALIDATE JSON SCHEMA
            var schemaText = File.ReadAllText(Path.Combine(Directory.GetParent(MilanShared.PipelineRoot).FullName, "ModManager", "merge", "v1", "schema.json"));
            var schemaFailureMessages = JsonSchemaValidator.ValidateSchema(manifestText, schemaText);
            if (schemaFailureMessages != null && schemaFailureMessages.Any())
            {
                return schemaFailureMessages;
            }

            var mm = JsonConvert.DeserializeObject<MergeMod1>(manifestText);
            MilanLog.Information($@"M3MCompiler: Json is valid for schema");

            // Update manifest

            SortedSet<string> assets = new();
            // Get all assets.
            foreach (var fc in mm.FilesToMergeInto)
            {
                foreach (var mc in fc.MergeChanges)
                {
                    if (mc.PropertyUpdates is not null)
                    {
                        foreach (PropertyUpdate1 propertyUpdate in mc.PropertyUpdates)
                        {
                            if (propertyUpdate.PropertyType is @"ArrayProperty")
                            {
                                var assetFilePath = Path.Combine(sourceDir, propertyUpdate.PropertyAsset);
                                MilanLog.Information($@"M3MCompiler: ArrayProperty file being added into m3m: {assetFilePath}");
                                if (!File.Exists(assetFilePath))
                                {
                                    throw new Exception($"Property script file not found: {propertyUpdate.PropertyAsset}");
                                }
                                propertyUpdate.PropertyValue = File.ReadAllText(assetFilePath);
                            }
                        }
                    }

                    if (mc.AssetUpdate?.AssetName != null)
                    {
                        var assetPath = Path.Combine(sourceDir, mc.AssetUpdate.AssetName);
                        if (!File.Exists(assetPath))
                        {
                            throw new Exception($"Asset not found: {mc.AssetUpdate.AssetName}");
                        }
                        MilanLog.Information($@"M3MCompiler: Adding merge asset file to m3m: {assetPath}");
                        assets.Add(mc.AssetUpdate.AssetName);
                    }

                    if (mc.ScriptUpdate?.ScriptFileName != null)
                    {
                        var scriptDiskFile = Path.Combine(sourceDir, mc.ScriptUpdate.ScriptFileName);
                        if (!File.Exists(scriptDiskFile))
                        {
                            throw new Exception($"Script not found: {mc.ScriptUpdate.ScriptFileName}");
                        }
                        MilanLog.Information($@"M3MCompiler: Adding script update file to m3m: {scriptDiskFile}");
                        mc.ScriptUpdate.ScriptText = File.ReadAllText(scriptDiskFile);
                    }

                    if (mc.AddToClassOrReplace?.ScriptFileNames is { Length: > 0 } fileNames)
                    {
                        mc.AddToClassOrReplace.Scripts = new string[fileNames.Length];
                        for (int i = 0; i < fileNames.Length; i++)
                        {
                            string fileName = fileNames[i];
                            string scriptDiskFile = Path.Combine(sourceDir, fileName);
                            if (!File.Exists(scriptDiskFile))
                            {
                                throw new Exception($"Script not found: {scriptDiskFile}");
                            }

                            MilanLog.Information($@"M3MCompiler: Adding AddToClassOrReplace file to m3m: {scriptDiskFile}");
                            mc.AddToClassOrReplace.Scripts[i] = File.ReadAllText(scriptDiskFile);
                        }
                    }
                }
            }

            MilanLog.Information($@"M3MCompiler: Serializing merge mod object");
            outStream.WriteUnrealStringUnicode(JsonConvert.SerializeObject(mm, Formatting.None));

            MilanLog.Information($@"M3MCompiler: Serializing {assets.Count} referenced assets");
            outStream.WriteInt32(assets.Count);
            foreach (var asset in assets)
            {
                MilanLog.Information($@"M3MCompiler: Serializing {asset} into m3m");
                outStream.WriteStringASCII(MMV1_ASSETMAGIC); // MAGIC
                outStream.WriteUnrealStringUnicode(asset); // ASSET NAME
                var assetBytes = File.ReadAllBytes(Path.Combine(sourceDir, asset));
                outStream.WriteInt32(assetBytes.Length); // ASSET LENGTH
                outStream.Write(assetBytes); // ASSET DATA
            }

            MilanLog.Information($@"M3MCompiler: V1 serialization complete");
            return null;
        }
    }
}
