namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Defines a basegame file that Milan patches before the rest of the pipeline runs, so that
    /// later stages import/relink against the patched version instead of vanilla. Implementations
    /// are not assumed to produce an <see cref="LegendaryExplorerCore.Packages.IMEPackage"/> - a
    /// target may be a package (.pcc) or some other binary file (e.g. a future Coalesced.bin target).
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

        /// <summary>
        /// Loads the unmodified vanilla bytes of <see cref="GameFile"/>, for diffing/restoring against.
        /// </summary>
        byte[] GetVanillaBytes();

        /// <summary>
        /// Applies this target's changes on top of vanilla and returns the serialized result.
        /// </summary>
        byte[] BuildPatchTarget();
    }
}
