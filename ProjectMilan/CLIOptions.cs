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

        [Option("import-cached-lighting-levels", Separator = ',', HelpText = "With --import-cached-lighting: only these BioP maps (comma separated) instead of every lit level.", Required = false)]
        public IEnumerable<string> ImportCachedLightingLevels { get; set; }

        [Option("bake-lighting", HelpText = "Only re-bake this BioP map's lighting from the pre-bake UDK maps an earlier build kept (--keep-prebake-maps), then exit. Ports and imports nothing; the previous --lightmass bake is backed up to StaticLighting\\Backup.", Required = false)]
        public string BakeLighting { get; set; }

        [Option("bake-lighting-quality", Default = "Medium", HelpText = "Lightmass quality for --bake-lighting (Preview, Medium, High, Production); kept even on a production configuration.", Required = false)]
        public string BakeLightingQuality { get; set; }

        [Option("ue4-indirect-bounces", HelpText = "UE4 Lightmass bakes this run: number of indirect bounces (the maps export 3; 0 bakes direct light only). Overrides every level's setting.", Required = false)]
        public int? UE4IndirectBounces { get; set; }

        [Option("ue4-diffuse-boost-scale", HelpText = "UE4 Lightmass bakes this run: scales every material's DiffuseBoost, i.e. how much light surfaces bounce (the maps export 5). Overrides every level's setting.", Required = false)]
        public float? UE4DiffuseBoostScale { get; set; }

        [Option("ue4-local-indirect-scale", HelpText = "UE4 Lightmass bakes this run: scales point and spot lights' indirect lighting. Overrides every level's setting.", Required = false)]
        public float? UE4LocalIndirectScale { get; set; }

        [Option("ue4-local-brightness-scale", HelpText = "UE4 Lightmass bakes this run: scales point and spot lights' brightness in the lightmaps. Overrides every level's setting.", Required = false)]
        public float? UE4LocalBrightnessScale { get; set; }

        [Option("ue4-local-radius-scale", HelpText = "UE4 Lightmass bakes this run: scales point and spot lights' radius (how far their light reaches) in the lightmaps. Overrides every level's setting.", Required = false)]
        public float? UE4LocalRadiusScale { get; set; }

        [Option("ue4-directional-indirect-scale", HelpText = "UE4 Lightmass bakes this run: scales directional lights' indirect lighting. Overrides every level's setting.", Required = false)]
        public float? UE4DirectionalIndirectScale { get; set; }

        [Option("ue4-environment-color-scale", HelpText = "UE4 Lightmass bakes this run: scales the environment (sky) color. Overrides every level's setting.", Required = false)]
        public float? UE4EnvironmentColorScale { get; set; }

        [Option("ue4-importance-box", Separator = ',', HelpText = "UE4 Lightmass bakes this run: the importance volume as minX,minY,minZ,maxX,maxY,maxZ, instead of the one computed around the gameplay sublevels. Write it as --ue4-importance-box=... when it starts with a minus sign.", Required = false)]
        public IEnumerable<float> UE4ImportanceBox { get; set; }

        [Option("build-vanilla-netindex-cache", HelpText = "Only regenerate Pipelines\\Finalize\\VanillaNetIndex.bin (and VanillaNetIndexOverrides.txt) by scanning every package LE3 loads, from the ME3Tweaks LE3 backup when there is one, then exit. Builds nothing else.", Required = false)]
        public bool BuildVanillaNetIndexCache { get; set; }

        [Option("check-vanilla-netindex-cache", HelpText = "Only load Pipelines\\Finalize\\VanillaNetIndex.bin, validate it against the LE3 source, and print its load time and size, then exit.", Required = false)]
        public bool CheckVanillaNetIndexCache { get; set; }

        [Option("slash-only", HelpText = "Only run the slash stage (Mod Manager builds a base install, we generate the slash manifest) against the existing output mod, then exit. For when slash generation failed and the build has already exited.", Required = false)]
        public bool SlashOnly { get; set; }

        [Option("compare-lighting-me3",HelpText = "Unpacked ME3 folder to read ME3's levels from for --compare-lighting. Defaults to the installed game.", Required = false)]
        public string CompareLightingME3 { get; set; }
    }
}
