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
            var dir = new DirectoryInfo(MilanShared.PipelineRoot);
            while (dir != null && !Directory.Exists(Path.Combine(dir.FullName, "ProjectMilanCore")))
            {
                dir = dir.Parent;
            }
            if (dir == null)
                throw new DirectoryNotFoundException("Could not locate a parent directory containing a 'ProjectMilanCore' folder.");
            var zipPath = Path.Combine(dir.FullName, "ProjectMilanCore", "Init", $"{game}ObjectDatabase.zip");
            using var zip = ZipFile.OpenRead(zipPath);
            var dbStream = zip.GetEntry($"{game}.bin").Open();
            var memStr = new MemoryStream();
            dbStream.CopyTo(memStr);
            memStr.Position = 0;
            return ObjectInstanceDB.Deserialize(game, memStr);
        }
    }
}
