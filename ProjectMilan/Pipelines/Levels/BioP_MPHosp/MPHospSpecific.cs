namespace ProjectMilan.Pipelines.Levels.BioP_MPHosp
{
    internal class MPHospSpecific
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public static string[] IgnoredLightingLevels => [
            "BioA_MPHosp" // Empty file
        ];

        public static void PreCorrect(LevelSpecificPipeline pipeline)
        {

        }
    }
}
