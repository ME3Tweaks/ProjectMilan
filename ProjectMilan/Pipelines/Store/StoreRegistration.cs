using System.Text.RegularExpressions;
using LegendaryExplorerCore.Packages;
using ProjectMilanCore.Utility;
using ProjectMilanCore;
using ProjectMilanCore.Config.Store;
using ProjectMilan.Pipelines.HeavyWeapons;

namespace ProjectMilan.Pipelines.Store
{
    /// <summary>
    /// Writes the whole multiplayer store (<see cref="StoreCards"/>, <see cref="StorePools"/>, <see cref="StorePacks"/>) into
    /// the active <see cref="MilanPipelinesShared.ConfigBundle"/> in one go. It's done once, from a single pipeline stage,
    /// rather than from each porting pipeline as items are pulled in: stages can be skipped or restored from checkpoints, so
    /// a store assembled from per-stage registrations could end up incomplete.
    /// </summary>
    public static partial class StoreRegistration
    {
        private const string LOG_CATEGORY = @"MILAN-Store";

        private static readonly LocalizedString BannerCardType = new() {
            [MELocalization.INT] = "Banner",
            [MELocalization.DEU] = "Banner",
            [MELocalization.ESN] = "Banner",
            [MELocalization.FRA] = "Bannière",
            [MELocalization.POL] = "Baner",
            [MELocalization.RUS] = "Баннер",
            [MELocalization.ITA] = "Banner",
        };
        private static readonly LocalizedString BannerCardDescription = new() {
            [MELocalization.INT] = "Unlocks this banner for use in the multiplayer lobby.",
            [MELocalization.DEU] = "Schaltet dieses Banner für die Verwendung in der Multiplayer-Lobby frei.",
            [MELocalization.ESN] = "Desbloquea este banner para utilizarlo en el lobby multijugador.",
            [MELocalization.FRA] = "Débloque cette bannière pour la salle d'attente multijoueurs.",
            [MELocalization.POL] = "Odblokowuje ten baner do użycia w lobby trybu wieloosobowego.",
            [MELocalization.RUS] = "Открывает данный баннер для использования в многопользовательстком лобби.",
            [MELocalization.ITA] = "Sblocca questo banner per usarlo nelle lobby multigiocatore",
        };

        /// <param name="builtImages">Images ImagePackageBuilder built, to check the packs that use them.</param>
        public static void Register(IReadOnlySet<string> builtImages)
        {
            MilanLog.Information("Registering the multiplayer store", customPrefix: LOG_CATEGORY);
            var catalog = new StoreCatalog();
            catalog.Cards.AddRange(StoreCards.All);
            HeavyWeaponStoreRegistration.Configure(catalog);
            catalog.Packs.AddRange(StorePacks.GetAll());
            var unassignedIds = MilanIds.FindUnassignedIds(catalog).ToList();
            if (unassignedIds.Count > 0)
            {
                throw new InvalidOperationException($"Store IDs must come from MilanIds.cs:\n{string.Join("\n", unassignedIds)}");
            }

            foreach (var pack in catalog.Packs)
            {
                // Vanilla packs use images from the game's own GUI packages; only these folders are built by Milan
                if ((pack.Image.StartsWith($"{StorePacks.StoreImages}.") || pack.Image.StartsWith($"{StorePacks.BannerImages}.")) && !builtImages.Contains(pack.Image))
                {
                    MilanLog.Error($"Image {pack.Image} for store pack {pack.PackName} was not built - is it missing from ImagePackages\\Online?", customPrefix: LOG_CATEGORY);
                }
            }

            var game = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame");
            var dynamicObjects = GetDynamicLoadObjects();
            var bannerImages = new HashSet<string>(builtImages, StringComparer.OrdinalIgnoreCase);
            bannerImages.UnionWith(dynamicObjects);
            var bannerValidation = catalog.ValidateBanners(StoreCatalog.ReadEmblemIds(game.GetOrAddSection(StoreCatalog.BannerEmblemsSection)), bannerImages);
            if (bannerValidation.Errors.Count > 0)
            {
                throw new InvalidOperationException(string.Join("\n", bannerValidation.Errors));
            }
            var warnings = catalog.Commit(game, dynamicObjects);
            var bannerType = 0;
            var bannerDescription = 0;
            if (catalog.Banners.Any())
            {
                bannerType = MilanPipelinesShared.AssignTLK(BannerCardType);
                bannerDescription = MilanPipelinesShared.AssignTLK(BannerCardDescription);
            }
            catalog.CommitBannerConfig(game, MilanPipelinesShared.ConfigBundle.GetAsset("BioEngine"),
                MilanPipelinesShared.ConfigBundle.GetAsset("BioUI"), bannerType, bannerDescription, bannerImages);
            foreach (var warning in warnings)
            {
                MilanLog.Warning(warning, customPrefix: LOG_CATEGORY);
            }
            MilanLog.Information($"Registered {catalog.Cards.Count} store cards and {catalog.Packs.Count} store packs", customPrefix: LOG_CATEGORY);
        }

        [GeneratedRegex("ObjectName\\s*=\\s*\"([^\"]+)\"", RegexOptions.IgnoreCase)]
        private static partial Regex DynamicLoadObjectNameRegex();

        /// <summary>
        /// Every object with a dynamicloadmapping, from the basegame config (vanilla weapons are mapped there) and this DLC's.
        /// </summary>
        internal static IReadOnlySet<string> GetDynamicLoadObjects()
        {
            var objects = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var baseEngineXml = Path.Combine(MilanShared.PipelineRoot, "Mod", "BaseConfig", "BioEngine.xml");
            foreach (Match match in DynamicLoadObjectNameRegex().Matches(File.ReadAllText(baseEngineXml)))
            {
                objects.Add(match.Groups[1].Value);
            }

            if (MilanPipelinesShared.ConfigBundle.GetAsset("BioEngine").Sections.TryGetValue("sfxgame.sfxengine", out var engine)
                && engine.TryGetValue("dynamicloadmapping", out var mappings))
            {
                foreach (var mapping in mappings)
                {
                    if (mapping.Value != null && DynamicLoadObjectNameRegex().Match(mapping.Value) is { Success: true } match)
                        objects.Add(match.Groups[1].Value);
                }
            }
            return objects;
        }
    }
}
