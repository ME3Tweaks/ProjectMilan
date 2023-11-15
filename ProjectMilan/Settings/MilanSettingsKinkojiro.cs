namespace ProjectMilan.Settings
{
    // Settings for Kinkojiro's system build
    internal class MilanSettingsKinkojiro : IMilanSettings
    {
        public string OutputPath { get; set; } = @"UNDEFINED"; // Z:\ModLibrary\LE3\Project Milan\MilanOutput
        public bool RunSFXGameMPContentPipeline { get; set; } = true;
    }
}