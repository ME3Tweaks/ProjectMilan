using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Textures;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.Classes;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using MilanShaderHost.LEX;
using System.Diagnostics;
using System.Reflection;

namespace MilanShaderHost
{
    /// <summary>
    /// Descibes what kind of level to build
    /// </summary>
    public enum EShaderLevelMode
    {
        /// <summary>
        /// Build a level for inventorying slashing the shader cache for.
        /// </summary>
        SlashLevel,
        /// <summary>
        /// If the level being built is the preview level
        /// </summary>
        Preview,
        /// <summary>
        /// If the level build built is the compile level (no meshes, improves build time)
        /// </summary>
        Compile
    }

    /// <summary>
    /// Contains the logic for building packages to feed to the game to trigger shader compilation.
    /// </summary>
    public static class MilanShaderPackageBuilder
    {
        /// <summary>
        /// List of directories that contain source packages that will be used when building the map.
        /// </summary>
        public static List<string> SourceFolders { get; } = new();

        /// <summary>
        /// Cache of installed-game packages used only for texture imports intentionally absent from
        /// the decooked material corpus (for example BioVFX_Z_TEXTURES). This avoids reparsing a
        /// source package for every expression in a large effects material package.
        /// </summary>
        private static readonly PackageCache InstalledTexturePackageCache = new();

        /// <summary>
        /// Above this many materials, porting is reported per-material. A package like
        /// EffectsMaterials holds ~1800 materials and each is ported twice (into the transient
        /// package, then into the compiler level), which runs for minutes with no output at all --
        /// indistinguishable from a hang. Small packages stay quiet so ordinary runs aren't noisier.
        /// </summary>
        private const int MaterialProgressThreshold = 10;

        private static void ReportMaterialProgress(string phase, int index, int total, ExportEntry mat)
        {
            if (total <= MaterialProgressThreshold)
                return;
            Console.WriteLine($"  [{phase} {index}/{total}] {mat.InstancedFullPath}");
        }

        private static void ReportBuildStage(string stage)
        {
            Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] {stage}");
        }

        /// <summary>
        /// Placeholder textures for unresolvable imports only have to *exist* for shader
        /// compilation -- codegen depends on the material graph, not on a texture's dimensions or
        /// contents. They are package-stored (<c>isPackageStored: true</c>), and package-stored
        /// mips cannot be deduplicated across packages, so a 512x512 DXT1 with a full mip chain
        /// costs ~170 KB per placeholder per package -- and a cubemap is six of them. A package
        /// with many missing imports bloats badly for data nothing ever samples.
        ///
        /// Compile and capture runs therefore use a 32x32 base (a 6-mip chain, well under a KB)
        /// and skip painting the artwork in at all. Preview runs are looked at by a human, so they
        /// keep the real 512x512 image.
        /// </summary>
        private static bool UseMinimalMissingTextures => !Program.ParsedOptions.PreviewShaders;

        private static int MissingTextureSize => UseMinimalMissingTextures ? 32 : 512;

        /// <summary>
        /// Gets asset used for the floor of the level.
        /// </summary>
        /// <param name="game"></param>
        /// <returns></returns>
        private static LEXOpenable GetFloorAsset(MEGame game) => game switch
        {
            MEGame.LE1 => new LEXOpenable()
            {
                EntryClass = "StaticMesh",
                EntryPath = "BIOA_ICE50_S.ice70_bigfloor01",
                FilePath = "BIOA_ICE50_13_LAY.pcc"
            },
            MEGame.LE2 => new LEXOpenable()
            {
                EntryClass = "StaticMesh",
                EntryPath = "BioS_AncientRuins_Ext.Floor_8x8_Bend",
                FilePath = "BioA_KroHub_130_MainHubArea.pcc"
            },
            MEGame.LE3 => new LEXOpenable()
            {
                EntryClass = "StaticMesh",
                EntryPath = "BioS_AncientCity.Floor.Floor_8x8",
                FilePath = "BioA_Kro002_500city.pcc"
            },
            _ => throw new NotImplementedException(),
        };

        private static LEXOpenable GetSkyAsset(MEGame game) => game switch
        {
            //MEGame.LE1 => new LEXOpenable()
            //{
            //    EntryClass = "StaticMesh",
            //    EntryPath = "BioS_AncientCity.Sky_Sphere",
            //    FilePath = "BioA_Kro002_500city.pcc"
            //},
            //MEGame.LE2 => new LEXOpenable()
            //{
            //    EntryClass = "StaticMesh",
            //    EntryPath = "BioS_AncientRuins_Ext.Sky_Sphere",
            //    FilePath = "BioA_KroHub_130_MainHubArea.pcc"
            //},
            MEGame.LE3 => new LEXOpenable()
            {
                EntryClass = "StaticMeshCollectionActor",
                EntryPath = "TheWorld.PersistentLevel.StaticMeshCollectionActor_1918",
                FilePath = "BioA_MPNov.pcc"
            },
            _ => throw new NotImplementedException(),
        };

        /// <summary>
        /// Builds material refs into the existing given map file. Does NOT save the package it creates.
        /// </summary>
        /// <param name="entryPath"></param>
        public static IMEPackage BuildIntoExistingPackage(string entryPath, string sourceStylePath, IMEPackage transientPackage, bool buildWithMeshes)
        {
            var startupLevel = MEPackageHandler.OpenMEPackage(entryPath);

            // Load our input package we are building shaders out of
            var sourceStylePackage = MEPackageHandler.OpenMEPackage(sourceStylePath);

            ConvertSourceToForcedExport(sourceStylePackage, sourceStylePackage.FileNameNoExtension);
            EnableStaticLightingForAllMaterials(sourceStylePackage);

            List<ExportEntry> portedMats = new List<ExportEntry>();

            // Port materials into transient
            foreach (var mat in sourceStylePackage.Exports.Where(x => x.IsA("Material")))
            {
                var pMat = PortSourceToCooked(mat, transientPackage);
            }
            EnableStaticLightingForAllMaterials(transientPackage);

            // Also port materials into the startup level. This should be faster... I hope
            foreach (var mat in transientPackage.Exports.Where(x => x.IsA("Material")))
            {
                var pMat = PortSourceToCooked(mat, startupLevel);
                if (pMat != null)
                {
                    portedMats.Add(pMat);
                }
            }
            EnableStaticLightingForAllMaterials(startupLevel);

            Point3D startPos = new Point3D(0, 0, 0);

            foreach (var pMat in portedMats)
            {
                AddStaticMeshActorForMaterial(pMat, startPos, buildWithMeshes);

                startPos.Y -= 256;
            }


            // Add static meshes that contain our materials.
            return startupLevel;
        }


        /// <summary>
        /// Builds the map package for shader compile/preview/cacheslashing. Does NOT save the package it creates.
        /// </summary>
        /// <param name="mapName"></param>
        /// <param name="sourceStylePath"></param>
        /// <param name="transientPackage"></param>
        /// <param name="buildMode"></param>
        /// <returns></returns>
        public static IMEPackage BuildMapPackage(string mapName, string sourceStylePath, IMEPackage transientPackage, EShaderLevelMode buildMode)
        {
            var shaderCompilingLevel = MEPackageHandler.CreateMemoryEmptyLevel(mapName, Program.Game);

            List<ExportEntry> portedMats = new List<ExportEntry>();
            List<ExportEntry> portedInstances = new List<ExportEntry>();
            List<ExportEntry> portedTerrains = new List<ExportEntry>();

            // If slashing cache level don't put other materials into it
            if (buildMode != EShaderLevelMode.SlashLevel)
            {
                // Load our input package we are building shaders out of
                var sourceStylePackage = MEPackageHandler.OpenMEPackage(sourceStylePath);

                var captureRoot = MilanShaderBuilderFlow.CaptureRootNameFor(sourceStylePath);
                if (captureRoot != sourceStylePackage.FileNameNoExtension)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] {sourceStylePackage.FileNameNoExtension} is loaded by the game at boot; " +
                                      $"compiling its objects as '{captureRoot}' so ours are the ones that load.");
                }
                ConvertSourceToForcedExport(sourceStylePackage, captureRoot);
                // LE1's Material default is static-lighting enabled while LE3's is disabled.
                // ShaderHost always compiles the LE3 representation with the bit explicitly on:
                // foliage, static meshes, and terrain all share the same material dependencies.
                EnableStaticLightingForAllMaterials(sourceStylePackage);


                // A focused terrain invocation relies on the terrain's authored references: its
                // layer setups pull in only the material graph dependencies it actually needs.
                // Normal package compilation retains the historical all-material behavior.
                var compileTerrainOnly = !string.IsNullOrWhiteSpace(Program.ParsedOptions.TerrainPackagePath);
                if (!compileTerrainOnly)
                {
                    // Port materials into transient
                    var sourceMats = sourceStylePackage.Exports.Where(x => x.IsA("Material"));
                    var requestedMaterial = Program.ParsedOptions?.MaterialPath;
                    if (!string.IsNullOrWhiteSpace(requestedMaterial))
                    {
                        sourceMats = sourceMats.Where(x => string.Equals(x.InstancedFullPath, requestedMaterial,
                            StringComparison.OrdinalIgnoreCase));
                    }
                    var sourceMatsList = sourceMats.ToList();
                    if (!string.IsNullOrWhiteSpace(requestedMaterial))
                    {
                        Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] Focused material filter selected {sourceMatsList.Count} of the source package's materials: {requestedMaterial}");
                    }
                    for (int i = 0; i < sourceMatsList.Count; i++)
                    {
                        var mat = sourceMatsList[i];
                        ReportMaterialProgress("port -> transient", i + 1, sourceMatsList.Count, mat);

                        mat.WriteProperty(new BoolProperty(true, "bUsedWithVectorLightMaps"));
                        mat.WriteProperty(new BoolProperty(true, "bUsedWithSimpleLightMaps"));

                        PortSourceToCooked(mat, transientPackage);
                    }
                    ReportBuildStage($"Finished porting {sourceMatsList.Count:N0} material(s) into the transient package.");

                    // MaterialInstanceConstants carry their own compiled shader map whenever their
                    // static parameter set diverges from the parent's: static switches, component
                    // masks and normal parameters are all compile-time, so the instance cannot share
                    // the parent's shaders. Porting only Materials left every such permutation
                    // uncompiled, and the instance then rendered the parent's defaults.
                    // MaterialInstance derives from MaterialInterface, not Material, so IsA("Material")
                    // above does not reach them.
                    if (!Program.ParsedOptions.NoInstances)
                    {
                        var sourceInstances = sourceStylePackage.Exports
                            .Where(x => x.IsA("MaterialInstance") && HasStaticPermutation(x))
                            .ToList();
                        for (int i = 0; i < sourceInstances.Count; i++)
                        {
                            var mic = sourceInstances[i];
                            ReportMaterialProgress("port instance -> transient", i + 1, sourceInstances.Count, mic);
                            // No bUsedWith* writes here: those are UMaterial fields. The parent picks
                            // them up through the material loop above and EnableStaticLightingForAllMaterials.
                            PortSourceToCooked(mic, transientPackage);
                        }
                        if (sourceInstances.Count > 0)
                        {
                            ReportBuildStage($"Finished porting {sourceInstances.Count:N0} material instance(s) into the transient package.");
                        }
                    }
                }

                // A terrain resource is generated from its owning ATerrain, its components' batch masks,
                // and its layer setups. Port the real terrain rather than compiling loose TerrainMaterial
                // wrappers on a synthetic donor; the result can then be matched back to this exact Terrain
                // export by its cached-resource mask.
                foreach (var terrain in sourceStylePackage.Exports.Where(x => x.IsA("Terrain")).ToList())
                {
                    terrain.Parent = null; // Remove out of tree so it doesn't bring in TheWorld
                    ObjectBinary.EditBinary<Terrain>(terrain, t =>
                    {
                        // Dump all cached materials so we don't reserialize any of them; we only want our new ones we are 
                        // regenerating
                        t.CachedTerrainMaterials = [];
                    });
                    var transientTerrain = PortSourceToCooked(terrain, transientPackage);

                    // This is important; otherwise PackagelessSerializer won't find it later
                    // Build fake level structure
                    var tw = transientPackage.CreatePackageExport("TheWorld");
                    var pl = transientPackage.CreatePackageExport("PersistentLevel", parent: tw);
                    transientTerrain.Parent = pl;
                }
                // Terrain-only builds arrive here through the authored terrain graph rather than the
                // all-material loop above. Normalize the actual relinker output as well, so there is
                // no path that can feed a false bUsedWithStaticLighting material to ShaderClient.
                EnableStaticLightingForAllMaterials(transientPackage);

                // This is the lazy way: Find all missing<X> objects and deduplicate them
                //string[] names = ["MissingTexture", "MissingTextureCube"];
                //foreach (var name in names)
                //{
                //    var matchingExports = transientPackage.Exports.Where(x => x.ObjectName == name && x.idxLink != 0).ToList();
                //    var target = transientPackage.FindExport(name);
                //    var dict = new ListenableDictionary<IEntry, IEntry>();
                //    foreach (var match in matchingExports)
                //    {
                //        dict[match] = target;
                //    }

                //    Relinker.RelinkSamePackage(transientPackage, dict);
                //}


                // Also port materials into the compiler level. This should be faster to port... I hope
                if (!compileTerrainOnly)
                {
                    var transientMats = transientPackage.Exports.Where(x => x.IsA("Material")).ToList();
                    for (int i = 0; i < transientMats.Count; i++)
                    {
                        var mat = transientMats[i];
                        ReportMaterialProgress("port -> level", i + 1, transientMats.Count, mat);

                        // This should already have the bUsedWithStaticLighting set.
                        var pMat = PortSourceToCooked(mat, shaderCompilingLevel);
                        if (pMat != null)
                        {
                            portedMats.Add(pMat);
                        }
                    }
                    ReportBuildStage($"Finished porting {portedMats.Count:N0} material(s) into the compiler level.");

                    if (!Program.ParsedOptions.NoInstances)
                    {
                        var transientInstances = transientPackage.Exports
                            .Where(x => x.IsA("MaterialInstance") && HasStaticPermutation(x))
                            .ToList();
                        for (int i = 0; i < transientInstances.Count; i++)
                        {
                            var mic = transientInstances[i];
                            ReportMaterialProgress("port instance -> level", i + 1, transientInstances.Count, mic);
                            var pMic = PortSourceToCooked(mic, shaderCompilingLevel);
                            if (pMic != null)
                            {
                                portedInstances.Add(pMic);
                            }
                        }
                        if (portedInstances.Count > 0)
                        {
                            ReportBuildStage($"Finished porting {portedInstances.Count:N0} material instance(s) into the compiler level.");
                        }
                    }
                }

                foreach (var terrain in transientPackage.Exports.Where(x => x.IsA("Terrain")))
                {
                    var pTerrain = PortSourceToCooked(terrain, shaderCompilingLevel);
                    if (pTerrain != null)
                    {
                        portedTerrains.Add(pTerrain);
                    }
                }
                EnableStaticLightingForAllMaterials(shaderCompilingLevel);
                ReportBuildStage($"Saving transient diagnostic package ({transientPackage.Exports.Count:N0} exports) to C:\\users\\public\\transient.pcc.");
                transientPackage.Save("C:\\users\\public\\transient.pcc");
                ReportBuildStage("Finished saving transient diagnostic package.");
            }
            else
            {
                // Force text mesh and material into package for slashing.
                LevelBuildTools.CreateTextMesh(shaderCompilingLevel, "TextMeshMaterialReference");
            }

            // PlayerStart is required or we can't even load into it
            ReportBuildStage("Adding required PlayerStart to compiler level.");
            var startPos = new Point3D(0, 0, 1000);
            AddPlayerStart(shaderCompilingLevel, startPos);

            startPos.Z -= 1000;
            startPos.X += 300;
            startPos.Y += 300;

            if (buildMode != EShaderLevelMode.Compile)
            {
                Console.WriteLine("Adding playable components");
                AddCubeMesh(shaderCompilingLevel);

                var floor = AddStaticMeshActor(shaderCompilingLevel, GetFloorAsset(shaderCompilingLevel.Game), startPos, "PlayerFloor");
                LevelTools.SetDrawScale3D(floor, 20, 20, 1);
                AddExistingMeshActor(shaderCompilingLevel, GetSkyAsset(shaderCompilingLevel.Game), startPos, "SkyBox");
            }

            if (buildMode == EShaderLevelMode.Preview)
            {

                // Static mesh lighting
                AddDominantLight(shaderCompilingLevel);

                // Dynamic mesh lighting
                AddSkyLight(shaderCompilingLevel);
            }

            if (buildMode is EShaderLevelMode.Preview or EShaderLevelMode.Compile)
            {
                startPos.Z = 127; // Helps reduce Zfighting on the bottom face

                // Add static meshes for each material
                // In compile mode we need mesh here still to force it to compile.
                ReportBuildStage($"Adding {portedMats.Count:N0} material actor(s) to the compiler level to force shader permutations.");
                for (var i = 0; i < portedMats.Count; i++)
                {
                    var pMat = portedMats[i];
                    ReportMaterialProgress("add -> compiler actor", i + 1, portedMats.Count, pMat);
                    // Required - if missing, the game will crash when trying to compile, not sure why.
                    AddStaticMeshActorForMaterial(pMat, startPos, buildMode == EShaderLevelMode.Preview);

                    if (buildMode == EShaderLevelMode.Preview)
                    {
                        var tmPos = new Point3D(startPos);
                        tmPos.X = tmPos.X + 160; // Offset it further cause some materials draw in front weirdly.
                        var textMesh = LevelBuildTools.CreateTextMesh(pMat.FileRef, pMat.ObjectName.Instanced);
                        var textMA = AddStaticMeshActorForMaterial(pMat, tmPos, buildMode == EShaderLevelMode.Preview, textMesh, "Text_", false);
                        // Adjust mesh actor positioning once we figure out what we want...
                    }

                    startPos.Y -= 257; // Helps reduce Z-fighting
                }

                // Each instance needs its own actor for the same reason the materials do: the engine
                // compiles a shader map when something in the level renders with it. An instance's
                // permutation is a separate shader map from its parent's, so placing the parent is
                // not enough to get it compiled.
                if (portedInstances.Count > 0)
                {
                    ReportBuildStage($"Adding {portedInstances.Count:N0} material instance actor(s) to the compiler level to force static permutations.");
                    for (var i = 0; i < portedInstances.Count; i++)
                    {
                        var pMic = portedInstances[i];
                        ReportMaterialProgress("add -> instance actor", i + 1, portedInstances.Count, pMic);
                        AddStaticMeshActorForMaterial(pMic, startPos, buildMode == EShaderLevelMode.Preview, namePrefix: "Inst_");
                        startPos.Y -= 257;
                    }
                }

                // Terrain material resources are generated by ATerrain::PostLoad / CacheResourceShaders,
                // not by static-mesh rendering. The copied actor retains its authored components, layer
                // ordering, weight maps, and per-component masks, which are all inputs to the generated
                // FTerrainMaterialResource cache.
                var terrainPos = new Point3D(startPos) { X = startPos.X + 8192 };
                if (portedTerrains.Count > 0)
                {
                    ReportBuildStage($"Adding {portedTerrains.Count:N0} terrain actor(s) to the compiler level.");
                }
                foreach (var pTerrain in portedTerrains)
                {
                    AddTerrainActorForCompilation(pTerrain, terrainPos);
                    terrainPos.Y -= 8192; // Terrain footprint is much larger than one material's preview mesh.
                }
            }

            ReportBuildStage($"Compiler level assembly complete ({shaderCompilingLevel.Exports.Count:N0} exports).");
            return shaderCompilingLevel;
        }

        /// <summary>
        /// Places a ported terrain into the synthetic compiler level without changing the authored
        /// terrain data that determines its material-resource permutations.
        /// </summary>
        private static ExportEntry AddTerrainActorForCompilation(ExportEntry terrain, Point3D location)
        {
            PathEdUtils.SetLocation(terrain, location);
            terrain.Parent = terrain.FileRef.GetLevel();
            terrain.FileRef.AddToLevelActorsIfNotThere(terrain);
            return terrain;
        }

        /// <summary>
        /// Makes static lighting an explicit ShaderHost compilation invariant. LE1 supplies this
        /// through its class default, but LE3 defaults it off; preserving the source omission would
        /// therefore skip static-lighting shader permutations after the port. Apply it to each
        /// intermediate package because relinking terrain dependencies bypasses the normal root
        /// material loop.
        /// </summary>
        /// <summary>
        /// True when this MaterialInstance owns a static permutation, i.e. the engine will compile a
        /// shader map for it rather than reusing its parent's.
        /// </summary>
        /// <remarks>
        /// Instances without one are deliberately left out of the compile level: they render through
        /// the parent's shader map, which the material loop already compiles, so adding them would be
        /// pure capture cost. The decooker only leaves the flag set when it preserved a real parameter
        /// set (see DecookerShared.PreparePackageForUDKify).
        /// </remarks>
        private static bool HasStaticPermutation(ExportEntry instance) =>
            instance.GetProperty<BoolProperty>("bHasStaticPermutationResource")?.Value == true;

        internal static void EnableStaticLightingForAllMaterials(IMEPackage package)
        {
            foreach (var material in package.Exports.Where(x => x.IsA("Material")))
            {
                material.WriteProperty(new BoolProperty(true, "bUsedWithStaticLighting"));
            }
        }

        private static void AddExistingMeshActor(IMEPackage package, LEXOpenable meshAsset, Point3D location, string name)
        {
            var exp = GetOpenableExport(package, meshAsset);
            if (exp == null)
                throw new Exception("Asset is null");

            EntryExporter.ExportExportToPackage(exp, package, out var sma);
            package.AddToLevelActorsIfNotThere((ExportEntry)sma);
        }

        /// <summary>
        /// Converts a source-style package exports to forced export style
        /// </summary>
        /// <param name="sourcePackage"></param>
        /// <param name="rootName">
        /// Name to give the package object every other export is reparented under. This is the object
        /// name the game matches against the packages it already loaded at boot, so a capture rename
        /// has to be applied here — to the object, not to the file. See
        /// <see cref="CapturePackageNaming"/>.
        /// </param>
        private static void ConvertSourceToForcedExport(IMEPackage sourcePackage, string rootName)
        {
            var fileRefExp = sourcePackage.FindExport(rootName);
            if (fileRefExp == null)
            {
                // A package object under the original name already exists in most decooked packages;
                // rename that one rather than creating a second root and leaving the colliding name
                // in the tree.
                var authoredRoot = sourcePackage.FindExport(sourcePackage.FileNameNoExtension);
                if (authoredRoot is { Parent: null })
                {
                    authoredRoot.ObjectName = rootName;
                }
                else
                {
                    ExportCreator.CreatePackageExport(sourcePackage, rootName);
                }

                fileRefExp = sourcePackage.FindExport(rootName)
                    ?? throw new InvalidOperationException(
                        $"Could not establish package object '{rootName}' in {sourcePackage.FileNameNoExtension}.");
            }

            // Move all root non-forced export objects to forced export
            foreach (var exp in sourcePackage.Exports.Where(x => x.idxLink == 0 && x != fileRefExp && (x.ExportFlags & UnrealFlags.EExportFlags.ForcedExport) == 0))
            {
                if (exp.ObjectName == "SeekFreeShaderCache")
                {
                    // Do not move this object
                    continue;
                }

                exp.idxLink = fileRefExp.UIndex;
            }

            foreach (var exp in sourcePackage.Exports.Where(x => x != fileRefExp))
            {
                exp.ExportFlags |= UnrealFlags.EExportFlags.ForcedExport;
            }
        }

        /// <summary>
        /// Ports an object from a source-style package to a cooked package, pulling in references.
        /// </summary>
        /// <param name="export">Source-style package export</param>
        /// <param name="target">Cooked package target</param>
        public static ExportEntry PortSourceToCooked(ExportEntry export, IMEPackage target)
        {
            var packageCache = new PackageCache();
            var rop = new RelinkerOptionsPackage()
            {
                CustomRelinkUIndex = ConvertToCookedRelink
            };
            EntryExporter.ExportExportToPackage(export, target, out var newEntry, packageCache, rop);
            return newEntry as ExportEntry;
        }

        /// <summary>
        /// Delegate function that performs a relink against a cooked package
        /// </summary>
        /// <param name="importingPcc"></param>
        /// <param name="relinkingExport"></param>
        /// <param name="uIndex"></param>
        /// <param name="propertyName"></param>
        /// <param name="prefix"></param>
        /// <param name="rop"></param>
        /// <param name="result"></param>
        /// <returns></returns>
        private static bool ConvertToCookedRelink(IMEPackage importingPcc, ExportEntry relinkingExport, ref int uIndex, string propertyName, string prefix, RelinkerOptionsPackage rop, out EntryStringPair result)
        {
            result = null;
            var sourceObj = importingPcc.GetEntry(uIndex);
            if (sourceObj is ImportEntry imp)
            {
                if (imp.ClassName == "Class")
                    return false; // We aren't relinking classes here.

                // Attempt source type lookup
                foreach (var sourceFolder in SourceFolders)
                {
                    var sourcePackagePath = Path.Combine(sourceFolder, $"{imp.GetLinker()}.pcc");
                    if (!File.Exists(sourcePackagePath))
                        continue;

                    // Console.WriteLine($@"Attempting to port as export: {imp.InstancedFullPath}");
                    // Source package exists.
                    using var sourcePackage = MEPackageHandler.OpenMEPackage(sourcePackagePath);
                    // Donor packages keep their real name deliberately: the import being satisfied
                    // names them, and these are dependencies we *want* resolved against the game's
                    // own objects. Only the package actually being compiled gets a capture rename.
                    ConvertSourceToForcedExport(sourcePackage, sourcePackage.FileNameNoExtension);
                    var sourceExport = sourcePackage.FindExport(imp.InstancedFullPath, imp.ClassName);
                    if (sourceExport == null)
                        continue;

                    // We found an export version of the object. Port it and use it instead.
                    EntryExporter.ExportExportToPackage(sourceExport, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                    uIndex = portedSourceObj.UIndex;
                    return true;
                }

                if (sourceObj.GetLinker() == "EngineMaterials")
                {
                    // This is a special case: EngineMaterials is not in the source folders (we purposely skip it). It should always be available to the game however; we won't be editing these.
                    return false; // Do not use custom relink
                }

                // The decooked corpus intentionally contains material packages, not every texture
                // source package. A missing source file therefore does not mean a missing game
                // texture. Import the exact LE3 asset before using a shared placeholder: otherwise
                // every absent texture becomes one MissingTexture, distinct samples collapse to one
                // slot, and the captured shader cannot match the shipped bytecode.
                if (sourceObj.ClassName is "Texture2D" or "TextureCube" or "TextureRenderTarget2D" or "TextureFlipBook" or "TextureRenderTargetCube")
                {
                    if (TryPortTextureFromInstalledGame(imp, relinkingExport, ref uIndex, rop))
                        return true;

                    return sourceObj.ClassName switch
                    {
                        "Texture2D" => RelinkMissingTexture2D(imp, relinkingExport, out uIndex, rop),
                        "TextureCube" => RelinkMissingTextureCube(imp, relinkingExport, out uIndex, rop),
                        "TextureRenderTarget2D" => RelinkMissingTextureRenderTarget2D(imp, relinkingExport, out uIndex, rop),
                        "TextureFlipBook" => RelinkMissingTextureFlipbook(imp, relinkingExport, out uIndex, rop),
                        "TextureRenderTargetCube" => RelinkMissingTextureRenderTargetCube(imp, relinkingExport, out uIndex, rop),
                        _ => false,
                    };
                }

                Console.WriteLine($"Unknown source class {imp.InstancedFullPath} ({imp.ClassName})");
            }

            // We don't handle unless it is an import
            return false;
        }

        /// <summary>
        /// Ports the exact installed LE3 texture when its owning package is intentionally absent
        /// from the material-only decooked corpus. This preserves independent texture slots and
        /// format-dependent shader generation without introducing LE1 or ME3 source folders.
        /// </summary>
        private static bool TryPortTextureFromInstalledGame(ImportEntry imp, ExportEntry relinkingExport,
            ref int uIndex, RelinkerOptionsPackage rop)
        {
            var linkerFile = $"{imp.GetLinker()}.pcc";
            if (!MELoadedFiles.GetFilesLoadedInGame(Program.Game).TryGetValue(linkerFile, out var sourcePath))
                return false;

            try
            {
                var sourcePackage = InstalledTexturePackageCache.GetCachedPackage(sourcePath);
                var sourceExport = sourcePackage.FindExport(imp.InstancedFullPath, imp.ClassName);
                if (sourceExport == null)
                    return false;

                EntryExporter.ExportExportToPackage(sourceExport, relinkingExport.FileRef, out var portedSourceObj,
                    customROP: rop);
                uIndex = portedSourceObj.UIndex;
                Console.WriteLine($"Resolved texture from installed LE3: {imp.InstancedFullPath}");
                return true;
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Could not resolve installed texture {imp.InstancedFullPath}: {ex.Message}");
                return false;
            }
        }

        private static bool RelinkMissingTextureRenderTarget2D(ImportEntry imp, ExportEntry relinkingExport, out int uIndex, RelinkerOptionsPackage rop)
        {
            Console.WriteLine($"Using missing texture render target 2D for {imp.InstancedFullPath} ({imp.ClassName})");
            var missingtex = GetMissingTextureRenderTarget2D(imp, relinkingExport.FileRef);
            if (missingtex.FileRef == relinkingExport.FileRef)
            {
                // Already in package
                uIndex = missingtex.UIndex;
            }
            else
            {
                EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                uIndex = portedSourceObj.UIndex;
            }
            return true;
        }

        private static bool RelinkMissingTextureRenderTargetCube(ImportEntry imp, ExportEntry relinkingExport, out int uIndex, RelinkerOptionsPackage rop)
        {
            Console.WriteLine($"Using missing texture render target cube for {imp.InstancedFullPath} ({imp.ClassName})");
            var missingtex = GetMissingTextureRenderTargetCube(imp, relinkingExport.FileRef);
            if (missingtex.FileRef == relinkingExport.FileRef)
            {
                // Already in package
                uIndex = missingtex.UIndex;
            }
            else
            {
                EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                uIndex = portedSourceObj.UIndex;
            }
            return true;
        }

        private static bool RelinkMissingTextureCube(ImportEntry imp, ExportEntry relinkingExport, out int uIndex, RelinkerOptionsPackage rop)
        {
            Console.WriteLine($"Using missing texture cube for {imp.InstancedFullPath} ({imp.ClassName})");
            var missingtex = GetMissingTextureCube(imp, relinkingExport.FileRef);
            if (missingtex.FileRef == relinkingExport.FileRef)
            {
                // Already in package
                uIndex = missingtex.UIndex;
            }
            else
            {
                EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                uIndex = portedSourceObj.UIndex;
            }
            return true;
        }

        private static bool RelinkMissingTexture2D(ImportEntry imp, ExportEntry relinkingExport, out int uIndex, RelinkerOptionsPackage rop)
        {
            Console.WriteLine($"Using missing texture for {imp.InstancedFullPath} ({imp.ClassName})");
            var missingtex = GetMissingTexture(imp, relinkingExport.FileRef);
            if (missingtex.FileRef == relinkingExport.FileRef)
            {
                // Already in package
                uIndex = missingtex.UIndex;
            }
            else
            {
                EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                uIndex = portedSourceObj.UIndex;
            }
            return true;
        }

        private static bool RelinkMissingTextureFlipbook(ImportEntry imp, ExportEntry relinkingExport, out int uIndex, RelinkerOptionsPackage rop)
        {
            Console.WriteLine($"Using missing texture flipbook for {imp.InstancedFullPath} ({imp.ClassName})");
            var missingtex = GetMissingTextureFlipbook(imp, relinkingExport.FileRef);
            if (missingtex.FileRef == relinkingExport.FileRef)
            {
                // Already in package
                uIndex = missingtex.UIndex;
            }
            else
            {
                EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                uIndex = portedSourceObj.UIndex;
            }
            return true;
        }

        private static ExportEntry missingTexturesExport;
        private static ExportEntry GetMissingTexture(ImportEntry imp, IMEPackage targetPackage)
        {
            // Check the fileref on return
            var existingMissingTex = targetPackage.FindExport("MissingTexture", "Texture2D");
            if (existingMissingTex != null)
            {
                return existingMissingTex;
            }

            if (missingTexturesExport == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTexturesExport = Texture2D.CreateTexture(missingTexturesPackage, "MissingTexture", MissingTextureSize, MissingTextureSize, PixelFormat.DXT1, true, null);
                missingTexturesExport.SetForcedExportFlag(false);
                if (!UseMinimalMissingTextures)
                {
                    // CreateTexture already wrote a valid pccUnc blank mip chain; Replace only
                    // exists to paint the visible artwork in, which no compile run ever samples.
                    var t2d = new Texture2D(missingTexturesExport);
                    var im = Image.LoadFromFileMemory(ShaderHost.ExtractResource("MilanShaderHost.missingtexture.png"), 2, PixelFormat.DXT1);
                    t2d.Replace(im, missingTexturesExport.GetProperties(), isPackageStored: true);
                }
                missingTexturesExport.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
            }

            //var parent = CreateParents(missingTexturesExport.FileRef, imp.InstancedFullPath);
            //missingTexturesExport.Parent = parent;
            return missingTexturesExport;
        }

        private static ExportEntry missingTexturesFlipbookExport;
        private static ExportEntry GetMissingTextureFlipbook(ImportEntry imp, IMEPackage targetPackage)
        {
            // Check the fileref on return
            var existingMissingTex = targetPackage.FindExport("MissingTextureFlipbook", "TextureFlipBook");
            if (existingMissingTex != null)
            {
                return existingMissingTex;
            }
            if (missingTexturesFlipbookExport == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                // Named for the class it will become, not the class it is built as. Every other
                // placeholder here already matches its own FindExport above; this one did not, and the
                // mismatch cost more than a dead cache lookup. All of these get ported into the same
                // compiler-level package, so a flipbook placeholder called "MissingTexture" collides
                // there with the Texture2D placeholder of that exact name and a flipbook reference can
                // end up resolved against a plain 2D texture -- which is how a FlipBookSample's
                // sub-image division silently became a default (HANDOFF 24).
                //
                // It is still *created* as a Texture2D so CreateTexture writes a valid mip chain, then
                // re-classed to TextureFlipBook below. That part is deliberate.
                missingTexturesFlipbookExport = Texture2D.CreateTexture(missingTexturesPackage, "MissingTextureFlipbook", MissingTextureSize, MissingTextureSize, PixelFormat.DXT1, true, null);
                missingTexturesFlipbookExport.SetForcedExportFlag(false);

                if (!UseMinimalMissingTextures)
                {
                    var t2d = new Texture2D(missingTexturesFlipbookExport);
                    var im = Image.LoadFromFileMemory(ShaderHost.ExtractResource("MilanShaderHost.missingtexture.png"), 2, PixelFormat.DXT1);
                    t2d.Replace(im, missingTexturesFlipbookExport.GetProperties(), isPackageStored: true);
                }
                missingTexturesFlipbookExport.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
                missingTexturesFlipbookExport.Class = EntryImporter.EnsureClassIsInFile(missingTexturesPackage, "TextureFlipBook", new RelinkerOptionsPackage());

                // Some placeholders
                missingTexturesFlipbookExport.WriteProperty(new IntProperty(8, "HorizontalImages"));
                missingTexturesFlipbookExport.WriteProperty(new IntProperty(8, "VerticalImages"));
                missingTexturesFlipbookExport.WriteProperty(new FloatProperty(20.0f, "FrameRate"));
                missingTexturesFlipbookExport.WriteProperty(new FloatProperty(0.0500000007f, "FrameTime"));
            }

            return missingTexturesFlipbookExport;
        }

        private static ExportEntry missingTextureRenderTarget2DExport;
        private static ExportEntry GetMissingTextureRenderTarget2D(ImportEntry imp, IMEPackage targetPackage)
        {
            // Check the fileref on return
            var existingMissingTex = targetPackage.FindExport("MissingTextureRenderTarget2D", "TextureRenderTarget2D");
            if (existingMissingTex != null)
            {
                return existingMissingTex;
            }

            if (missingTextureRenderTarget2DExport == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTextureRenderTarget2DExport = ExportCreator.CreateExport(missingTexturesPackage, "MissingTextureRenderTarget2D", "TextureRenderTarget2D");
                missingTextureRenderTarget2DExport.SetForcedExportFlag(false);
                missingTextureRenderTarget2DExport.WriteProperty(new IntProperty(1024, "SizeX"));
                missingTextureRenderTarget2DExport.WriteProperty(new IntProperty(1024, "SizeY"));
                missingTextureRenderTarget2DExport.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
            }

            return missingTextureRenderTarget2DExport;
        }

        private static ExportEntry missingTextureRenderTargetCube;
        private static ExportEntry GetMissingTextureRenderTargetCube(ImportEntry imp, IMEPackage targetPackage)
        {
            // Check the fileref on return
            var existingMissingTex = targetPackage.FindExport("MissingTextureRenderTargetCube", "TextureRenderTargetCube");
            if (existingMissingTex != null)
            {
                return existingMissingTex;
            }

            if (missingTextureRenderTargetCube == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTextureRenderTargetCube = ExportCreator.CreateExport(missingTexturesPackage, "MissingTextureRenderTargetCube", "TextureRenderTargetCube");
                missingTextureRenderTargetCube.SetForcedExportFlag(false);
                missingTextureRenderTargetCube.WriteProperty(new IntProperty(256, "SizeX"));
                missingTextureRenderTargetCube.WriteProperty(new EnumProperty("TEXTUREGROUP_Environment_512", "TextureGroup", Program.Game, "LODGroup"));
                missingTextureRenderTargetCube.WriteBinary(new UTextureRenderTarget2D());
                missingTextureRenderTargetCube.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
            }

            return missingTextureRenderTargetCube;
        }

        private static ExportEntry missingTextureCubeExport;
        private static ExportEntry GetMissingTextureCube(ImportEntry imp, IMEPackage targetPackage)
        {
            // Check the fileref on return
            var existingMissingTex = targetPackage.FindExport("MissingTextureCube", "TextureCube");
            if (existingMissingTex != null)
            {
                return existingMissingTex;
            }

            if (missingTextureCubeExport == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTextureCubeExport = ExportCreator.CreateExport(missingTexturesPackage, "MissingTextureCube", "TextureCube", indexed: false);
                var props = missingTextureCubeExport.GetProperties();

                // Make the face of a cube
                for (int i = 0; i < 6; i++)
                {
                    var tex = Texture2D.CreateTexture(missingTexturesPackage, $"CubemapFace{i}", MissingTextureSize, MissingTextureSize, PixelFormat.DXT1, true, missingTextureCubeExport);
                    if (!UseMinimalMissingTextures)
                    {
                        var t2d = new Texture2D(tex);
                        var im = Image.LoadFromFileMemory(ShaderHost.ExtractResource("MilanShaderHost.missingtexture.png"), 2, PixelFormat.DXT1);
                        t2d.Replace(im, tex.GetProperties(), isPackageStored: true);
                    }
                    tex.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
                    string propName = i switch
                    {
                        0 => "FacePosX",
                        1 => "FacePosY",
                        2 => "FaceNegX",
                        3 => "FaceNegY",
                        4 => "FacePosZ",
                        5 => "FaceNegZ",
                        _ => "Blorbo"
                    };
                    props.Add(new ObjectProperty(tex, propName));
                }

                props.Add(new BoolProperty(true, "CompressionNone"));
                props.Add(new EnumProperty("TEXTUREGROUP_Environment_512", "TextureGroup", Program.Game, "LODGroup"));
                missingTextureCubeExport.WriteProperties(props);
                missingTextureCubeExport.WriteBinary(new UTextureCube());
            }

            return missingTextureCubeExport;
        }

        private static IEntry CreateParents(IMEPackage package, string ifp)
        {
            var pieces = ifp.Split('.').ToList();
            pieces.RemoveAt(pieces.Count - 1);

            IEntry parent = null;
            foreach (var piece in pieces)
            {
                var tifp = parent?.InstancedFullPath;
                if (tifp != null) tifp += ".";
                tifp += piece;

                var tparent = package.FindExport(tifp, "Package");
                if (parent == null)
                {
                    parent = package.CreatePackageExport(piece, parent);
                }
                else
                {
                    parent = tparent;
                }
            }

            return parent;
        }

        /// <summary>
        /// Required for level to load
        /// </summary>
        /// <param name="package"></param>
        /// <param name="loc">Where to place the start position</param>
        private static void AddPlayerStart(IMEPackage package, Point3D loc)
        {
            var level = package.GetLevel();
            ExportEntry startLoc = null;
            if (package.Game is MEGame.LE1 or MEGame.LE2)
            {
                startLoc = ExportCreator.CreateExport(package, "PlayerStart", "PlayerStart", level, createWithStack: true);

                // Start locations are done via looking at navigation. BioStartLocation exists, but it doesn't work for map load.
                var levelBin = package.GetLevelBinary();
                levelBin.NavListStart = startLoc.UIndex;
                levelBin.NavListEnd = startLoc.UIndex;
                level.WriteBinary(levelBin);
            }
            else if (package.Game is MEGame.LE3)
            {
                startLoc = ExportCreator.CreateExport(package, "BioStartLocation", "BioStartLocation", level, createWithStack: true);
            }

            var cylinderComp = SharedMethods.CreateExport(package, "CylinderComponent", "CylinderComponent", startLoc, prePropBinary: new byte[8]); // NetIndex & TemplatedOwnerClass
            cylinderComp.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            cylinderComp.Archetype = GetImportArchetype(package, (startLoc.Class as ImportEntry).GetRootName(), $"Default__{startLoc.ClassName}.CollisionCylinder");

            cylinderComp.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
            startLoc.WriteProperty(new ObjectProperty(cylinderComp, "CollisionComponent"));
            PathEdUtils.SetLocation(startLoc, loc);

            package.AddToLevelActorsIfNotThere(startLoc);
        }

        private static ExportEntry AddStaticMeshActor(IMEPackage package, LEXOpenable meshAsset, Point3D location, string name, LEXOpenable material = null)
        {
            var level = package.GetLevel();
            var meshSMA = ExportCreator.CreateExport(package, name, "StaticMeshActor", level, createWithStack: true);
            PathEdUtils.SetLocation(meshSMA, location);
            var meshSMC = ExportCreator.CreateExport(package, "StaticMeshComponent", "StaticMeshComponent", meshSMA);
            meshSMC.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            meshSMA.WriteProperty(new ObjectProperty(meshSMC, "StaticMeshComponent"));
            meshSMA.WriteProperty(new ObjectProperty(meshSMC, "CollisionComponent"));
            meshSMC.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
            meshSMC.Archetype = GetImportArchetype(package, "Engine", "Default__StaticMeshActor.StaticMeshComponent0");

            var smcb = ObjectBinary.From<StaticMeshComponent>(meshSMC);
            smcb.LODData = new StaticMeshComponentLODInfo[]
            {
                new StaticMeshComponentLODInfo()
                {
                    LightMap = new LightMap()
                    {
                        LightMapType = ELightMapType.LMT_None
                    }
                }
            };
            meshSMC.WriteBinary(smcb);

            var exp = GetOpenableExport(package, meshAsset);
            EntryExporter.ExportExportToPackage(exp, package, out var staticMesh);
            meshSMC.WriteProperty(new ObjectProperty(staticMesh, "StaticMesh"));

            if (material != null)
                SetMaterial(meshSMC, material);


            package.AddToLevelActorsIfNotThere(meshSMA);
            return meshSMA;
        }

        private static ExportEntry GetOpenableExport(IMEPackage package, LEXOpenable meshAsset)
        {
            var loadedFiles = MELoadedFiles.GetFilesLoadedInGame(package.Game);
            if (loadedFiles.TryGetValue(meshAsset.FilePath, out var path))
            {
                using var assetPackage = MEPackageHandler.OpenMEPackage(path);
                return assetPackage.FindExport(meshAsset.EntryPath);
            }
            else
            {
                Debugger.Break();
            }

            return null;
        }

        private static void AddDominantLight(IMEPackage package)
        {
            // Dominant Lights only affect static
            var level = package.GetLevel();
            var dominantLight = ExportCreator.CreateExport(package, "DominantLight", "DominantDirectionalLight", level, createWithStack: true);
            var dominantLightC = ExportCreator.CreateExport(package, "DominantDirectionalLightComponent", "DominantDirectionalLightComponent", dominantLight, prePropBinary: new byte[12]);
            dominantLightC.WriteBinary(LightComponent.Create());

            // Setup actor
            dominantLight.WriteProperty(new ObjectProperty(dominantLightC, "LightComponent"));
            PathEdUtils.SetLocation(dominantLight, new Point3D(0, 0, 150000));

            // Setup component
            dominantLightC.WriteProperty(new FloatProperty(2, "Brightness"));

            PropertyCollection channels = new PropertyCollection();
            channels.Add(new BoolProperty(true, "Static"));
            dominantLightC.WriteProperty(new StructProperty("LightingChannelContainer", channels, "LightingChannels"));

            package.AddToLevelActorsIfNotThere(dominantLight);
        }

        private static void AddSkyLight(IMEPackage package)
        {
            var level = package.GetLevel();
            var skyLight = ExportCreator.CreateExport(package, "SkyLight", "SkyLight", level, createWithStack: true);
            var skyLightC = ExportCreator.CreateExport(package, "SkyLightComponent", "SkyLightComponent", skyLight, prePropBinary: new byte[8]);
            skyLightC.WriteBinary(LightComponent.Create());
            skyLightC.Archetype = GetImportArchetype(package, "Engine", "Default__SkyLight.SkyLightComponent0");

            // Setup actor
            skyLight.WriteProperty(new ObjectProperty(skyLightC, "LightComponent"));
            PathEdUtils.SetLocation(skyLight, new Point3D(0, 0, 100000));

            // Setup component
            skyLightC.WriteProperty(new FloatProperty(1.1f, "Brightness"));

            PropertyCollection channels = new PropertyCollection();
            channels.Add(new BoolProperty(true, "Dynamic"));
            channels.Add(new BoolProperty(true, "CompositeDynamic"));
            skyLightC.WriteProperty(new StructProperty("LightingChannelContainer", channels, "LightingChannels"));

            package.AddToLevelActorsIfNotThere(skyLight);
        }

        /// <summary>
        /// Adds the import for the cube mesh
        /// </summary>
        /// <param name="package"></param>
        private static void AddCubeMesh(IMEPackage package)
        {
            var engineMeshes = ExportCreator.CreatePackageImport(package, "EngineMeshes");
            ImportEntry impPackage = new ImportEntry(package)
            {
                ClassName = "StaticMesh",
                ObjectName = "Cube",
                PackageFile = "Engine",
                Parent = engineMeshes
            };
            package.AddImport(impPackage);
        }

        private static ExportEntry AddStaticMeshActorForMaterial(ExportEntry material, Point3D location, bool setMesh, ExportEntry mesh = null, string namePrefix = "", bool assignMaterials = true)
        {
            var package = material.FileRef;
            var level = package.GetLevel();
            var meshSMA = ExportCreator.CreateExport(package, $"{namePrefix}StaticMeshActor_{material.ObjectName}", "StaticMeshActor", level, createWithStack: true, indexed: false);
            PathEdUtils.SetLocation(meshSMA, location);
            var meshSMC = ExportCreator.CreateExport(package, "StaticMeshComponent", "StaticMeshComponent", meshSMA);
            meshSMC.ObjectFlags |= UnrealFlags.EObjectFlags.Transactional;
            meshSMA.WriteProperty(new ObjectProperty(meshSMC, "StaticMeshComponent"));
            meshSMA.WriteProperty(new ObjectProperty(meshSMC, "CollisionComponent"));
            meshSMC.WriteProperty(new ObjectProperty(0, "ReplacementPrimitive"));
            meshSMC.Archetype = GetImportArchetype(package, "Engine", "Default__StaticMeshActor.StaticMeshComponent0");

            var smcb = ObjectBinary.From<StaticMeshComponent>(meshSMC);
            smcb.LODData = new StaticMeshComponentLODInfo[]
            {
                new StaticMeshComponentLODInfo()
                {
                    LightMap = new LightMap()
                    {
                        LightMapType = ELightMapType.LMT_None
                    }
                }
            };
            meshSMC.WriteBinary(smcb);

            if (setMesh)
            {
                if (mesh != null)
                {
                    // Use passed in mesh.
                    meshSMC.WriteProperty(new ObjectProperty(mesh, "StaticMesh"));
                }
                else
                {
                    var engineMeshes = package.CreatePackageImport("EngineMeshes");
                    var cube = package.CreateImport("StaticMesh", "Cube", engineMeshes);
                    meshSMC.WriteProperty(new ObjectProperty(cube, "StaticMesh"));
                }
            }
            else
            {
                // Null - prevents crashes since we can't actually compile on demand
                meshSMC.WriteProperty(new ObjectProperty(0, "StaticMesh"));
            }
            if (material != null && assignMaterials)
                SetMaterial(meshSMC, material);


            package.AddToLevelActorsIfNotThere(meshSMA);
            return meshSMA;
        }

        /// <summary>
        /// Sets 1 material in the Materials property array for this target
        /// </summary>
        private static void SetMaterial(ExportEntry target, ExportEntry material)
        {
            target.WriteProperty(new ArrayProperty<ObjectProperty>("Materials")
            {
                new ObjectProperty(material)
            });
        }

        /// <summary>
        /// Sets 1 material in the Materials property array for this target
        /// </summary>
        private static void SetMaterial(ExportEntry target, LEXOpenable materialOpenable)
        {
            var exp = GetOpenableExport(target.FileRef, materialOpenable);
            EntryExporter.ExportExportToPackage(exp, target.FileRef, out var portedMat);
            target.WriteProperty(new ArrayProperty<ObjectProperty>("Materials")
            {
                new ObjectProperty(portedMat)
            });
        }

        internal static IEntry GetImportArchetype(IMEPackage package, string packageFile, string ifp)
        {
            IEntry result = package.FindExport($"{packageFile}.{ifp}");
            if (result != null)
                return result;

            var file = $"{packageFile}.pcc";
            var fullPath = Path.Combine(MEDirectories.GetCookedPath(package.Game), file);
            using var lookupPackage = MEPackageHandler.UnsafePartialLoad(fullPath, x => false);
            var entry = lookupPackage.FindExport(ifp) as IEntry;
            if (entry == null)
                Debugger.Break();

            Stack<IEntry> children = new Stack<IEntry>();
            children.Push(entry); // Must port at least the found IFP.
            while (entry.Parent != null && package.FindEntry(entry.ParentInstancedFullPath) == null)
            {
                children.Push(entry.Parent);
                entry = entry.Parent;
            }

            // Create imports from top down.
            var packageEntry = package.FindEntry(packageFile);
            packageEntry ??= (IEntry)ExportCreator.CreatePackageExport(package, packageFile);

            // This doesn't work if the part of the parents already exist.
            var attachParent = packageEntry;
            foreach (var item in children)
            {
                ImportEntry imp = package.FindImport($"{attachParent.InstancedFullPath}.{item.ObjectName.Instanced}");
                if (imp == null)
                {
                    imp = new ImportEntry(item as ExportEntry, packageEntry.UIndex, package);
                    imp.idxLink = attachParent.UIndex;
                    package.AddImport(imp);
                }
                attachParent = imp;
                result = imp;
            }

            return result;
        }
    }
}
