using ProjectMilanCore.Config;
using ProjectMilanCore.Utility;

namespace ProjectMilan.Pipelines.Startups
{
    /// <summary>
    /// Registers the challenge banners whose images ME3 downloaded from EA's servers at runtime
    /// ("ChallengeBanners/X.dds"). Their images are now built locally from ImagePackages\Online by
    /// <see cref="ImagePackageBuilder"/>, and these used to be static XML in MergedConfig\BioGame.xml - they live here
    /// instead so they can only exist if Milan built their images. The online store packs moved to Pipelines\Store.
    /// <para>
    /// Every emblem ID here is the vanilla ME3 value and must not change - ME3 MP profiles refer to them. New content
    /// gets new IDs after these.
    /// </para>
    /// </summary>
    internal static class OnlineContentRegistration
    {
        private const string LOG_CATEGORY = @"MILAN-OnlineContent";

        /// <summary>
        /// Image package folder under ImagePackages\Online these images are built from.
        /// </summary>
        private const string BannerImages = "ChallengeBanners";

        public static void RegisterOnlineBanners(IReadOnlySet<string> builtImages)
        {
            MilanLog.Information("Registering online challenge banners", customPrefix: LOG_CATEGORY);
            foreach (var banner in OnlineBanners)
            {
                CheckImageBuilt(builtImages, banner.BackgroundResource, $"challenge banner {banner.ID}");
                ChallengeBannerRegistration.RegisterChallengeBanner(banner);
            }
        }

        private static void CheckImageBuilt(IReadOnlySet<string> builtImages, string imagePath, string usedBy)
        {
            if (!builtImages.Contains(imagePath))
            {
                // This needs expanded to support the new Milan image package
                MilanLog.Error($"Image {imagePath} for {usedBy} was not built - is it missing from ImagePackages\\Online?", customPrefix: LOG_CATEGORY);
            }
        }

        private static ChallengeBannerEntry Banner(int id, string image, int titleStrRefId) =>
            new() { ID = id, BackgroundResource = $"{BannerImages}.{image}", TitleStrRefId = titleStrRefId };

        private static readonly List<ChallengeBannerEntry> OnlineBanners =
        [
            Banner(100, "MEMstr", 778515),
            Banner(150, "Halloween", 812513),
            Banner(153, "N7Day", 813744),
            Banner(154, "Bioware", 813603), // No available unlock method - I guess if someone copies their MP profile over though...
            Banner(155, "Corsair", 813915),
            Banner(157, "Prophecy", 814532),
            Banner(206, "Punisher", 814545),
            Banner(207, "MEMstrF", 778515),
            Banner(208, "zaeed", 817835),
            Banner(209, "ContestWinner1", 778529),
            Banner(210, "ContestWinner2", 778529),
            Banner(211, "ContestWinner3", 778522),
            Banner(212, "ContestWinner4", 778522),
            Banner(213, "ContestWinner5", 778531),
            Banner(214, "ContestWinner6", 778526),
            Banner(215, "ContestWinner7", 778516),
            Banner(216, "ContestWinner8", 778518),
            Banner(217, "ContestWinner9", 778538),
            Banner(218, "ContestWinner10", 778539),
            Banner(219, "VolusLover", 817851),
            Banner(220, "FullTeam", 817847),
        ];
    }
}
