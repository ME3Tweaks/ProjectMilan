using System;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.UnrealScript;

namespace ProjectMilanCore
{
    /// <summary>
    /// Caches process-lifetime, eagerly-built <see cref="FileLib"/>s for LE3 that other FileLib
    /// construction can tier off of via <see cref="UnrealScriptOptionsPackage.BaseFilesFileLib"/>,
    /// instead of every FileLib re-resolving Core/Engine/GameFramework/GFxUI/WwiseAudio/
    /// SFXOnlineFoundation/SFXGame (and, once it exists, BIOP_MP_COMMON) from scratch.
    ///
    /// Neither cached FileLib is ever disposed - both are meant to live for the entire process,
    /// mirroring how MilanShared's le3GlobalCache/globalCache are handled. FileLib.Dispose() only
    /// clears WeakUsers/objBinCache, so this isn't required for correctness, but avoids the question
    /// entirely.
    /// </summary>
    public static class LE3FileLibCache
    {
        /// <summary>
        /// Master on/off switch for the whole cache. The upstream FileLib.BaseFilesFileLib tiering
        /// mechanism this class builds on (LegendaryExplorerCore) isn't fully functional yet - flip this
        /// to false to disable tiering everywhere at once (no FileLib is built or handed out as a
        /// BaseFilesFileLib) without touching any of the call sites that reference this class. Every
        /// call site treats a null return from GetBaseFilesFileLibFor as "fall back to full resolution",
        /// so disabling this is always safe - just slower, as if this cache didn't exist.
        /// </summary>
        private const bool Enabled = false;

        private static readonly object _syncObj = new();

        /// <summary>
        /// FileLib initialized against SFXGame.pcc - the last file in FileLib.BaseFileNames(LE3) - so
        /// it covers the 7-file LE3 base chain (Core/Engine/GameFramework/GFxUI/WwiseAudio/
        /// SFXOnlineFoundation/SFXGame).
        /// </summary>
        private static FileLib _le3BaseFileLib;

        /// <summary>
        /// FileLib initialized against BIOP_MP_COMMON.pcc, tiered off <see cref="_le3BaseFileLib"/>.
        /// Matches any target package whose own LECLTagData.ImportHintFiles ends with
        /// MilanShared.MP_STARTUP_FILENAME, since FileLib.PrivateInitialize appends those hints onto
        /// the base-file list before doing its BaseFilesFileLib match.
        /// </summary>
        private static FileLib _mpCommonFileLib;

        /// <summary>
        /// Builds and caches the LE3 base-file tier. Call once, from MilanShared.InitGlobalPackages(LE3),
        /// after SFXGame.pcc has been loaded into le3GlobalCache. A failure here is never fatal - it just
        /// means every LE3 FileLib construction this run falls back to full base-file resolution.
        /// </summary>
        public static void InitializeLE3BaseFileLib(IMEPackage sfxGamePackage)
        {
            if (!Enabled)
                return;

            lock (_syncObj)
            {
                if (_le3BaseFileLib != null)
                    return;

                var usop = new UnrealScriptOptionsPackage
                {
                    CustomFileResolver = MilanShared.LE3PackageResolver,
                    MissingObjectResolver = MilanShared.MissingObjectResolver,
                    GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                };
                var lib = new FileLib(sfxGamePackage);
                if (!lib.Initialize(usop))
                {
                    MilanShared.LogFailedFileLibInit(lib, "Failed to initialize shared LE3 base FileLib - LE3 FileLib construction will be slower for the rest of this run", "Milan-FileLibCache");
                    return;
                }

                _le3BaseFileLib = lib;
            }
        }

        /// <summary>
        /// Builds and caches the MPCommon tier, chained off the LE3 base tier. Call once BIOP_MP_COMMON.pcc
        /// exists and has been registered into le3GlobalCache (via MilanShared.AddGlobalCachedPackage),
        /// whether that happened because the MPCommon pipeline just built it, or because a checkpoint
        /// restored it. Safe to call more than once - only the first call does anything.
        /// </summary>
        public static void InitializeMPCommonFileLib(IMEPackage mpCommonPackage)
        {
            if (!Enabled)
                return;

            lock (_syncObj)
            {
                if (_mpCommonFileLib != null)
                    return;

                var usop = new UnrealScriptOptionsPackage
                {
                    CustomFileResolver = MilanShared.LE3PackageResolver,
                    MissingObjectResolver = MilanShared.MissingObjectResolver,
                    GetVTableFromDonor = MilanShared.GetVTableFromDonor,
                    BaseFilesFileLib = _le3BaseFileLib,
                };
                var lib = new FileLib(mpCommonPackage);
                if (!lib.Initialize(usop))
                {
                    MilanShared.LogFailedFileLibInit(lib, "Failed to initialize shared MPCommon FileLib - MPCommon-dependent FileLib construction will be slower for the rest of this run", "Milan-FileLibCache");
                    return;
                }

                _mpCommonFileLib = lib;
            }
        }

        /// <summary>
        /// Returns whichever cached tier matches targetPackage's own base-file resolution, for use as
        /// usop.BaseFilesFileLib, or null if neither tier is built yet. Always safe to assign
        /// unconditionally: if the returned FileLib doesn't actually match (wrong tier, or null),
        /// FileLib.PrivateInitialize's own check just fails silently and the caller falls back to a
        /// full resolution - never an error, only a missed speedup.
        /// </summary>
        public static FileLib GetBaseFilesFileLibFor(IMEPackage targetPackage)
        {
            if (!Enabled)
                return null;

            lock (_syncObj)
            {
                var hints = targetPackage?.LECLTagData?.ImportHintFiles;
                if (_mpCommonFileLib != null && hints is { Count: > 0 }
                    && hints[^1].Equals(MilanShared.MP_STARTUP_FILENAME, StringComparison.OrdinalIgnoreCase))
                {
                    return _mpCommonFileLib;
                }

                return _le3BaseFileLib;
            }
        }
    }
}
