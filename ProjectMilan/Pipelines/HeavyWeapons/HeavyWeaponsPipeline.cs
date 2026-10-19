using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using ProjectMilan.Pipelines.Startups;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.HeavyWeapons
{
    /// <summary>
    /// The heavy weapons pipeline copies our pregenerated heavy weapon packages and links them into the game for use.
    /// <para/>
    /// Every .pcc directly in Pipelines\HeavyWeapons is copied to CookedPCConsole\HeavyWeapons. Each consumable heavy
    /// weapon class in them - a concrete <see cref="SFXHeavyWeaponClass"/> subclass whose own classes in the package hold a
    /// <see cref="ConsumablePowerClass"/> property, like SFXWeapon_Heavy_ConsumableRocketLauncher's Power - is dynamic load
    /// mapped to its package and preloaded by every player, so the rocket consumable power can create it by class path, and
    /// gets its name, descriptions and icons set in its BioWeapon section. Every consumable class needs an entry in <see cref="HeavyWeapons"/> for those.
    /// <para/>
    /// Not done yet: the rocket consumable in BIOP_MP_COMMON only creates the class it names itself. It will read the
    /// registered weapons once there is a heavy weapon selection and an identifier to select by.
    /// </summary>
    internal static class HeavyWeaponsPipeline
    {
        private const string LOG_CATEGORY = "MILAN-HeavyWeapons";

        /// <summary>
        /// Every consumable heavy weapon inherits from this.
        /// </summary>
        private const string SFXHeavyWeaponClass = "SFXHeavyWeapon";

        /// <summary>
        /// What makes a heavy weapon a consumable one: a property of this class or a subclass of it, which the weapon finds
        /// the rocket consumable power through to spend its charges.
        /// </summary>
        private const string ConsumablePowerClass = "SFXPowerCustomActionMP_Consumable";

        private static string SourceFolder => Path.Combine(MilanShared.PipelineRoot, "HeavyWeapons");
        private static string OutputFolder => Path.Combine(Program.Settings.OutputModPath, "CookedPCConsole", "HeavyWeapons");

        /// <summary>
        /// Forced export package the heavy weapon icons are built under: images in
        /// Startups\NonStartup\ImagePackages\&lt;any folder&gt;\MilanHeavyWeapons\.
        /// </summary>
        private const string IconPackage = "MilanHeavyWeapons";

        internal static readonly List<HeavyWeaponEntry> HeavyWeapons =
        [
            new()
            {
                // M-490 Blackstorm
                ClassPath = "SFXGameContent_Milan.SFXWeapon_Heavy_ConsumableBlackstorm",
                NonConsumableClassPath = "SFXGameContent_Milan.SFXHeavyWeapon_Blackstorm",
                Name = 361364, // M-490 Blackstorm
                ShortName = new LocalizedString { [MELocalization.INT] = "Blackstorm" },
                Description = 361363,
                ShortDescription = 344479,
                Image = $"{IconPackage}.Blackstorm_512x256", // Needs a source
                NotificationImage = $"{IconPackage}.Blackstorm_256x128", // Needs a source
            },
        ];

        public static void RunPipeline()
        {
            Directory.CreateDirectory(OutputFolder);

            // Class path to the package it is in
            var foundClasses = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var nonConsumableClasses = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var sourcePath in Directory.GetFiles(SourceFolder, "*.pcc", SearchOption.TopDirectoryOnly))
            {
                var packageName = Path.GetFileNameWithoutExtension(sourcePath);
                bool hasConsumable = false;
                using (var package = MEPackageHandler.OpenMEPackage(sourcePath))
                {
                    foreach (var classExport in package.Exports.Where(x => x.IsClass))
                    {
                        var kind = GetHeavyWeaponKind(classExport);
                        if (kind == HeavyWeaponKind.Consumable)
                        {
                            hasConsumable = true;
                            AddFoundClass(foundClasses, classExport.InstancedFullPath, packageName);
                        }
                        else if (kind == HeavyWeaponKind.NonConsumable)
                        {
                            AddFoundClass(nonConsumableClasses, classExport.InstancedFullPath, packageName);
                        }
                    }
                }

                if (!hasConsumable)
                {
                    MilanLog.Warning($"{packageName} has no consumable heavy weapon class, not installing it", customPrefix: LOG_CATEGORY);
                    continue;
                }

                File.Copy(sourcePath, Path.Combine(OutputFolder, Path.GetFileName(sourcePath)), true);
                MilanLog.Information($"Installed {packageName}", customPrefix: LOG_CATEGORY);
            }

            foreach (var (classPath, packageName) in foundClasses)
            {
                var entry = HeavyWeapons.FirstOrDefault(x => x.ClassPath.CaseInsensitiveEquals(classPath));
                if (entry == null)
                {
                    MilanLog.Error($"Consumable heavy weapon {classPath} in {packageName} has no entry in {nameof(HeavyWeaponsPipeline)}.{nameof(HeavyWeapons)} for its strings and icons, so it was not registered", customPrefix: LOG_CATEGORY);
                    continue;
                }
                RegisterHeavyWeapon(entry, packageName, nonConsumableClasses);
            }

            foreach (var entry in HeavyWeapons.Where(x => !foundClasses.ContainsKey(x.ClassPath)))
            {
                MilanLog.Error($"No package in {Path.GetRelativePath(MilanShared.PipelineRoot, SourceFolder)} has the consumable heavy weapon {entry.ClassPath}", customPrefix: LOG_CATEGORY);
            }

            MilanPipelinesShared.CommitConfigBundle();
        }

        private static void AddFoundClass(Dictionary<string, string> foundClasses, string classPath, string packageName)
        {
            if (foundClasses.TryGetValue(classPath, out var otherPackage))
            {
                MilanLog.Error($"{classPath} is in both {otherPackage} and {packageName}", customPrefix: LOG_CATEGORY);
                return;
            }
            foundClasses[classPath] = packageName;
        }

        /// <param name="nonConsumableClasses">Every non-consumable heavy weapon class found, to the package it is in.</param>
        private static void RegisterHeavyWeapon(HeavyWeaponEntry entry, string packageName, Dictionary<string, string> nonConsumableClasses)
        {
            // Weapon classes are replicated, as every MP weapon's mapping is in vanilla
            DynamicLoadMappingRegistration.RegisterDynamicLoadMapping(entry.ClassPath, packageName, replicate: true);

            // Only mapped, which is all the GiveItem console command needs to find it
            if (entry.NonConsumableClassPath != null)
            {
                if (nonConsumableClasses.TryGetValue(entry.NonConsumableClassPath, out var nonConsumablePackage))
                    DynamicLoadMappingRegistration.RegisterDynamicLoadMapping(entry.NonConsumableClassPath, nonConsumablePackage, replicate: true);
                else
                    MilanLog.Error($"{entry.ClassPath}'s {nameof(entry.NonConsumableClassPath)} {entry.NonConsumableClassPath} is not a non-consumable heavy weapon in any installed package", customPrefix: LOG_CATEGORY);
            }

            // Every player loads every heavy weapon before spawning, until each player selects one and
            // SFXPRIMP.GetAsyncLoadingStatus loads just that
            MilanPipelinesShared.ConfigBundle.GetAsset("BioGame").GetOrAddSection("sfxgamempcontent.sfxprimp")
                .AddEntry(new CoalesceProperty("defaultloadclasses", new CoalesceValue(entry.ClassPath, CoalesceParseAction.AddUnique)));

            var name = entry.Name.Resolve();
            var description = entry.Description.Resolve();
            var section = MilanPipelinesShared.ConfigBundle.GetAsset("BioWeapon").GetOrAddSection(entry.ClassPath.ToLowerInvariant());
            SetConfigValue(section, "prettyname", name.ToString());
            SetConfigValue(section, "shortprettyname", (entry.ShortName?.Resolve() ?? name).ToString());
            SetConfigValue(section, "generaldescription", description.ToString());
            SetConfigValue(section, "shortdescription", (entry.ShortDescription?.Resolve() ?? description).ToString());
            SetConfigValue(section, "guiimage", ImagePackageBuilder.Require(entry.Image, $"{entry.ClassPath} GUIImage"));
            SetConfigValue(section, "notificationimage", ImagePackageBuilder.Require(entry.NotificationImage, $"{entry.ClassPath} NotificationImage"));

            MilanLog.Information($"Registered {entry.ClassPath} in {packageName}", customPrefix: LOG_CATEGORY);
        }

        private static void SetConfigValue(CoalesceSection section, string propertyName, string value)
        {
            section.AddEntry(new CoalesceProperty(propertyName, new CoalesceValue(value, CoalesceParseAction.New)));
        }

        private enum HeavyWeaponKind
        {
            None,
            NonConsumable,
            Consumable,
        }

        /// <summary>
        /// Whether <paramref name="classExport"/> is a concrete heavy weapon, and if it spends consumables. Walks its
        /// superclasses in the package, as the class info only knows the game's own classes, until one is
        /// <see cref="SFXHeavyWeaponClass"/> or an import that inherits from it. The <see cref="ConsumablePowerClass"/>
        /// property has to be on one of the package's own classes.
        /// </summary>
        private static HeavyWeaponKind GetHeavyWeaponKind(ExportEntry classExport)
        {
            if (classExport.ObjectName.Name.CaseInsensitiveEquals(SFXHeavyWeaponClass)
                || ObjectBinary.From<UClass>(classExport).ClassFlags.Has(UnrealFlags.EClassFlags.Abstract))
                return HeavyWeaponKind.None;

            bool hasConsumablePower = false;
            IEntry current = classExport;
            while (current != null)
            {
                if (current.ObjectName.Name.CaseInsensitiveEquals(SFXHeavyWeaponClass)
                    || (current is ImportEntry && GlobalUnrealObjectInfo.IsA(current.ObjectName.Name, SFXHeavyWeaponClass, MEGame.LE3)))
                    return hasConsumablePower ? HeavyWeaponKind.Consumable : HeavyWeaponKind.NonConsumable;

                if (current is not ExportEntry currentExport)
                    return HeavyWeaponKind.None;

                hasConsumablePower |= DeclaresConsumablePower(currentExport);
                current = currentExport.SuperClass;
            }

            return HeavyWeaponKind.None;
        }

        private static bool DeclaresConsumablePower(ExportEntry classExport)
        {
            foreach (var property in classExport.GetChildren<ExportEntry>().Where(x => x.ClassName == "ObjectProperty"))
            {
                var propertyClass = classExport.FileRef.GetEntry(ObjectBinary.From<UObjectProperty>(property).ObjectRef);
                if (propertyClass != null && (propertyClass.ObjectName.Name.StartsWith(ConsumablePowerClass, StringComparison.OrdinalIgnoreCase)
                                              || GlobalUnrealObjectInfo.IsA(propertyClass.ObjectName.Name, ConsumablePowerClass, MEGame.LE3)))
                    return true;
            }

            return false;
        }
    }

    /// <summary>
    /// What a consumable heavy weapon needs registered alongside its class: its strings and icons.
    /// </summary>
    internal class HeavyWeaponEntry
    {
        /// <summary>
        /// Full path of the consumable weapon class, e.g. SFXGameContent_Milan.SFXWeapon_Heavy_ConsumableBlackstorm.
        /// </summary>
        public required string ClassPath { get; init; }

        /// <summary>
        /// Full path of the weapon's ordinary heavy weapon class, which <see cref="ClassPath"/> usually extends, e.g.
        /// SFXGameContent_Milan.SFXHeavyWeapon_Blackstorm. If set, it is dynamic load mapped, so the GiveItem console
        /// command can spawn it. It doesn't spend consumables.
        /// </summary>
        public string? NonConsumableClassPath { get; init; }

        /// <summary>
        /// PrettyName.
        /// </summary>
        public required HeavyWeaponString Name { get; init; }

        /// <summary>
        /// ShortPrettyName. <see cref="Name"/> if not set.
        /// </summary>
        public HeavyWeaponString? ShortName { get; init; }

        /// <summary>
        /// GeneralDescription.
        /// </summary>
        public required HeavyWeaponString Description { get; init; }

        /// <summary>
        /// ShortDescription. <see cref="Description"/> if not set.
        /// </summary>
        public HeavyWeaponString? ShortDescription { get; init; }

        /// <summary>
        /// GUIImage: the 512x256 weapon image. Object path of an image built from Startups\NonStartup\ImagePackages.
        /// </summary>
        public required string Image { get; init; }

        /// <summary>
        /// NotificationImage: the 256x128 weapon image. Object path of an image built from
        /// Startups\NonStartup\ImagePackages.
        /// </summary>
        public required string NotificationImage { get; init; }
    }

    /// <summary>
    /// A heavy weapon TLK string: either an existing string ID to reuse, or new text in each language, which gets an ID
    /// assigned when the weapon is registered. Converts from either, so entries can be written as <c>Name = 344477</c> or
    /// <c>Name = new LocalizedString { [MELocalization.INT] = "..." }</c>.
    /// </summary>
    internal class HeavyWeaponString
    {
        private readonly int? ExistingId;
        private readonly LocalizedString? Text;

        private HeavyWeaponString(int? existingId, LocalizedString? text)
        {
            ExistingId = existingId;
            Text = text;
        }

        public static implicit operator HeavyWeaponString(int existingId) => new(existingId, null);
        public static implicit operator HeavyWeaponString(LocalizedString text) => new(null, text);

        /// <summary>
        /// The string's ID: the existing one, or a newly assigned one for its text. Only call once per string, as each call
        /// with text assigns a new ID.
        /// </summary>
        public int Resolve() => ExistingId ?? MilanPipelinesShared.AssignTLK(Text!); // One of the two is always set
    }
}
