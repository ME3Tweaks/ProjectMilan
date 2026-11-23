namespace ProjectMilan.Pipelines.Store
{
    /// <summary>
    /// Picks the image the Direct Buy store shows for a card. Cards use the game's notification images
    /// (GUI_Icons.Weapons.*_256x128), which LE3 remastered at anything from 512x256 to 2048x1024, some of them as poor
    /// upscales. The codex copies of the same art (GUI_Codex_Weapons_Images.Weapons.*_512x256) are 1024x512 for every
    /// weapon and mod, and are mapped to the merged weapon UI packages, so the store uses the copy weapon select already loads.
    /// </summary>
    internal static class DirectBuyImages
    {
        private const string NotificationSuffix = "_256x128";
        private const string LargeSuffix = "_512x256";
        private const string NotificationWeaponGroup = "GUI_Icons.Weapons.";
        private const string CodexWeaponGroup = "GUI_Codex_Weapons_Images.Weapons.";

        /// <summary>
        /// The image the store shows for a card
        /// </summary>
        /// <param name="builtImages">Images ImagePackageBuilder built (all of them mapped)</param>
        /// <param name="mappedImages">Every dynamic load mapped object</param>
        public static string GetStoreImage(string cardImage, IReadOnlySet<string> builtImages, IReadOnlySet<string> mappedImages)
        {
            if (!cardImage.EndsWith(NotificationSuffix, StringComparison.OrdinalIgnoreCase))
            {
                // Not a notification image 
                return cardImage;
            }

            var stem = cardImage[..^NotificationSuffix.Length];
            if (stem.StartsWith(NotificationWeaponGroup, StringComparison.OrdinalIgnoreCase))
            {
                var codex = $"{CodexWeaponGroup}{stem[NotificationWeaponGroup.Length..]}{LargeSuffix}";
                if (mappedImages.Contains(codex))
                {
                    // Has a codex image
                    return codex;
                }
            }

            // Take large suffix version if available
            var sibling = $"{stem}{LargeSuffix}";
            return builtImages.Contains(sibling) ? sibling : cardImage;
        }
    }
}
