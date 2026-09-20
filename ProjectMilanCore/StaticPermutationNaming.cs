using LegendaryExplorerCore.Unreal.BinaryConverters;

namespace MilanShaderHost
{
    /// <summary>
    /// The on-the-wire shape of a MaterialInstance permutation's capture name.
    ///
    /// ShaderClient appends <c>#&lt;16 hex&gt;</c> to a material's wire name when the resource being
    /// compiled is an instance permutation rather than the base material (the hash itself is
    /// <c>ShaderClient::StaticPermutationSuffix</c> / <c>StaticPermutationKey</c>). Three separate
    /// assemblies have to agree on how to recognise and strip that suffix -- the host, when deciding
    /// what a payload is; the research tool, when joining a capture to a shipping shader map -- so
    /// the format lives here, in the one assembly both of them already reference.
    /// </summary>
    public static class StaticPermutationNaming
    {
        /// <summary>'#' plus 16 lowercase hex digits.</summary>
        private const int KeyLength = 17;

        /// <summary>
        /// Splits a captured name into the parent material path and the permutation key. The key is
        /// null for a plain UMaterial capture, which is the overwhelming majority of the corpus.
        /// </summary>
        /// <remarks>
        /// Only an exact '#' + 16 hex digits tail counts. A material whose own name contains a '#'
        /// would otherwise be truncated to a path that does not exist, and the job would fail to
        /// resolve for a reason that looks nothing like the cause.
        /// </remarks>
        public static (string BasePath, string? Key) Split(string capturedName)
        {
            if (string.IsNullOrEmpty(capturedName) || capturedName.Length <= KeyLength)
            {
                return (capturedName, null);
            }

            int start = capturedName.Length - KeyLength;
            if (capturedName[start] != '#') return (capturedName, null);

            for (int i = start + 1; i < capturedName.Length; i++)
            {
                if (!Uri.IsHexDigit(capturedName[i])) return (capturedName, null);
            }

            return (capturedName[..start], capturedName[start..]);
        }

        /// <summary>True when this captured name identifies an instance permutation.</summary>
        public static bool HasPermutationKey(string capturedName) => Split(capturedName).Key != null;

        // ---- the key itself ----------------------------------------------------------------
        //
        // This must stay byte-for-byte identical to ShaderClient::StaticPermutationSuffix. Any change
        // has to be made in both places and invalidates every capture taken with the old one. It is a
        // hand-rolled FNV-1a rather than a library hash so neither side can drift on a dependency.

        private const ulong FnvOffsetBasis = 0xcbf29ce484222325UL;
        private const ulong FnvPrime = 0x100000001b3UL;

        private static void HashByte(ref ulong hash, byte value)
        {
            hash ^= value;
            hash *= FnvPrime;
        }

        /// <summary>
        /// Hashes a name as its UTF-16 code units, low byte first, then a NUL separator. Not UTF-8:
        /// the C++ side must produce the same bytes without either depending on an encoder.
        /// </summary>
        private static void HashName(ref ulong hash, string name)
        {
            foreach (var c in name)
            {
                HashByte(ref hash, (byte)(c & 0xFF));
                HashByte(ref hash, (byte)((c >> 8) & 0xFF));
            }
            HashByte(ref hash, 0);
        }

        /// <summary>
        /// True when the instance actually diverges from its parent. The parameter set carries the
        /// parent's whole parameter list; only entries flagged bOverride are the instance's own.
        /// </summary>
        public static bool HasAnyOverride(StaticParameterSet? set)
        {
            if (set == null) return false;
            return set.StaticSwitchParameters.Any(p => p.bOverride)
                   || set.StaticComponentMaskParameters.Any(p => p.bOverride)
                   || set.NormalParameters.Any(p => p.bOverride);
        }

        /// <summary>
        /// The key for a set, with no <see cref="HasAnyOverride"/> gate. BaseMaterialId and the
        /// per-parameter ExpressionGUIDs are deliberately excluded -- the parent's path is already in
        /// the name, and FGuid byte order across the C++/C# boundary is one more thing that could
        /// silently disagree. bOverride is excluded too: two instances with identical values share
        /// one shader map however they are flagged.
        /// </summary>
        public static string RawKey(StaticParameterSet set)
        {
            ulong hash = FnvOffsetBasis;
            foreach (var p in set.StaticSwitchParameters)
            {
                HashByte(ref hash, (byte)'S');
                HashName(ref hash, p.ParameterName.Instanced);
                HashByte(ref hash, p.Value ? (byte)1 : (byte)0);
            }
            foreach (var p in set.StaticComponentMaskParameters)
            {
                HashByte(ref hash, (byte)'M');
                HashName(ref hash, p.ParameterName.Instanced);
                HashByte(ref hash, p.R ? (byte)1 : (byte)0);
                HashByte(ref hash, p.G ? (byte)1 : (byte)0);
                HashByte(ref hash, p.B ? (byte)1 : (byte)0);
                HashByte(ref hash, p.A ? (byte)1 : (byte)0);
            }
            foreach (var p in set.NormalParameters)
            {
                HashByte(ref hash, (byte)'N');
                HashName(ref hash, p.ParameterName.Instanced);
                HashByte(ref hash, p.CompressionSettings);
            }

            return $"#{hash:x16}";
        }

        /// <summary>The key a capture of this set is filed under, or "" when it overrides nothing.</summary>
        public static string Key(StaticParameterSet? set) =>
            HasAnyOverride(set) ? RawKey(set!) : string.Empty;
    }
}
