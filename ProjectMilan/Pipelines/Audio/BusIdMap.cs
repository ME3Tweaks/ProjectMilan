using System.Data;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace ProjectMilan.Pipelines;

public static class BusIdMap
{
    public static Dictionary<uint, BusIdName> Map = new();

    private static readonly string BusIdMapFileName = "BusIdMap.json";
    
    public static void LoadBusIdMap()
    {
        var mapFileName = Path.Combine(MilanShared.PipelineRoot, "Audio", "Wwise", BusIdMapFileName);
        if (File.Exists(mapFileName))
        {
            var json = File.ReadAllText(mapFileName);
            Map = JsonSerializer.Deserialize<Dictionary<uint, BusIdName>>(json) ?? throw new InvalidOperationException();
        }
    }
    
    public static void RebuildBusIdMap()
    {
        var bankInfoRoot = Path.Combine(MilanShared.PipelineRoot, "Audio", "Wwise");
        var bankInfoName = @"SFXWwise_Init.Init.txt";
        var busMap = new Dictionary<uint, BusIdName>();
        
        var ME3Map = LoadTableFromTabSeparatedTextFile(Path.Combine(bankInfoRoot, "ME3", bankInfoName));
        var LE3Map = LoadTableFromTabSeparatedTextFile(Path.Combine(bankInfoRoot, "LE3", bankInfoName));

        for (int i = 0; i < ME3Map.Rows.Count; i++)
        {
            var ME3Row = ME3Map.Rows[i];
            var LE3Row = LE3Map.Rows[i];
            if (ME3Row.ItemArray[1] is string me3IdStr && LE3Row.ItemArray[1] is string le3IdStr)
            {
                if (me3IdStr != le3IdStr && uint.TryParse(me3IdStr, out var me3Id) && uint.TryParse(le3IdStr, out var le3Id))
                {
                    busMap.TryAdd(me3Id, new BusIdName(le3Id, LE3Row.ItemArray[2] as string));
                }
            }
        }

        var json = JsonSerializer.Serialize(busMap);
        File.WriteAllText(Path.Combine(bankInfoRoot, BusIdMapFileName), json);
        Map = busMap;
    }

    /// <summary>
    /// Loads a datatable of the bus info from an exported Wwise metadata .txt file out of an init bank
    ///
    /// File likely will need to be modified so it just has the bus info.
    /// </summary>
    /// <param name="path">Path to .txt file</param>
    /// <returns></returns>
    /// <exception cref="FileNotFoundException"></exception>
    private static DataTable LoadTableFromTabSeparatedTextFile(string path)
    {
        if (!Path.Exists(path))
        {
            throw new FileNotFoundException();
        }
        DataTable dt = new DataTable();
        StreamReader reader = new StreamReader(path);
        char[] delimiter = { '\t' };
        string[] columnHeaders = reader.ReadLine().Split(delimiter);
        foreach (string column in columnHeaders)
        {
            dt.Columns.Add(column);
        }
        
        while (reader.Peek() > 0)
        {
            DataRow row = dt.NewRow();
            row.ItemArray = reader.ReadLine().Split(delimiter);
            dt.Rows.Add(row);
        }

        return dt;
    }
}

public record BusIdName (uint Id, string? Name);