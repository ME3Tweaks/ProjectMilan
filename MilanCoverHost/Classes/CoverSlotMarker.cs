using System;
using System.Collections.Generic;
using System.Text;

namespace MilanCoverHost.Classes
{
    public class CoverSlotMarker : NavigationPoint
    {
        public override string ClassName => "CoverSlotMarker";

        /// <summary>
        /// What CoverLink owns this slot.
        /// </summary>
        public CoverLink OwningLink { get; internal set; }
        /// <summary>
        /// Index into owning link's list of slots. This is used to determine which slot this marker represents.
        /// </summary>
        public int SlotIndex { get; internal set; }
    }
}
