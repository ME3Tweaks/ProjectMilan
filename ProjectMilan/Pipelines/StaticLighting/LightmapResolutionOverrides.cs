using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.StaticLighting
{
    /// <summary>
    /// Writes per-component lightmap resolution overrides into the UDK maps before they're baked.
    /// <para/>
    /// ME3's cooked StaticMeshComponents don't carry bOverrideLightMapRes/OverriddenLightMapRes (editor-only,
    /// stripped at cook), so every per-component override BioWare set was lost and UDK falls back to the mesh's
    /// LightMapResolution - which for most components BioWare texture-lit is lower than what they actually baked
    /// (see <see cref="LightmapResolutionScan"/>). BioWare's baked lightmaps still record the resolution they
    /// used, so this restores it as a UDK override, never going below what UDK would have used anyway, then
    /// applies a global multiplier on top - scaled back per package to stay under <see cref="MaxTexelsPerPackage"/>.
    /// </summary>
    internal static class LightmapResolutionOverrides
    {
        private const string LOG_CATEGORY = @"MILAN-LightmapRes";

        /// <summary>
        /// Largest resolution we'll ask for - the largest BioWare ever baked a component at in the MP maps.
        /// </summary>
        private const int MaxResolution = 1024;

        /// <summary>
        /// Mesh resolutions below this are treated as placeholders rather than something to scale.
        /// </summary>
        private const int MinResolution = 8;

        /// <summary>
        /// Most lightmap texels (sum of resolution squared over every component) a single package may bake. UDK's
        /// file writer seeks with a signed 32-bit offset (FArchiveFileWriter::Seek -> SetFilePointer with no high
        /// part, verified in UDK.exe), so a map package past 2 GB fails to save with "Error seeking file" - which a
        /// ~124M texel BioA_MPTowr3_200 at 2x did. Uncompressed UDK lightmaps are the bulk of a map package, so
        /// packages whose targets exceed this get their multiplier scaled down until they fit.
        /// </summary>
        private const long MaxTexelsPerPackage = 70_000_000;

        /// <summary>
        /// Computes the resolution each StaticMeshComponent in <paramref name="package"/> should bake at, keyed by
        /// the component's InstancedFullPath (which ConvertToUDK stores in the UDK actor's Tag). Only components
        /// that should differ from what UDK would pick on its own are included.
        /// <para/>
        /// Must run BEFORE ConvertToUDK.GenerateUDKFileForLevel on the same package object: the conversion empties
        /// the source components' binary, which is where BioWare's lightmap lives.
        /// </summary>
        /// <param name="multiplier">Scale applied on top of the restored resolution. Reduced for this package if it would exceed <see cref="MaxTexelsPerPackage"/>.</param>
        /// <param name="defaultResolution">DevOptions.StaticLighting.DefaultStaticMeshLightingRes the bake will use - what UDK uses for a mesh with no LightMapResolution. Already includes <paramref name="multiplier"/>.</param>
        internal static Dictionary<string, int> Compute(IMEPackage package, float multiplier, int defaultResolution, PackageCache cache)
        {
            // The ini default the caller passes is already scaled by the multiplier; restoration works in unscaled
            // (1x) terms so the multiplier is applied exactly once.
            var unscaledDefault = defaultResolution / multiplier;
            var components = new List<(string Path, float Basis, int Current)>();
            var meshResolutions = new Dictionary<int, int?>();
            var actors = package.GetLevelBinary()?.Actors.ToHashSet() ?? [];

            // Same selection ConvertToUDK.PortStaticMeshActors makes, so the texel budget only counts what gets baked.
            foreach (var smc in package.Exports.Where(x => x.ClassName == "StaticMeshComponent"))
            {
                if (smc.Parent is not ExportEntry parent || !actors.Contains(parent.UIndex) || !parent.IsA("StaticMeshActorBase"))
                    continue;
                if ((smc.ObjectFlags & UnrealFlags.EObjectFlags.ArchetypeObject) != 0)
                    continue;
                if (smc.GetProperty<ObjectProperty>("StaticMesh") is not { } meshProp || meshProp.Value == 0)
                    continue;

                if (!meshResolutions.TryGetValue(meshProp.Value, out var meshRes))
                {
                    meshRes = GetMeshLightMapResolution(package, meshProp.Value, cache);
                    meshResolutions[meshProp.Value] = meshRes;
                }

                var baked = LightmapResolutionScan.GetBakedLightmapResolution(ObjectBinary.From<StaticMeshComponent>(smc), package);

                // basis: the 1x resolution this component should have. current: what UDK bakes it at with no override.
                float basis;
                int current;
                if (meshRes is > 0 and < MinResolution && baked == null)
                {
                    continue; // Placeholder mesh resolution, vertex-lit by BioWare - leave alone
                }
                else if (meshRes is > 0)
                {
                    current = meshRes.Value;
                    basis = Math.Max(baked?.Width ?? 0, meshRes.Value);
                }
                else if (meshRes != null)
                {
                    // Absent/0 - UDK falls back to DefaultStaticMeshLightingRes
                    current = defaultResolution;
                    basis = Math.Max(baked?.Width ?? 0, unscaledDefault);
                }
                else if (baked is { } b)
                {
                    // Mesh couldn't be read, so UDK's pick is unknown - BioWare's bake is all we have
                    current = -1;
                    basis = b.Width;
                }
                else
                {
                    continue;
                }

                components.Add((smc.InstancedFullPath, basis, current));
            }

            // Fit the package into the texel budget by shrinking its multiplier if needed.
            var effectiveMultiplier = multiplier;
            var totalTexels = SumTexels(components, multiplier);
            if (totalTexels > MaxTexelsPerPackage)
            {
                // Largest multiplier that fits - texels grow monotonically with the multiplier, so bisect.
                float lo = 0.05f, hi = multiplier;
                for (int i = 0; i < 30; i++)
                {
                    var mid = (lo + hi) / 2;
                    if (SumTexels(components, mid) > MaxTexelsPerPackage) hi = mid; else lo = mid;
                }
                effectiveMultiplier = lo;
                MilanLog.Warning($"{package.FileNameNoExtension}: {totalTexels / 1e6:0}M lightmap texels at x{multiplier} exceeds the {MaxTexelsPerPackage / 1e6:0}M per-package budget; scaling this package to x{effectiveMultiplier:0.00} ({SumTexels(components, effectiveMultiplier) / 1e6:0}M texels)", customPrefix: LOG_CATEGORY);
            }

            var result = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            foreach (var (path, basis, current) in components)
            {
                var target = TargetResolution(basis, effectiveMultiplier);
                if (target != current)
                    result[path] = target;
            }

            return result;
        }

        private static int TargetResolution(float basis, float multiplier) =>
            Math.Clamp((int)MathF.Round(basis * multiplier / 4) * 4, MinResolution, MaxResolution);

        private static long SumTexels(List<(string Path, float Basis, int Current)> components, float multiplier)
        {
            long total = 0;
            foreach (var c in components)
            {
                long r = TargetResolution(c.Basis, multiplier);
                total += r * r;
            }
            return total;
        }

        /// <summary>
        /// Writes the computed overrides onto the StaticMeshComponents of the StaticMeshActors in a converted UDK map.
        /// </summary>
        internal static void Apply(string udkMapPath, Dictionary<string, int> overrides)
        {
            if (overrides == null || overrides.Count == 0)
                return;

            using var udk = MEPackageHandler.OpenUDKPackage(udkMapPath);
            int applied = 0;
            foreach (var sma in udk.Exports.Where(x => x.ClassName == "StaticMeshActor"))
            {
                if (sma.GetProperty<NameProperty>("Tag") is not { } tag || !overrides.TryGetValue(tag.Value.Name, out var resolution))
                    continue;
                if (sma.GetProperty<ObjectProperty>("StaticMeshComponent")?.ResolveToEntry(udk) is not ExportEntry smc)
                    continue;

                // UDK also has bOverrideLightMapResolution/OverriddenLightMapResolution, but those are flagged
                // Deprecated in Engine.u - these are the live ones.
                smc.WriteProperty(new BoolProperty(true, "bOverrideLightMapRes"));
                smc.WriteProperty(new IntProperty(resolution, "OverriddenLightMapRes"));
                applied++;
            }

            if (applied > 0)
                udk.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);

            MilanLog.Information($"{Path.GetFileNameWithoutExtension(udkMapPath)}: applied {applied} lightmap resolution overrides ({overrides.Count} computed)", customPrefix: LOG_CATEGORY);
        }

        private static int? GetMeshLightMapResolution(IMEPackage package, int uIndex, PackageCache cache)
        {
            var meshExp = package.GetEntry(uIndex) switch
            {
                ExportEntry exp => exp,
                ImportEntry imp => EntryImporter.ResolveImport(imp, cache, fileResolver: MilanShared.LE3PackageResolver),
                _ => null
            };

            if (meshExp == null)
                return null;

            return meshExp.GetProperty<IntProperty>("LightMapResolution")?.Value ?? 0;
        }
    }
}
