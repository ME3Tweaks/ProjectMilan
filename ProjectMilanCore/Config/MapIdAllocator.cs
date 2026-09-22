using System.Diagnostics;

namespace ProjectMilanCore
{
    /// <summary>
    /// Assigns sequential IDs to newly-registered multiplayer maps for the mastermaplist/availablemaps
    /// bitmask. The starting point is not fixed here - the main ProjectMilan build and standalone
    /// ProjectMilan_ExtraContent builds intentionally use different ranges (see their own callers of
    /// <see cref="ResetCounter"/>) so a developer's standalone Redemption/Rejects output can never collide
    /// with the shipping mod's own IDs.
    /// </summary>
    public static class MapIdAllocator
    {
        private static int _nextId = 1;

        /// <summary>
        /// Allocates and returns the next free map ID.
        /// </summary>
        public static int AllocateNext()
        {
            var id = _nextId;
            _nextId++;
            if (_nextId > 255)
            {
                // Milan is configured to support no mo than 255 maps as it replicates a byte array of 255 elements, up from the default of 30 vanilla shipped with
                Debugger.Break();
            }
            return id;
        }

        /// <summary>
        /// Resets the counter to the given starting value. Called once at the start of a build.
        /// </summary>
        public static void ResetCounter(int startValue)
        {
            _nextId = startValue;
        }

        /// <summary>
        /// Advances the counter past the given ID if it isn't already there, without going backwards. Used
        /// when rehydrating from a checkpoint whose on-disk config already contains registered maps.
        /// </summary>
        public static void FastForwardPast(int highestExistingId)
        {
            _nextId = Math.Max(_nextId, highestExistingId + 1);
        }
    }
}
