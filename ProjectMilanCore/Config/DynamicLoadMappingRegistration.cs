using LegendaryExplorerCore.Coalesced;
using ProjectMilanCore;

namespace ProjectMilanCore.Config
{
    /// <summary>
    /// Writes SFXEngine dynamicloadmapping entries into whichever <see cref="MilanPipelinesShared.ConfigBundle"/>
    /// is currently active. A mapping tells the engine which seek free package file to load when something asks
    /// for an object path it doesn't have in memory - GUI images are referenced by path string only, so this is
    /// how they get found. The object's top level package must be a ForcedExport in the seek free file, and is
    /// named independently of the file (e.g. GUI_MPImages_SMP.Challenge.SoloMstr lives in GUI_MPChallengeImages).
    /// </summary>
    public static class DynamicLoadMappingRegistration
    {
        public static void RegisterDynamicLoadMapping(string objectPath, string seekFreePackageName)
        {
            var engine = MilanPipelinesShared.ConfigBundle.GetAsset("BioEngine");
            engine.GetOrAddSection("sfxgame.sfxengine").AddEntry(new CoalesceProperty("dynamicloadmapping",
                new CoalesceValue($"(ObjectName=\"{objectPath}\", SeekFreePackageName=\"{seekFreePackageName}\")", CoalesceParseAction.AddUnique)));
        }
    }
}
