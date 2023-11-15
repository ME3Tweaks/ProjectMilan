namespace ProjectMilan.Settings
{
    // Settings for d00t's system build
    internal class MilanSettingsd00t : IMilanSettings
    {
        public string OutputPath { get; set; } = @"UNDEFINED"; // Z:\ModLibrary\LE3\Project Milan\MilanOutput
        public bool RunSFXGameMPContentPipeline { get; set; } = true;
    }
}