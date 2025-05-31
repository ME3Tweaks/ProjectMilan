using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Pathing;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using System.Numerics;

namespace MilanShaderHost.LEX
{
    public static class PathEdUtils
    {
        public static List<ExportEntry> GetCollectionItems(ExportEntry smac)
        {
            var collectionItems = new List<ExportEntry>();
            var smacItems = smac.GetProperty<ArrayProperty<ObjectProperty>>(smac.ClassName == "StaticMeshCollectionActor" ? "StaticMeshComponents" : "LightComponents");
            if (smacItems != null)
            {
                //Read exports...
                foreach (ObjectProperty obj in smacItems)
                {
                    if (obj.Value > 0)
                    {
                        ExportEntry item = smac.FileRef.GetUExport(obj.Value);
                        collectionItems.Add(item);
                    }
                    else
                    {
                        //this is a blank entry, or an import, somehow.
                        collectionItems.Add(null);
                    }
                }
                return collectionItems;
            }
            return null;
        }

        public static void SetCollectionActorLocation(ExportEntry component, float x, float y, float z, List<ExportEntry> collectionitems = null, ExportEntry collectionactor = null)
        {
            if (collectionactor == null)
            {
                if (!(component.HasParent && component.Parent.ClassName.Contains("CollectionActor")))
                    return;
                collectionactor = (ExportEntry)component.Parent;
            }

            collectionitems ??= GetCollectionItems(collectionactor);

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
    }
}
