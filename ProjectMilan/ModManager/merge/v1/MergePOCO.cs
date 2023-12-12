using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Packages;
using Newtonsoft.Json;

namespace ProjectMilan.ModManager.merge.v1
{
    // Root myDeserializedClass = JsonConvert.DeserializeObject<Root>(myJsonResponse);

    public class Change
    {
        public string entryname { get; set; }

        public Scriptupdate scriptupdate { get; set; }
    }

    public class File
    {
        public string filename { get; set; }
        public List<Change> changes { get; set; }
    }

    public class MergePOCO
    {
        [JsonProperty("files")]
        public List<File> Files { get; set; }
        
        [JsonProperty("game")]
        public MEGame Game { get; set; }
    }

    public class Scriptupdate
    {
        [JsonProperty("scriptfilename")]
        public string ScriptFilename { get; set; }
    }


}
