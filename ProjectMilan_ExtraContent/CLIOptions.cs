using CommandLine;

namespace ProjectMilan_ExtraContent
{
    /// <summary>
    /// Defines command line options for ProjectMilan
    /// </summary>
    internal class CLIOptions
    {
        [Option('c', "config", HelpText = "Specifies which developer configuration to use.", Required = true)]
        public string Config { get; set; } = string.Empty;

        [Option("psaudio-build", HelpText = "Builds the Wwise_Vegas sound bank from Pinnacle Station's LE1 ISACT audio into the given working directory, then exits. Requires Wwise 2019.1.6.7110 (WWISEROOT) and ffmpeg on PATH.")]
        public string PinnacleStationAudioBuild { get; set; }

        [Option("psaudio-report", HelpText = "Scans Pinnacle Station's LE1 ISACT audio and writes a report of what the Wwise_Vegas bank build would produce, then exits without building anything.")]
        public string PinnacleStationAudioReport { get; set; }
    }
}
