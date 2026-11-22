using System.Text.RegularExpressions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK.ME2ME3;
using ProjectMilanCore;
using MilanDelta;

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

        /// <summary>
        /// String remapping to point to correct omni-key split input alias
        /// </summary>
        private static readonly Dictionary<int, string> PcActionRetarget = new()
        {
            // Use
            [339230] = "PC_Use", [339251] = "PC_Use", [705044] = "PC_Use", [705045] = "PC_Use",
            // Storm, evade roll
            [339280] = "PC_Sprint", [344119] = "PC_Sprint", [349583] = "PC_Sprint", [351464] = "PC_Sprint",
            [554190] = "PC_Sprint", [562474] = "PC_Sprint", [675661] = "PC_Sprint", [722322] = "PC_Sprint",
            [722407] = "PC_Sprint", [562479] = "PC_Sprint", [722326] = "PC_Sprint",
            // Cover, vault, climb, cover-to-cover roll, gap jump
            [339231] = "PC_Cover", [339243] = "PC_Cover", [339246] = "PC_Cover", [344126] = "PC_Cover",
            [344136] = "PC_Cover", [554205] = "PC_Cover", [554215] = "PC_Cover", [554219] = "PC_Cover",
            [554220] = "PC_Cover", [555204] = "PC_Cover", [562483] = "PC_Cover",
            [675662] = "PC_Cover", [675841] = "PC_Cover", [718564] = "PC_Cover",
            [722401] = "PC_Cover", [722405] = "PC_Cover",
        };

        private static readonly Regex PcActionRegex = new(@"\bPC_Action\b", RegexOptions.Compiled | RegexOptions.CultureInvariant);

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

        public string Comment => $"Basegame TLK ({localization}): PC_/Console_ control tokens reverted to Shared_, omnikey prompts split";

        public string DeltaFormat => TlkDeltaXml.Format;

        public byte[] RestoreFileBytes(byte[] patched) => TlkDeltaXml.Compress(patched);

        public byte[] GetVanillaBytes() => TlkDeltaXml.Decompress(File.ReadAllBytes(BaseDeltaHandler.GetVanillaCookedFilePath(GameFile)));

        public byte[] BuildPatchTarget()
        {
            var vanilla = File.ReadAllBytes(BaseDeltaHandler.GetVanillaCookedFilePath(GameFile));
            using var vanillaStream = new MemoryStream(vanilla);
            var tlk = new ME2ME3TalkFile(vanillaStream, GameFile);

            var changed = 0;
            foreach (var str in tlk.StringRefs)
            {
                if (string.IsNullOrEmpty(str.Data))
                    continue;

                var replaced = str.Data;
                if (PcActionRetarget.TryGetValue(str.CalculatedID, out var pcAlias))
                {
                    replaced = PcActionRegex.Replace(replaced, pcAlias);
                }
                replaced = TokenRegex.Replace(replaced, m => TokenMap[m.Value]);
                if (replaced != str.Data)
                {
                    str.Data = replaced;
                    changed++;
                }
            }

            MilanLog.Information($"{GameFile}: replaced control tokens in {changed} string(s)", customPrefix: "Milan-TLK");
            if (changed == 0)
            {
                // Identical XML gives an empty-content delta without diffing a new Huffman tree.
                return TlkDeltaXml.Serialize(tlk);
            }

            return TlkDeltaXml.Serialize(tlk);
        }
    }
}
