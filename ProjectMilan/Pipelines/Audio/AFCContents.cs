using System.Text.Json;

namespace ProjectMilan.Pipelines.Audio;

public class AFCContents
{
    public Dictionary<string, AFCItem> Streams { get; set; } = new();
    public string AFCName { get; set; } = "";
    public bool ForceUpdateFileName { get; set; }

    public AFCContents(string contentsPath, string afcName)
    {
        AFCName = afcName;
        if(File.Exists(contentsPath))
        {
            var json = File.ReadAllText(contentsPath);
            var newContents = JsonSerializer.Deserialize<AFCContents>(json) ?? throw new InvalidOperationException();
            Streams = newContents.Streams;
            AFCName = newContents.AFCName;
            ForceUpdateFileName = newContents.ForceUpdateFileName;
        }
    }

    public AFCContents()
    {
    }

    public void AddAFCItem(string streamName, long wemSize, long wemOffset)
    {
        Streams.TryAdd(streamName, new AFCItem(wemSize, wemOffset));
    }

    public void WriteToFile(string contentsPath)
    {
        var json = JsonSerializer.Serialize(this);
        File.WriteAllText(contentsPath, json);
    }
}

public record AFCItem(long Size, long Offset);
