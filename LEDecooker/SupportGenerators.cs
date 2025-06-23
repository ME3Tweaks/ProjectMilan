using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Misc.ME3Tweaks;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using Newtonsoft.Json;
using System.Diagnostics;
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
            Console.WriteLine($"Building list of all textures for {game}...");
            // Maps a texture's instance object name to the path of a package that contains it's export data
            var TextureToPackageName = new CaseInsensitiveConcurrentDictionary<TexInfo>();

            string ext = game == MEGame.ME1 ? "upk" : "pcc";

            var backupPath = ME3TweaksBackups.GetGameBackupPath(game);
            var files = Directory.GetFiles(backupPath, $"*.{ext}", SearchOption.AllDirectories);
            var set = new SortedSet<string>();

            int done = 0;
            int total = files.Length;
            Parallel.ForEach(files, packageF =>
            {
                var package = MEPackageHandler.UnsafePartialLoad(packageF, x => false);
                foreach (var tex in package.Exports.Where(x => !x.IsDefaultObject && x.IsA("Texture")))
                {
                    if (tex.ClassName is "LightMapTexture2D" or "ShadowMapTexture2D")
                        continue; // Do not care.
                    set.Add(tex.ClassName);
                    var instancedName = tex.ObjectName.Instanced;
                    if (!TextureToPackageName.TryGetValue(instancedName, out _))
                    {
                        TextureToPackageName[instancedName] = new TexInfo() { packagefile = package.FilePath, memoryfullpath = tex.MemoryFullPath, classname = tex.ClassName };
                    }
                }
                Interlocked.Increment(ref done);
                if (done % 10 == 0 || done == total)
                {
                    Console.Write($"\r[{done}/{total}]");
                }
            });
            Console.WriteLine();
            Console.WriteLine("Done.");
            var outJ = JsonConvert.SerializeObject(TextureToPackageName, Formatting.Indented);
            File.WriteAllText($@"../../../supportfiles/texturedb_{game}.json", outJ);
            Debug.WriteLine(string.Join('\n', set));
        }

        private static void InventoryPackage(CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>> packageToObjList, string packageF, string objectType, bool isA)
        {
            var package = MEPackageHandler.UnsafePartialLoad(packageF, x => false);
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
                    objs = packageToObjList[linker] = new CaseInsensitiveDictionary<string>();
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
            var packageToObjList = new CaseInsensitiveDictionary<CaseInsensitiveDictionary<string>>();

            var backupPath = ME3TweaksBackups.GetGameBackupPath(game);
            var files = Directory.GetFiles(backupPath, "*.pcc", SearchOption.AllDirectories);
            var set = new SortedSet<string>();

            // Inventory MP DLC. It must be unpacked.
            if (game == MEGame.ME3)
            {
#if FALSE
                for (int i = 1; i < 5; i++)
                {
                    var backupPath = $@"Z:\Mass Effect Builds\ME3\PC\Retail\BIOGame\DLC\DLC_CON_MP{i}\CookedPCConsole";
                    //ME3TweaksBackups.GetGameBackupPath(MEGame.LE3);
                    foreach (var packageF in Directory.GetFiles(backupPath, "*.pcc", SearchOption.AllDirectories))
                    {
                        InventoryPackage(packageToObjList, packageF, objectType, isA);
                    }
                }
#endif
            }


            int done = 0;
            int total = files.Length;
            Parallel.ForEach(files, packageF =>
            {
                InventoryPackage(packageToObjList, packageF, objectType, isA);
                Interlocked.Increment(ref done);
                if (done % 10 == 0 || done == total)
                {
                    Console.Write($"\r[{done}/{total}]");
                }
            });
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

            Parallel.ForEach(loadedFiles, f =>
            {
                //foreach (var f in loadedFiles)
                {
                    var p = MEPackageHandler.UnsafePartialLoad(f.Value, x => false);
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
            });
            Console.WriteLine();


            File.WriteAllText($@"../../../supportfiles/materialifps_{game}.json", JsonConvert.SerializeObject(mapping, Formatting.Indented));
        }
#endif
    }
}
