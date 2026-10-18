namespace ProjectMilan.Utility
{
    /// <summary>
    /// A pipeline that a checkpoint can be taken at. Restoring a checkpoint skips every pipeline
    /// up to and including its stage.
    /// <para/>
    /// The numeric values ARE the ordering - the whole skip mechanism is a 'stage &lt;= restored stage'
    /// comparison - so these must stay in the same order the pipelines run in
    /// <see cref="Program.RunPipelines"/>. Values are spaced out so a new pipeline can be slotted in
    /// between two existing ones without renumbering (which would silently repoint every checkpoint
    /// on disk at the wrong stage).
    /// <para/>
    /// Past Redemption the build is no longer porting content, and the remaining pipelines (Texture, Shaders,
    /// Audio, Conformance, ...) must always run in a production build. The exceptions are the dev-only stages
    /// from <see cref="Texture"/> through <see cref="VTables"/> (see <see cref="ECheckpointStageExtensions.IsDevOnly"/>),
    /// which dev builds can checkpoint so that the pipelines after them can be iterated on without rerunning
    /// the slow ones before them. Conformance and later are never checkpointed.
    /// </summary>
    internal enum ECheckpointStage
    {
        /// <summary>
        /// Not a checkpointable pipeline / no checkpoint selected.
        /// </summary>
        None = 0,

        /// <summary>
        /// Not offered in the checkpoint menu - ModBuild always runs and is quick, so there is no reason
        /// to stop here. It still needs a stage so that restoring ANY checkpoint skips it: it regenerates
        /// the DLC's Coalesced .bin and TLKs from source, which would wipe the Rejects/Redemption merges
        /// that a restored checkpoint already contains.
        /// </summary>
        ModBuild = 5,
        MPCommon = 10,
        NonStartup = 20,
        Kits = 30,
        Weapons = 40,
        MP4Enemies = 50,
        Levels = 60,
        Rejection = 70,
        Redemption = 80,

        /// <summary>
        /// Dev builds only, never offered or restored by a production build. Lets the pipelines after it
        /// (Shaders, ...) be iterated on without rerunning the slow texture pipeline. The TLK finalize that
        /// runs before Texture is already in such a checkpoint, so restoring one skips it. Changes to
        /// <c>TFCBuild</c> make a Texture checkpoint stale without bumping MIN_CHECKPOINT_VERSION; retake it.
        /// </summary>
        Texture = 90,

        /// <summary>
        /// Dev builds only, never offered or restored by a production build (see <see cref="Texture"/>). Changes to
        /// <c>ShaderPipeline</c> (or the offline shader compiler it drives) make a Shaders checkpoint stale without
        /// bumping MIN_CHECKPOINT_VERSION; retake it. Everything the pipeline writes is inside the mod output.
        /// </summary>
        Shaders = 100,

        /// <summary>Disk-only material binding repairs; checkpointed with no rehydration required.</summary>
        PostShaders = 105,

        /// <summary>
        /// Dev builds only, never offered or restored by a production build (see <see cref="Texture"/>). Changes to
        /// <c>AudioPipeline</c> make an Audio checkpoint stale without bumping MIN_CHECKPOINT_VERSION; retake it.
        /// The converted .afc files it writes live in the mod output (CookedPCConsole\Audio), so they are in the checkpoint.
        /// <para/>
        /// <c>MilanShared.UnregisterObjectDBPackages</c> runs between this stage and Resynthesis, outside any stage.
        /// It is safe after a restore: it only drops what this process registered (the global donors MilanInit
        /// registers every run, plus whatever skipped pipelines would have added - nothing, when restored), so the
        /// database ends up vanilla either way, which is what Conformance expects.
        /// </summary>
        Audio = 110,

        /// <summary>
        /// Dev builds only, never offered or restored by a production build (see <see cref="Texture"/>). Changes to
        /// <c>ModResynthesis</c> make a Resynthesis checkpoint stale without bumping MIN_CHECKPOINT_VERSION; retake it.
        /// </summary>
        Resynthesis = 120,

        /// <summary>
        /// Dev builds only, never offered or restored by a production build (see <see cref="Texture"/>). The last
        /// stage before Conformance, so restoring one lets Conformance onward be iterated on alone. Changes to
        /// <c>VTablePipeline</c> make a VTables checkpoint stale without bumping MIN_CHECKPOINT_VERSION; retake it.
        /// </summary>
        VTables = 130,
    }

    internal static class ECheckpointStageExtensions
    {
        /// <summary>
        /// If the stage is one only a dev build may checkpoint - <see cref="ECheckpointStage.Texture"/> and every stage
        /// after it. A production build never offers, creates or restores one, and a restore of one skips the TLK
        /// finalize (the checkpoint was taken after it). Keep this in step with the enum: any stage added after
        /// Texture is dev-only automatically, because only the ordering matters here.
        /// </summary>
        public static bool IsDevOnly(this ECheckpointStage stage) => stage >= ECheckpointStage.Texture;
    }
}
