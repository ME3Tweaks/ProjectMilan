using System.Text.Json;

namespace ProjectMilan.Pipelines.Audio;

public class AFCInventory
{
    public string AFCFilename { get; set; }
    public Dictionary<string, AFCItem> Streams = new();

    public AFCInventory(string afcFilename, string folder)
    {
        AFCFilename = Path.ChangeExtension(afcFilename, ".afc") ?? "";
        var jsonFile = Path.ChangeExtension(Path.Combine(folder, AFCFilename), ".json");
        if(File.Exists(jsonFile))
        {
            var json = File.ReadAllText(jsonFile);
            Streams = JsonSerializer.Deserialize<Dictionary<string, AFCItem>>(json) ?? throw new InvalidOperationException();
        }
    }

    public void AddAFCItem(string streamName, int wemSize, int wemOffset)
    {
        Streams.TryAdd(streamName, new AFCItem(wemSize, wemOffset));
    }

    public void WriteToFile(string folder)
    {
        var json = JsonSerializer.Serialize(Streams);
        var jsonFile = Path.ChangeExtension(Path.Combine(folder, AFCFilename), ".json");
        File.WriteAllText(jsonFile, json);
    }
}

public record AFCItem(int Size, int Offset);
