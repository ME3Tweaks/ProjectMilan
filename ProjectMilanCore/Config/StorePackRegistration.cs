using System.Globalization;
using LegendaryExplorerCore.Coalesced;
using ProjectMilanCore;

namespace ProjectMilanCore.Config
{
    /// <summary>
    /// Writes a multiplayer store pack registration into whichever <see cref="MilanPipelinesShared.ConfigBundle"/>
    /// is currently active - the store listing (StoreInfoArray), its contents (PackList), and optionally its
    /// consumable mapping and per-player purchase counter. The vanilla packs stay as static XML
    /// (MergedConfig\BioGame.xml) - this only appends new ones.
    /// </summary>
    public static class StorePackRegistration
    {
        public static void RegisterStorePack(StorePackEntry entry)
        {
            if (entry.PerPlayerMax != null && entry.PlayerVariableId == null)
                throw new Exception($"Store pack {entry.PackName} has a PerPlayerMax but no PlayerVariableId to store its purchase count in");
            if (entry.Contents.Count == 0)
                throw new Exception($"Store pack {entry.PackName} has no contents");

            var game = MilanPipelinesShared.ConfigBundle.GetAsset("BioGame");
            var manager = game.GetOrAddSection("sfxgamempcontent.sfxgawreinforcementmanager");
            manager.AddEntry(new CoalesceProperty("storeinfoarray", new CoalesceValue(BuildStoreInfo(entry), CoalesceParseAction.AddUnique)));
            foreach (var slot in entry.Contents)
            {
                manager.AddEntry(new CoalesceProperty("packlist", new CoalesceValue(BuildPackSlot(entry.PackName, slot), CoalesceParseAction.AddUnique)));
            }

            if (entry.OfferId != null)
            {
                manager.AddEntry(new CoalesceProperty("consumableidpacknamemap", new CoalesceValue($"(ID={entry.OfferId}, PackName=\"{entry.PackName}\")", CoalesceParseAction.AddUnique)));
            }

            if (entry.PlayerVariableId != null)
            {
                game.GetOrAddSection("sfxgame.sfxgameconfig").AddEntry(new CoalesceProperty("mpplayervariablemappings",
                    new CoalesceValue($"(ClassName=\"{entry.PackName}\",ID={entry.PlayerVariableId})", CoalesceParseAction.AddUnique)));
            }
        }

        private static string BuildStoreInfo(StorePackEntry entry)
        {
            var parts = new List<string>
            {
                $"nID={entry.ID}",
                $"PackName=\"{entry.PackName}\"",
                $"Title={entry.TitleStrRefId}",
            };
            if (entry.SubTitleStrRefId != null)
                parts.Add($"SubTitle={entry.SubTitleStrRefId}");
            parts.Add($"Description={entry.DescriptionStrRefId}");
            if (entry.Visible.Count > 0)
                parts.Add($"Visible=({string.Join(",", entry.Visible.Select(ids => $"(and=({string.Join(",", ids)}))"))})");
            if (entry.OfferId != null)
                parts.Add($"OfferId={entry.OfferId}");
            if (entry.ExpirationTime != null)
                parts.Add($"ExpirationTime={entry.ExpirationTime}");
            parts.Add($"CreditCost={entry.CreditCost}");
            if (entry.PromoStrRefId != null)
                parts.Add($"srPromoString={entry.PromoStrRefId}");
            if (entry.PerPlayerMax != null)
                parts.Add($"PerPlayerMax={entry.PerPlayerMax}");
            parts.Add($"ImageData=(ImageLocation=EStoreImageLocation_Local, ImageReference=\"{entry.Image}\")");
            parts.Add($"RevealIntroTextureRef=\"{entry.RevealIntroTextureRef}\"");
            parts.Add($"RevealIntroHoloTextureRef=\"{entry.RevealIntroHoloTextureRef}\"");
            parts.Add($"RevealIntroSound={entry.RevealIntroSound}");
            return $"({string.Join(", ", parts)})";
        }

        private static string BuildPackSlot(string packName, StorePackSlot slot)
        {
            // A lone pool gets drawn every time, so vanilla leaves its weight off
            var pools = slot.Pools.Count == 1
                ? $"(PoolName=\"{slot.Pools[0].PoolName}\")"
                : string.Join(",", slot.Pools.Select(p => $"(PoolName=\"{p.PoolName}\",Weight={p.Weight.ToString("0.0##", CultureInfo.InvariantCulture)})"));
            var backup = slot.BackupPool != null ? $", BackupPool=\"{slot.BackupPool}\"" : "";
            return $"(PackName=\"{packName}\", Quantity={slot.Quantity}, Pools=({pools}){backup})";
        }
    }
}
