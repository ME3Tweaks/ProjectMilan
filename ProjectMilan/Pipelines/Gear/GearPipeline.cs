using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilanCore;
using ProjectMilanCore.Config.Store;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Gear
{
    /// <summary>
    /// Compiles our new gear classes into one seek free package
    /// </summary>
    internal static class GearPipeline
    {
        private const string LOG_CATEGORY = "MILAN-Gear";

        /// <summary>
        /// Package file containing our game effects
        /// </summary>
        internal const string PackageName = "SFXMilanGear";

        /// <summary>
        /// The gear base class our gear extends
        /// </summary>
        private const string GearBasePackageName = "SFXGameMPContentDLC_Shared_MP";
        private const string GearBaseClassName = "SFXGameEffect_MatchConsumable_Gear";

        /// <summary>
        /// Ported package we decompile the gear base class from
        /// </summary>
        private const string GearBaseDonorFile = "SFXMP4Gear.pcc";

        internal static string SourceFolder => Path.Combine(MilanShared.PipelineRoot, "Gear", "Classes");
        private static string OutputFolder => Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", "Gear");

        private static readonly LocalizedString RegenName = new() {
            [MELocalization.INT] = "Regeneration Module <CUSTOM0>",
        };
        private static readonly LocalizedString RegenDescription = new() {
            [MELocalization.INT] = "Nanite clusters repair tissue damage while you stay out of enemy fire, restoring lost health one segment at a time.\nRegeneration Delay: <CUSTOM0> seconds",
        };

        /// <summary>
        /// List of new gear to compile
        /// </summary>
        internal static readonly List<GearEntry> Gear =
        [
            new()
            {
                ClassName = "SFXGameEffect_MatchConsumable_Gear_Regen",
                PlayerVariable = MilanPlayerVariable.Card_GearRegen,
                Rarity = CardRarity.Rare,
                Pool = Store.StorePools.GoldGear,
                Name = RegenName,
                Description = RegenDescription,
                // Unused vanilla card art, mapped to MP1Images
                Image = "DLC_MPImages.Cards.DLCHealthRegen",
                // Custom0 is shown x100. these are PulseInterval[0..4] in seconds
                // KEEP IN LINE WITH VALUES IN CLASS AND CONFIG!
                Tokens = "Custom0Tokens[0]=0.06f,Custom0Tokens[1]=0.5f,Custom0Tokens[2]=0.04f,Custom0Tokens[3]=0.03f,Custom0Tokens[4]=0.02f",
            },
        ];

        /// <summary>
        /// Throws if a gear entry is a duplicate or has no source file
        /// </summary>
        internal static void ValidateEntries()
        {
            var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var variables = new HashSet<MilanPlayerVariable>();
            foreach (var entry in Gear)
            {
                if (!names.Add(entry.ClassName) || !variables.Add(entry.PlayerVariable))
                {
                    throw new InvalidOperationException($"Duplicate gear registration: {entry.ClassPath}");
                }
                if (!File.Exists(entry.SourcePath))
                {
                    throw new InvalidOperationException($"Gear {entry.ClassPath} has no source file at {entry.SourcePath}");
                }
            }
        }

        public static void RunPipeline()
        {
            ValidateEntries();
            var outputPath = Path.Combine(Directory.CreateDirectory(OutputFolder).FullName, PackageName + ".pcc");

            using var cache = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache(debugName: "Gear package");
            using var package = MEPackageHandler.CreateAndOpenPackage(outputPath, MEGame.LE3);
            package.LECLTagData.ImportHintFiles.Add(MilanShared.MP_STARTUP_FILENAME); // Our gear imports from BIOP_MP_COMMON
            package.LECLTagData.IsPostLoadFile = false;

            // Compile gear classes
            var classes = new List<UnrealScriptCompiler.LooseClassPackage>
            {
                new(GearBasePackageName, [new UnrealScriptCompiler.LooseClass(GearBaseClassName, DecompileGearBase(cache))]),
                new(MilanPackages.SFXGameContentMilan, Gear.Select(e => new UnrealScriptCompiler.LooseClass(e.ClassName, File.ReadAllText(e.SourcePath), e.SourcePath)).ToList()),
            };
            var options = new UnrealScriptOptionsPackage
            {
                Cache = cache,
                MissingObjectResolver = MilanShared.MissingObjectResolverExportsAsImports,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                CustomFileResolver = MilanShared.LE3PackageResolver,
                BaseFilesFileLib = LE3FileLibCache.GetBaseFilesFileLibFor(package),
            };
            MilanLog.Information($"Compiling {Gear.Count} gear class(es) into {PackageName}", customPrefix: LOG_CATEGORY);
            var log = UnrealScriptCompiler.CompileLooseClasses(package, classes, options);
            if (log.HasErrors)
            {
                throw new InvalidOperationException($"Cannot compile {PackageName}: {string.Join(Environment.NewLine, log.AllErrors)}");
            }

            // Unreferenced data gets garbage collected unless the ObjectReferencer lists them
            package.CreateObjectReferencer(false);
            foreach (var classExport in package.Exports.Where(x => x.IsClass))
            {
                classExport.AddToObjectReferencer();
            }

            foreach (var entry in Gear)
            {
                var classExport = package.FindExport(entry.ClassPath) ?? throw new InvalidOperationException($"{PackageName} is missing {entry.ClassPath} after compiling");
                if (!ExtendsLocalGearBase(classExport))
                {
                    throw new InvalidOperationException($"{entry.ClassPath} does not extend {GearBasePackageName}.{GearBaseClassName} in {PackageName}");
                }
                MilanLog.Information($"Compiled {entry.ClassPath}", customPrefix: LOG_CATEGORY);
            }

            package.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            MilanShared.RefreshMilanFiles = true;
            MilanLog.Information($"Saved {outputPath}", customPrefix: LOG_CATEGORY);
        }

        /// <summary>
        /// Whether the class extends the copy of the gear base class in this package, rather than an import of one in a
        /// package that may not be loaded.
        /// </summary>
        private static bool ExtendsLocalGearBase(ExportEntry classExport)
        {
            var basePath = $"{GearBasePackageName}.{GearBaseClassName}";
            for (var current = classExport.SuperClass; current != null; current = (current as ExportEntry)?.SuperClass)
            {
                if (current.InstancedFullPath.CaseInsensitiveEquals(basePath))
                {
                    return current is ExportEntry;
                }
            }
            return false;
        }

        /// <summary>
        /// Source of the gear base class, from our ported copy of it.
        /// </summary>
        private static string DecompileGearBase(PackageCache cache)
        {
            var donor = MilanShared.LE3PackageResolver(GearBaseDonorFile, cache) ?? throw new InvalidOperationException($"Cannot find {GearBaseDonorFile} for the gear base class, has NonStartup run?");
            var baseClass = donor.FindExport($"{GearBasePackageName}.{GearBaseClassName}");
            var options = new UnrealScriptOptionsPackage { Cache = cache, CustomFileResolver = MilanShared.LE3PackageResolver };
            using var library = new FileLib(donor);
            if (!library.Initialize(options))
            {
                // Decompiling still works, it just can't resolve enum names
                MilanShared.LogFailedFileLibInit(library, logCategory: LOG_CATEGORY);
            }
            var (_, text) = UnrealScriptCompiler.DecompileExport(baseClass, library, options);
            return MilanShared.CleanErrorComments(text, out _);
        }
    }

    /// <summary>
    /// A gear item <see cref="GearPipeline"/> adds.
    /// </summary>
    internal sealed record GearEntry
    {
        /// <summary>
        /// Class name; the source is Gear\Classes\&lt;ClassName&gt;.uc.
        /// </summary>
        public required string ClassName { get; init; }

        /// <summary>
        /// Ownership counter (mpplayervariablemappings ID). Saved in player profiles. NEVER CHANGE ONCE ASSIGNED.
        /// </summary>
        public required MilanPlayerVariable PlayerVariable { get; init; }

        /// <summary>
        /// Rarity of the item
        /// </summary>
        public required CardRarity Rarity { get; init; }

        /// <summary>
        /// Store pool the card drops from (SilverGear for uncommon, GoldGear for rare).
        /// </summary>
        public required StorePool Pool { get; init; }

        /// <summary>
        /// Name of the gear item. Ends in " &lt;CUSTOM0&gt;", which is the gear level's roman numeral
        /// </summary>

        public required LocalizedString Name { get; init; }

        /// <summary>
        /// Card description. &lt;CUSTOM0&gt;-&lt;CUSTOM2&gt; show <see cref="Tokens"/> floats x100; &lt;CUSTOM3&gt;-&lt;CUSTOM4&gt; show ints.
        /// </summary>
        public required LocalizedString Description { get; init; }

        /// <summary>
        /// Card image object path. Must be built by ImagePackageBuilder or dynamic load mapped.
        /// </summary>
        public required string Image { get; init; }

        /// <summary>
        /// Per-level description token values, e.g. "Custom0Tokens[0]=0.05f,...". Keep in sync with the class's values
        /// </summary>
        public required string Tokens { get; init; }

        public string ClassPath => $"{MilanPackages.SFXGameContentMilan}.{ClassName}";

        public string SourcePath => Path.Combine(GearPipeline.SourceFolder, ClassName + ".uc");
    }
}
