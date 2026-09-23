namespace ProjectMilanCore.Config
{
    /// <summary>
    /// A single entry in the multiplayer difficulty ("Challenge") select list.
    /// </summary>
    public class DifficultyEntry
    {
        /// <summary>
        /// Numeric ID this difficulty is selected by.
        /// </summary>
        public int ID { get; set; }

        /// <summary>
        /// TLK String ID of the difficulty's display name.
        /// </summary>
        public int NameStrRefId { get; set; }

        /// <summary>
        /// TLK String ID of the difficulty's all-caps display name.
        /// </summary>
        public int AllCapsNameStrRefId { get; set; }

        /// <summary>
        /// Map-select-UI image reference path, e.g. "GUI_MPImages.MatchSettings.OptChallgDiamond"
        /// </summary>
        public string Image { get; set; }
    }
}
