namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Defines a basegame file that Milan patches before the rest of the pipeline runs, so that
    /// later stages import/relink against the patched version instead of vanilla. Implementations
    /// are not assumed to produce an <see cref="LegendaryExplorerCore.Packages.IMEPackage"/> - a
    /// target may be a package (.pcc) or some other binary file (e.g. Coalesced.bin).
    /// </summary>
    internal interface IBasePatchClass
    {
        /// <summary>
        /// The basegame file being patched (e.g. "SFXGame.pcc").
        /// </summary>
        string GameFile { get; }

        /// <summary>
        /// Human-readable description of what this patch does, recorded in the MilanDelta manifest.
        /// </summary>
        string Comment { get; }

        /// <summary>Optional transform applied before diffing; null means the existing byte format.</summary>
        string? DeltaFormat => null;

        /// <summary>Converts patched delta data to the final game file (e.g. XML to Huffman TLK).</summary>
        byte[] RestoreFileBytes(byte[] patched) => patched;

        /// <summary>
        /// Loads the unmodified vanilla data of <see cref="GameFile"/> in its delta representation.
        /// </summary>
        byte[] GetVanillaBytes();

        /// <summary>
        /// Applies this target's changes on top of vanilla and returns the delta representation.
        /// Use <see cref="RestoreFileBytes"/> to produce a game-readable file.
        /// </summary>
        byte[] BuildPatchTarget();
    }
}
