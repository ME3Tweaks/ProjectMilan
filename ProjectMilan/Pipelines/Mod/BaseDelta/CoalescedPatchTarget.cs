using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Patches the basegame Coalesced.bin: the result is compiled from Mod/BaseConfig/Coalesced.xml.
    /// This is not a package, so the delta is applied to the raw file bytes.
    /// </summary>
    internal class CoalescedPatchTarget : IBasePatchClass
    {
        public string GameFile => "Coalesced.bin";

        public string Comment => "Basegame Coalesced.bin config";

        public byte[] GetVanillaBytes() => File.ReadAllBytes(BaseDeltaHandler.GetVanillaCookedFilePath(GameFile));

        public byte[] BuildPatchTarget()
        {
            var manifest = Path.Combine(MilanShared.PipelineRoot, @"Mod", @"BaseConfig", @"Coalesced.xml");
            if (!File.Exists(manifest))
            {
                // ConvertToBin silently writes nothing for a missing manifest
                throw new FileNotFoundException($"Coalesced manifest not found: {manifest}");
            }

            MilanLog.Information("Compiling Coalesced.bin", customPrefix: "Milan-Coalesced");
            using var ms = new MemoryStream();
            LegendaryExplorerCore.Coalesced.CoalescedConverter.ConvertToBin(manifest, null, outStream: ms);
            return ms.ToArray();
        }
    }
}
