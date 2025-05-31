using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Misc;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.Gammtek.Extensions;
using System.Diagnostics;
using LegendaryExplorerCore.Helpers;
using MilanShaderHost.LEX;

namespace MilanShaderHost
{
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

        public static void BuildMapPackage(string packagePath)
        {
            //var outDir = @"S:\Milan\UDK\MilanShaderMapPackages";
            var outDir = @"S:\SteamLibrary\steamapps\common\Mass Effect Legendary Edition\Game\ME3\BioGame\CookedPCConsole";
            var mapName = @"MilanShaderMap_" + Path.GetFileNameWithoutExtension(packagePath) + ".pcc";

            var startupLevel = MEPackageHandler.CreateMemoryEmptyLevel(mapName, MEGame.LE3);

            // Add PlayerStart.

            // Load our input package we are building shaders out of
            var sourceStylePackage = MEPackageHandler.OpenMEPackage(packagePath);

            ConvertSourceToForcedExport(sourceStylePackage);

            List<ExportEntry> portedMats = new List<ExportEntry>();
            foreach (var mat in sourceStylePackage.Exports.Where(x => x.IsA("Material")))
            {
                var pMat = PortSourceToCooked(mat, startupLevel);
                if (pMat != null)
                {
                    portedMats.Add(pMat);
                }
            }

            AddCubeMesh(startupLevel);

            var startPos = new Point3D(0, 0, 1000);
            AddPlayerStart(startupLevel, startPos);

            startPos.Z -= 1000;
            startPos.X += 300;
            startPos.Y += 300;

            AddStaticMeshActor(startupLevel, GetFloorAsset(sourceStylePackage.Game), startPos, "PlayerFloor");

            
            // Static mesh lighting
            AddDominantLight(startupLevel);

            // Dynamic mesh lighting
            AddSkyLight(startupLevel);

            startPos.Z = 0;

            foreach (var pMat in portedMats)
            {
                AddStaticMeshActorForMaterial(pMat, startPos);
                startPos.Y -= 256;
            }


            // Add static meshes that contain our materials.

            startupLevel.Save(Path.Combine(outDir, mapName));
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
                        Console.WriteLine($@"Attempting to port as export: {imp.InstancedFullPath}");
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
                    }
                }
            }

            // We don't handle unless it is an import
            return false;
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

        private static ExportEntry AddStaticMeshActorForMaterial(ExportEntry material, Point3D location)
        {
            var package = material.FileRef;
            var level = package.GetLevel();
            var meshSMA = ExportCreator.CreateExport(package, $"StaticMeshActor_{material.ObjectName}", "StaticMeshActor", level, createWithStack: true);
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

            var cube = package.FindImport("EngineMeshes.Cube");
            meshSMC.WriteProperty(new ObjectProperty(cube, "StaticMesh"));

            if (material != null)
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
            var packageExport = (IEntry)ExportCreator.CreatePackageExport(package, packageFile);

            // This doesn't work if the part of the parents already exist.
            var attachParent = packageExport;
            foreach (var item in children)
            {
                ImportEntry imp = new ImportEntry(item as ExportEntry, packageExport.UIndex, package);
                imp.idxLink = attachParent.UIndex;
                package.AddImport(imp);
                attachParent = imp;
                result = imp;
            }

            return result;
        }
    }
}
