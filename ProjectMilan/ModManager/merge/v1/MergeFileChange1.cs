using System.Diagnostics;
using Newtonsoft.Json;

namespace ME3TweaksModManager.modmanager.objects.mod.merge.v1
{
    /// <summary>
    /// Describes a change to a single export (or at least specified by a single target if it depends on that export)
    /// </summary>
    public class MergeFileChange1
    {
        [JsonProperty(@"entryname")] public string EntryName { get; set; }
        [JsonProperty(@"propertyupdates")] public List<PropertyUpdate1> PropertyUpdates { get; set; }
        [JsonProperty(@"disableconfigupdate")] public bool DisableConfigUpdate { get; set; }
        public bool ShouldSerializeDisableConfigUpdate()
        {
            // don't serialize the Manager property if an employee is their own manager
            return DisableConfigUpdate;
        }
        [JsonProperty(@"assetupdate")] public AssetUpdate1 AssetUpdate { get; set; }
        [JsonProperty(@"newassetupdate")] public AssetUpdate1 NewAssetUpdate { get; set; }

        [JsonProperty(@"scriptupdate")] public ScriptUpdate1 ScriptUpdate { get; set; }
        [JsonProperty(@"sequenceskipupdate")] public SequenceSkipUpdate1 SequenceSkipUpdate { get; set; }
        [JsonProperty(@"addtoclassorreplace")] public AddToClassOrReplace1 AddToClassOrReplace { get; set; }

        [JsonIgnore] public MergeFile1 Parent;
        [JsonIgnore] public MergeMod1 OwningMM => Parent.OwningMM;

        public void SetupParent(MergeFile1 parent)
        {
            Parent = parent;
            if (AssetUpdate != null)
                AssetUpdate.Parent = this;
        }

        public void Validate()
        {
            if (PropertyUpdates != null)
            {
                foreach (var pu in PropertyUpdates)
                {
                    pu.Validate();
                }
            }

            AssetUpdate?.Validate();
            ScriptUpdate?.Validate();
            SequenceSkipUpdate?.Validate();
            AddToClassOrReplace?.Validate();
        }

        /// <summary>
        /// Get the weight of this merge change
        /// </summary>
        /// <returns></returns>
        public int GetMergeWeight()
        {
            if (AssetUpdate != null)
                return WEIGHT_ASSETUPDATE;
            if (ScriptUpdate != null)
                return WEIGHT_SCRIPTUPDATE;
            if (AddToClassOrReplace != null)
                return WEIGHT_SCRIPTUPDATE * AddToClassOrReplace.ScriptFileNames.Length;
            if (SequenceSkipUpdate != null)
                return WEIGHT_SEQSKIPUPDATE;
            if (PropertyUpdates != null)
                return WEIGHT_PROPERTYUPDATE * PropertyUpdates.Count;
            if (DisableConfigUpdate)
                return WEIGHT_DISABLECONFIGUPDATE;
            Debug.WriteLine(@"Merge weight not calculated: All merge variables were null, does this calculation need updated?");
            return 0;
        }

        internal const int WEIGHT_PROPERTYUPDATE = 2;

        internal const int WEIGHT_DISABLECONFIGUPDATE = 1;

        internal const int WEIGHT_SEQSKIPUPDATE = 2;

        internal const int WEIGHT_SCRIPTUPDATE = 15;

        internal const int WEIGHT_ASSETUPDATE = 7;
    }

    public class PropertyUpdate1
    {
        [JsonProperty(@"propertyname")]
        public string PropertyName { get; set; }

        [JsonProperty(@"propertytype")]
        public string PropertyType { get; set; }

        [JsonProperty(@"propertyvalue")]
        public string PropertyValue { get; set; }

        [JsonProperty(@"propertyasset")]
        public string PropertyAsset { get; set; }
        //         public bool ApplyUpdate(IMEPackage package, PropertyCollection properties, ExportEntry targetExport, MergeAssetCache1 assetsCache, GameTarget gameTarget)
        public void Validate()
        {
            if (PropertyType == @"EnumProperty")
            {
                if (PropertyValue.Split('.').Length != 2)
                    throw new Exception("Invalid enum property value!");
            }
        }
    }

    public class AssetUpdate1
    {
        /// <summary>
        /// Name of asset file
        /// </summary>
        [JsonProperty(@"assetname")]
        public string AssetName { get; set; }

        /// <summary>
        /// If the entry name can be null, indicating we must merge this asset into the file as new (Mod Manager 8.1)
        /// </summary>
        [JsonProperty(@"canmergeasnew")]
        public bool CanMergeAsNew { get; set; } = false;

        /// <summary>
        /// Entry in the asset to use as porting source
        /// </summary>
        [JsonProperty(@"entryname")]
        public string EntryName { get; set; }

        [JsonIgnore] public MergeFileChange1 Parent;
        [JsonIgnore] public MergeMod1 OwningMM => Parent.OwningMM;


        public void Validate()
        {
        }
    }

    public class ScriptUpdate1
    {
        /// <summary>
        /// Name of text file containing the script
        /// </summary>
        [JsonProperty(@"scriptfilename")]
        public string ScriptFileName { get; set; }

        [JsonProperty(@"scripttext")]
        public string ScriptText { get; set; }

        [JsonIgnore] public MergeFileChange1 Parent;
        [JsonIgnore] public MergeMod1 OwningMM => Parent.OwningMM;


        public void Validate()
        {

        }
    }

    public class AddToClassOrReplace1
    {
        /// <summary>
        /// Name of text file containing the script
        /// </summary>
        [JsonProperty(@"scriptfilenames")]
        public string[] ScriptFileNames { get; set; }


        [JsonProperty(@"scripts")]
        public string[] Scripts { get; set; }

        [JsonIgnore] public MergeFileChange1 Parent;
        [JsonIgnore] public MergeMod1 OwningMM => Parent.OwningMM;


        public void Validate()
        {

        }
    }

    public class SequenceSkipUpdate1
    {
        /// <summary>
        /// The MD5 of the target entry. This is to ensure this doesn't apply to a modified object as this could easily break the game.
        /// This limits functionality of this feature
        /// </summary>
        [JsonProperty(@"entrymd5")]
        public string EntryMD5 { get; set; }

        /// <summary>
        /// What outbound link to set as the one to skip through to
        /// </summary>
        [JsonProperty(@"outboundlinknametouse")]
        public string OutboundLinkNameToUse { get; set; }

        [JsonIgnore] public MergeFileChange1 Parent;
        [JsonIgnore] public MergeMod1 OwningMM => Parent.OwningMM;

        public void Validate()
        {

        }
    }
}
