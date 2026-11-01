using LegendaryExplorerCore.Coalesced.Config;
using LegendaryExplorerCore.Coalesced.Xml;
using LegendaryExplorerCore.GameFilesystem;
using LegendaryExplorerCore.Packages;
using ProjectMilan.Pipelines.Mod.BaseDelta;
using ProjectMilanCore;
using ProjectMilanCore.Config.Store;

namespace ProjectMilan.Pipelines.Verify;

internal static class StoreImageVerification
{
    internal static void Verify(string outputModPath)
    {
        var baseEngine = XmlCoalesceAsset.Load(Path.Combine(MilanShared.PipelineRoot, "Mod", "BaseConfig", "BioEngine.xml"));
        var dlc = ConfigAssetBundle.FromSingleFile(MEGame.LE3,
            Path.Combine(outputModPath, "CookedPCConsole", $"Default_{MilanShared.DLC_NAME}.bin"));
        var builtFiles = Directory.EnumerateFiles(outputModPath, "*.pcc", SearchOption.AllDirectories)
            .ToLookup(Path.GetFileName, StringComparer.OrdinalIgnoreCase);
        var shippedBaseFiles = LMPShippedPackages.Files.ToHashSet(StringComparer.OrdinalIgnoreCase);

        IReadOnlySet<string>? LoadTextures(string packageName)
        {
            var fileName = packageName + ".pcc";
            var path = builtFiles[fileName].FirstOrDefault();
            if (path == null && (!shippedBaseFiles.Contains(fileName)
                || !MELoadedFiles.TryGetHighestMountedFile(MEGame.LE3, fileName, out path)))
            {
                return null;
            }
            // Inspect the build and only the LE3 files LMP's base installer copies. An
            // installed LMP package or an unshipped SP asset must not hide missing output.
            using var package = MEPackageHandler.UnsafePartialLoad(path, _ => false);
            return package.Exports.Where(export => export.ClassName == "Texture2D")
                .Select(export => export.InstancedFullPath).ToHashSet(StringComparer.OrdinalIgnoreCase);
        }

        var errors = StoreImageValidator.Validate(baseEngine, dlc.GetAsset("BioEngine"), dlc.GetAsset("BioGame"), LoadTextures);
        if (errors.Count > 0)
        {
            throw new InvalidDataException("Store card image validation failed:\n" + string.Join("\n", errors));
        }
        MilanLog.Information("Verified store card image mappings and Texture2D exports", customPrefix: "MILAN-Verify");
    }
}
