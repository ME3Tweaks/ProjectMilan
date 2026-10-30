using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using LegendaryExplorerCore.UnrealScript;
using ProjectMilan.Pipelines.Startups;
using ProjectMilanCore;
using ProjectMilanCore.Config;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.HeavyWeapons
{
    /// <summary>
    /// The heavy weapons pipeline copies our pregenerated heavy weapon packages and links them into the game for use.
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

        private static readonly LocalizedString NoneName = new() { [MELocalization.INT] = "None" };
        // Might consider seeing if this can be done via config instead.
        private static readonly LocalizedString NoneDescription = new() { [MELocalization.INT] = "No heavy weapon equipped. Grants +5% movement speed and +10% reserve ammo capacity." };
        private static readonly LocalizedString CategoryName = new() { [MELocalization.INT] = "Heavy Weapons" };
        private static readonly LocalizedString HiddenCategoryName = new() { [MELocalization.INT] = "Hidden" };

        internal static readonly List<HeavyWeaponEntry> HeavyWeapons =
        [
            // IDs aren't consistent for the first two entries due to development order
            // IDs:
            // 0 Cobra
            // 1 Blackstorm
            // 2 Hidden Cobra
            // 3 Hidden blackstorm
            // 4 None (reserved, not an entry)
            // 5 Blackstar
            // 6 Hidden Blackstar
            // 7 Cain
            // 8 Hidden

            // M-490 Blackstorm
            new()
            {
                Id = 1,
                HiddenId = 3,
                UnlockName = "MilanHeavy_Blackstorm",
                HiddenUnlockTitle = new LocalizedString { [MELocalization.INT] = "M-490 Blackstorm (Hidden)" },
                UnlockPlayerVariableId = 801,
                HiddenUnlockPlayerVariableId = 802,
                Rarity = "rare",
                DisplayOrder = 10,
                ClassPath = "SFXGameContent_Milan.SFXWeapon_Heavy_ConsumableBlackstorm",
                NonConsumableClassPath = "SFXGameContent_Milan.SFXHeavyWeapon_Blackstorm",
                Name = 361364, // M-490 Blackstorm
                ShortName = new LocalizedString { [MELocalization.INT] = "M-490 Blackstorm" },
                Description = 361363,
                ShortDescription = 344479,
                Image = $"{IconPackage}.Blackstorm_512x256",
                NotificationImage = $"{IconPackage}.Blackstorm_256x128",
                IconResource = "GUI_SF_DLC_PRE_Terminus.ME2_Weap_Blackstorm",
                IconIndex = 2,
            },
            // Reaper Blackstar
            new()
            {
                Id = 5,
                HiddenId = 6,
                UnlockName = "MilanHeavy_Blackstar",
                HiddenUnlockTitle = new LocalizedString { [MELocalization.INT] = "Reaper Blackstar (Hidden)" },
                UnlockPlayerVariableId = 803,
                HiddenUnlockPlayerVariableId = 804,
                Rarity = "rare",
                DisplayOrder = 20,
                ClassPath = "SFXGameContent_Milan.SFXWeapon_Heavy_ConsumableBlackstar",
                InheritFrom = "SFXGameContent.SFXWeapon_Heavy_Blackstar",
                // Vanilla has no ShortPrettyName for it
                ShortName = new LocalizedString { [MELocalization.INT] = "Reaper Blackstar" },
                IconResource = "GUI_SF_ME2_Weapon_Icons.ME2_Weapon_Icons",
                // TODO: We need an actual short text or move hidden to the top.
            },
            // M-920 Cain
            new()
            {
                Id = 7,
                HiddenId = 8,
                UnlockName = "MilanHeavy_Cain",
                HiddenUnlockTitle = new LocalizedString { [MELocalization.INT] = "M-920 Cain (Hidden)" },
                UnlockPlayerVariableId = 805,
                HiddenUnlockPlayerVariableId = 806,
                // Drop from ultrarare pool, cain is special
                Rarity = "ultrarare",
                DisplayOrder = 30,
                ClassPath = "SFXGameContent_Milan.SFXWeapon_Heavy_ConsumableCain",
                InheritFrom = "SFXGameContent.SFXWeapon_Heavy_Cain",
                ShortName = new LocalizedString { [MELocalization.INT] = "M-920 Cain" },
                IconResource = "GUI_SF_ME2_Weapon_Icons.ME2_Weapon_Icons",
            },
        ];

        /// <summary>
        /// Takes an open IMEPackage and prepares it for install into Project Milan
        /// </summary>
        /// <param name="package"></param>
        /// <param name="foundClasses"></param>
        /// <param name="nonConsumableClasses"></param>
        private static void InstallHeavyWeaponPackage(IMEPackage package, Dictionary<string, string> foundClasses, Dictionary<string, string> nonConsumableClasses)
        {
            bool hasConsumable = false;

            var consumableClasses = new List<ExportEntry>();
            foreach (var classExport in package.Exports.Where(x => x.IsClass && !HiddenHeavyWeaponVariants.IsHiddenVariant(x)))
            {
                var kind = GetHeavyWeaponKind(classExport);
                if (kind == HeavyWeaponKind.Consumable)
                {
                    hasConsumable = true;
                    consumableClasses.Add(classExport);
                    AddFoundClass(foundClasses, classExport.InstancedFullPath, package.FileNameNoExtension);
                }
                else if (kind == HeavyWeaponKind.NonConsumable)
                {
                    AddFoundClass(nonConsumableClasses, classExport.InstancedFullPath, package.FileNameNoExtension);
                }
            }

            if (!hasConsumable)
            {
                // Add consumable class
                
            }

            GenerateHiddenVariants(package, consumableClasses);

            // Change its licensee to LE3 so TFC compaction doesn't die on it
            var outFile = Path.Combine(OutputFolder, package.FileNameNoExtension + ".pcc");
            package.Save(outFile);
            MilanLicensee.SetGame(outFile, MEGame.LE3);
            MilanLog.Information($"Installed {package.FileNameNoExtension}", customPrefix: LOG_CATEGORY);
        }

        public static void RunPipeline()
        {
            Directory.CreateDirectory(OutputFolder);
            var ids = new HashSet<int> { 0, 2, 4 };
            var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var entry in HeavyWeapons)
            {
                if (entry.Id < 0 || entry.HiddenId < 0 || !ids.Add(entry.Id) || !ids.Add(entry.HiddenId)
                    || !paths.Add(entry.ClassPath) || entry.ClassPath.CaseInsensitiveEquals(CobraClassPath))
                    throw new InvalidOperationException($"Invalid/duplicate heavy weapon registration: {entry.ClassPath}");
            }
            var noneName = MilanPipelinesShared.AssignTLK(NoneName);
            var catalog = new List<HeavyWeaponCatalogEntry>
            {
                new() { Id = 4, ClassPath = "", Name = noneName, ShortName = noneName,
                    Description = MilanPipelinesShared.AssignTLK(NoneDescription),
                    Image = "", Icon = "", IconResource = "", IconIndex = 0, NoWeapon = true, Rarity = "", DisplayOrder = -10 }
            };

            // Cobra lives in MPCommon rather than a standalone heavy weapon package.
            var mpCommon = MilanShared.GetMPCommonPackage();
            HeavyWeaponStoreRegistration.ApplyPowerDefaults(mpCommon);
            var cobra = mpCommon.FindExport(CobraClassPath);
            GenerateHiddenVariants(mpCommon, [cobra]);
            RegisterHiddenVariant(CobraClassPath, MilanShared.MP_STARTUP_NAME);
            var cobraDefaults = mpCommon.GetUExport(ObjectBinary.From<UClass>(cobra).Defaults);
            var cobraEntry = new HeavyWeaponCatalogEntry
            {
                Id = 0,
                ClassPath = CobraClassPath,
                DisplayOrder = 0,
                Name = cobraDefaults.GetProperty<StringRefProperty>("PrettyName").Value,
                ShortName = cobraDefaults.GetProperty<StringRefProperty>("ShortPrettyName").Value,
                Description = cobraDefaults.GetProperty<StringRefProperty>("GeneralDescription").Value,
                Image = "GUI_Codex_Weapons_Images.Weapons.hvy_titan_512x256",
                Icon = "GUI_Icons.Weapons.hvy_titan_256x128",
                // Native SFXWeaponUIData: SFXWeapon_Heavy_TitanMissileLauncher uses frame 49.
                IconResource = "GUI_SF_ME2_Weapon_Icons.ME2_Weapon_Icons",
                IconIndex = 49,
            };
            catalog.Add(cobraEntry);
            catalog.Add(cobraEntry with { Id = 2, ClassPath = HiddenHeavyWeaponVariants.GetClassPath(CobraClassPath), DisplayOrder = 1, Hidden = true, Rarity = "rare", UnlockVariable = HeavyWeaponStoreRegistration.HiddenCobraUnlock });

            // INSTALL PRECOMPILED PACKAGES ----------
            // Class path to the package it is in
            var foundClasses = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            var nonConsumableClasses = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var sourcePath in Directory.GetFiles(SourceFolder, "*.pcc", SearchOption.TopDirectoryOnly))
            {
                using var package = MEPackageHandler.OpenMEPackage(sourcePath, forceLoadFromDisk: true);
                InstallHeavyWeaponPackage(package, foundClasses, nonConsumableClasses);
            }
            // END PRECOMPILED PACKAGES ----------

            // GAME SOURCED PACKAGES -------------
            // We have to pre-prep packages so these aren't useful
            //foreach (var entry in HeavyWeapons.Where(x => x.SourcePackage != null && !foundClasses.ContainsKey(x.ClassPath)))
            //{
            //    using var package = MilanShared.GetLE3Package(entry.SourcePackage);
            //    InstallHeavyWeaponPackage(package, foundClasses, nonConsumableClasses);
            //}
            // END GAME SOURCED PACKAGES ---------

            // Our images, plus the game's own mapped ones (vanilla weapon art)
            var loadableImages = new HashSet<string>(ImagePackageBuilder.BuiltImages, StringComparer.OrdinalIgnoreCase);
            loadableImages.UnionWith(Store.StoreRegistration.GetDynamicLoadObjects());
            foreach (var (classPath, packageName) in foundClasses)
            {
                var entry = HeavyWeapons.FirstOrDefault(x => x.ClassPath.CaseInsensitiveEquals(classPath));
                if (entry == null)
                {
                    MilanLog.Warning($"Consumable heavy weapon {classPath} in {packageName} has no registration.");
                    continue;
                }
                var resolved = RegisterHeavyWeapon(entry, packageName, nonConsumableClasses, loadableImages);
                catalog.Add(resolved);
                catalog.Add(resolved with { Id = entry.HiddenId, ClassPath = entry.HiddenClassPath, DisplayOrder = entry.DisplayOrder + 1, Hidden = true, UnlockVariable = entry.HiddenUnlockName });
            }

            foreach (var entry in HeavyWeapons.Where(x => !foundClasses.ContainsKey(x.ClassPath)))
            {
                throw new InvalidOperationException($"Registered consumable class {entry.ClassPath} has no package in {SourceFolder}.");
            }

            CompileResolver(mpCommon, catalog);
            mpCommon.Save(diskIOSyncLock: MilanShared.DiskIOSyncLock);
            HeavyWeaponCatalogRegistration.Register(catalog,
                MilanPipelinesShared.AssignTLK(CategoryName),
                MilanPipelinesShared.AssignTLK(HiddenCategoryName));
            MilanShared.RefreshMilanFiles = true;
            MilanPipelinesShared.CommitConfigBundle();
        }

        internal const string CobraClassPath = "SFXGameMPContent.SFXWeapon_Heavy_ConsumableRocketLauncher";

        internal static void CompileResolver(IMEPackage package, IEnumerable<HeavyWeaponCatalogEntry> catalog)
        {
            var source = HeavyWeaponResolverSource.Build(catalog);
            var function = package.FindExport("SFXGameContent_Milan.SFXMilanHeavyWeaponCatalog.ResolveClass")
                ?? throw new InvalidOperationException("MPCommon is missing the heavy resolver; rebuild its checkpoint.");
            using var cache = MilanShared.GetMPCommonTieredPackageCache().ChainNewCache(debugName: "Heavy resolver");
            var options = new UnrealScriptOptionsPackage { Cache = cache, CustomFileResolver = MilanShared.LE3PackageResolver };
            using var library = new FileLib(package);
            if (!library.Initialize(options))
                throw new InvalidOperationException($"Cannot initialize heavy resolver: {string.Join(Environment.NewLine, library.InitializationLog.AllErrors)}");
            var (_, log) = UnrealScriptCompiler.CompileFunction(function, source, library, options);
            if (log.HasErrors)
                throw new InvalidOperationException($"Cannot compile heavy resolver: {string.Join(Environment.NewLine, log.AllErrors)}");
        }

        private static void GenerateHiddenVariants(IMEPackage package, IEnumerable<ExportEntry> consumables)
        {
            using var cache = MilanShared.GetMPCommonTieredPackageCache()
                .ChainNewCache(debugName: $"Hidden heavy weapons ({package.FileNameNoExtension})");
            var options = new UnrealScriptOptionsPackage
            {
                Cache = cache,
                CustomFileResolver = MilanShared.LE3PackageResolver,
                MissingObjectResolver = MilanShared.MissingObjectResolver,
                GetVTableFromDonor = MilanShared.GetVTableFromDonor,
            };
            foreach (var (original, variant) in HiddenHeavyWeaponVariants.Generate(package, consumables, options))
            {
                MilanLog.Information($"Generated {variant.InstancedFullPath} from {original}", customPrefix: LOG_CATEGORY);
            }
        }

        private static void RegisterHiddenVariant(string originalClassPath, string packageName)
        {
            var hiddenClassPath = HiddenHeavyWeaponVariants.GetClassPath(originalClassPath);
            DynamicLoadMappingRegistration.RegisterDynamicLoadMapping(hiddenClassPath, packageName, replicate: true);
            MilanPipelinesShared.ConfigBundle.GetAsset("BioGame").GetOrAddSection("sfxgamempcontent.sfxprimp")
                .AddEntry(new CoalesceProperty("defaultloadclasses", new CoalesceValue(hiddenClassPath, CoalesceParseAction.AddUnique)));

            // Copy the registered tuning and UI overrides; the subclass inherits the weapon's other defaults.
            var asset = MilanPipelinesShared.ConfigBundle.GetAsset("BioWeapon");
            var original = asset.GetOrAddSection(originalClassPath.ToLowerInvariant());
            var hidden = asset.GetOrAddSection(hiddenClassPath.ToLowerInvariant());
            hidden.Clear();
            foreach (var (name, property) in original)
            {
                hidden.Add(name, new CoalesceProperty(name, property.ToList()));
            }
            MilanLog.Information($"Registered {hiddenClassPath} in {packageName}", customPrefix: LOG_CATEGORY);
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
        /// <param name="loadableImages">Images we built, and every object a dynamic load mapping covers.</param>
        private static HeavyWeaponCatalogEntry RegisterHeavyWeapon(HeavyWeaponEntry entry, string packageName, Dictionary<string, string> nonConsumableClasses, IReadOnlySet<string> loadableImages)
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

            var image = entry.GetImage();
            var icon = entry.GetNotificationImage();
            if (!loadableImages.Contains(image) || !loadableImages.Contains(icon))
            {
                throw new InvalidOperationException($"{entry.ClassPath}'s images {image} / {icon} aren't built or dynamic load mapped.");
            }
            var name = entry.ResolveName();
            var description = entry.ResolveDescription();
            var shortName = entry.ResolveShortName(name);
            // Written even when inherited, as the catalog and hidden variant copy them from here
            var section = MilanPipelinesShared.ConfigBundle.GetAsset("BioWeapon").GetOrAddSection(entry.ClassPath.ToLowerInvariant());
            SetConfigValue(section, "prettyname", name.ToString());
            SetConfigValue(section, "shortprettyname", shortName.ToString());
            SetConfigValue(section, "generaldescription", description.ToString());
            SetConfigValue(section, "shortdescription", entry.ResolveShortDescription(description).ToString());
            SetConfigValue(section, "guiimage", image);
            SetConfigValue(section, "notificationimage", icon);

            RegisterHiddenVariant(entry.ClassPath, packageName);
            MilanLog.Information($"Registered {entry.ClassPath} in {packageName}", customPrefix: LOG_CATEGORY);
            return new HeavyWeaponCatalogEntry
            {
                Id = entry.Id,
                ClassPath = entry.ClassPath,
                DisplayOrder = entry.DisplayOrder,
                Name = name,
                ShortName = shortName,
                Description = description,
                Image = image,
                Icon = icon,
                IconResource = entry.IconResource,
                IconIndex = entry.GetIconIndex(),
                Rarity = entry.Rarity,
                UnlockVariable = entry.UnlockName
            };
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
        /// <summary>Permanent visible/hidden selection IDs; never assign from collection order.</summary>
        public required int Id { get; init; }
        public required int HiddenId { get; init; }
        public required string UnlockName { get; init; }
        public string HiddenUnlockName => UnlockName + "_Hidden";
        /// <summary>Title of the hidden variant's store unlock card.</summary>
        public required HeavyWeaponString HiddenUnlockTitle { get; init; }
        public required int UnlockPlayerVariableId { get; init; }
        public required int HiddenUnlockPlayerVariableId { get; init; }
        public int DisplayOrder { get; init; }

        /// <summary>Indexed Scaleform weapon icon, separate from the notification texture.</summary>
        public required string IconResource { get; init; }

        /// <summary>Frame in <see cref="IconResource"/>. <see cref="InheritFrom"/>'s IconRef if not set.</summary>
        public int? IconIndex { get; init; }
        public string Rarity { get; init; } = "common";

        /// <summary>
        /// Class path of a vanilla weapon, e.g. SFXGameContent.SFXWeapon_Heavy_Blackstar, whose basegame BioWeapon section
        /// supplies every name, description, image and <see cref="IconIndex"/> not set here. In game, a consumable class
        /// that extends that weapon also inherits the rest of its config (tuning) from that section.
        /// </summary>
        public string? InheritFrom { get; init; }

        /// <summary>
        /// Full path of the consumable weapon class, e.g. SFXGameContent_Milan.SFXWeapon_Heavy_ConsumableBlackstorm.
        /// </summary>
        public required string ClassPath { get; init; }

        /// <summary>The generated concealed version, for the heavy weapon selector.</summary>
        public string HiddenClassPath => HiddenHeavyWeaponVariants.GetClassPath(ClassPath);

        /// <summary>
        /// Full path of the weapon's ordinary heavy weapon class, which <see cref="ClassPath"/> usually extends, e.g.
        /// SFXGameContent_Milan.SFXHeavyWeapon_Blackstorm. If set, it is dynamic load mapped, so the GiveItem console
        /// command can spawn it. It doesn't spend consumables.
        /// </summary>
        public string? NonConsumableClassPath { get; init; }

        /// <summary>
        /// PrettyName. <see cref="InheritFrom"/>'s if not set.
        /// </summary>
        public HeavyWeaponString? Name { get; init; }

        /// <summary>
        /// ShortPrettyName. <see cref="InheritFrom"/>'s, then <see cref="Name"/>, if not set.
        /// </summary>
        public HeavyWeaponString? ShortName { get; init; }

        /// <summary>
        /// GeneralDescription. <see cref="InheritFrom"/>'s if not set.
        /// </summary>
        public HeavyWeaponString? Description { get; init; }

        /// <summary>
        /// ShortDescription. <see cref="InheritFrom"/>'s, then <see cref="Description"/>, if not set.
        /// </summary>
        public HeavyWeaponString? ShortDescription { get; init; }

        /// <summary>
        /// GUIImage: the 512x256 weapon image. Object path of an image built from Startups\NonStartup\ImagePackages, or
        /// a dynamic load mapped vanilla one. <see cref="InheritFrom"/>'s if not set.
        /// </summary>
        public string? Image { get; init; }

        /// <summary>
        /// NotificationImage: the 256x128 weapon image, from the same places as <see cref="Image"/>.
        /// <see cref="InheritFrom"/>'s if not set.
        /// </summary>
        public string? NotificationImage { get; init; }

        // Each call with new text assigns a new TLK ID, as HeavyWeaponString.Resolve does
        public int ResolveName() => Name?.Resolve() ?? InheritedInt("prettyname") ?? throw Missing(nameof(Name));
        public int ResolveShortName(int name) => ShortName?.Resolve() ?? InheritedInt("shortprettyname") ?? name;
        public int ResolveDescription() => Description?.Resolve() ?? InheritedInt("generaldescription") ?? throw Missing(nameof(Description));
        public int ResolveShortDescription(int description) => ShortDescription?.Resolve() ?? InheritedInt("shortdescription") ?? description;
        public string GetImage() => Image ?? Inherited("guiimage") ?? throw Missing(nameof(Image));
        public string GetNotificationImage() => NotificationImage ?? Inherited("notificationimage") ?? throw Missing(nameof(NotificationImage));
        public int GetIconIndex() => IconIndex ?? InheritedInt("iconref") ?? throw Missing(nameof(IconIndex));

        private string? Inherited(string property) => InheritFrom == null ? null : VanillaWeaponConfig.Get(InheritFrom, property);
        private int? InheritedInt(string property) => Inherited(property) is { } value ? int.Parse(value) : null;

        private InvalidOperationException Missing(string field) => new(InheritFrom == null
            ? $"Heavy weapon {ClassPath} has no {field}"
            : $"Heavy weapon {ClassPath} has no {field}, and {InheritFrom}'s basegame BioWeapon section doesn't have one either");
    }

    /// <summary>
    /// The basegame BioWeapon config (Mod\BaseConfig\BioWeapon.xml), which the DLC config bundle doesn't hold.
    /// </summary>
    internal static class VanillaWeaponConfig
    {
        // Section (class path) -> property -> first value
        private static readonly Lazy<Dictionary<string, Dictionary<string, string>>> Sections = new(Load);

        /// <returns>The first value of <paramref name="property"/> in <paramref name="classPath"/>'s section, or null.</returns>
        public static string? Get(string classPath, string property)
        {
            if (!Sections.Value.TryGetValue(classPath, out var section))
            {
                throw new InvalidOperationException($"The basegame BioWeapon config has no {classPath} section");
            }
            return section.GetValueOrDefault(property);
        }

        private static Dictionary<string, Dictionary<string, string>> Load()
        {
            var path = Path.Combine(MilanShared.PipelineRoot, "Mod", "BaseConfig", "BioWeapon.xml");
            var sections = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var section in System.Xml.Linq.XDocument.Load(path).Descendants("Section"))
            {
                var properties = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                foreach (var property in section.Elements("Property"))
                    properties.TryAdd(property.Attribute("name")!.Value, property.Value);
                sections[section.Attribute("name")!.Value] = properties;
            }
            return sections;
        }
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
