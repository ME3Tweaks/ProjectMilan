using System.Numerics;
using System.Text;
using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UDK;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.Levels;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Research scan comparing the lightmap resolution UDK will bake each static mesh component at against
    /// the resolution BioWare actually baked it at in ME3.
    /// <para/>
    /// UDK resolves a component's resolution as: component override (bOverrideLightMapRes/OverriddenLightMapRes)
    /// -> StaticMesh.LightMapResolution -> DevOptions.StaticLighting.DefaultStaticMeshLightingRes, the last only
    /// if the others come out as 0 (verified in UDK.exe). ME3/LE3 cooked components don't have the override
    /// properties at all - they're editor-only - so any per-component overrides BioWare used were lost at cook
    /// time, and our bakes only ever see the mesh's own LightMapResolution. BioWare's baked lightmaps still
    /// record what they actually used though: the lightmap texture's size times its CoordinateScale is the
    /// region of the atlas the component was allocated, which is the resolution it was baked at.
    /// </summary>
    internal static class LightmapResolutionScan
    {
        private const string LOG_CATEGORY = @"MILAN-LightmapResScan";

        /// <summary>
        /// Resolution BioWare baked a component's LOD0 lightmap at, from its texture-mapped lightmap - or null
        /// if the component has no texture lightmap (vertex lit, unlit, or the texture couldn't be read).
        /// </summary>
        internal static (int Width, int Height)? GetBakedLightmapResolution(StaticMeshComponent smcBin, IMEPackage package)
        {
            if (smcBin.LODData.Length == 0)
                return null;

            (int texture, Vector2 scale) = smcBin.LODData[0].LightMap switch
            {
                LightMap_2D lm2d => ((int)lm2d.Texture1, lm2d.CoordinateScale),
                LightMap_4or6 lm46 => ((int)lm46.Texture1, lm46.CoordinateScale),
                _ => (0, default)
            };

            if (!package.TryGetUExport(texture, out var texExp))
                return null;

            var sizeX = texExp.GetProperty<IntProperty>("SizeX")?.Value ?? 0;
            var sizeY = texExp.GetProperty<IntProperty>("SizeY")?.Value ?? 0;
            if (sizeX == 0 || sizeY == 0)
                return null;

            return ((int)MathF.Round(sizeX * scale.X), (int)MathF.Round(sizeY * scale.Y));
        }

        private sealed record MeshInfo(string Name, int? LightMapResolution, int? LightMapCoordinateIndex, uint NumTexCoords, float SphereRadius);

        private sealed record ComponentRow(string Package, string Component, MeshInfo Mesh, string LightMapType, int? BakedRes, float WorldDiameter)
        {
            /// <summary>Baked resolution / mesh LightMapResolution - above 1 means BioWare baked it higher than UDK will.</summary>
            public float? Ratio => BakedRes is { } b && Mesh?.LightMapResolution is > 0 ? b / (float)Mesh.LightMapResolution.Value : null;
        }

        /// <summary>
        /// Scans the ME3 source packages (BioP + sublevels) of the given maps and writes a per-component CSV
        /// plus a summary to <paramref name="outputFolder"/>.
        /// </summary>
        internal static void Run(IEnumerable<string> bioPs, string outputFolder)
        {
            Directory.CreateDirectory(outputFolder);
            var allRows = new List<ComponentRow>();
            var summary = new StringBuilder();

            foreach (var bioP in bioPs)
            {
                using var me3BioP = MilanShared.GetME3Package($"{bioP}.pcc");
                if (me3BioP == null)
                    continue;

                var mapRows = new List<ComponentRow>();
                mapRows.AddRange(ScanPackage(me3BioP));
                foreach (var subLevel in LevelShared.GetSublevelPackages(me3BioP) ?? [])
                {
                    using var subPackage = MilanShared.GetME3Package($"{subLevel}.pcc");
                    if (subPackage != null)
                        mapRows.AddRange(ScanPackage(subPackage));
                }

                MilanLog.Information($"{bioP}: {mapRows.Count} static mesh components", customPrefix: LOG_CATEGORY);
                summary.AppendLine($"===== {bioP} =====");
                Summarize(mapRows, summary);
                summary.AppendLine();
                allRows.AddRange(mapRows);
            }

            summary.AppendLine("===== ALL MAPS =====");
            Summarize(allRows, summary);

            var csv = new StringBuilder();
            csv.AppendLine("Package,Component,Mesh,MeshLightMapResolution,MeshLightMapCoordinateIndex,MeshNumTexCoords,LightMapType,BakedRes,Ratio,WorldDiameter,MeshTexelsPer100Units,BakedTexelsPer100Units");
            foreach (var r in allRows)
            {
                float? meshDensity = r.Mesh?.LightMapResolution is > 0 && r.WorldDiameter > 0 ? r.Mesh.LightMapResolution.Value / r.WorldDiameter * 100 : null;
                float? bakedDensity = r.BakedRes is { } b && r.WorldDiameter > 0 ? b / r.WorldDiameter * 100 : null;
                csv.AppendLine(string.Join(",", r.Package, r.Component, r.Mesh?.Name, r.Mesh?.LightMapResolution, r.Mesh?.LightMapCoordinateIndex,
                    r.Mesh?.NumTexCoords, r.LightMapType, r.BakedRes, r.Ratio?.ToString("0.00"), r.WorldDiameter.ToString("0"),
                    meshDensity?.ToString("0.00"), bakedDensity?.ToString("0.00")));
            }

            var csvPath = Path.Combine(outputFolder, "LightmapResolutionScan.csv");
            var summaryPath = Path.Combine(outputFolder, "LightmapResolutionScan_Summary.txt");
            File.WriteAllText(csvPath, csv.ToString());
            File.WriteAllText(summaryPath, summary.ToString());
            MilanLog.Information($"Wrote {csvPath} and {summaryPath}", customPrefix: LOG_CATEGORY);
        }

        private static List<ComponentRow> ScanPackage(IMEPackage package)
        {
            var rows = new List<ComponentRow>();
            var meshCache = new Dictionary<int, MeshInfo>();
            var actors = package.GetLevelBinary()?.Actors.ToHashSet() ?? [];

            // Component UIndex -> world transform, for components owned by a StaticMeshCollectionActor
            var collectionTransforms = new Dictionary<int, Matrix4x4>();
            foreach (var sca in package.Exports.Where(x => x.ClassName == "StaticMeshCollectionActor" && actors.Contains(x.UIndex)))
            {
                var scaBin = ObjectBinary.From<StaticMeshCollectionActor>(sca);
                var components = sca.GetProperty<ArrayProperty<ObjectProperty>>("StaticMeshComponents");
                if (components == null)
                    continue;
                for (int i = 0; i < components.Count && i < scaBin.LocalToWorldTransforms.Count; i++)
                    collectionTransforms[components[i].Value] = scaBin.LocalToWorldTransforms[i];
            }

            // Same selection the UDK export uses (ConvertToUDK.PortStaticMeshActors) so the numbers describe
            // what actually gets baked.
            foreach (var smc in package.Exports.Where(x => x.ClassName == "StaticMeshComponent"))
            {
                if (!ConvertToUDK.IsStaticLightingMeshComponent(smc, actors) || smc.Parent is not ExportEntry parent)
                    continue;
                if (smc.GetProperty<ObjectProperty>("StaticMesh") is not { } meshProp || meshProp.Value == 0)
                    continue;

                var mesh = GetMeshInfo(package, meshProp.Value, meshCache);

                float scale;
                if (parent.ClassName == "StaticMeshCollectionActor")
                {
                    if (!collectionTransforms.TryGetValue(smc.UIndex, out var m))
                        continue;
                    var s = m.UnrealDecompose().scale;
                    scale = MathF.Max(MathF.Abs(s.X), MathF.Max(MathF.Abs(s.Y), MathF.Abs(s.Z)));
                }
                else
                {
                    var s3d = parent.GetProperty<StructProperty>("DrawScale3D") is { } s3dProp ? CommonStructs.GetVector3(s3dProp) : Vector3.One;
                    var s = s3d * (parent.GetProperty<FloatProperty>("DrawScale")?.Value ?? 1f);
                    scale = MathF.Max(MathF.Abs(s.X), MathF.Max(MathF.Abs(s.Y), MathF.Abs(s.Z)));
                }

                var smcBin = ObjectBinary.From<StaticMeshComponent>(smc);
                var lightMapType = smcBin.LODData.Length > 0 ? smcBin.LODData[0].LightMap.LightMapType.ToString() : "NoLOD";
                var baked = GetBakedLightmapResolution(smcBin, package);

                rows.Add(new ComponentRow(package.FileNameNoExtension, smc.InstancedFullPath, mesh, lightMapType,
                    baked?.Width, (mesh?.SphereRadius ?? 0) * 2 * scale));
            }

            return rows;
        }

        private static MeshInfo GetMeshInfo(IMEPackage package, int uIndex, Dictionary<int, MeshInfo> cache)
        {
            if (cache.TryGetValue(uIndex, out var info))
                return info;

            if (package.TryGetUExport(uIndex, out var meshExp))
            {
                var bin = ObjectBinary.From<LegendaryExplorerCore.Unreal.BinaryConverters.StaticMesh>(meshExp);
                info = new MeshInfo(meshExp.InstancedFullPath,
                    meshExp.GetProperty<IntProperty>("LightMapResolution")?.Value,
                    meshExp.GetProperty<IntProperty>("LightMapCoordinateIndex")?.Value,
                    bin.LODModels.Length > 0 ? bin.LODModels[0].VertexBuffer.NumTexCoords : 0,
                    bin.Bounds.SphereRadius);
            }
            else
            {
                // Imported mesh - lives in another package; record it but we can't see its settings from here.
                info = new MeshInfo($"[import] {package.GetEntry(uIndex)?.InstancedFullPath}", null, null, 0, 0);
            }

            cache[uIndex] = info;
            return info;
        }

        private static void Summarize(List<ComponentRow> rows, StringBuilder sb)
        {
            sb.AppendLine($"Components: {rows.Count}");

            sb.AppendLine("BioWare LOD0 lightmap type:");
            foreach (var g in rows.GroupBy(x => x.LightMapType).OrderByDescending(g => g.Count()))
                sb.AppendLine($"\t{g.Key,-12}{g.Count()}");

            sb.AppendLine("Mesh LightMapResolution (what UDK bakes at, absent an override):");
            foreach (var g in rows.GroupBy(x => x.Mesh?.LightMapResolution?.ToString() ?? "(absent)").OrderBy(g => int.TryParse(g.Key, out var v) ? v : int.MaxValue))
                sb.AppendLine($"\t{g.Key,-12}{g.Count()}");

            var textured = rows.Where(x => x.BakedRes != null).ToList();
            sb.AppendLine($"BioWare baked resolution ({textured.Count} texture-lit components):");
            foreach (var g in textured.GroupBy(x => BucketPow2(x.BakedRes.Value)).OrderBy(g => g.Key))
                sb.AppendLine($"\t~{g.Key,-11}{g.Count()}");

            var withRatio = textured.Where(x => x.Ratio != null).ToList();
            sb.AppendLine($"Baked / mesh resolution ({withRatio.Count} comparable components):");
            (string Label, Func<float, bool> Match)[] buckets =
            [
                ("< 0.75x", r => r < 0.75f),
                ("0.75-1.25x", r => r is >= 0.75f and < 1.25f),
                ("1.25-2.5x", r => r is >= 1.25f and < 2.5f),
                ("2.5-5x", r => r is >= 2.5f and < 5f),
                (">= 5x", r => r >= 5f),
            ];
            foreach (var (label, match) in buckets)
                sb.AppendLine($"\t{label,-12}{withRatio.Count(x => match(x.Ratio.Value))}");

            var vertexLitWithRes = rows.Count(x => x.BakedRes == null && x.Mesh?.LightMapResolution is > 0);
            sb.AppendLine($"Not texture-lit by BioWare but mesh has a LightMapResolution (UDK will texture-bake these): {vertexLitWithRes}");
            sb.AppendLine($"Imported meshes (settings not visible): {rows.Count(x => x.Mesh?.Name?.StartsWith("[import]") ?? false)}");
        }

        private static int BucketPow2(int v)
        {
            int p = 1;
            while (p * 2 <= v * 1.414f) // nearest power of two, geometric midpoint
                p *= 2;
            return p;
        }
    }
}
