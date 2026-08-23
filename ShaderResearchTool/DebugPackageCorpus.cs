namespace ShaderResearchTool;

/// <summary>
/// One captured compile job on disk. The JSON body is not read until it is needed, because the
/// corpus is ~48k files each carrying a full Material.usf.
/// </summary>
public sealed record DebugJobRef(
    string JsonPath,
    string PackageFile,
    string MaterialPath,
    string VertexFactory,
    string ShaderType);

/// <summary>
/// The ShaderClient debug package corpus, laid out as
/// <c>&lt;PackageFile&gt;/&lt;MaterialIFP&gt;/&lt;VertexFactory&gt;/&lt;ShaderType&gt;.json</c>.
/// </summary>
public static class DebugPackageCorpus
{
    public static List<DebugJobRef> Enumerate(string root)
    {
        var jobs = new List<DebugJobRef>();
        if (!Directory.Exists(root)) return jobs;

        foreach (var packageDir in Directory.EnumerateDirectories(root))
        {
            var packageFile = Path.GetFileName(packageDir);

            foreach (var materialDir in Directory.EnumerateDirectories(packageDir))
            {
                var materialPath = Path.GetFileName(materialDir);

                foreach (var vfDir in Directory.EnumerateDirectories(materialDir))
                {
                    var vf = Path.GetFileName(vfDir);

                    foreach (var json in Directory.EnumerateFiles(vfDir, "*.json"))
                    {
                        jobs.Add(new DebugJobRef(
                            json,
                            packageFile,
                            materialPath,
                            vf,
                            Path.GetFileNameWithoutExtension(json)));
                    }
                }
            }
        }

        return jobs;
    }
}
