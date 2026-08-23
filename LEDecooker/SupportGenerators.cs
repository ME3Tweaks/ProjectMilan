using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Newtonsoft.Json;
using System.Diagnostics;
using static System.Net.Mime.MediaTypeNames;
namespace LEDecooker
{
    internal class SupportGenerators
    {
#if DEBUG
        /// <summary>
        /// DO NOT CHANGE!
        /// </summary>
        class TexInfo
        {
            public string packagefile { get; set; }
            public string memoryfullpath { get; set; }
            public string classname { get; set; }
        }

        /// <summary>
        /// Generates the Texture to Package DB file that is used to pull in all textures to decook fileset.
        /// </summary>
        /// <param name="game"></param>
        public static void GenerateTextureDB(MEGame game)
        {
            // Maps a texture's instance object name to the path of a package that contains it's export data
            var TextureToPackageName = new CaseInsensitiveConcurrentDictionary<TexInfo>();
            var set = new SortedSet<string>();

            int done = 0;
            int total = 1;
            void inventoryPackage(IMEPackage package)
            {
                foreach (var tex in package.Exports.Where(x => !x.IsDefaultObject && x.IsA("Texture")))
                {
                    if (tex.ClassName is "LightMapTexture2D" or "ShadowMapTexture2D")
                        continue; // Do not care.
                    set.Add(tex.ClassName);
                    var instancedName = tex.ObjectName.Instanced;
                    var candidate = new TexInfo() { packagefile = package.FilePath, memoryfullpath = tex.MemoryFullPath, classname = tex.ClassName };

                    // Several packages can own a texture with the same object name. Keeping whichever
                    // arrived first made the winner depend on thread scheduling, so the same inputs
                    // could produce a different DB -- and a different pixel format, which changes the
                    // compiled shader -- from one run to the next. Break the tie on the path instead so
                    // the result is reproducible. Which copy a material should actually use is decided
                    // at resolve time, where the material's own package is known and preferred.
                    lock (TextureToPackageName)
                    {
                        if (!TextureToPackageName.TryGetValue(instancedName, out var existing)
                            || string.Compare(candidate.memoryfullpath, existing.memoryfullpath, StringComparison.OrdinalIgnoreCase) < 0)
                        {
                            TextureToPackageName[instancedName] = candidate;
                        }
                    }
                }
                Interlocked.Increment(ref done);
                if (done % 10 == 0 || done == total)
                {
                    Console.Write($"\r[{done}/{total}]");
                }
            }


            Console.WriteLine($"Building list of all textures for {game}...");
            string ext = game == MEGame.ME1 ? "upk" : "pcc";
            var backupPath = ME3TweaksBackups.GetGameBackupPath(game);
            var files = Directory.GetFiles(backupPath, $"*.{ext}", SearchOption.AllDirectories);
            total = files.Length;

            Parallel.ForEach(files, packageF =>
            {
                var package = MEPackageHandler.UnsafePartialLoad(packageF, x => false);
                inventoryPackage(package);
            });

            if (game == MEGame.ME3)
            {
                // Enumerate DLCs
                var dlcPath = Path.Combine(backupPath, "BIOGame", "DLC");
                if (Directory.Exists(dlcPath))
                {
                    var dlcFolders = Directory.GetDirectories(dlcPath);
                    foreach (var dlcFolder in dlcFolders)
                    {
                        var sfarPath = Path.Combine(dlcFolder, "CookedPCConsole", "Default.sfar");
                        if (File.Exists(sfarPath))
                        {
                            var dlcPackage = new DLCPackage(sfarPath);
                            var pccFiles = dlcPackage.Files.Where(x => x.FileName.EndsWith($".{ext}", StringComparison.OrdinalIgnoreCase) && x.isActualFile).ToList();

                            // Update total count when SFAR is opened
                            Interlocked.Add(ref total, pccFiles.Count);

                            Parallel.ForEach(pccFiles, fileEntry =>
                            {
                                var fileIndex = dlcPackage.Files.IndexOf(fileEntry);
                                using var decompressedStream = dlcPackage.DecompressEntry(fileIndex);
                                var package = MEPackageHandler.UnsafePartialLoadFromStream(decompressedStream, dlcPackage.Files[fileIndex].FileName, x => false);
                                inventoryPackage(package);
                            });
                        }
                    }
                }
            }

            Console.WriteLine();
            Console.WriteLine("Done.");
            var outJ = JsonConvert.SerializeObject(TextureToPackageName, Formatting.Indented);
            File.WriteAllText($@"../../../supportfiles/texturedb_{game}.json", outJ);
            Debug.WriteLine(string.Join('\n', set));
        }

        /// <summary>
        /// Inventories objects of a specified type from a package file and organizes them into a dictionary for further
        /// processing.
        /// </summary>
        /// <remarks>Objects that are default objects, archetypes, or have a root object named "TheWorld"
        /// are excluded from the inventory. The method assumes the package file exists and is accessible.</remarks>
        /// <param name="packageToObjList">A dictionary that maps object linkers to their corresponding memory paths and package file paths. This
        /// collection is populated with the inventoried objects.</param>
        /// <param name="packageF">The file path of the package to be loaded and processed.</param>
        /// <param name="objectType">The name of the object type to inventory from the package. Only objects matching this type or its subclasses
        /// are considered, depending on the value of isA.</param>
        /// <param name="isA">true to include objects that are subclasses of the specified object type; false to include only objects of
        /// the exact type.</param>
        private static void InventoryPackage(CaseInsensitiveConcurrentDictionary<CaseInsensitiveConcurrentDictionary<string>> packageToObjList, IMEPackage package, string objectType, bool isA)
        {
            List<ExportEntry> objects = null;
            if (!isA)
            {
                objects = package.Exports.Where(x => !x.IsDefaultObject && !x.IsArchetype && x.ClassName == objectType && x.GetRoot().ObjectName != "TheWorld").ToList();
            }
            else
            {
                objects = package.Exports.Where(x => !x.IsDefaultObject && !x.IsArchetype && (x.Parent == null || x.Parent.ClassName == "Package") && x.IsA(objectType) && x.GetRoot().ObjectName != "TheWorld").ToList();
            }


            foreach (var obj in objects) // This might need changed later.
            {
                var linker = obj.GetLinker();
                if (!packageToObjList.TryGetValue(linker, out var objs))
                {
                    objs = packageToObjList[linker] = new CaseInsensitiveConcurrentDictionary<string>();
                }

                if (!objs.TryGetValue(obj.MemoryFullPath, out _))
                {
                    objs[obj.MemoryFullPath] = package.FilePath;
                }
            }
        }

        public static void GenUObjDB(MEGame game, string objectType, bool isA)
        {
            Console.WriteLine($"Building list of all '{objectType}' objects for {game}...");


            // Maps all objects of a specific type to their source packages
            var packageToObjList = new CaseInsensitiveConcurrentDictionary<CaseInsensitiveConcurrentDictionary<string>>();

            var backupPath = ME3TweaksBackups.GetGameBackupPath(game);
            var files = Directory.GetFiles(backupPath, "*.pcc", SearchOption.AllDirectories);
            var set = new SortedSet<string>();

            int done = 0;
            int total = files.Length;
            Parallel.ForEach(files, packageF =>
            {
                var package = MEPackageHandler.UnsafePartialLoad(packageF, x => false);
                InventoryPackage(packageToObjList, package, objectType, isA);
                Interlocked.Increment(ref done);
                if (done % 10 == 0 || done == total)
                {
                    Console.Write($"\r[{done}/{total}]");
                }
            });

            // Inventory DLCs
            if (game == MEGame.ME3)
            {
                // Inventory DLCs
                var dlcPath = Path.Combine(backupPath, "BIOGame", "DLC");
                if (Directory.Exists(dlcPath))
                {
                    var dlcFolders = Directory.GetDirectories(dlcPath);
                    foreach (var dlcFolder in dlcFolders)
                    {
                        var sfarPath = Path.Combine(dlcFolder, "CookedPCConsole", "Default.sfar");
                        if (File.Exists(sfarPath))
                        {
                            var dlcPackage = new DLCPackage(sfarPath);
                            var pccFiles = dlcPackage.Files.Where(x => x.FileName.EndsWith($".pcc", StringComparison.OrdinalIgnoreCase) && x.isActualFile).ToList();

                            // Update total count when SFAR is opened
                            Interlocked.Add(ref total, pccFiles.Count);
                            Console.Write($"\r[{done}/{total}]");

                            Parallel.ForEach(pccFiles, fileEntry =>
                            {
                                var fileIndex = dlcPackage.Files.IndexOf(fileEntry);
                                using var decompressedStream = dlcPackage.DecompressEntry(fileIndex);
                                var package = MEPackageHandler.UnsafePartialLoadFromStream(decompressedStream, dlcPackage.Files[fileIndex].FileName, x => false);
                                InventoryPackage(packageToObjList, package, objectType, isA);

                            });
                        }
                    }
                }
            }


            Console.WriteLine();
            Console.WriteLine("Done.");
            var outJ = JsonConvert.SerializeObject(packageToObjList, Formatting.Indented);
            File.WriteAllText($@"../../../supportfiles/{objectType.ToLower()}db_{game}.json", outJ);
            Debug.WriteLine(string.Join('\n', set));
        }

        public static void GeneratePerPackageNesting(MEGame game)
        {
            Console.WriteLine($"Generating Material IFP database for {game}...");
            // Maps PackageName -> (MaterialName -> IFP)
            var mapping = new CaseInsensitiveConcurrentDictionary<CaseInsensitiveConcurrentDictionary<string>>();
            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(game, gameRootOverride: ME3TweaksBackups.GetGameBackupPath(game));

            int total = loadedFiles.Count;
            int done = 0;


            void inventoryPackage(IMEPackage p)
            {
                foreach (var mat in p.Exports.Where(x => x.IsA("Material")))
                {
                    var package = mat.GetLinker();
                    if (!mapping.TryGetValue(package, out var subMapping))
                    {
                        // Map the list
                        subMapping = new CaseInsensitiveConcurrentDictionary<string>();
                        mapping[package] = subMapping;
                    }

                    var subPath = mat.MemoryFullPath.Substring(mat.GetLinker().Length + 1);
                    if (subPath.Contains("."))
                    {
                        subMapping[mat.ObjectName.Instanced] = subPath;
                    }
                }

                Interlocked.Increment(ref done);
                if (done % 10 == 0 || done == total)
                {
                    Console.Write($"\r[{done}/{total}]");
                }
            }

            Parallel.ForEach(loadedFiles, f =>
            {
                //foreach (var f in loadedFiles)
                {
                    var p = MEPackageHandler.UnsafePartialLoad(f.Value, x => false);
                    inventoryPackage(p);
                }
            });
            Console.WriteLine();

            if (game == MEGame.ME3)
            {
                // Inventory DLCs
                var backupPath = ME3TweaksBackups.GetGameBackupPath(game);
                var dlcPath = Path.Combine(backupPath, "BIOGame", "DLC");
                if (Directory.Exists(dlcPath))
                {
                    var dlcFolders = Directory.GetDirectories(dlcPath);
                    foreach (var dlcFolder in dlcFolders)
                    {
                        var sfarPath = Path.Combine(dlcFolder, "CookedPCConsole", "Default.sfar");
                        if (File.Exists(sfarPath))
                        {
                            var dlcPackage = new DLCPackage(sfarPath);
                            var pccFiles = dlcPackage.Files.Where(x => x.FileName.EndsWith($".pcc", StringComparison.OrdinalIgnoreCase) && x.isActualFile).ToList();

                            // Update total count when SFAR is opened
                            Interlocked.Add(ref total, pccFiles.Count);

                            Parallel.ForEach(pccFiles, fileEntry =>
                            {
                                var fileIndex = dlcPackage.Files.IndexOf(fileEntry);
                                using var decompressedStream = dlcPackage.DecompressEntry(fileIndex);
                                var package = MEPackageHandler.UnsafePartialLoadFromStream(decompressedStream, dlcPackage.Files[fileIndex].FileName, x => false);
                                inventoryPackage(package);
                            });
                        }
                    }
                }
            }

            File.WriteAllText($@"../../../supportfiles/materialifps_{game}.json", JsonConvert.SerializeObject(mapping, Formatting.Indented));
        }
#endif
    }
}
