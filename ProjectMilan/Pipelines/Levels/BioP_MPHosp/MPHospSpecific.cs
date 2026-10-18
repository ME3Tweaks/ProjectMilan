namespace ProjectMilan.Pipelines.Levels.BioP_MPHosp
{
    internal class MPHospSpecific : LevelSpecificFixesBase
    {
        // Map has some extra levels we don't want to include in the lighting bake.
        public override string[] IgnoredLightingLevels => [
            "BioA_MPHosp" // Empty file
        ];
    }
}
