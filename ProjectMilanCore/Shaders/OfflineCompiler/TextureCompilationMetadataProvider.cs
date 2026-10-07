using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Packages.CloningImportingAndRelinking;
using LegendaryExplorerCore.Shaders;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// Supplies the compile-affecting metadata of a texture reference. The reference's identity is never
/// replaced: the compiler keeps the graph's original entry. A null result fails translation.
/// </summary>
public interface ITextureCompilationMetadataProvider
{
    TextureCompilationMetadata? GetMetadata(IEntry textureReference);

    /// <summary>Every lookup made so far, including failures and where the metadata came from.</summary>
    IReadOnlyList<TextureMetadataResolution> Resolutions { get; }
}

public sealed record TextureMetadataResolution(string Reference, string? SourcePackage,
    TextureCompilationMetadata? Metadata, string? Failure);

/// <summary>Candidate package files that may contain an imported texture, most preferred first.</summary>
public delegate IEnumerable<string> TextureDonorLocator(ImportEntry import);

/// <summary>
/// Request-scoped metadata provider. Exports are read from their already loaded properties; imports are
/// looked up in donor packages through <see cref="LE3TextureMetadataReader"/>, which reads only the
/// package tables and texture properties, never mips, bulk data or TFCs. Results are cached per
/// reference. Not thread-safe. Dispose to close the donor readers.
/// </summary>
public sealed class PackageTextureMetadataProvider(TextureDonorLocator? donorLocator = null)
    : ITextureCompilationMetadataProvider, IDisposable
{
    private readonly Dictionary<IEntry, TextureCompilationMetadata?> cache = new(ReferenceEqualityComparer.Instance);
    private readonly Dictionary<string, LE3TextureMetadataReader?> readers = new(StringComparer.OrdinalIgnoreCase);
    private readonly List<TextureMetadataResolution> resolutions = [];
    private bool disposed;

    public IReadOnlyList<TextureMetadataResolution> Resolutions => resolutions;

    public TextureCompilationMetadata? GetMetadata(IEntry textureReference)
    {
        ObjectDisposedException.ThrowIf(disposed, this);
        ArgumentNullException.ThrowIfNull(textureReference);
        if (cache.TryGetValue(textureReference, out var cached)) return cached;

        var resolution = textureReference switch
        {
            ExportEntry export => FromExport(export),
            ImportEntry import => FromImport(import),
            _ => Fail(textureReference, null, "Unknown entry type.")
        };
        resolutions.Add(resolution);
        cache[textureReference] = resolution.Metadata;
        return resolution.Metadata;
    }

    private static TextureMetadataResolution FromExport(ExportEntry export)
    {
        if (export.Game != MEGame.LE3) return Fail(export, export.FileRef.FilePath, $"Texture is from {export.Game}, not LE3.");
        if (!export.IsA("Texture2D") && !export.IsA("TextureCube"))
            return Fail(export, export.FileRef.FilePath, $"{export.ClassName} is not a Texture2D or TextureCube.");
        if (!export.IsDataLoaded())
            return Fail(export, export.FileRef.FilePath, "Export data is not loaded; open the package normally or supply a donor.");
        try
        {
            // Properties only. The in-memory package wins over its file, which may be older.
            return new(export.InstancedFullPath, export.FileRef.FilePath, TextureCompilationMetadata.FromExport(export), null);
        }
        catch (Exception ex)
        {
            return Fail(export, export.FileRef.FilePath, ex.Message);
        }
    }

    private TextureMetadataResolution FromImport(ImportEntry import)
    {
        if (donorLocator == null) return Fail(import, null, "Imported texture and no donor locator was supplied.");
        var tried = new List<string>();
        foreach (var path in donorLocator(import))
        {
            var reader = GetReader(path, tried);
            if (reader == null) continue;
            var export = reader.Package.FindExport(import.InstancedFullPath, import.ClassName);
            if (export == null)
            {
                tried.Add($"{Path.GetFileName(path)}: not present");
                continue;
            }
            try
            {
                return new(import.InstancedFullPath, path, reader.Read(export), null);
            }
            catch (Exception ex)
            {
                // A donor that has the object but unreadable properties is an error, not a reason to try the next one.
                return Fail(import, path, ex.Message);
            }
        }
        return Fail(import, null, tried.Count == 0 ? "No donor candidates." : "Not found in donors: " + string.Join("; ", tried));
    }

    private LE3TextureMetadataReader? GetReader(string path, List<string> tried)
    {
        if (readers.TryGetValue(path, out var existing)) return existing;
        LE3TextureMetadataReader? reader = null;
        try
        {
            if (File.Exists(path)) reader = LE3TextureMetadataReader.Open(path);
            else tried.Add($"{Path.GetFileName(path)}: file missing");
        }
        catch (Exception ex)
        {
            tried.Add($"{Path.GetFileName(path)}: {ex.Message}");
        }
        readers[path] = reader;
        return reader;
    }

    private static TextureMetadataResolution Fail(IEntry entry, string? source, string reason)
        => new(entry.InstancedFullPath, source, null, reason);

    public void Dispose()
    {
        if (disposed) return;
        disposed = true;
        foreach (var reader in readers.Values) reader?.Dispose();
        readers.Clear();
    }
}

public static class TextureDonorLocators
{
    /// <summary>
    /// Files the object database lists for the import's path. Files under <paramref name="preferredRoots"/>
    /// come first, so converted output packages win over the vanilla files they were built from.
    /// </summary>
    public static TextureDonorLocator FromObjectDatabase(ObjectInstanceDB database, string gameRoot,
        IReadOnlyList<string>? preferredRoots = null)
    {
        ArgumentNullException.ThrowIfNull(database);
        ArgumentException.ThrowIfNullOrWhiteSpace(gameRoot);
        var roots = (preferredRoots ?? []).Select(r => Path.GetFullPath(r).TrimEnd('\\', '/') + Path.DirectorySeparatorChar).ToArray();
        return import =>
        {
            var files = database.GetFilesContainingObject(import.InstancedFullPath, import.FileRef.Localization);
            if (files == null) return [];
            // Database paths are relative to the game root; packages registered at runtime may be absolute.
            return files.Select(f => Path.GetFullPath(Path.Combine(gameRoot, f)))
                .OrderBy(f => PreferredIndex(f, roots));
        };
    }

    /// <summary>Tries each locator in order, skipping files already offered.</summary>
    public static TextureDonorLocator Concat(params TextureDonorLocator[] locators)
    {
        ArgumentNullException.ThrowIfNull(locators);
        return import => locators.SelectMany(l => l(import)).Distinct(StringComparer.OrdinalIgnoreCase);
    }

    private static int PreferredIndex(string file, string[] roots)
    {
        for (int i = 0; i < roots.Length; i++)
            if (file.StartsWith(roots[i], StringComparison.OrdinalIgnoreCase)) return i;
        return roots.Length;
    }
}
