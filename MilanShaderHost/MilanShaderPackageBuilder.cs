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

            ConvertSourceToForcedExport(sourceStylePackage);

            List<ExportEntry> portedMats = new List<ExportEntry>();

            // Port materials into transient
            foreach (var mat in sourceStylePackage.Exports.Where(x => x.IsA("Material")))
            {
                var pMat = PortSourceToCooked(mat, transientPackage);
            }

            // Also port materials into the startup level. This should be faster... I hope
            foreach (var mat in transientPackage.Exports.Where(x => x.IsA("Material")))
            {
                var pMat = PortSourceToCooked(mat, startupLevel);
                if (pMat != null)
                {
                    portedMats.Add(pMat);
                }
            }

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

            // If slashing cache level don't put other materials into it
            if (buildMode != EShaderLevelMode.SlashLevel)
            {
                // Load our input package we are building shaders out of
                var sourceStylePackage = MEPackageHandler.OpenMEPackage(sourceStylePath);

                ConvertSourceToForcedExport(sourceStylePackage);


                // Port materials into transient
                foreach (var mat in sourceStylePackage.Exports.Where(x => x.IsA("Material")))
                {
                    var bUsedWithStaticLighting = mat.GetProperty<BoolProperty>("bUsedWithStaticLighting");
                    if (mat.Game == MEGame.LE1 && mat.Game == MEGame.LE3 && bUsedWithStaticLighting == null)
                    {
                        // LE1 sets this to true, LE3 doesn't have it defined (so its false). 
                        // If the mat doesn't explicitly specify, write it here, then port it over.
                        mat.WriteProperty(new BoolProperty(true, "bUsedWithStaticLighting"));
                    }

                    // Custom milan additions for now.
                    mat.WriteProperty(new BoolProperty(true, "bUsedWithStaticLighting"));
                    mat.WriteProperty(new BoolProperty(true, "bUsedWithVectorLightMaps"));
                    mat.WriteProperty(new BoolProperty(true, "bUsedWithSimpleLightMaps"));

                    var pMat = PortSourceToCooked(mat, transientPackage);
                }

                // Also port materials into the compiler level. This should be faster to port... I hope
                foreach (var mat in transientPackage.Exports.Where(x => x.IsA("Material")))
                {
                    // This should already have the bUsedWithStaticLighting set.
                    var pMat = PortSourceToCooked(mat, shaderCompilingLevel);
                    if (pMat != null)
                    {
                        portedMats.Add(pMat);
                    }
                }
            }
            else
            {
                // Force text mesh and material into package for slashing.
                LevelBuildTools.CreateTextMesh(shaderCompilingLevel, "TextMeshMaterialReference");
            }

            // PlayerStart is required or we can't even load into it
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
                foreach (var pMat in portedMats)
                {
                    // Required - if missing, the game will crash when trying to compile, not sure why.
                    AddStaticMeshActorForMaterial(pMat, startPos, buildMode == EShaderLevelMode.Preview);

                    if (buildMode == EShaderLevelMode.Preview)
                    {
                        var textMesh = LevelBuildTools.CreateTextMesh(pMat.FileRef, pMat.ObjectName.Instanced);
                        var textMA = AddStaticMeshActorForMaterial(pMat, startPos, buildMode == EShaderLevelMode.Preview, textMesh, "Text_", false);
                        // Adjust mesh actor positioning once we figure out what we want...
                    }

                    startPos.Y -= 257; // Helps reduce Z-fighting
                }
            }

            return shaderCompilingLevel;
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
        private static void ConvertSourceToForcedExport(IMEPackage sourcePackage)
        {
            if (sourcePackage.FindExport(sourcePackage.FileNameNoExtension) == null)
            {
                ExportCreator.CreatePackageExport(sourcePackage, sourcePackage.FileNameNoExtension);
            }

            var fileRefExp = sourcePackage.FindExport(sourcePackage.FileNameNoExtension);

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

        public static void BootShaderMap()
        {

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

        private static bool ConvertToCookedRelink(IMEPackage importingPcc, ExportEntry relinkingExport, ref int uIndex, string propertyName, string prefix, RelinkerOptionsPackage rop, out EntryStringPair result)
        {
            result = null;
            var sourceObj = importingPcc.GetEntry(uIndex);
            if (sourceObj is ImportEntry imp)
            {
                // Attempt source type lookup
                foreach (var sourceFolder in SourceFolders)
                {
                    var sourcePackagePath = Path.Combine(sourceFolder, $"{imp.GetLinker()}.pcc");
                    if (File.Exists(sourcePackagePath))
                    {
                        // Console.WriteLine($@"Attempting to port as export: {imp.InstancedFullPath}");
                        // Source package exists
                        // todo: Maybe use cache.
                        using var sourcePackage = MEPackageHandler.OpenMEPackage(sourcePackagePath);
                        ConvertSourceToForcedExport(sourcePackage);
                        var sourceExport = sourcePackage.FindExport(imp.InstancedFullPath, imp.ClassName);
                        if (sourceExport != null)
                        {
                            // We found an export version of the object
                            // Port it and use it instead.
                            EntryExporter.ExportExportToPackage(sourceExport, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                            uIndex = portedSourceObj.UIndex;
                            return true;
                        }

                        // Could not find import!
                        if (sourceObj.ClassName == "Texture2D")
                        {
                            Console.WriteLine($"Using missing texture for {imp.InstancedFullPath} ({imp.ClassName})");
                            var missingtex = GetMissingTexture(imp);
                            EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                            uIndex = portedSourceObj.UIndex;
                            return true;
                        }
                        else if (sourceObj.ClassName == "TextureCube")
                        {
                            Console.WriteLine($"Using missing texture cube for {imp.InstancedFullPath} ({imp.ClassName})");
                            var missingtex = GetMissingTextureCube(imp);
                            EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                            uIndex = portedSourceObj.UIndex;
                            return true;
                        }
                        else if (sourceObj.ClassName == "TextureRenderTarget2D")
                        {
                            Console.WriteLine($"Using missing texture render target 2D for {imp.InstancedFullPath} ({imp.ClassName})");
                            var missingtex = GetMissingTextureRenderTarget2D(imp);
                            EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                            uIndex = portedSourceObj.UIndex;
                            return true;
                        }
                        else if (sourceObj.ClassName == "TextureRenderTargetCube")
                        {
                            Console.WriteLine($"Using missing texture render target cube for {imp.InstancedFullPath} ({imp.ClassName})");
                            var missingtex = GetMissingTextureRenderTargetCube(imp);
                            EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                            uIndex = portedSourceObj.UIndex;
                            return true;
                        }
                        else
                        {
                            Console.WriteLine($"Unknown source class {imp.InstancedFullPath} ({imp.ClassName})");
                        }
                    }
                    else
                    {
                        if (sourceObj.ClassName == "Texture2D")
                        {
                            Console.WriteLine($"Using missing texture for {imp.InstancedFullPath} ({imp.ClassName})");
                            var missingtex = GetMissingTexture(imp);
                            EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                            uIndex = portedSourceObj.UIndex;
                            return true;
                        }
                        else if (sourceObj.ClassName == "TextureFlipBook")
                        {
                            Console.WriteLine($"Using missing texture flipbook for {imp.InstancedFullPath} ({imp.ClassName})");
                            var missingtex = GetMissingTextureFlipbook(imp);
                            EntryExporter.ExportExportToPackage(missingtex, relinkingExport.FileRef, out var portedSourceObj, customROP: rop);
                            uIndex = portedSourceObj.UIndex;
                            return true;
                        }
                        else
                        {
                            Console.WriteLine($"Not porting as export: {imp.InstancedFullPath} ({imp.ClassName})");
                        }
                    }
                }
            }

            // We don't handle unless it is an import
            return false;
        }


        private static ExportEntry missingTexturesExport;
        private static ExportEntry GetMissingTexture(ImportEntry imp)
        {
            if (missingTexturesExport == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTexturesExport = Texture2D.CreateTexture(missingTexturesPackage, "MissingTexture", 512, 512, PixelFormat.DXT1, true, null);
                var t2d = new Texture2D(missingTexturesExport);
                var im = Image.LoadFromFileMemory(ShaderHost.ExtractResource("MilanShaderHost.missingtexture.png"), 2, PixelFormat.DXT1);
                t2d.Replace(im, missingTexturesExport.GetProperties(), isPackageStored: true);
                missingTexturesExport.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
            }

            var parent = CreateParents(missingTexturesExport.FileRef, imp.InstancedFullPath);
            missingTexturesExport.Parent = parent;
            return missingTexturesExport;
        }

        private static ExportEntry missingTexturesFlipbookExport;
        private static ExportEntry GetMissingTextureFlipbook(ImportEntry imp)
        {
            if (missingTexturesFlipbookExport == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTexturesFlipbookExport = Texture2D.CreateTexture(missingTexturesPackage, "MissingTexture", 512, 512, PixelFormat.DXT1, true, null);
                var t2d = new Texture2D(missingTexturesFlipbookExport);
                var im = Image.LoadFromFileMemory(ShaderHost.ExtractResource("MilanShaderHost.missingtexture.png"), 2, PixelFormat.DXT1);
                t2d.Replace(im, missingTexturesFlipbookExport.GetProperties(), isPackageStored: true);
                missingTexturesFlipbookExport.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
                missingTexturesFlipbookExport.Class = EntryImporter.EnsureClassIsInFile(missingTexturesPackage, "TextureFlipbook", new RelinkerOptionsPackage());

                // Some placeholders
                missingTexturesFlipbookExport.WriteProperty(new IntProperty(8, "HorizontalImages"));
                missingTexturesFlipbookExport.WriteProperty(new IntProperty(8, "VerticalImages"));
                missingTexturesFlipbookExport.WriteProperty(new FloatProperty(20.0f, "FrameRate"));
                missingTexturesFlipbookExport.WriteProperty(new FloatProperty(0.0500000007f, "FrameTime"));
            }

            var parent = CreateParents(missingTexturesFlipbookExport.FileRef, imp.InstancedFullPath);
            missingTexturesFlipbookExport.Parent = parent;
            return missingTexturesFlipbookExport;
        }

        private static ExportEntry missingTextureRenderTarget2DExport;
        private static ExportEntry GetMissingTextureRenderTarget2D(ImportEntry imp)
        {
            if (missingTextureRenderTarget2DExport == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTextureRenderTarget2DExport = ExportCreator.CreateExport(missingTexturesPackage, "MissingTextureRenderTarget2D", "TextureRenderTarget2D");
                missingTextureRenderTarget2DExport.WriteProperty(new IntProperty(1024, "SizeX"));
                missingTextureRenderTarget2DExport.WriteProperty(new IntProperty(1024, "SizeY"));
                missingTextureRenderTarget2DExport.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
            }

            var parent = CreateParents(missingTextureRenderTarget2DExport.FileRef, imp.InstancedFullPath);
            missingTextureRenderTarget2DExport.Parent = parent;
            return missingTextureRenderTarget2DExport;
        }

        private static ExportEntry missingTextureRenderTargetCube;
        private static ExportEntry GetMissingTextureRenderTargetCube(ImportEntry imp)
        {
            if (missingTextureRenderTargetCube == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTextureRenderTargetCube = ExportCreator.CreateExport(missingTexturesPackage, "MissingTextureRenderTargetCube", "TextureRenderTargetCube");
                missingTextureRenderTargetCube.WriteProperty(new IntProperty(256, "SizeX"));
                missingTextureRenderTargetCube.WriteProperty(new EnumProperty("TEXTUREGROUP_Environment_512", "TextureGroup", Program.Game, "LODGroup"));
                missingTextureRenderTargetCube.WriteBinary(new UTextureRenderTarget2D());
                missingTextureRenderTargetCube.ObjectFlags |= UnrealFlags.EObjectFlags.Standalone; // Keep if unreferenced.
            }

            var parent = CreateParents(missingTextureRenderTargetCube.FileRef, imp.InstancedFullPath);
            missingTextureRenderTargetCube.Parent = parent;
            return missingTextureRenderTargetCube;
        }

        private static ExportEntry missingTextureCubeExport;
        private static ExportEntry GetMissingTextureCube(ImportEntry imp)
        {
            if (missingTextureCubeExport == null)
            {
                var missingTexturesPackage = MEPackageHandler.CreateMemoryEmptyPackage(@"MissingTextures.pcc", Program.Game);

                missingTextureCubeExport = ExportCreator.CreateExport(missingTexturesPackage, "MissingTextureCube", "TextureCube", indexed: false);
                var props = missingTextureCubeExport.GetProperties();

                // Make the face of a cube
                for (int i = 0; i < 6; i++)
                {
                    var tex = Texture2D.CreateTexture(missingTexturesPackage, $"CubemapFace{i}", 512, 512, PixelFormat.DXT1, true, missingTextureCubeExport);
                    var t2d = new Texture2D(tex);
                    var im = Image.LoadFromFileMemory(ShaderHost.ExtractResource("MilanShaderHost.missingtexture.png"), 2, PixelFormat.DXT1);
                    t2d.Replace(im, tex.GetProperties(), isPackageStored: true);
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

            // Parent to match import so it ports across at same path
            var parent = CreateParents(missingTextureCubeExport.FileRef, imp.InstancedFullPath);
            missingTextureCubeExport.Parent = parent;
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
