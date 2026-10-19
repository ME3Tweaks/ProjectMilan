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
        /// <param name="objectPath">Object path to map.</param>
        /// <param name="seekFreePackageName">Package file name the object is in, without its extension.</param>
        /// <param name="replicate">Sets bReplicate, as vanilla does for the classes and archetypes multiplayer players spawn with (weapons, characters).</param>
        public static void RegisterDynamicLoadMapping(string objectPath, string seekFreePackageName, bool replicate = false)
        {
            var engine = MilanPipelinesShared.ConfigBundle.GetAsset("BioEngine");
            var replicateValue = replicate ? ", bReplicate=true" : "";
            engine.GetOrAddSection("sfxgame.sfxengine").AddEntry(new CoalesceProperty("dynamicloadmapping",
                new CoalesceValue($"(ObjectName=\"{objectPath}\", SeekFreePackageName=\"{seekFreePackageName}\"{replicateValue})", CoalesceParseAction.AddUnique)));
        }
    }
}
