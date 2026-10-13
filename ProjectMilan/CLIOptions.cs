using CommandLine;

namespace ProjectMilan
{
    /// <summary>
    /// Defines command line options for ProjectMilan
    /// </summary>
    internal class CLIOptions
    {
        [Option('c', "config", HelpText = "Specifies which developer configuration to use.", Required = true)]
        public string Config { get; set; } = string.Empty;

        [Option('r', "researchmode", HelpText = "Runs the research mode code path instead of the build path.", Required = false)]
        public bool ResearchMode { get; internal set; }

        [Option("keep-prebake-maps", HelpText = "Keep copies of exported UDK maps before static lighting is built, for debugging.", Required = false)]
        public bool KeepPreBakeMaps { get; set; }

        [Option("compare-lighting", Separator = ',', HelpText = "Only score the built lightmaps of these BioP maps (comma separated) against ME3's, then exit. Builds nothing.", Required = false)]
        public IEnumerable<string> CompareLighting { get; set; }

        [Option("compare-lighting-levels", HelpText = "Levels folder (one subfolder per BioP) for --compare-lighting. Defaults to the output mod's CookedPCConsole\\Levels.", Required = false)]
        public string CompareLightingLevels { get; set; }

        [Option("lightmass", Default = "UE4", HelpText = "Which Lightmass bakes every level: UE3 (UDK's own) or UE4 (through the UdkInj bridge; a level can still opt out of it). Each has its own cached bakes (StaticLighting\\Levels\\UE3 and UE4), and the build writes and imports the ones for the Lightmass named here.", Required = false)]
        public string Lightmass { get; set; }

        [Option("cached-lighting", HelpText = "Don't bake static lighting, even on a production build: import each level's cached --lightmass bake instead.", Required = false)]
        public bool CachedLighting { get; set; }

        [Option("import-cached-lighting", HelpText = "Only import each level's cached --lightmass bake into the level packages already in the output mod, then exit. Builds nothing else; the lightmaps stay package stored (not moved to the Lighting TFC).", Required = false)]
        public bool ImportCachedLighting { get; set; }

        [Option("bake-lighting", HelpText = "Only re-bake this BioP map's lighting from the pre-bake UDK maps an earlier build kept (--keep-prebake-maps), then exit. Ports and imports nothing; the previous --lightmass bake is backed up to StaticLighting\\Backup.", Required = false)]
        public string BakeLighting { get; set; }

        [Option("bake-lighting-quality", Default = "Medium", HelpText = "Lightmass quality for --bake-lighting (Preview, Medium, High, Production); kept even on a production configuration.", Required = false)]
        public string BakeLightingQuality { get; set; }

        [Option("build-vanilla-netindex-cache", HelpText = "Only regenerate Pipelines\\Finalize\\VanillaNetIndex.bin (and VanillaNetIndexOverrides.txt) by scanning every package LE3 loads, from the ME3Tweaks LE3 backup when there is one, then exit. Builds nothing else.", Required = false)]
        public bool BuildVanillaNetIndexCache { get; set; }

        [Option("check-vanilla-netindex-cache", HelpText = "Only load Pipelines\\Finalize\\VanillaNetIndex.bin, validate it against the LE3 source, and print its load time and size, then exit.", Required = false)]
        public bool CheckVanillaNetIndexCache { get; set; }

        [Option("compare-lighting-me3",HelpText = "Unpacked ME3 folder to read ME3's levels from for --compare-lighting. Defaults to the installed game.", Required = false)]
        public string CompareLightingME3 { get; set; }
    }
}
