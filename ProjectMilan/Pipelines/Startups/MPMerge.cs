using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using ME3TweaksModManager.modmanager.objects.mod.merge;
using ME3TweaksModManager.modmanager.objects.mod.merge.v1;
using Newtonsoft.Json;
using ProjectMilan.Utility;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Pipeline that generates merge mods.
    /// </summary>
    internal class MPMerge
    {
        private const string LOG_CATEGORY = @"MILAN-MPCommon-Merge";
        public static void RunPipeline()
        {
            InternalRunPipeline();
        }



        private static void InternalRunPipeline()
        {
            BuildMergeMods();
        }

        /// <summary>
        /// Creates merge mods for each subdirectory within MergeMod
        /// </summary>
        private static void BuildMergeMods()
        {
            var mergeModNames = new List<string>();
            var compilingPath = Path.Combine(MilanShared.PipelineRoot, "Startups", "MPCommon", "MergeMod");
            var stagingPath = Path.Combine(compilingPath, "Staging");
            var mergeModsDirs = Directory.GetDirectories(compilingPath, "*", SearchOption.TopDirectoryOnly);

            Utilities.DeleteFilesAndFoldersRecursively(stagingPath, deleteDirectoryItself: false);
            Directory.CreateDirectory(stagingPath);

            var mergeModsPath = Path.Combine(Directory.GetParent(Program.Settings.OutputModPath)!.FullName, "MergeMods");
            Directory.CreateDirectory(mergeModsPath);
            
            foreach (var modDir in mergeModsDirs)
            {
                if (modDir == stagingPath) continue;
                var modName = Directory.CreateDirectory(modDir).Name;
                var manifest = Path.Combine(stagingPath, $"{modName}.json");
                var m3mPath = Path.Combine(mergeModsPath, $"{modName}.m3m");
                MilanLog.Information($"Creating merge mod for {modName}", true, LOG_CATEGORY);

                var mm1 = new MergeMod1()
                {
                    Game = MEGame.LMP,
                    FilesToMergeInto = [],
                };
                
                // Copy to staging for compilation later
                var uc = Directory.GetFiles(modDir, "*.uc", SearchOption.AllDirectories);
                var pcc = Directory.GetFiles(modDir, "*.pcc", SearchOption.AllDirectories);
                var sourceFiles = uc.Concat(pcc);
                foreach (var source in sourceFiles)
                {
                    File.Copy(source, Path.Combine(stagingPath, Path.GetFileName(source)), true);
                }

                foreach (var package in Directory.GetDirectories(modDir))
                {
                    var atcorPath = Path.Combine(package, "AddToClassOrReplace");
                    var auPath = Path.Combine(package, "AssetUpdate");
                    var suPath = Path.Combine(package, "ScriptUpdate");
                    var puPath = Path.Combine(package, "PropertyUpdate");
                    var mergeFile = new MergeFile1()
                    {
                        ApplyToAllLocalizations = false,
                        FileName = $"{Path.GetFileName(package)}.pcc",
                        MergeChanges = []
                    };
                    if (Directory.Exists(atcorPath))
                    {
                        HandleAddToClassOrReplace(mergeFile, atcorPath);
                    }

                    if (Directory.Exists(auPath))
                    {
                        HandleAssetUpdate(mergeFile, auPath);
                    }

                    if (Directory.Exists(suPath))
                    {
                        HandleScriptUpdate(mergeFile, suPath);
                    }
                    if (Directory.Exists(puPath))
                    {
                        HandlePropertyUpdate(mergeFile, puPath);
                    }
                    mm1.FilesToMergeInto.Add(mergeFile);
                }
                using var fs = File.Open(m3mPath, FileMode.Create, FileAccess.ReadWrite);
                var json = JsonConvert.SerializeObject(mm1, Formatting.Indented, new JsonSerializerSettings
                {
                    NullValueHandling = NullValueHandling.Ignore
                });
                File.WriteAllText(manifest, json);
                MergeModLoader.SerializeManifest(fs, json, stagingPath);
            }

            foreach (var mergeModPath in Directory.GetFiles(mergeModsPath, "*.m3m", SearchOption.TopDirectoryOnly))
            {
                mergeModNames.Add(Path.GetFileName(mergeModPath));
            }
            MilanLog.Information($"Updating ModDesc with new merge mods: {string.Join(", ", mergeModNames)}", customPrefix: LOG_CATEGORY);
            // Add all merge mods to moddesc.ini
            var moddescPath = Path.Combine(Program.Settings.OutputModPath, "..", "moddesc.ini");
            var moddesc = DuplicatingIni.LoadIni(moddescPath);
            moddesc["BASEGAME"]["mergemods"].Value = $"{string.Join(";", mergeModNames)}";
            moddesc.WriteToFile(moddescPath);
        }

        /// <summary>
        /// Adds an "AddToClassOrReplace1" merge item to the passed mergeFile. Used to add things to a class or update them if they already exist
        /// </summary>
        /// <param name="mergeFile">MergeFile which to add the changes to</param>
        /// <param name="atcorPath">Path to the ATCOR directory</param>
        private static void HandleAddToClassOrReplace(MergeFile1 mergeFile, string atcorPath)
        {
            mergeFile.MergeChanges = mergeFile.MergeChanges.Concat(GetAddToClassOrReplaceChanges(atcorPath)).ToList();
        }

        /// <summary>
        /// Creates a MergeFileChange1 list with AddToClassOrReplace objects
        /// </summary>
        /// <param name="atcorDir">Path to the ATCOR directory</param>
        /// <returns></returns>
        private static List<MergeFileChange1> GetAddToClassOrReplaceChanges(string atcorDir)
        {
            var mergeChanges = new List<MergeFileChange1>();
            var packageFiles = Directory.GetFiles(atcorDir, "*.uc", SearchOption.AllDirectories);
            packageFiles.Sort(); // Have dependencies like new properties be merged first
            var packageFilesGrouped = packageFiles.GroupBy(x => x.Substring(0, x.IndexOf('.')));
            foreach (var className in packageFilesGrouped)
            {
                mergeChanges.Add(new MergeFileChange1()
                {
                    EntryName = Path.GetFileName(className.Key),
                    AddToClassOrReplace = new AddToClassOrReplace1()
                    {
                        ScriptFileNames = className.Select(x => Path.GetFileName(x)).ToArray()
                    }
                });
            }
            return mergeChanges;
        }
        
        /// <summary>
        /// Adds a "ScriptUpdate1" merge item to the passed mergeFile. Used to replace whole scripts.
        /// </summary>
        /// <param name="mergeFile">MergeFile which to add the changes to</param>
        /// <param name="scriptUpdateDir">Path to the ScriptUpdate directory</param>
        private static void HandleScriptUpdate(MergeFile1 mergeFile, string scriptUpdateDir)
        {
            mergeFile.MergeChanges = mergeFile.MergeChanges.Concat(GetScriptUpdateChanges(scriptUpdateDir)).ToList();
        }

        /// <summary>
        /// Creates a MergeFileChange1 list with ScriptUpdate objects
        /// </summary>
        /// <param name="scriptUpdateDir">Path to the ScriptUpdate directory</param>
        /// <returns></returns>
        private static List<MergeFileChange1> GetScriptUpdateChanges(string scriptUpdateDir)
        {
            var mergeChanges = new List<MergeFileChange1>();
            var scriptFiles = Directory.GetFiles(scriptUpdateDir, "*.uc", SearchOption.AllDirectories);
            foreach (var scriptFile in scriptFiles)
            {
                mergeChanges.Add(new MergeFileChange1()
                {
                    EntryName = Path.GetFileNameWithoutExtension(scriptFile),
                    ScriptUpdate = new ScriptUpdate1()
                    {
                        ScriptFileName = Path.GetFileName(scriptFile)
                    }
                });
            }

            return mergeChanges;
        }

        /// <summary>
        /// Used for full asset replacements (or additionas) from a package file. Requires valid mergemod manifests for each affected package file!
        /// </summary>
        /// <param name="mergeFile">MergeFile which to add the changes to</param>
        /// <param name="assetUpdateDir">Path to the AssetUpdate directory</param>
        private static void HandleAssetUpdate(MergeFile1 mergeFile, string assetUpdateDir)
        {
            foreach (var manifest in Directory.GetFiles(assetUpdateDir, "*.json", SearchOption.AllDirectories))
            {
                var json = JsonConvert.DeserializeObject<MergeMod1>(File.ReadAllText(manifest));
                if (json == null) continue;
                foreach (var m3MergeFile in json.FilesToMergeInto)
                {
                    // Only join changes for the same merge file
                    if (m3MergeFile.FileName == mergeFile.FileName)
                    {
                        mergeFile.MergeChanges = mergeFile.MergeChanges.Concat(m3MergeFile.MergeChanges).ToList();
                        return;
                    } 
                }
            }
        }
        
        /// <summary>
        /// Updates a default property for a specific class.<br/>
        /// ArrayProperties are not currently supported.
        /// </summary>
        /// <param name="mergeFile">MergeFile which to add the changes to</param>
        /// <param name="propertyUpdateDir">Path to the PropertyUpdate directory</param>
        private static void HandlePropertyUpdate(MergeFile1 mergeFile, string propertyUpdateDir)
        {
            mergeFile.MergeChanges = mergeFile.MergeChanges.Concat(GetPropertyUpdateChanges(propertyUpdateDir)).ToList();
        }

        /// <summary>
        /// Creates a MergeFileChange1 list with PropertyUpdate objects
        /// </summary>
        /// <param name="propertyUpdateDir"></param>
        /// <returns></returns>
        private static List<MergeFileChange1> GetPropertyUpdateChanges(string propertyUpdateDir)
        {
            var mmChanges = new List<MergeFileChange1>();
            foreach (var file in Directory.GetFiles(propertyUpdateDir, "*.uc", SearchOption.TopDirectoryOnly))
            {
                var mmChange = new MergeFileChange1
                {
                    EntryName = Path.GetFileNameWithoutExtension(file),
                    PropertyUpdates = []
                };

                foreach (var property in File.ReadLines(file))
                {
                    // Allow comments and empty lines
                    if (property.Trim().StartsWith("//") || property.Trim() == "")
                    {
                        continue;
                    }
                    var prop = property.Split("//")[0]; // get rid of inline comments

                    var propType = prop.Split(" ")[0].Trim('"');
                    var propName = prop.Split(" ")[1].Trim('"');
                    var propValue = prop.Split("=")[1].TrimStart().Trim('"');
                    mmChange.PropertyUpdates.Add(new PropertyUpdate1()
                    {
                        PropertyName = propName,
                        PropertyType = propType,
                        PropertyValue = propValue
                    });
                }
                mmChanges.Add(mmChange);
            }
            return mmChanges;
        }
    }
}
