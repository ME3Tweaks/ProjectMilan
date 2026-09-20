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
    /// Nothing past Redemption is checkpointable: after that point the build is no longer porting
    /// content, and the remaining pipelines (Texture, Audio, Shaders, Conformance, ...) must always run.
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
    }
}
