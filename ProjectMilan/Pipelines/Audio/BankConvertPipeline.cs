using System.Collections.Concurrent;
using System.Diagnostics;
using LegendaryExplorerCore.Packages;
using ME3Tweaks.Wwiser;
using ME3Tweaks.Wwiser.Model;
using ME3Tweaks.Wwiser.Model.Hierarchy;
using ME3Tweaks.Wwiser.Model.Hierarchy.Enums;
using ProjectMilan.Utility;
using WwiseBankLEC = LegendaryExplorerCore.Unreal.BinaryConverters.WwiseBank;

namespace ProjectMilan.Pipelines.Audio;

/// <summary>
/// Pipeline for converting WwiseBanks from ME3 to LE3 using the Wwiser.NET tool
/// </summary>
internal static class BankConvertPipeline
{
    private const string LOG_CATEGORY = @"MILAN-Audio-WwiserConvert";

    public static void RunPipeline(List<MilanBankConvertInfo> bankInventory)
    {
        MilanLog.Information("Converting banks using Wwiser.NET", customPrefix: LOG_CATEGORY);

        var packageMap = MapBanksToPackages(bankInventory);

        var bankCacheFolder = Path.Combine(MilanShared.PipelineRoot, "Audio", "ConvertedBankCache");
        Directory.CreateDirectory(bankCacheFolder);
        Utilities.DeleteFilesAndFoldersRecursively(bankCacheFolder, deleteDirectoryItself:false);
        var bankCache = new ConcurrentDictionary<string, string>();
        
        //BusIdMap.RebuildBusIdMap(); // run this when more bus ids have been found
        BusIdMap.LoadBusIdMap();
        
        Parallel.ForEach(packageMap,
            new ParallelOptions() { MaxDegreeOfParallelism = /* 1 */ Program.Settings.MaxThreads }, map =>
            {
                foreach (var b in map.Value)
                {
                    if(bankCache.TryGetValue(b.LocalizedInfo.ToString(), out var value))
                    {
                        MilanLog.Information(
                            $" - Already converted {b.LocalizedInfo} - copying from cache to {Path.GetFileName(b.LE3BankExport.FileRef.FilePath)}",
                            customPrefix: LOG_CATEGORY);
                        var bank = File.ReadAllBytes(value);
                        WwiseBankLEC.WriteBankRaw(bank, b.LE3BankExport);
                    }
                    else
                    {
                        MilanLog.Information(
                            $" - Converting {b.LocalizedInfo} in {Path.GetFileName(b.LE3BankExport.FileRef.FilePath)}",
                            customPrefix: LOG_CATEGORY);
                        if (b.BankParser is null) continue;
                        try
                        {
                            var bankArray = ConvertBank(b).ToArray();
                            WwiseBankLEC.WriteBankRaw(bankArray, b.LE3BankExport);
                            
                            var cacheFileName = Path.Combine(bankCacheFolder, $"{b.LocalizedInfo}.bnk");
                            if (bankCache.TryAdd(b.LocalizedInfo.ToString(), cacheFileName))
                            {
                                File.WriteAllBytes(cacheFileName, bankArray);
                            }
                        }
                        catch (Exception e)
                        {
                            MilanLog.Exception(e, $"Error converting WwiseBank {b.LE3BankExport.InstancedFullPath}",
                                customPrefix: LOG_CATEGORY);
                        }
                    }
                }

                // Save package
                map.Key.Save();
            });
    }

    private static Dictionary<IMEPackage, List<MilanBankConvertInfo>> MapBanksToPackages(List<MilanBankConvertInfo> bankInventory)
    {
        var packageMap = new Dictionary<IMEPackage, List<MilanBankConvertInfo>>();
        foreach (var f in bankInventory)
        {
            if (!packageMap.TryGetValue(f.LE3BankExport.FileRef, out var list))
            {
                list = new List<MilanBankConvertInfo>();
                packageMap[f.LE3BankExport.FileRef] = list;
            }

            list.Add(f);
        }

        return packageMap;
    }

    private static MemoryStream ConvertBank(MilanBankConvertInfo b)
    {
        if (b.BankParser is null) return new MemoryStream();
        
        b.BankParser.Deserialize(); // Deserialize binary into object graph

        b.BankParser.ConvertToVersion(134); // Run Wwiser version convert
        
        if (b.BankParser.WwiseBank != null)
        {
            SetMilanSpecificBankData(b.BankParser.WwiseBank);
        }

        var dataOut = new MemoryStream();
        b.BankParser.SerializeTo(dataOut);
        return dataOut;
    }

    private static void SetMilanSpecificBankData(WwiseBank bank)
    {
        bank.BKHD.ProjectId = 7572;
        bank.BKHD.LanguageIdStringHash = bank.BKHD.LanguageId switch
        {
            LanguageId.SFX => 393239870,
            LanguageId.English_US => 684519430,
            //TODO: Rest of language ids
            _ => 0
        };
        
        // No STID chunks found on LE wwise banks
        bank.STID = null;

        // Padding that seems to be found on banks that ordinarily would have zero?
        if (bank.DATA is null)
        {
            bank.BKHD.Padding.Padding = new byte[4];
        }

        if (bank.HIRC is null) return;
        foreach (var i in bank.HIRC.Items)
        {
            if (i.Item is IHasNode itemWithNode)
            {
                // Bus IDs changed from OT to LE.
                UpdateBusIdToLE(itemWithNode);
            }
        }
    }

    private static void UpdateBusIdToLE(IHasNode itemWithNode)
    {
        var busId = itemWithNode.NodeBaseParameters.OverrideBusId;
        if (busId != 0)
        {
            if (BusIdMap.Map.TryGetValue(busId, out var value))
            {
                itemWithNode.NodeBaseParameters.OverrideBusId = value.Id;
            }
            else
            {
                MilanLog.Warning(
                    $" - Found no matching LE3 bus for AkBus ID {busId}",
                    customPrefix: LOG_CATEGORY);
            }
        }
    }

    private static void BankDebug(WwiseBank bank)
    {
        Debug.Assert(bank.HIRC != null, "bank.HIRC != null");
        var idToItem = new Dictionary<uint, HircItemContainer>();
        foreach (var i in bank.HIRC.Items)
        {
            idToItem.Add(i.Item.Id, i);
        }

        foreach (var i in bank.HIRC.Items)
        {
            if (i.Type.Value is HircType.ActorMixer && i.Item is ActorMixer am)
            {
                if (!idToItem.ContainsKey(am.NodeBaseParameters.DirectParentId))
                {
                    MilanLog.Information($"Wwise Id {am.NodeBaseParameters.DirectParentId} is not in this bank!");
                }
            }
        }
    }
}