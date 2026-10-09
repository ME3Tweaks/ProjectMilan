using System.Numerics;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// The Lightmass importance volume a map's UE4 bake uses: the static meshes of its gameplay sublevels, plus a margin.
    /// </summary>
    /// <remarks>
    /// Cooking strips BioWare's LightmassImportanceVolumes, so the exported UDK maps have none. UE3 Lightmass copes, but
    /// UE4 then sizes the scene from every mesh, vistas and skyboxes included, and spreads a capped photon budget over
    /// all of it. On Thessia the scene radius came out ~250,000 units, both photon passes hit the 40M cap, and
    /// interiors lit by bounced light baked at a fraction of ME3's (UdkInj docs/LIGHTING_CALIBRATION_EXPERIMENTS.md).
    /// The bridge only adds this box when the scene has no importance volume of its own.
    /// </remarks>
    internal static class GameplayImportanceVolume
    {
        private const string LOG_CATEGORY = "MILAN-StaticLightingCompute";

        /// <summary>
        /// Points further than this many interquartile ranges outside the middle half on any axis are dropped, so
        /// one stray mesh far from the playable area doesn't stretch the box.
        /// </summary>
        private const float OutlierIQRs = 3f;

        /// <summary>
        /// Computes the box from the map's exported .udk files in <paramref name="mapFolder"/>, skipping vista
        /// sublevels; null if they hold no static meshes.
        /// </summary>
        public static (Vector3 Min, Vector3 Max)? Compute(string mapFolder, float margin)
        {
            var points = new List<Vector3>();
            var used = new List<string>();
            foreach (var file in Directory.GetFiles(mapFolder, "*.udk").Order(StringComparer.OrdinalIgnoreCase))
            {
                var name = Path.GetFileNameWithoutExtension(file);
                if (name.Contains("Vista", StringComparison.OrdinalIgnoreCase))
                    continue;
                using var package = MEPackageHandler.OpenMEPackage(file);
                var meshOwners = package.Exports.Where(e => e.ClassName == "StaticMeshComponent" && e.Parent is ExportEntry)
                    .Select(e => e.Parent.UIndex).ToHashSet();
                int before = points.Count;
                foreach (var actor in package.Exports.Where(e => meshOwners.Contains(e.UIndex)))
                {
                    if (actor.GetProperty<StructProperty>("Location") is { } location)
                        points.Add(CommonStructs.GetVector3(location));
                }
                if (points.Count > before)
                    used.Add($"{name} {points.Count - before}");
            }
            if (points.Count == 0)
                return null;

            var (low, high) = OutlierLimits(points);
            var kept = points.Where(p => Vector3.Clamp(p, low, high) == p).ToList();
            var min = kept.Aggregate(new Vector3(float.MaxValue), Vector3.Min) - new Vector3(margin);
            var max = kept.Aggregate(new Vector3(float.MinValue), Vector3.Max) + new Vector3(margin);
            MilanLog.Information($"Importance volume ({min.X:0},{min.Y:0},{min.Z:0})-({max.X:0},{max.Y:0},{max.Z:0}) from {kept.Count} mesh actors " +
                $"({string.Join(", ", used)}); {points.Count - kept.Count} outliers dropped, margin {margin:0}", customPrefix: LOG_CATEGORY);
            return (min, max);
        }

        private static (Vector3 Low, Vector3 High) OutlierLimits(List<Vector3> points)
        {
            Vector3 low = default, high = default;
            for (int axis = 0; axis < 3; axis++)
            {
                var values = points.Select(v => v[axis]).Order().ToArray();
                float q1 = values[values.Length / 4], q3 = values[values.Length * 3 / 4], iqr = q3 - q1;
                low[axis] = q1 - OutlierIQRs * iqr;
                high[axis] = q3 + OutlierIQRs * iqr;
            }
            return (low, high);
        }
    }
}
