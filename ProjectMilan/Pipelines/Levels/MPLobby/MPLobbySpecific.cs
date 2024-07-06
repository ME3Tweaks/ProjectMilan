using ProjectMilan.Utility;

namespace ProjectMilan.Pipelines.Levels.MPLobby
{
    internal class MPLobbySpecific
    {
        public static void PreCorrect(LevelSpecificPipeline pipeline)
        {
            var biop = pipeline.ME3BioP;
            var bin = biop.GetLevelBinary();

            for (int i = 0; i < bin.Actors.Count; i++)
            {
                if (biop.TryGetUExport(bin.Actors[i], out var actor))
                {
                    if (actor.ClassName == "PrefabInstance")
                        bin.Actors[i] = 0; // Do not port PrefabInstance currently
                }
            }

            biop.GetLevel().WriteBinary(bin);
        }
    }
}
