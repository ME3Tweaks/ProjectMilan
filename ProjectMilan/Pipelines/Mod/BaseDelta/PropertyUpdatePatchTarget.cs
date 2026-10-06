using LegendaryExplorerCore.Packages;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Applies only BaseDelta PropertyUpdate files (e.g. replacement SWFs) to a vanilla package - no UnrealScript,
    /// so no FileLib. Unlike <see cref="ScriptPackagePatchTarget"/> this is not a global package cache target: it's
    /// for packages outside FilesSafeToImportFrom (which the cache never visits), and nothing downstream imports
    /// from them, so it is built directly and only ships as a MilanDelta patch.
    /// </summary>
    internal class PropertyUpdatePatchTarget : IBasePatchClass
    {
        private readonly string packageName;
        private readonly Action? preBuild;

        /// <param name="preBuild">
        /// Optional step that generates the PropertyUpdate inputs. Like <see cref="ScriptPackagePatchTarget"/>'s, it
        /// is skipped when the target is restored from its checkpointed patch.
        /// </param>
        public PropertyUpdatePatchTarget(string packageName, string comment, Action? preBuild = null)
        {
            this.packageName = packageName;
            Comment = comment;
            this.preBuild = preBuild;
        }

        public string GameFile => $"{packageName}.pcc";

        public string Comment { get; }

        public byte[] GetVanillaBytes()
        {
            // Same compression state as BuildPatchTarget's output, so JDiff compares aligned layouts.
            using var vanillaPackage = MEPackageHandler.OpenMEPackage(BaseDeltaHandler.GetVanillaCookedFilePath(GameFile));
            return vanillaPackage.SaveToStream(BaseDeltaHandler.UseCompressedPackages).ToArray();
        }

        public byte[] BuildPatchTarget()
        {
            preBuild?.Invoke();

            using var package = MEPackageHandler.OpenMEPackage(BaseDeltaHandler.GetVanillaCookedFilePath(GameFile));
            var baseDeltaFolder = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"BaseDelta", packageName);
            ScriptPackagePatchTarget.ApplyPropertyUpdates(package, baseDeltaFolder, packageName, $"Milan-{packageName}");
            return package.SaveToStream(BaseDeltaHandler.UseCompressedPackages).ToArray();
        }
    }
}
