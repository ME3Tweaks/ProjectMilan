using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal;
using ProjectMilan;
using System.Numerics;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Unreal.ObjectInfo;

namespace ProjectMilanCore
{
    public static class MilanLevelTools
    {

        public static void SetDrawScale3D(ExportEntry export, float x, float y, float z)
        {
            if (export.ClassName.Contains("Component"))
            {
                SetCollectionActorDrawScale3D(export, x, y, z);
            }
            else
            {
                export.WriteProperty(CommonStructs.Vector3Prop(x, y, z, "DrawScale3D"));
            }
        }

        public static void SetLocation(ExportEntry export, float x, float y, float z)
        {
            if (export.ClassName.Contains("Component"))
            {
                SetCollectionActorLocation(export, x, y, z);
            }
            else
            {
                export.WriteProperty(CommonStructs.Vector3Prop(x, y, z, "location"));
            }
        }

        public static void SetLocation(ExportEntry export, Point3D point)
        {
            if (export.ClassName.Contains("Component"))
            {
                SetCollectionActorLocation(export, point.X, point.Y, point.Z);
            }
            else
            {
                export.WriteProperty(CommonStructs.Vector3Prop(point.X, point.Y, point.Z, "location"));
            }
        }

        public static void SetLocation(StructProperty prop, float x, float y, float z)
        {
            prop.GetProp<FloatProperty>("X").Value = x;
            prop.GetProp<FloatProperty>("Y").Value = y;
            prop.GetProp<FloatProperty>("Z").Value = z;
        }

        public static void SetCollectionActorLocation(ExportEntry component, float x, float y, float z, List<ExportEntry> collectionitems = null, ExportEntry collectionactor = null)
        {
            if (collectionactor == null)
            {
                if (!(component.HasParent && component.Parent.ClassName.Contains("CollectionActor")))
                    return;
                collectionactor = (ExportEntry)component.Parent;
            }

            collectionitems ??= LevelTools.GetCollectionItems(collectionactor);

            if (collectionitems?.Count > 0)
            {
                var idx = collectionitems.FindIndex(o => o != null && o.UIndex == component.UIndex);
                if (idx >= 0)
                {
                    var binData = (StaticCollectionActor)ObjectBinary.From(collectionactor);

                    Matrix4x4 m = binData.LocalToWorldTransforms[idx];
                    m.Translation = new Vector3(x, y, z);
                    binData.LocalToWorldTransforms[idx] = m;

                    collectionactor.WriteBinary(binData);
                }
            }
        }

        public static void SetCollectionActorDrawScale3D(ExportEntry component, float x, float y, float z, List<ExportEntry> collectionitems = null, ExportEntry collectionactor = null)
        {
            if (collectionactor == null)
            {
                if (!(component.HasParent && component.Parent.ClassName.Contains("CollectionActor")))
                    return;
                collectionactor = (ExportEntry)component.Parent;
            }

            collectionitems ??= LevelTools.GetCollectionItems(collectionactor);

            if (collectionitems?.Count > 0)
            {
                var idx = collectionitems.FindIndex(o => o != null && o.UIndex == component.UIndex);
                if (idx >= 0)
                {
                    var binData = (StaticCollectionActor)ObjectBinary.From(collectionactor);
                    Matrix4x4 m = binData.LocalToWorldTransforms[idx];
                    var dsd = m.UnrealDecompose();
                    binData.LocalToWorldTransforms[idx] = ActorUtils.ComposeLocalToWorld(dsd.translation, dsd.rotation, new Vector3(x, y, z));
                    collectionactor.WriteBinary(binData);
                }
            }
        }

        public static void RebuildPersistentLevelChildren(ExportEntry pl)
        {
            ExportEntry[] actorsToAdd = pl.FileRef.Exports.Where(exp => exp.Parent == pl && exp.IsA("Actor")).ToArray();
            Level level = ObjectBinary.From<Level>(pl);
            level.Actors.Clear();

            var bwi = pl.FileRef.GetBioWorldInfo();
            level.Actors.Add(bwi.UIndex); // Must be first


            foreach (var actor in actorsToAdd)
            {
                if (actor == bwi)
                    continue; // Already added.
                // Old Wardle code
                //if (vTestOptions != null && (!vTestOptions.debugBuild || !vTestOptions.debugConvertStaticLightingToNonStatic))
                //{
                //    // Don't add things that are in collection actors. 
                //    // In a debug build we want to not use them in a collection actor
                //    // so that they are not static.
                //    var lc = actor.GetProperty<ObjectProperty>("LightComponent");
                //    if (lc != null && pl.FileRef.TryGetUExport(lc.Value, out var lightComp))
                //    {
                //        if (lightComp.Parent != null && lightComp.Parent.ClassName == "StaticLightCollectionActor")
                //            continue; // don't add this one
                //    }
                //}
                //else if (vTestOptions != null && vTestOptions.debugBuild && vTestOptions.debugConvertStaticLightingToNonStatic && actor.ClassName == "StaticLightCollectionActor")
                //{
                //    continue; // Debug builds with debugConvertStaticLightingToNonStatic don't add StaticLightCollectionActor, instead porting over the lights individually.
                //}

                level.Actors.Add(actor.UIndex);
            }

            //if (level.Actors.Count > 1)
            //{

            // BioWorldInfo will always be present
            // or at least, it better be!
            // Slot 2 has to be blank in LE. In ME1 i guess it was a brush.
            level.Actors.Insert(1, 0); // Epic pls
            //}

            pl.WriteBinary(level);
        }

        /// <summary>
        /// Rebuilds the stream levels list for the package
        /// </summary>
        /// <param name="Pcc"></param>
        public static void RebuildStreamingLevels(IMEPackage Pcc, string logCategory)
        {
            MilanLog.Information("Rebuilding streaming levels list", customPrefix: logCategory);

            try
            {
                var levelStreamingKismets = new List<ExportEntry>();
                ExportEntry bioworldinfo = null;
                foreach (ExportEntry exp in Pcc.Exports)
                {
                    switch (exp.ClassName)
                    {
                        case "BioWorldInfo" when exp.ObjectName == "BioWorldInfo":
                            bioworldinfo = exp;
                            continue;
                        case "LevelStreamingKismet" when exp.ObjectName == "LevelStreamingKismet":
                            levelStreamingKismets.Add(exp);
                            continue;
                    }
                }

                levelStreamingKismets = levelStreamingKismets.OrderBy(o => o.GetProperty<NameProperty>("PackageName").ToString()).ToList();
                if (bioworldinfo != null)
                {
                    var streamingLevelsProp =
                        bioworldinfo.GetProperty<ArrayProperty<ObjectProperty>>("StreamingLevels") ??
                        new ArrayProperty<ObjectProperty>("StreamingLevels");

                    streamingLevelsProp.Clear();
                    foreach (ExportEntry exp in levelStreamingKismets)
                    {
                        streamingLevelsProp.Add(new ObjectProperty(exp.UIndex));
                    }

                    bioworldinfo.WriteProperty(streamingLevelsProp);
                }
                else
                {
                    MilanLog.Warning("No BioWorldInfo object found in this file", customPrefix: logCategory);
                }
            }
            catch (Exception ex)
            {
                MilanLog.Exception(ex, "Error setting streaming levels:", customPrefix: logCategory);
            }
        }


        /// <summary>
        /// Takes a filename and converts it to an indexed name. The level name must have a _ in it!!
        /// </summary>
        /// <param name="levelName"></param>
        /// <returns></returns>
        public static NameReference GetLevelFileName(string levelName)
        {
            var name = Path.GetFileNameWithoutExtension(levelName);
            var baseName = name.Substring(0, name.LastIndexOf("_"));
            var suffixStr = name.Substring(name.LastIndexOf("_") + 1);
            if (int.TryParse(suffixStr, out var number))
            {
                return new NameReference(baseName, number + 1);
            }

            return levelName;
        }

        /// <summary>
        /// Sets the game modes on BioWorldInfo
        /// </summary>
        /// <param name="bioP"></param>
        public static void SetupHordeModes(IMEPackage bioP, bool isLobby)
        {
            if (isLobby)
            {
                var mpContent = bioP.FindEntry("SFXGameMPContentDLC_Shared_MP") ??
                                ExportCreator.CreatePackageExport(bioP, "SFXGameMPContentDLC_Shared_MP");
                ImportEntry lobbyMode = new ImportEntry(bioP)
                {
                    ObjectName = "SFXGameInfoMP_Lobby_DLC",
                    idxLink = mpContent.UIndex,
                    ClassName = "Class",
                    PackageFile = "Core"
                };
                bioP.AddImport(lobbyMode);
                bioP.GetBioWorldInfo().WriteProperty(
                    new ArrayProperty<ObjectProperty>("GameTypesSupportedOnThisMap")
                    {
                        new ObjectProperty(lobbyMode),
                    });
            }
            else
            {
                var mpContent = bioP.FindEntry("SFXGameMPContent") ??
                                ExportCreator.CreatePackageExport(bioP, "SFXGameMPContent");

                ImportEntry infoMP = new ImportEntry(bioP)
                {
                    ObjectName = "SFXGameInfoMP",
                    idxLink = mpContent.UIndex,
                    ClassName = "Class",
                    PackageFile = "Core"
                };
                ImportEntry gameTypeHorde = new ImportEntry(bioP)
                {
                    ObjectName = "SFXGameType_Horde_Operation",
                    idxLink = mpContent.UIndex,
                    ClassName = "Class",
                    PackageFile = "Core"
                };
                bioP.AddImport(infoMP);
                bioP.AddImport(gameTypeHorde);
                bioP.GetBioWorldInfo().WriteProperty(
                    new ArrayProperty<ObjectProperty>("GameTypesSupportedOnThisMap")
                    {
                        new ObjectProperty(infoMP),
                        new ObjectProperty(gameTypeHorde)
                    });
            }
        }

        public static void SetMPStartLocations(IMEPackage biop, Vector3 sl)
        {
            for (int i = 0; i < 4; i++)
            {
                var bsl = biop.FindExport($"TheWorld.PersistentLevel.BioStartLocationMP_{i}");
                SetLocation(bsl, sl.X + i * 85, sl.Y, sl.Z); // No idea if this is a good idea. Will fix later. // Mgamerz 08/15/2024
            }
        }
    }
}
