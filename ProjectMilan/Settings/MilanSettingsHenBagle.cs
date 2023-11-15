namespace ProjectMilan.Settings
{
    // Settings for HenBagle's system build
    internal class MilanSettingsHenBagle : IMilanSettings
    {
        public string OutputPath { get; set; } = @"UNDEFINED"; // Z:\ModLibrary\LE3\Project Milan\MilanOutput
        public bool RunSFXGameMPContentPipeline { get; set; } = true;
    }
}