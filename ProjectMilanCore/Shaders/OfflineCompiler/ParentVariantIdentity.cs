using System.Globalization;
using System.Numerics;
using System.Security.Cryptography;
using System.Text;
using static LegendaryExplorerCore.Shaders.LE3MaterialShaderCompiler;

namespace ProjectMilanCore.Shaders.OfflineCompiler;

/// <summary>
/// Name and material resource ID for a parent variant compiled against different default texture
/// metadata. Deterministic: the same parent and the same defaults give the same identity in every package,
/// so identical copies can sit in several seekfree packages and whichever loads first is valid.
/// Only computes identities; creating and reparenting variants is not implemented.
/// </summary>
public sealed record ParentVariantIdentity(string ObjectName, Guid MaterialResourceId, string Signature)
{
    /// <param name="parentPath">Instanced full path of the original parent material.</param>
    /// <param name="parentObjectName">The original parent's instanced object name; the variant name extends it.</param>
    /// <param name="parentResourceId">The original parent's material resource ID.</param>
    /// <param name="variantDefaults">Each changed texture parameter and the metadata its variant default must have.</param>
    public static ParentVariantIdentity Create(string parentPath, string parentObjectName, Guid parentResourceId,
        IEnumerable<(string Parameter, TextureCompilationMetadata Metadata)> variantDefaults)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(parentPath);
        ArgumentException.ThrowIfNullOrWhiteSpace(parentObjectName);
        ArgumentNullException.ThrowIfNull(variantDefaults);
        if (parentResourceId == Guid.Empty) throw new ArgumentException("The parent's resource ID is required.", nameof(parentResourceId));

        var entries = variantDefaults.ToArray();
        if (entries.Length == 0) throw new ArgumentException("A variant needs at least one changed default.", nameof(variantDefaults));
        if (entries.Any(e => string.IsNullOrWhiteSpace(e.Parameter) || e.Metadata == null))
            throw new ArgumentException("Every changed default needs a parameter name and metadata.", nameof(variantDefaults));
        if (entries.Select(e => e.Parameter).Distinct(StringComparer.OrdinalIgnoreCase).Count() != entries.Length)
            throw new ArgumentException("A parameter can only appear once.", nameof(variantDefaults));

        // Parameter names compare case-insensitively, like engine names, so the signature does too.
        string signature = string.Join(";", entries
            .OrderBy(e => e.Parameter, StringComparer.OrdinalIgnoreCase)
            .Select(e => $"{e.Parameter.ToLowerInvariant()}={e.Metadata.Dimension}|{e.Metadata.CompressionSettings}|" +
                         $"{Format(e.Metadata.UnpackMin)}|{Format(e.Metadata.UnpackMax)}"));
        byte[] hash = SHA256.HashData(Encoding.UTF8.GetBytes(
            $"{parentPath.ToLowerInvariant()}\n{parentResourceId:D}\n{signature}"));
        string suffix = "_MV" + Convert.ToHexString(hash, 0, 4);
        return new(parentObjectName + suffix, new Guid(hash.AsSpan(0, 16)), signature);
    }

    private static string Format(Vector4 v) => string.Join(",",
        new[] { v.X, v.Y, v.Z, v.W }.Select(f => f.ToString("R", CultureInfo.InvariantCulture)));
}
