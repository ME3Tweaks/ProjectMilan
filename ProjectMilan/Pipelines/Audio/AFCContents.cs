using System.Text.Json;

namespace ProjectMilan.Pipelines.Audio;

public class AFCContents
{
    public Dictionary<string, AFCItem> Streams = new();

    public AFCContents(string contentsPath)
    {
        if(File.Exists(contentsPath))
        {
            var json = File.ReadAllText(contentsPath);
            Streams = JsonSerializer.Deserialize<Dictionary<string, AFCItem>>(json) ?? throw new InvalidOperationException();
        }
    }

    public void AddAFCItem(string streamName, long wemSize, long wemOffset)
    {
        Streams.TryAdd(streamName, new AFCItem(wemSize, wemOffset));
    }

    public void WriteToFile(string contentsPath)
    {
        var json = JsonSerializer.Serialize(Streams);
        File.WriteAllText(contentsPath, json);
    }
}

public record AFCItem(long Size, long Offset);
