using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Shared
{
    /// <summary>
    /// Replaces the geometry of ported static meshes with fixed copies kept in Shared/UVFixes.
    /// <para/>
    /// Every StaticMesh export in a UVFixes package fixes the mesh at the same instanced path. Only the geometry is taken:
    /// the ported mesh keeps its own materials, BodySetup and everything else that came through the normal port. The
    /// packages are never registered with the object database - as donors every other object in them (materials, physical
    /// materials, Wwise events...) would also replace same-path objects anywhere in the port.
    /// <para/>
    /// If the fixed mesh has the same vertices in the same order, only its vertex buffer (UVs and tangents) is copied and
    /// the components using it are untouched. Otherwise the whole render data is replaced, and each component's painted
    /// vertex colors are remapped onto the new vertices by position, normal and section, since they are indexed by vertex.
    /// </summary>
    internal static class UVFixGraft
    {
        private const string LOG_CATEGORY = @"MILAN-UVFix";

        /// <summary>
        /// Positions closer than this are the same vertex. Fixed meshes come back from a modeling tool, so they don't match bit for bit.
        /// </summary>
        private const float PositionTolerance = 0.01f;

        /// <summary>
        /// A fixed vertex with no old vertex at its position takes the paint of the nearest old vertex within this distance.
        /// </summary>
        private const float NearestPaintDistance = 1f;

        /// <summary>
        /// Packed normal components further apart than this (out of 255) are different normals.
        /// </summary>
        private const int NormalTolerance = 8;

        /// <summary>
        /// Instanced full path of a mesh to the fixed mesh that replaces its geometry
        /// </summary>
        private static readonly Dictionary<string, ExportEntry> FixedMeshes = new(StringComparer.OrdinalIgnoreCase);

        public static string GetUVFixesPath()
        {
            return Path.Combine(MilanShared.PipelineRoot, "Shared", "UVFixes");
        }

        /// <summary>
        /// Opens every UVFixes package and records the meshes it fixes. The packages stay open for the rest of the run.
        /// </summary>
        public static void LoadFixedMeshes()
        {
            FixedMeshes.Clear();
            var fixesPath = Directory.CreateDirectory(GetUVFixesPath()).FullName;
            foreach (var file in Directory.GetFiles(fixesPath, "*.pcc", SearchOption.AllDirectories))
            {
                var package = MEPackageHandler.OpenMEPackage(file);
                foreach (var mesh in package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "StaticMesh"))
                {
                    if (FixedMeshes.TryGetValue(mesh.InstancedFullPath, out var existing))
                    {
                        throw new Exception($"UV fix for {mesh.InstancedFullPath} is in both {Path.GetFileName(existing.FileRef.FilePath)} and {Path.GetFileName(file)}");
                    }

                    FixedMeshes[mesh.InstancedFullPath] = mesh;
                    MilanLog.Information($"Registered UV fix for {mesh.InstancedFullPath} from {Path.GetFileName(file)}", customPrefix: LOG_CATEGORY);
                }
            }
        }

        /// <summary>
        /// Grafts fixed geometry onto every fixed mesh exported in the package. Must run before lighting is imported or exported for the package.
        /// </summary>
        public static void Apply(IMEPackage package, string logCategory)
        {
            if (FixedMeshes.Count == 0)
                return;

            foreach (var import in package.Imports.Where(x => FixedMeshes.ContainsKey(x.InstancedFullPath)))
            {
                // Its geometry comes from wherever the import resolves, which this package can't change
                MilanLog.Warning($"  {package.FileNameNoExtension}: {import.InstancedFullPath} has a UV fix but is imported here, so the fix does not apply to it", customPrefix: logCategory);
            }

            foreach (var meshExp in package.Exports.Where(x => !x.IsDefaultObject && x.ClassName == "StaticMesh").ToList())
            {
                if (!FixedMeshes.TryGetValue(meshExp.InstancedFullPath, out var fixedExp))
                    continue;

                // Parsed fresh each time, as its arrays end up in this package's binary
                GraftMesh(meshExp, fixedExp, ObjectBinary.From<StaticMesh>(fixedExp), logCategory);
            }
        }

        private static void GraftMesh(ExportEntry meshExp, ExportEntry fixedExp, StaticMesh fixedMesh, string logCategory)
        {
            var package = meshExp.FileRef;
            var mesh = ObjectBinary.From<StaticMesh>(meshExp);
            if (mesh.LODModels.Length != fixedMesh.LODModels.Length)
            {
                MilanLog.Error($"  {package.FileNameNoExtension}: UV fix for {meshExp.InstancedFullPath} has {fixedMesh.LODModels.Length} LODs, the mesh has {mesh.LODModels.Length}; not applied", customPrefix: logCategory);
                return;
            }

            for (int i = 0; i < mesh.LODModels.Length; i++)
            {
                if (mesh.LODModels[i].Elements.Length != fixedMesh.LODModels[i].Elements.Length)
                {
                    // Sections are matched by index to keep the ported materials
                    MilanLog.Error($"  {package.FileNameNoExtension}: UV fix for {meshExp.InstancedFullPath} has {fixedMesh.LODModels[i].Elements.Length} sections in LOD {i}, the mesh has {mesh.LODModels[i].Elements.Length}; not applied", customPrefix: logCategory);
                    return;
                }
            }

            if (mesh.LODModels.Zip(fixedMesh.LODModels).All(x => HasSameVertices(x.First, x.Second)))
            {
                for (int i = 0; i < mesh.LODModels.Length; i++)
                {
                    mesh.LODModels[i].VertexBuffer = fixedMesh.LODModels[i].VertexBuffer;
                }

                meshExp.WriteBinary(mesh);
                CopyLightmapProperties(meshExp, fixedExp);
                MilanLog.Information($"  {package.FileNameNoExtension}: grafted fixed UVs onto {meshExp.InstancedFullPath}", customPrefix: logCategory);
                return;
            }

            var oldLODs = mesh.LODModels;
            for (int i = 0; i < fixedMesh.LODModels.Length; i++)
            {
                var fixedLOD = fixedMesh.LODModels[i];
                for (int k = 0; k < fixedLOD.Elements.Length; k++)
                {
                    fixedLOD.Elements[k].Material = oldLODs[i].Elements[k].Material;
                }

                // Source data from the mesh import; cooked meshes don't carry it
                fixedLOD.RawTriangles = [];
            }

            mesh.LODModels = fixedMesh.LODModels;
            mesh.Bounds = fixedMesh.Bounds;
            mesh.kDOPTreeME3UDKLE = fixedMesh.kDOPTreeME3UDKLE;
            meshExp.WriteBinary(mesh);
            CopyLightmapProperties(meshExp, fixedExp);

            var componentCount = 0;
            var paintedCount = 0;
            foreach (var componentExp in package.Exports.Where(x => !x.IsDefaultObject && x.IsA("StaticMeshComponent")))
            {
                if (componentExp.GetProperty<ObjectProperty>("StaticMesh")?.Value != meshExp.UIndex)
                    continue;

                componentCount++;
                if (FixComponent(componentExp, oldLODs, mesh.LODModels))
                    paintedCount++;
            }

            MilanLog.Information($"  {package.FileNameNoExtension}: grafted fixed geometry onto {meshExp.InstancedFullPath} ({string.Join(", ", oldLODs.Zip(mesh.LODModels).Select(x => $"{x.First.NumVertices} -> {x.Second.NumVertices} verts"))}); updated {componentCount} component(s), remapped paint on {paintedCount}", customPrefix: logCategory);
        }

        /// <summary>
        /// True if both LODs have the same vertices in the same order, so anything indexed by vertex stays valid.
        /// </summary>
        private static bool HasSameVertices(StaticMeshRenderData a, StaticMeshRenderData b)
        {
            if (a.NumVertices != b.NumVertices || !a.IndexBuffer.AsSpan().SequenceEqual(b.IndexBuffer))
                return false;

            var positionsA = a.PositionVertexBuffer.VertexData;
            var positionsB = b.PositionVertexBuffer.VertexData;
            for (int i = 0; i < positionsA.Length; i++)
            {
                if (Math.Abs(positionsA[i].X - positionsB[i].X) > PositionTolerance
                    || Math.Abs(positionsA[i].Y - positionsB[i].Y) > PositionTolerance
                    || Math.Abs(positionsA[i].Z - positionsB[i].Z) > PositionTolerance)
                    return false;
            }

            return true;
        }

        private static void CopyLightmapProperties(ExportEntry meshExp, ExportEntry fixedExp)
        {
            // A UV fix can move or add the lightmap channel
            foreach (var propName in new[] { "LightMapCoordinateIndex", "LightMapResolution" })
            {
                if (fixedExp.GetProperty<IntProperty>(propName) is { } prop)
                {
                    meshExp.WriteProperty(new IntProperty(prop.Value, propName));
                }
            }
        }

        /// <summary>
        /// Drops per-vertex data on a component whose mesh changed vertices, and remaps its painted vertex colors. Returns true if it had paint.
        /// </summary>
        private static bool FixComponent(ExportEntry componentExp, StaticMeshRenderData[] oldLODs, StaticMeshRenderData[] newLODs)
        {
            var component = ObjectBinary.From<StaticMeshComponent>(componentExp);
            var painted = false;
            for (int i = 0; i < component.LODData.Length && i < newLODs.Length; i++)
            {
                var lodInfo = component.LODData[i];

                // Vertex lighting is per vertex. Lighting is rebaked for the new geometry anyway.
                lodInfo.ShadowVertexBuffers = [];
                if (lodInfo.LightMap?.LightMapType == ELightMapType.LMT_1D)
                {
                    lodInfo.LightMap = new LightMap { LightMapType = ELightMapType.LMT_None };
                }

                if (lodInfo.bLoadVertexColorData > 0 && lodInfo.OverrideVertexColors?.VertexData != null)
                {
                    lodInfo.OverrideVertexColors = new ColorVertexBuffer
                    {
                        Stride = 4,
                        NumVertices = newLODs[i].NumVertices,
                        VertexData = RemapPaint(lodInfo.OverrideVertexColors.VertexData, oldLODs[i], newLODs[i]),
                    };
                    painted = true;
                }
            }

            componentExp.WriteBinary(component);
            return painted;
        }

        /// <summary>
        /// Moves paint indexed by the old vertices onto the new ones.
        /// <para/>
        /// Each new vertex takes the paint of the old vertices at its position, narrowed to those with the same normal and then
        /// to those in the same section where any are left. Disagreeing candidates are settled by the most common value, then the
        /// lowest old index. Old vertices past the end of the paint buffer get nothing - the game reads zero for them.
        /// </summary>
        /// <typeparam name="TColor">The vertex color struct. Generic only because its assembly is not referenced here; the default value is no paint.</typeparam>
        private static TColor[] RemapPaint<TColor>(TColor[] oldPaint, StaticMeshRenderData oldLOD, StaticMeshRenderData newLOD) where TColor : struct
        {
            var oldPositions = oldLOD.PositionVertexBuffer.VertexData;
            var newPositions = newLOD.PositionVertexBuffer.VertexData;

            var oldByPosition = new Dictionary<(int, int, int), List<int>>();
            for (int v = 0; v < oldPositions.Length; v++)
            {
                var key = PositionKey(oldPositions[v].X, oldPositions[v].Y, oldPositions[v].Z);
                if (!oldByPosition.TryGetValue(key, out var list))
                    oldByPosition[key] = list = [];
                list.Add(v);
            }

            var oldSections = GetVertexSections(oldLOD);
            var newSections = GetVertexSections(newLOD);
            var newPaint = new TColor[newPositions.Length];
            for (int v = 0; v < newPositions.Length; v++)
            {
                var position = newPositions[v];
                if (!oldByPosition.TryGetValue(PositionKey(position.X, position.Y, position.Z), out var candidates))
                {
                    var nearest = FindNearest(oldPositions, position.X, position.Y, position.Z);
                    if (nearest < 0)
                        continue;
                    candidates = [nearest];
                }

                var normal = newLOD.VertexBuffer.VertexData[v].TangentZ;
                var sameNormal = candidates.Where(c => IsSameNormal(oldLOD.VertexBuffer.VertexData[c].TangentZ, normal)).ToList();
                if (sameNormal.Count > 0)
                    candidates = sameNormal;

                var sameSection = candidates.Where(c => oldSections[c] == newSections[v]).ToList();
                if (sameSection.Count > 0)
                    candidates = sameSection;

                // GroupBy keeps first-seen order and OrderByDescending is stable, so ties go to the lowest old index
                var votes = candidates.Where(c => c < oldPaint.Length).OrderBy(c => c).Select(c => oldPaint[c]).GroupBy(x => x).OrderByDescending(x => x.Count()).FirstOrDefault();
                if (votes != null)
                {
                    newPaint[v] = votes.Key;
                }
            }

            return newPaint;
        }

        private static (int, int, int) PositionKey(float x, float y, float z)
        {
            return ((int)MathF.Round(x / PositionTolerance), (int)MathF.Round(y / PositionTolerance), (int)MathF.Round(z / PositionTolerance));
        }

        private static int FindNearest(System.Numerics.Vector3[] positions, float x, float y, float z)
        {
            var nearest = -1;
            var nearestDistanceSquared = NearestPaintDistance * NearestPaintDistance;
            for (int i = 0; i < positions.Length; i++)
            {
                var dx = positions[i].X - x;
                var dy = positions[i].Y - y;
                var dz = positions[i].Z - z;
                var distanceSquared = dx * dx + dy * dy + dz * dz;
                if (distanceSquared <= nearestDistanceSquared)
                {
                    nearest = i;
                    nearestDistanceSquared = distanceSquared;
                }
            }

            return nearest;
        }

        private static bool IsSameNormal(PackedNormal a, PackedNormal b)
        {
            return Math.Abs(a.X - b.X) <= NormalTolerance && Math.Abs(a.Y - b.Y) <= NormalTolerance && Math.Abs(a.Z - b.Z) <= NormalTolerance;
        }

        /// <summary>
        /// Section index of each vertex, from the triangles that use it. -1 for vertices no triangle uses.
        /// </summary>
        private static int[] GetVertexSections(StaticMeshRenderData lod)
        {
            var sections = new int[lod.NumVertices];
            Array.Fill(sections, -1);
            for (int e = 0; e < lod.Elements.Length; e++)
            {
                var element = lod.Elements[e];
                for (uint i = element.FirstIndex; i < element.FirstIndex + element.NumTriangles * 3; i++)
                {
                    var vertex = lod.IndexBuffer[i];
                    if (sections[vertex] < 0)
                        sections[vertex] = e;
                }
            }

            return sections;
        }
    }
}
