using LegendaryExplorerCore.Gammtek.Extensions;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Unreal;

namespace ShaderResearchTool;

/// <summary>
/// Audits which texture a decooked material actually bound, against the one the shipping material
/// bound, for materials whose shaders diverge in a texture-shaped way.
///
/// This exists because <see cref="TextureParityCommand"/> cannot answer the question: a decooked
/// rebuild has no compiled MaterialResource, so its UniformExpressionTextures list is empty and
/// every such material comes back "NotCompiled". The bindings are still recoverable from the
/// material's expression graph, which is what this reads.
///
/// The interesting output is not the binding itself but the ambiguity behind it. T3D material data
/// names a texture without its package path, so the decooker has to guess; wherever that name has
/// several candidates in the game and they disagree on pixel format, the guess can silently pick a
/// normal map of the wrong format -- which is exactly what the shader diffs show.
/// </summary>
public static class TextureAuditCommand
{
    private sealed class TextureRef
    {
        public string Slot = "";
        public string Ifp = "";
        public string Name = "";
        public string Format = "?";
    }

    public static int Run(ToolPaths paths, string? materialsFile)
    {
        var wanted = ReadMaterialList(paths, materialsFile);
        if (wanted.Count == 0)
        {
            Console.Error.WriteLine("no materials to audit; pass --materials <file> with one instanced full path per line");
            return 1;
        }
        Console.WriteLine($"auditing {wanted.Count} materials");

        var decIndex = PackageObjectIndex.Load(Path.Combine(paths.OutputDir, "index-decooked.json"));
        if (decIndex == null)
        {
            Console.Error.WriteLine("decooked index not found -- run 'texture-parity --rebuild' first");
            return 1;
        }

        Console.WriteLine("loading object DB");
        ObjectInstanceDB db;
        using (var fs = File.OpenRead(paths.ObjectDbPath))
        {
            db = ObjectInstanceDB.Deserialize(MEGame.LE3, fs);
        }

        // Name -> every object in the game with that leaf name. This is the lookup the decooker
        // needs and the DB does not offer directly; it only indexes by instanced full path.
        var byName = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        foreach (var ifp in db.GetAllObjectPaths(false))
        {
            var leaf = LeafName(ifp);
            if (!byName.TryGetValue(leaf, out var list)) byName[leaf] = list = [];
            list.Add(ifp);
        }
        Console.WriteLine($"  {byName.Count} distinct object names indexed");

        var resolver = ShippingMaterialResolver.Load(paths.ObjectDbPath, paths.GameRoot);
        var shipping = resolver.GetMaterials(wanted, Console.WriteLine);

        // Formats for everything either side references, resolved in one batch.
        var allTextures = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var b in shipping.Values) allTextures.UnionWith(b.Textures.Where(t => t.Length > 0));

        var decookedFiles = Directory.EnumerateFiles(paths.DecookedDir, "*.pcc", SearchOption.AllDirectories)
            .GroupBy(Path.GetFileName, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key!, g => g.First(), StringComparer.OrdinalIgnoreCase);
        Console.WriteLine($"  {decookedFiles.Count} decooked packages on disk");

        var decookedBindings = new Dictionary<string, List<TextureRef>>(StringComparer.OrdinalIgnoreCase);
        foreach (var material in wanted)
        {
            var refs = ReadExpressionTextures(decIndex, material, decookedFiles);
            decookedBindings[material] = refs;
            allTextures.UnionWith(refs.Select(r => r.Ifp).Where(t => t.Length > 0));
        }

        // Candidates too, so an ambiguous name can be shown with each candidate's format.
        foreach (var refs in decookedBindings.Values)
        foreach (var r in refs)
            if (byName.TryGetValue(r.Name, out var cands))
                allTextures.UnionWith(cands.Take(12));

        Console.WriteLine("resolving texture formats");
        var shipFormats = resolver.GetTextureFormats(allTextures, Console.WriteLine);
        string FormatOf(string ifp) =>
            decIndex.FormatOf(ifp) ?? (shipFormats.TryGetValue(ifp, out var f) ? f : "?");

        var report = new List<string>
        {
            "material\tside\tslot\ttexture\tformat\tnameCandidates\tcandidateFormats"
        };
        int divergent = 0, ambiguous = 0;

        foreach (var material in wanted)
        {
            Console.WriteLine();
            Console.WriteLine($"=== {material}");

            var ours = decookedBindings[material];
            shipping.TryGetValue(material, out var ship);
            var shipTex = ship?.Textures.Where(t => t.Length > 0).ToList() ?? [];

            if (ours.Count == 0)
                Console.WriteLine("  decooked: no texture expressions found");
            foreach (var r in ours) r.Format = FormatOf(r.Ifp);

            Console.WriteLine($"  shipping bound {shipTex.Count} textures, decooked expressions reference {ours.Count}");

            var shipSet = shipTex.ToDictionary(t => LeafName(t), t => t, StringComparer.OrdinalIgnoreCase);

            foreach (var r in ours)
            {
                byName.TryGetValue(r.Name, out var cands);
                cands ??= [];
                var candFormats = cands.Take(12).Select(FormatOf).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
                bool nameAmbiguous = cands.Count > 1 && candFormats.Count > 1;
                if (nameAmbiguous) ambiguous++;

                shipSet.TryGetValue(r.Name, out var shipMatch);
                var shipFmt = shipMatch != null ? FormatOf(shipMatch) : "-";
                bool formatDiffers = shipMatch != null && !string.Equals(shipFmt, r.Format, StringComparison.OrdinalIgnoreCase);
                if (formatDiffers) divergent++;

                var flag = formatDiffers ? "  <== FORMAT DIFFERS" : nameAmbiguous ? "  <== name ambiguous" : "";
                Console.WriteLine($"    {r.Slot,-34} ours: {r.Format,-12} {r.Ifp}");
                if (shipMatch != null)
                    Console.WriteLine($"    {"",-34} ship: {shipFmt,-12} {shipMatch}{flag}");
                else
                    Console.WriteLine($"    {"",-34} ship: (no texture with this name bound){flag}");
                if (nameAmbiguous)
                    Console.WriteLine($"    {"",-34}       {cands.Count} objects named '{r.Name}', formats: {string.Join(", ", candFormats)}");

                // Simulates the decooker's same-package preference: of the candidates sharing this
                // name, the one owned by the material's own package is the copy the shipping
                // material bound.
                var ownPrefix = material.Split('.')[0] + ".";
                var ownPick = cands.Where(x => x.StartsWith(ownPrefix, StringComparison.OrdinalIgnoreCase))
                                   .OrderBy(x => x, StringComparer.OrdinalIgnoreCase).FirstOrDefault();
                if (formatDiffers)
                {
                    var verdict = ownPick == null ? "NO same-package candidate"
                        : string.Equals(ownPick, shipMatch, StringComparison.OrdinalIgnoreCase)
                            ? $"same-package rule picks {ownPick} -- MATCHES shipping"
                            : $"same-package rule picks {ownPick} -- differs from shipping";
                    Console.WriteLine($"    {"",-34}       {verdict}");
                }

                report.Add(string.Join('\t', material, "decooked", r.Slot, r.Ifp, r.Format,
                    cands.Count.ToString(), string.Join(",", candFormats)));
                if (shipMatch != null)
                    report.Add(string.Join('\t', material, "shipping", r.Slot, shipMatch, shipFmt, "", ""));
            }
        }

        var outPath = Path.Combine(paths.OutputDir, "texture-audit.tsv");
        File.WriteAllLines(outPath, report);
        Console.WriteLine();
        Console.WriteLine("=== texture audit ===");
        Console.WriteLine($"  materials audited          {wanted.Count}");
        Console.WriteLine($"  bindings where format differs {divergent}");
        Console.WriteLine($"  bindings with an ambiguous name (candidates disagree on format) {ambiguous}");
        Console.WriteLine($"  written to {outPath}");
        return 0;
    }

    /// <summary>
    /// Texture bindings recovered from the material's expression graph. Used instead of
    /// UniformExpressionTextures because an uncompiled rebuild has none.
    /// </summary>
    private static List<TextureRef> ReadExpressionTextures(
        PackageObjectIndex decIndex, string materialPath, IReadOnlyDictionary<string, string> decookedFiles)
    {
        var refs = new List<TextureRef>();
        if (!decIndex.Materials.TryGetValue(materialPath, out var binding))
        {
            Console.WriteLine($"    [warn] {materialPath}: not in the decooked index");
            return refs;
        }
        // The index stores only the file name; the decooked tree is nested, so map it back.
        if (!decookedFiles.TryGetValue(Path.GetFileName(binding.SourceFile), out var sourceFile))
        {
            Console.WriteLine($"    [warn] {materialPath}: {binding.SourceFile} not found under the decooked directory");
            return refs;
        }

        IMEPackage? pkg = null;
        try
        {
            pkg = MEPackageHandler.OpenMEPackage(sourceFile);
            var material = pkg.Exports.FirstOrDefault(e =>
                string.Equals(e.InstancedFullPath, materialPath, StringComparison.OrdinalIgnoreCase));
            if (material == null)
            {
                Console.WriteLine($"    [warn] {materialPath}: export not found in {Path.GetFileName(sourceFile)}");
                return refs;
            }

            var expressions = material.GetProperty<ArrayProperty<ObjectProperty>>("Expressions");
            if (expressions == null)
            {
                Console.WriteLine($"    [warn] {materialPath}: no Expressions array ({material.ClassName})");
                return refs;
            }

            foreach (var exprRef in expressions)
            {
                if (pkg.GetEntry(exprRef.Value) is not ExportEntry expr) continue;

                // Every texture-bearing expression exposes the object under "Texture".
                var texProp = expr.GetProperty<ObjectProperty>("Texture");
                if (texProp == null || texProp.Value == 0) continue;

                var tex = pkg.GetEntry(texProp.Value);
                if (tex == null) continue;

                var paramName = expr.GetProperty<NameProperty>("ParameterName")?.Value.Name;
                refs.Add(new TextureRef
                {
                    Slot = paramName ?? expr.ObjectName.Name,
                    Ifp = tex.InstancedFullPath,
                    Name = LeafName(tex.InstancedFullPath)
                });
            }
        }
        catch (Exception e)
        {
            Console.Error.WriteLine($"  could not read expressions for {materialPath}: {e.Message}");
        }
        finally
        {
            pkg?.Dispose();
        }
        return refs;
    }

    private static string LeafName(string ifp)
    {
        int dot = ifp.LastIndexOf('.');
        return dot < 0 ? ifp : ifp[(dot + 1)..];
    }

    /// <summary>
    /// Reads the material list, defaulting to the divergence report the cluster analysis writes so
    /// the two commands chain without the caller restating the list.
    /// </summary>
    private static List<string> ReadMaterialList(ToolPaths paths, string? materialsFile)
    {
        var path = materialsFile ?? Path.Combine(paths.OutputDir, "texture-divergence-materials.tsv");
        if (!File.Exists(path)) return [];

        var list = new List<string>();
        foreach (var line in File.ReadLines(path))
        {
            if (line.Length == 0 || line.StartsWith('#') || line.StartsWith("package\t")) continue;
            var parts = line.Split('\t');
            // Either "package<TAB>material<TAB>..." from the divergence report, or a bare path.
            var ifp = parts.Length >= 2 ? $"{parts[0]}.{parts[1]}" : parts[0].Trim();
            // The divergence report's package column is the package file stem; the material column
            // is already the path within it.
            if (parts.Length >= 7 && !bool.Parse(parts[6].Trim())) continue; // skip out-of-scope Users.*
            if (!list.Contains(ifp)) list.Add(ifp);
        }
        return list;
    }
}
