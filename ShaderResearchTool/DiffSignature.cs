using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace ShaderResearchTool;

/// <summary>
/// Reduces a pair of decompiled shaders to a signature describing *how* they differ, so that
/// mismatches sharing a root cause group together.
///
/// Bytecode is useless for this: register allocation and instruction scheduling make two shaders
/// with the same underlying mistake look unrelated. Normalising registers and literals out of the
/// decompiled HLSL leaves the structural change, which is what actually identifies the cause.
/// </summary>
public static partial class DiffSignature
{
    [GeneratedRegex(@"\b[rvoutxs]\d+\b", RegexOptions.IgnoreCase)]
    private static partial Regex RegisterPattern();

    /// <summary>
    /// Swizzles on a normalised register. Which components a temporary happens to occupy is an
    /// artifact of register allocation, not of the shader logic, so two compiles of the same code
    /// routinely disagree here. Left in, every such disagreement became its own singleton cluster.
    /// </summary>
    [GeneratedRegex(@"(?<=REG)\.[xyzwrgba]{1,4}\b")]
    private static partial Regex SwizzlePattern();

    [GeneratedRegex(@"-?\d+\.\d+(e[+-]?\d+)?|(?<![A-Za-z_])\d+(?![A-Za-z_])")]
    private static partial Regex NumberPattern();

    [GeneratedRegex(@"\s+")]
    private static partial Regex WhitespacePattern();

    /// <summary>
    /// Strips the things that vary between two compiles of the same logic — register names,
    /// numeric literals, whitespace — leaving the shape of the statement.
    /// </summary>
    public static string NormalizeLine(string line)
    {
        var s = line.Trim();
        if (s.Length == 0) return s;

        s = RegisterPattern().Replace(s, "REG");
        s = SwizzlePattern().Replace(s, ".SWZ");
        s = NumberPattern().Replace(s, "NUM");
        s = WhitespacePattern().Replace(s, " ");
        return s;
    }

    /// <summary>
    /// Lines present in one side but not the other, normalised, as an order-insensitive multiset.
    /// Order is deliberately discarded: the same mistake can land at different offsets depending on
    /// how much unrelated code surrounds it.
    /// </summary>
    public static (List<string> OnlyOurs, List<string> OnlyReference) Delta(string ours, string reference)
    {
        var ourCounts = CountLines(ours);
        var refCounts = CountLines(reference);

        var onlyOurs = new List<string>();
        var onlyRef = new List<string>();

        foreach (var (line, count) in ourCounts)
        {
            refCounts.TryGetValue(line, out var other);
            for (int i = 0; i < count - other; i++) onlyOurs.Add(line);
        }

        foreach (var (line, count) in refCounts)
        {
            ourCounts.TryGetValue(line, out var other);
            for (int i = 0; i < count - other; i++) onlyRef.Add(line);
        }

        onlyOurs.Sort(StringComparer.Ordinal);
        onlyRef.Sort(StringComparer.Ordinal);
        return (onlyOurs, onlyRef);
    }

    private static Dictionary<string, int> CountLines(string text)
    {
        var counts = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var raw in text.Split('\n'))
        {
            var line = NormalizeLine(raw);
            if (line.Length == 0) continue;
            counts.TryGetValue(line, out var c);
            counts[line] = c + 1;
        }
        return counts;
    }

    /// <summary>Short stable hash of the delta. Identical signatures mean the same structural change.</summary>
    public static string Compute(string ours, string reference)
    {
        var (onlyOurs, onlyRef) = Delta(ours, reference);
        if (onlyOurs.Count == 0 && onlyRef.Count == 0) return "identical";

        // Distinct shapes, not the multiset: the same root cause produces a different *number*
        // of extra lines depending on how many texture reads or lights a material happens to
        // have. Hashing the count as well split single causes across dozens of clusters.
        var sb = new StringBuilder();
        foreach (var l in onlyOurs.Distinct(StringComparer.Ordinal)) sb.Append("-").Append(l).Append('\n');
        foreach (var l in onlyRef.Distinct(StringComparer.Ordinal)) sb.Append("+").Append(l).Append('\n');

        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(sb.ToString()));
        return Convert.ToHexString(hash)[..12].ToLowerInvariant();
    }
}
