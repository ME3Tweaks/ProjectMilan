namespace ProjectMilan.Settings
{
    // Settings for Mgamerz' system build
    internal class MilanSettingsMgamerz : IMilanSettings
    {
        public string OutputPath { get; set; } = @"Z:\ModLibrary\LE3\Project Milan\MilanOutput";
        public bool RunSFXGameMPContentPipeline { get; set; } = true;
    }
}
