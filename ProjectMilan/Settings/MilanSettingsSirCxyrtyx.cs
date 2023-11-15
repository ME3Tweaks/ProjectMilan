namespace ProjectMilan.Settings
{
    // Settings for SirCxyrtyx's system build
    internal class MilanSettingsSirCxyrtyx : IMilanSettings
    {
        public string OutputPath { get; set; } = @"UNDEFINED"; // Z:\ModLibrary\LE3\Project Milan\MilanOutput
        public bool RunSFXGameMPContentPipeline { get; set; } = true;
    }
}