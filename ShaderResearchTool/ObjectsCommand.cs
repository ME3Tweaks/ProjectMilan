using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;

namespace ShaderResearchTool;

/// <summary>
/// Queries the ObjectInstanceDB directly: every object with a given leaf name, or every object
/// under a given path prefix. The DB indexes by instanced full path only, so both of these
/// otherwise need a full enumeration.
///
/// Exists to answer "does the shipping game have objects our decooked rebuild does not", which is
/// invisible to the parity report -- that only compares materials present on both sides.
/// </summary>
public static class ObjectsCommand
{
    public static int Run(ToolPaths paths, string? name, string? prefix)
    {
        if (string.IsNullOrWhiteSpace(name) && string.IsNullOrWhiteSpace(prefix))
        {
            Console.Error.WriteLine("pass --name <objectName> or --prefix <path prefix>");
            return 1;
        }

        ObjectInstanceDB db;
        using (var fs = File.OpenRead(paths.ObjectDbPath))
        {
            db = ObjectInstanceDB.Deserialize(MEGame.LE3, fs);
        }

        var matches = new List<string>();
        foreach (var ifp in db.GetAllObjectPaths(false))
        {
            if (prefix != null && !ifp.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) continue;
            if (name != null)
            {
                int dot = ifp.LastIndexOf('.');
                var leaf = dot < 0 ? ifp : ifp[(dot + 1)..];
                if (!string.Equals(leaf, name, StringComparison.OrdinalIgnoreCase)) continue;
            }
            matches.Add(ifp);
        }

        matches.Sort(StringComparer.OrdinalIgnoreCase);
        Console.WriteLine($"{matches.Count} matching objects" +
                          (db.HasClassNames ? "  (database carries class names)" : "  (database has no class table -- version 2 or older)"));
        foreach (var m in matches)
        {
            var files = db.GetFilesContainingObject(m);
            var className = db.GetClassName(m);
            Console.WriteLine($"  [{className ?? "?"}] {m}");
            if (files is { Count: > 0 })
            {
                Console.WriteLine($"      in: {string.Join(", ", files.Take(4))}{(files.Count > 4 ? $" (+{files.Count - 4})" : "")}");
            }
        }
        return 0;
    }
}
