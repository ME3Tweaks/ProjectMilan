using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.PhysX;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Levels.BioP_MPHosp
{
    internal class MPHospSpecific : LevelSpecificFixesBase
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public override string[] IgnoredLightingLevels => [
            "BioA_MPHosp" // Empty file
        ];

        public override void PostCorrect(LevelSpecificPipeline pipeline)
        {
            // Reported by Ody
            // Slats at wall of upper right side stairs lets praetorian beam go through
            // Investigation shows th the glass door mesh is missing its simple collision volume,
            // which is used by praetorian beam for collision.
            var package = pipeline.LE3Packages["BioA_MPHosp_100"];
            var panel = package.FindExport("BioS_SolMP.Earth_GlassDoor01", "StaticMesh");
            var mesh = ObjectBinary.From<StaticMesh>(panel);

            // Generate the RB Body setup data
            var hull = CreatePanelHull(mesh.Bounds);
            var body = ExportCreator.CreateExport(package, "RB_BodySetup", "RB_BodySetup", panel, indexed: false);
            body.WritePropertiesAndBinary(new PropertyCollection
            {
                new StructProperty("KAggregateGeom", new PropertyCollection
                {
                    new ArrayProperty<StructProperty>([hull.GetStructProperty()], "ConvexElems")
                }, "AggGeom"),
                new IntProperty(34079762, "PreCachedPhysDataVersion")
            }, RB_BodySetup.Create());

            mesh.BodySetup = body.UIndex;
            var properties = panel.GetProperties();
            properties.AddOrReplaceProp(new ObjectProperty(body, "BodySetup"));
            panel.WritePropertiesAndBinary(properties, mesh);
            MilanLog.Information($"Added simple collision to {panel.InstancedFullPath}", customPrefix: pipeline.LogCategory);
        }

        // Create a basic hull convex element for the given bounds
        private static KConvexElem CreatePanelHull(BoxSphereBounds bounds)
        {
            var min = bounds.Origin - bounds.BoxExtent;
            var max = bounds.Origin + bounds.BoxExtent;
            var hull = new KConvexElem
            {
                VertexData =
                [
                    new(min.X, min.Y, min.Z), new(max.X, min.Y, min.Z),
                    new(max.X, max.Y, min.Z), new(min.X, max.Y, min.Z),
                    new(min.X, min.Y, max.Z), new(max.X, min.Y, max.Z),
                    new(max.X, max.Y, max.Z), new(min.X, max.Y, max.Z)
                ],
                // Unreal's hull winding uses Cross(v2-v0, v1-v0) for outward normals
                FaceTriData =
                [
                    0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6,
                    0, 5, 1, 0, 4, 5, 3, 2, 6, 3, 6, 7,
                    0, 3, 7, 0, 7, 4, 1, 5, 6, 1, 6, 2
                ],
                EdgeDirections = [Vector3.UnitX, Vector3.UnitY, Vector3.UnitZ],
                FaceNormalDirections = [Vector3.UnitX, Vector3.UnitY, Vector3.UnitZ],
                // UE3 stores W = Dot(normal, point)
                FacePlaneData =
                [
                    new(Vector3.UnitX, max.X), new(-Vector3.UnitX, -min.X),
                    new(Vector3.UnitY, max.Y), new(-Vector3.UnitY, -min.Y),
                    new(Vector3.UnitZ, max.Z), new(-Vector3.UnitZ, -min.Z)
                ],
                ElemBox = new Box(min, max)
            };

            for (int i = 0; i < hull.VertexData.Count; i += 4)
            {
                var v = hull.VertexData;
                hull.PermutedVertexData.Add(new(v[i].X, v[i + 1].X, v[i + 2].X, v[i + 3].X));
                hull.PermutedVertexData.Add(new(v[i].Y, v[i + 1].Y, v[i + 2].Y, v[i + 3].Y));
                hull.PermutedVertexData.Add(new(v[i].Z, v[i + 1].Z, v[i + 2].Z, v[i + 3].Z));
            }
            return hull;
        }
    }
}
