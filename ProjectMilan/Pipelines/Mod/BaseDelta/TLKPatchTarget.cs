using System.Text.RegularExpressions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK.ME2ME3;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Patches one localized basegame TLK (BIOGame_INT.tlk, BIOGame_FRA.tlk, ...): the vanilla ones contain hardcoded
    /// control tokens that LE split into PC_/Console_ variants. Milan merges those back into the single Shared_ alias
    /// in BaseConfig/BioInput.xml, so the tokens in the text have to follow or the button prompts won't resolve.
    /// This is not a package and thus uses specific changes. There is one target per localization, see <see cref="CreateAll"/>.
    /// </summary>
    internal class TLKPatchTarget : IBasePatchClass
    {
        /// <summary>
        /// Every old token -> merged Shared_ token. Must be kept in sync with the alias merge in
        /// Mod/BaseConfig/BioInput.xml. Any other PC_/Console_ token (movement, look, hotkeys, etc.) is
        /// still platform specific there and is left alone.
        /// </summary>
        private static readonly Dictionary<string, string> TokenMap = BuildTokenMap();

        private static Dictionary<string, string> BuildTokenMap()
        {
            // Names that exist as both PC_<name> and Console_<name> and became Shared_<name>.
            string[] sharedNames =
            [
                "Action", "AdvanceSlideshowBackward", "AdvanceSlideshowForward", "Aim", "CineSkip",
                "ConvIntParagon", "ConvIntRenegade", "ConvSelect", "ConvSkip", "ExitAtlas", "ExitMountedGun",
                "ExitSlideshow", "GalaxyProbe", "GalaxyScan", "GalaxySystemScan", "HideMap", "MPToggleReady",
                "Melee", "Menu", "MoveDown", "MoveUp", "MovieSkip", "QuickSave", "Screenshot", "Shoot",
                "TogglePhotoOptions", "ViewNextPlayer", "ViewPrevPlayer"
            ];

            var map = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (var name in sharedNames)
            {
                map["PC_" + name] = "Shared_" + name;
                map["Console_" + name] = "Shared_" + name;
            }

            // Not a straight prefix swap: the console map/photo button became the shared HideMap.
            map["Console_MapAndPhotoMode"] = "Shared_HideMap";
            return map;
        }

        // Whole tokens only, in case one token shadows another longer one.
        private static readonly Regex TokenRegex = new(
            @"\b(?:" + string.Join("|", TokenMap.Keys.OrderByDescending(k => k.Length).Select(Regex.Escape)) + @")\b",
            RegexOptions.Compiled | RegexOptions.CultureInvariant);

        private readonly MELocalization localization;

        public TLKPatchTarget(MELocalization localization)
        {
            if (localization == MELocalization.None)
                throw new ArgumentException("A TLK target needs a specific localization", nameof(localization));
            this.localization = localization;
        }

        /// <summary>
        /// Creates a target for every localization LE3 ships a basegame TLK for (INT, DEU, ESN, FRA, ITA, JPN, POL, RUS).
        /// </summary>
        public static TLKPatchTarget[] CreateAll() =>
            Enum.GetValues<MELocalization>()
                .Where(l => l != MELocalization.None)
                .Select(l => new TLKPatchTarget(l))
                .ToArray();

        public string GameFile => $"BIOGame_{localization}.tlk";

        public string Comment => $"Basegame TLK ({localization}): PC_/Console_ control tokens reverted to Shared_";

        public byte[] GetVanillaBytes() => File.ReadAllBytes(BaseDeltaHandler.GetVanillaCookedFilePath(GameFile));

        public byte[] BuildPatchTarget()
        {
            var vanilla = GetVanillaBytes();
            using var vanillaStream = new MemoryStream(vanilla);
            var tlk = new ME2ME3TalkFile(vanillaStream, GameFile);

            var changed = 0;
            foreach (var str in tlk.StringRefs)
            {
                if (string.IsNullOrEmpty(str.Data))
                    continue;

                var replaced = TokenRegex.Replace(str.Data, m => TokenMap[m.Value]);
                if (replaced != str.Data)
                {
                    str.Data = replaced;
                    changed++;
                }
            }

            MilanLog.Information($"{GameFile}: replaced control tokens in {changed} string(s)", customPrefix: "Milan-TLK");
            if (changed == 0)
            {
                // Nothing to patch; don't re-encode the Huffman tree just to produce a noisier diff.
                return vanilla;
            }

            return HuffmanCompression.SaveToTlkStream(tlk.StringRefs).ToArray();
        }
    }
}
