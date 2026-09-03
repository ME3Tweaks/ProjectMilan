using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK.ME2ME3;
using Newtonsoft.Json.Linq;
using ProjectMilan_ExtraContent.Redemption.Levels.MapPack;
using System.Text.RegularExpressions;

namespace RedemptionMapTool
{
    /// <summary>
    /// Reads the original mod's per-map display metadata (name/description/GAW subtitle) out of its
    /// Coalesced config (Default_DLC_MOD_MPMapPack.bin, BioGame.sfxonlinefoundation.sfxonlinegamesettings.
    /// mastermaplist) and resolves the StrRefs it references against the mod's own TLK files, so the change
    /// manifest can carry the actual string text forward. The old StrRef IDs themselves are not kept - they're
    /// far too high to reuse in this project's own content and get replaced with freshly assigned ones when
    /// the manifest is consumed to build the map list config (see RedemptionShared.AssignTLK).
    /// </summary>
    internal static class MasterMapListReader
    {
        private static readonly Regex PackageNameField = new(@"PackageName=""([^""]*)""");
        private static readonly Regex PrettyNameField = new(@"PrettyName=(\d+)");
        private static readonly Regex DescriptionField = new(@"Description=(\d+)");
        private static readonly Regex SubtitleField = new(@"GalaxyAtWarMapSubtitle=(\d+)");
        private static readonly Regex GawPositionField = new(@"GalaxyAtWarMapPosition=\(X=([^,]+),\s*Y=([^)]+)\)");
        private static readonly Regex ImageField = new(@"Image=""([^""]*)""");

        public static Dictionary<string, MapDisplayInfo> Read(string cookedDir)
        {
            var result = new Dictionary<string, MapDisplayInfo>(StringComparer.OrdinalIgnoreCase);

            // Lives alongside the .pcc files in CookedPCConsole, not the DLC root.
            var configPath = Path.Combine(cookedDir, "Default_DLC_MOD_MPMapPack.bin");
            if (!File.Exists(configPath))
            {
                Console.WriteLine($"  [WARN] Coalesced config not found at {configPath} - map display info will not be captured");
                return result;
            }

            var tlks = LoadTlks(cookedDir);
            if (tlks.Count == 0)
            {
                Console.WriteLine($"  [WARN] No DLC_MOD_MPMapPack_*.tlk files found in {cookedDir} - map display info will not be captured");
                return result;
            }

            var assets = CoalescedConverter.DecompileGame3ToAssets(configPath, stripExtensions: true);
            if (!assets.TryGetValue("BioGame", out var bioGame) ||
                !bioGame.Sections.TryGetValue("sfxonlinefoundation.sfxonlinegamesettings", out var section) ||
                !section.TryGetValue("mastermaplist", out var mapListProperty))
            {
                Console.WriteLine("  [WARN] BioGame.sfxonlinefoundation.sfxonlinegamesettings.mastermaplist not found in config - map display info will not be captured");
                return result;
            }

            foreach (var value in mapListProperty)
            {
                var entry = value.Value;
                var packageMatch = PackageNameField.Match(entry);
                if (!packageMatch.Success)
                {
                    continue;
                }

                var info = new MapDisplayInfo();

                var posMatch = GawPositionField.Match(entry);
                if (posMatch.Success)
                {
                    float.TryParse(posMatch.Groups[1].Value, out var x);
                    float.TryParse(posMatch.Groups[2].Value, out var y);
                    info.GAWMapPositionX = x;
                    info.GAWMapPositionY = y;
                }

                var imageMatch = ImageField.Match(entry);
                if (imageMatch.Success)
                {
                    info.Image = imageMatch.Groups[1].Value;
                }

                ResolveField(PrettyNameField, entry, tlks, info.PrettyName);
                ResolveField(DescriptionField, entry, tlks, info.Description);
                ResolveField(SubtitleField, entry, tlks, info.GAWMapSubtitle);

                // Need to read Image
                   

                result[packageMatch.Groups[1].Value] = info;
            }

            return result;
        }

        private static void ResolveField(Regex fieldRegex, string entry, Dictionary<MELocalization, ME2ME3TalkFile> tlks, Dictionary<MELocalization, string> target)
        {
            var match = fieldRegex.Match(entry);
            if (!match.Success || !int.TryParse(match.Groups[1].Value, out var strRef))
            {
                return;
            }

            foreach (var (loc, tlk) in tlks)
            {
                var text = tlk.FindDataById(strRef, returnNullIfNotFound: true, noQuotes: true);
                if (!string.IsNullOrEmpty(text))
                {
                    target[loc] = text;
                }
            }
        }

        private static Dictionary<MELocalization, ME2ME3TalkFile> LoadTlks(string cookedDir)
        {
            var tlks = new Dictionary<MELocalization, ME2ME3TalkFile>();
            foreach (var path in Directory.GetFiles(cookedDir, "DLC_MOD_MPMapPack_*.tlk"))
            {
                var tlk = new ME2ME3TalkFile(path);
                tlks[tlk.Localization] = tlk;
            }

            return tlks;
        }
    }
}
