using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using ProjectMilan;
using System;
using System.Collections.Generic;
using System.IO.Compression;
using System.Text;

namespace ProjectMilanCore
{
    /// <summary>
    /// Shared process initialization code
    /// </summary>
    public static class MilanInitShared
    {
        public static ObjectInstanceDB LoadObjectDB(MEGame game)
        {
            MilanLog.Information($"Loading {game} object database");
            using var zip = ZipFile.OpenRead(Path.Combine(MilanShared.PipelineRoot, "..", "ProjectMilanCore", @"Init", $@"{game}ObjectDatabase.zip"));
            var dbStream = zip.GetEntry($"{game}.bin").Open();
            var memStr = new MemoryStream();
            dbStream.CopyTo(memStr);
            memStr.Position = 0;
            return ObjectInstanceDB.Deserialize(game, memStr);
        }
    }
}
