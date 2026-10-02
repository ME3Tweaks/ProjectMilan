using CommandLine;
using LegendaryExplorerCore.Packages;

namespace LEDecooker
{
    /// <summary>
    /// Defines command line options for LEDecooker
    /// </summary>
    internal class CLIOptions
    {
        public static CLIOptions ParsedOptions { get; set; }

        [Option('o', "outputfolder", HelpText = "Specifies where decooked game output files should be placed", Required = true)]
        public string CompiledAssetsOutputFolder { get; set; } = string.Empty;

        /// <summary>
        /// Overrides the hardcoded debug package filter for a --compileassets run.
        /// </summary>
        /// <remarks>
        /// Which packages get decooked is otherwise a code-level set that has to be edited and put
        /// back afterwards. That is fine for a planned worklist but poor for the common case of
        /// rebuilding one package because something downstream could not resolve it, which is how
        /// Engine_MI_Shaders was missed: it was excluded by the StartsWith("Engine") rule, so nothing
        /// decooked it and the shader host silently relinked its textures to MissingTextures.
        /// Supplying this leaves the checked-in filter untouched.
        /// </remarks>
        [Option("packages", Separator = ',', HelpText = "Only process these packages (comma separated, no extension) during decook, conversion or normal-compression maintenance. Names are matched case-insensitively.")]
        public IEnumerable<string> Packages { get; set; }

        /// <summary>
        /// Decooks everything rather than the checked-in debug worklist. Takes precedence over
        /// <see cref="Packages"/>.
        /// </summary>
        [Option("allpackages", HelpText = "Decook every package in the source set, ignoring the built-in filter list. This is the full rebuild; it takes hours.")]
        public bool AllPackages { get; set; }

        /// <summary>
        /// Wipes the per-game output folder before the first pass.
        /// </summary>
        /// <remarks>
        /// Decooking is otherwise incremental: an existing output package is reopened and added to, and
        /// AddObjects skips any object already present. That is right for a targeted --packages run, but
        /// it means a full rebuild silently keeps objects from the previous run in whatever state that
        /// run left them -- which is how a full --allpackages decook produced 1,526 packages whose
        /// MaterialInstances still had the static permutations an older build had stripped.
        /// </remarks>
        [Option("clearoutput", HelpText = "Deletes the existing decooked packages for this game before decooking. Use for a full rebuild; without it, objects already present in an output package are left exactly as the previous run wrote them.")]
        public bool ClearOutput { get; set; }

        [Option('c', "compileassets", HelpText = "Compiles T3D (materials) and other assets to decooked packages")]
        public bool CompileAssets { get; set; }


        [Option('m', "udkoutputfolder", HelpText = "Specifies where converted UDK asset files should be placed")]
        public string ConvertedUDKAssetsOutputFolder { get; set; } = string.Empty;

        [Option('u', "convert", HelpText = "Converts decooked assets to UDK asset packages")]
        public bool ConvertAssetsToUDK { get; set; }

        [Option("auditnormalcompression", HelpText = "Read-only normal-compression audit of existing packages; does not decook.")]
        public bool AuditNormalCompression { get; set; }

        [Option("fixnormalcompression", HelpText = "Repair verified enabled normal-compression mismatches in existing packages, with backups; does not decook.")]
        public bool FixNormalCompression { get; set; }

        [Option("normalcompressionpath", HelpText = "Package or flat package folder to audit/repair. Defaults to outputfolder/<game>. Accepts PCC or UPK.")]
        public string? NormalCompressionPath { get; set; }

        [Option("normalcompressionreport", HelpText = "New JSONL report path for the standalone normal-compression audit/repair.")]
        public string? NormalCompressionReport { get; set; }

        [Option("normalcompressionbackup", HelpText = "Backup folder for changed packages. Existing backup files are never overwritten.")]
        public string? NormalCompressionBackup { get; set; }

        [Option("fixnormalsamplers", HelpText = "Re-encode BC5 normal maps bound into three channel normal samplers in an existing UDK folder (normalcompressionpath, or udkoutputfolder/Decooked/<game>); does not convert.")]
        public bool FixNormalSamplers { get; set; }

        [Option('g', "game", HelpText = "Game to run the operation on.", Required = true)]
        public MEGame Game { get; set; }

        [Option("genobjectdb", HelpText = "Regenerates supportfiles/<game>.bin, the ObjectInstanceDB. For ME3 this includes DLC SFAR content. Runs on ME games as well as LE ones.")]
        public bool GenerateObjectDB { get; set; }

        [Option("gensupportfiles", HelpText = "Regenerates every support database for the game (textures, object type lookups, material IFPs and the ObjectInstanceDB) in a single pass over its packages. Runs on ME games as well as LE ones.")]
        public bool GenerateSupportFiles { get; set; }

        [Option("gentexturedb", HelpText = "Regenerates only supportfiles/texturedb_<game>.json, leaving the object instance DB and the other lookup databases alone. Faster than --gensupportfiles because the walk does not need export data.")]
        public bool GenerateTextureDB { get; set; }

        [Option("zipsupportfiles", HelpText = "Rebuilds supportfiles/supportdbs.zip from the loose support files. LEDecooker must be recompiled afterwards, as the zip is an embedded resource.")]
        public bool ZipSupportFiles { get; set; }

    }
}
