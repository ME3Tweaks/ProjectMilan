using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using LegendaryExplorerCore.Unreal.ObjectInfo;
using System;
using System.Collections.Generic;
using System.Text;
using static System.Net.WebRequestMethods;

namespace MilanCoverHost.Classes
{
    public class CoverLink : NavigationPoint
    {
        public override string ClassName => "CoverLink";

        public List<CoverSlotMarker> CoverSlots = new();

        private record PendingFireLink(int TargetNetworkIndex, int TargetSlotIndex, ArrayProperty<ByteProperty> PackedInteractions);
        private PropertyCollection _pendingProps;
        private readonly List<(StructProperty SlotStruct, List<PendingFireLink> PendingFireLinks)> _pendingSlotFireLinks = new();

        public override void Serialize(BinaryReader reader, LevelSerializer levelSerializer)
        {
            base.Serialize(reader, levelSerializer);

            // Read slots
            var props = Export.GetProperties();
            var slotCount = reader.ReadInt32();
            if (slotCount > 0)
            {
                var slots = new ArrayProperty<StructProperty>("Slots");
                for (int i = 0; i < slotCount; i++)
                {
                    // First we fetch the cover slot marker that was already serialized before us.
                    var networkIndex = reader.ReadInt32();
                    var coverSlotMarker = CoverHost.nodeNetwork[networkIndex] as CoverSlotMarker;
                    coverSlotMarker.OwningLink = this;
                    coverSlotMarker.SlotIndex = i;
                    CoverSlots.Add(coverSlotMarker);
                    coverSlotMarker.Export.WriteProperty(new ObjectProperty(Export, "Owner"));
                    var slotIndex = new StructProperty("CoverInfo", new PropertyCollection()
                    {
                        new ObjectProperty(Export, "Link"),
                        new IntProperty(i, "SlotIdx")
                    }, "OwningSlot", isImmutable: true);

                    coverSlotMarker.Export.WriteProperty(slotIndex);
                    // Then we read the slot information. It contains a reference to the export in that marker.
                    var (slot, pendingLinks) = SerializeSlot(reader, coverSlotMarker, levelSerializer);
                    slots.Add(slot);
                    _pendingSlotFireLinks.Add((slot, pendingLinks));
                }

                props.Add(slots);
                _pendingProps = props; // Deferred until ResolveFireLinks is called
            }
        }

        private (StructProperty SlotStruct, List<PendingFireLink> PendingFireLinks) SerializeSlot(BinaryReader reader, CoverSlotMarker coverSlotMarker, LevelSerializer levelSerializer)
        {
            var coverSlotStruct = GenerateCoverSlot(coverSlotMarker);
            var pendingFireLinks = new List<PendingFireLink>();

            // Read 'Actions'
            {
                var count = reader.ReadInt32();
                if (count > 0)
                {
                    var actions = coverSlotStruct.GetProp<ArrayProperty<EnumProperty>>("Actions");
                    for (int i = 0; i < count; i++)
                    {
                        var actionValue = reader.BaseStream.ReadUnrealString();
                        actions.Add(new EnumProperty(actionValue, "ECoverAction", Export.Game));
                    }
                }
            }

            // Read 'FireLinks'
            {
                var count = reader.ReadInt32();
                if (count > 0)
                {
                    for (int flCount = 0; flCount < count; flCount++)
                    {

                        var targetNetworkIndex = reader.ReadInt32();
                        var targetSlotIndex = reader.ReadInt32();

                        var packedInteractions = new ArrayProperty<ByteProperty>("Interactions");
                        var actionCount = reader.ReadInt32();
                        for (int i = 0; i < actionCount; i++)
                        {
                            // This isn't very efficient, will work to improve later.
                            var srcCoverType = reader.ReadByte();
                            var srcAction = reader.ReadByte();
                            var dstCoverType = reader.ReadByte();
                            var dstCoverAction = reader.ReadByte();

                            // Generate packed interactions byte
                            var srcTypeStr = GlobalUnrealObjectInfo.GetEnums(Export.Game)["ECoverType"][srcCoverType].Name;
                            var srcActionStr = GlobalUnrealObjectInfo.GetEnums(Export.Game)["ECoverAction"][srcAction].Name;
                            var destTypeStr = GlobalUnrealObjectInfo.GetEnums(Export.Game)["ECoverType"][dstCoverType].Name;
                            var destActionStr = GlobalUnrealObjectInfo.GetEnums(Export.Game)["ECoverAction"][dstCoverAction].Name;

                            byte packedByte = 0;

                            // Pack Source
                            if (srcTypeStr == "CT_MidLevel") packedByte |= (1 << 0); // 0 = Standing
                            if (srcActionStr == "CA_LeanLeft") packedByte |= (1 << 1);
                            else if (srcActionStr == "CA_LeanRight") packedByte |= (1 << 2);
                            else if (srcActionStr == "CA_LeanPopUp") packedByte |= (1 << 3);

                            // Pack Dest
                            if (destTypeStr == "CT_MidLevel") packedByte |= (1 << 4); // 0 = Standing
                            if (destActionStr == "CA_LeanLeft") packedByte |= (1 << 5);
                            else if (destActionStr == "CA_LeanRight") packedByte |= (1 << 6);
                            else if (destActionStr == "CA_LeanPopUp") packedByte |= (1 << 7);

                            packedInteractions.Add(new ByteProperty(packedByte));
                        }

                        // Store for resolution once all nodes have been loaded
                        pendingFireLinks.Add(new PendingFireLink(targetNetworkIndex, targetSlotIndex, packedInteractions));
                    }
                }
            }

            // Read 'ExposedCoverPackedProperties'
            {
                var count = reader.ReadInt32();
                if (count > 0)
                {
                    var exposedProps = coverSlotStruct.GetProp<ArrayProperty<IntProperty>>("ExposedCoverPackedProperties");
                    for (int i = 0; i < count; i++)
                    {
                        var propValue = reader.ReadInt32();
                        exposedProps.Add(new IntProperty(propValue));
                    }
                }
            }

            // Read 'DangerCoverPackedProperties'
            {
                Console.WriteLine("item");
                var count = reader.ReadInt32();
                if (count > 0)
                {
                    var dangerProps = coverSlotStruct.GetProp<ArrayProperty<IntProperty>>("DangerCoverPackedProperties");
                    for (int i = 0; i < count; i++)
                    {
                        var propValue = reader.ReadInt32();
                        dangerProps.Add(new IntProperty(propValue));
                    }
                }
            }


            // TODO: READ THESE, use existing struct array.
            // Read 'SlipTarget' - This is a struct, but it appears to be empty in the default data, so we'll just add an empty struct for now.
            {
                var slipTargetStruct = new StructProperty("SlipTarget", new PropertyCollection());
                // coverSlotStruct.Properties.Add(slipTargetStruct);
            }

            // Read 'SlipRefs' - This is an array of structs, but it appears to be empty in the default data, so we'll just add an empty array for now.
            {
                var slipRefs = new ArrayProperty<StructProperty>("SlipRefs");
                // coverSlotStruct.Properties.Add(slipRefs);
            }

            // Read 'OverlapClaims' - This is an array of structs, but it appears to be empty in the default data, so we'll just add an empty array for now.
            {
                var overlapClaims = new ArrayProperty<StructProperty>("OverlapClaims");
                // coverSlotStruct.Properties.Add(overlapClaims);
            }

            // Read 'MantleTarget'
            {
                var hasMantleTarget = reader.ReadByte();
                if (hasMantleTarget != 0)
                {
                    // Read CoverReference.
                    var mantleTarget = coverSlotStruct.GetProp<StructProperty>("MantleTarget");
                    SerializeCoverReference(reader, mantleTarget);
                }
            }

            // Read 'LocationOffset'
            {
                var locationOffset = coverSlotStruct.GetProp<StructProperty>("LocationOffset");
                SerializeVector(reader, locationOffset);
            }

            // Read 'RotationOffset'
            {
                var rotationOffset = coverSlotStruct.GetProp<StructProperty>("RotationOffset");
                SerializeRotator(reader, rotationOffset);
            }

            // Skip SlotOwner, it is always 0 (probably)
            // Skip SlotMarker, it is in the generated struct from above.

            // Read 'TurnTargetPackedProperties'
            coverSlotStruct.GetProp<IntProperty>("TurnTargetPackedProperties").Value = reader.ReadInt32();

            // Read 'CoverTurnTargetPackedProperties'
            coverSlotStruct.GetProp<IntProperty>("CoverTurnTargetPackedProperties").Value = reader.ReadInt32();

            // Read 'ExtraCost'
            coverSlotStruct.GetProp<IntProperty>("ExtraCost").Value = reader.ReadInt32();

            // Skip LeanTraceDist - Not sure what this is for...

            // Lotta bools
            coverSlotStruct.GetProp<BoolProperty>("bLeanLeft").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bLeanRight").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bForceCanPopUp").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanPopUp").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanMantle").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanClimbUp").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bForceCanCoverSlip_Left").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bForceCanCoverSlip_Right").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanCoverSlip_Left").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanCoverSlip_Right").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanSwatTurn_Left").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanSwatTurn_Right").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanCoverTurn_Left").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bCanCoverTurn_Right").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bEnabled").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bAllowPopup").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bAllowMantle").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bAllowCoverSlip").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bAllowClimbUp").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bAllowSwatTurn").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bAllowCoverTurn").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bForceNoGroundAdjust").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bPlayerOnly").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bUnsafeCover").Value = reader.ReadByte() != 0;
            coverSlotStruct.GetProp<BoolProperty>("bFailedToFindSurface").Value = reader.ReadByte() != 0;

            // Read 'ForceCoverType'. Clone it into CoverType as well.
            var coverType = reader.BaseStream.ReadUnrealString();
            coverSlotStruct.GetProp<EnumProperty>("ForceCoverType").Value = coverType;
            coverSlotStruct.GetProp<EnumProperty>("CoverType").Value = coverType;

            // Skip LocationDescription, it seems to be useless.

            return (coverSlotStruct, pendingFireLinks);
        }

        /// <summary>
        /// Resolves deferred FireLink data that requires the full node network to be loaded.
        /// Must be called after all nodes in the network have been deserialized.
        /// </summary>
        public void ResolveFireLinks(LevelSerializer levelSerializer)
        {
            if (_pendingProps == null) return;

            foreach (var (slotStruct, pendingFireLinks) in _pendingSlotFireLinks)
            {
                var fireLinks = slotStruct.GetProp<ArrayProperty<StructProperty>>("FireLinks");
                foreach (var pending in pendingFireLinks)
                {
                    var targetLink = CoverHost.nodeNetwork[pending.TargetNetworkIndex] as CoverLink;

                    // We need to generate the indices into CoverLinkRefs/CrossLevelCoverGuidRefs/CoverIndexPairs
                    int packedValue = 0;
                    int foundIdx = -1;
                    if (targetLink.Export.FileRef == levelSerializer.package)
                    {
                        // Same-level reference
                        foundIdx = levelSerializer.levelBin.CoverLinkRefs.IndexOf(targetLink.Export.UIndex);
                        if (foundIdx == -1)
                        {
                            // Add the reference
                            levelSerializer.levelBin.CoverLinkRefs.Add(targetLink.Export.UIndex);
                            foundIdx = levelSerializer.levelBin.CoverLinkRefs.Count - 1;
                        }
                    }
                    else
                    {
                        // Cross-level reference
                        // If we find this, then it's been resolved cross level already and will be matching in CoverLinkRefs.
                        foreach (var kvp in levelSerializer.levelBin.CrossLevelCoverGuidRefs)
                        {
                            if (kvp.Value == targetLink.NavGuid)
                            {
                                foundIdx = kvp.Key;
                                break;
                            }
                        }

                        if (foundIdx == -1)
                        {
                            // Add the reference
                            foundIdx = levelSerializer.levelBin.CoverLinkRefs.Count;
                            levelSerializer.levelBin.CoverLinkRefs.Add(0); // Add null value.
                            levelSerializer.levelBin.CrossLevelCoverGuidRefs[foundIdx] = targetLink.NavGuid;
                        }
                    }

                    // Find or add a CoverIndexPair for this (CoverLinkRefs index, slot) combination.
                    // The index into CoverIndexPairs is what the lower 16 bits of packedValue encodes.
                    var pair = new CoverIndexPair { CoverIndexIdx = (uint)foundIdx, SlotIdx = (byte)pending.TargetSlotIndex };
                    int covRefIdx = levelSerializer.levelBin.CoverIndexPairs.FindIndex(
                        p => p.CoverIndexIdx == pair.CoverIndexIdx && p.SlotIdx == pair.SlotIdx);
                    if (covRefIdx == -1)
                    {
                        levelSerializer.levelBin.CoverIndexPairs.Add(pair);
                        covRefIdx = levelSerializer.levelBin.CoverIndexPairs.Count - 1;
                    }

                    // Lower 16 bits = index into CoverIndexPairs, upper 16 bits = dynamicLinkInfoIndex (0 = not dynamic)
                    packedValue = covRefIdx & 0x0000FFFF;

                    PropertyCollection pc = new PropertyCollection();
                    pc.Add(pending.PackedInteractions);
                    pc.Add(new IntProperty(packedValue, "PackedProperties_CoverPairRefAndDynamicInfo"));
                    pc.Add(new BoolProperty(false, "bFallbackLink"));
                    pc.Add(new BoolProperty(false, "bDynamicIndexInited"));

                    fireLinks.Add(new StructProperty("FireLink", pc, isImmutable: true));
                }
            }

            Export.WriteProperties(_pendingProps);
        }

        private void SerializeCoverReference(BinaryReader reader, StructProperty coverReference)
        {
            // NOTE: This is wrong.
            coverReference.GetProp<IntProperty>("SlotIdx").Value = reader.ReadInt32(); // The slot in the other coverlink.
            coverReference.GetProp<IntProperty>("Direction").Value = reader.ReadInt32(); // Direction of the cover on the other coverlink.
            coverReference.Properties.AddOrReplaceProp(CommonStructs.GuidProp(reader.BaseStream.ReadGuid(), "Guid")); // Cross-level coverlink guid
            coverReference.GetProp<ObjectProperty>("SlotIdx").Value = reader.ReadInt32(); // Same-level coverlink actor // TODO: This is a lookup into the actors index, we need to resolve it to the export!!
        }

        private void SerializeVector(BinaryReader reader, StructProperty vectorProp)
        {
            vectorProp.Properties.GetProp<FloatProperty>("X").Value = reader.ReadSingle();
            vectorProp.Properties.GetProp<FloatProperty>("Y").Value = reader.ReadSingle();
            vectorProp.Properties.GetProp<FloatProperty>("Z").Value = reader.ReadSingle();
        }

        private void SerializeRotator(BinaryReader reader, StructProperty rotatorProp)
        {
            rotatorProp.Properties.GetProp<IntProperty>("Pitch").Value = reader.ReadInt32();
            rotatorProp.Properties.GetProp<IntProperty>("Yaw").Value = reader.ReadInt32();
            rotatorProp.Properties.GetProp<IntProperty>("Roll").Value = reader.ReadInt32();
        }

        /*
         SSSSSSSSSSSSSSS                        SSSSSSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSS                      SSSSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSS                    SSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSSSS                  SSSSSSSSSSSSSSS                      SSS
    SSSSSSSSSSSSSSSSSSSSS                     SSSSSS                   SSSSSSSS
         SSSSSSSSSSSSSSSSSS       SSSSSSSSSSS   SS                 SSSSSSSSSSSS
              SSSSSSSSSSSSSSS  SSSSSSSSSSSSSSSSS              SSSSSSSSSSSSSSSSS
                   SSSSSSSS  SSSSSSSSSSSSSSSSSSSSS       SSSSSSSSSSSSSSSSSSSSSS
                        SS  SSSSSSSSSSSSSSSSSSSSSSS  SSSSSSSSSSSSSSSSSSSSSSSSSS
                           SSSSS     SSS     SSSSSSS  SSSSSSSSSSSSSSSSSSSSSSSSS
                          SSSSS   SS  S   SS  SSSSSSS  SSSSSSSSSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSSSSSSS  SSSSSSSSSSS SSSSSSSSSSSSSSS  SSSSSSSSSSSSSSSSSSSSSSSS
SSSSSSSSSSSSSSSSSSSSSSSS  SSSSSSSS S   SS SSSSSSSSSSS
SSSSSSSSSSSSSSSSSSSSSSSSS  SSSSS  SSSSSSSS   SSSSSSS
SSSSSSSSSSSSSSSSSSSSSSSSSS  SSS SS        SSS SSSSS  SS
SSSSSSSSSSSSSSSSSSSSSS       SSSSSSSSSSSSSSSSSSSSS  SSSSSSSS
SSSSSSSSSSSSSSSSS              SSSSS   SSSSSSSSS  SSSSSSSSSSSSSSS
SSSSSSSSSSSS                 SS   SSSSSSSSSSS   SSSSSSSSSSSSSSSSSSSSSS
SSSSSSS                    SSSSSS                 SSSSSSSSSSSSSSSSSSSSSSSSS
SS                       SSSSSSSSSSSSSSS            SSSSSSSSSSSSSSSSSSSSSSSSSSS
                       SSSSSSSSSSSSSSSSS              SSSSSSSSSSSSSSSSSSSSSSSSS
                     SSSSSSSSSSSSSSSSSSS                SSSSSSSSSSSSSSSSSSSSSSS
                   SSSSSSSSSSSSSSSSSSSSS                  SSSSSSSSSSSSSSSSSSSSS

        May your day be as bright as this sun
        Cause this code will assuredly be horrible
        - John 12:8
        */
        /// <summary>
        /// Generates a basic CoverSlot struct with default values. You must customize
        /// this for use.
        /// </summary>
        /// <param name="marker"></param>
        /// <returns></returns>
        private StructProperty GenerateCoverSlot(CoverSlotMarker marker)
        {
            PropertyCollection pc = new PropertyCollection();
            /*
             *     Slots = ({
              Actions = (ECoverAction.CA_PopUp), 
              FireLinks = ({Interactions = "mQ==", PackedProperties_CoverPairRefAndDynamicInfo = 102, bFallbackLink = FALSE, bDynamicIndexInited = FALSE}, 
                           {Interactions = "OZkZ", PackedProperties_CoverPairRefAndDynamicInfo = 104, bFallbackLink = FALSE, bDynamicIndexInited = FALSE}, 
                           {Interactions = "WZkZ", PackedProperties_CoverPairRefAndDynamicInfo = 105, bFallbackLink = FALSE, bDynamicIndexInited = FALSE}, 
                           {Interactions = "mQ==", PackedProperties_CoverPairRefAndDynamicInfo = 24, bFallbackLink = FALSE, bDynamicIndexInited = FALSE}
                          ), 
              ExposedCoverPackedProperties = (6881301, 
                                              16711801, 
                                              16711802, 
                                              16711800, 
                                              11075707, 
                                              11010172, 
                                              10944543, 
                                              9568286, 
                                              3932288, 
                                              3866663
                                             ), 
              DangerCoverPackedProperties = (10485814, 
                                             6619271, 
                                             1835151, 
                                             15859848, 
                                             8781880, 
                                             16187530, 
                                             5505163, 
                                             14745740, 
                                             458809, 
                                             10748033, 
                                             327738, 
                                             6815901, 
                                             12255382, 
                                             589956, 
                                             5898393, 
                                             16515213, 
                                             10748046, 
                                             10158234, 
                                             14745758, 
                                             2949279
                                            ), 
              SlipTarget = (), 
              SlipRefs = (), 
              OverlapClaims = (), 
              MantleTarget = {
                              SlotIdx = -1, 
                              Direction = 0, 
                              Guid = {A = 0, B = 0, C = 0, D = 0}, 
                              Actor = None
                             }, 
              LocationOffset = {X = 193.699219, Y = -79.0, Z = 11.100132}, 
              RotationOffset = {Pitch = 0, Yaw = 0, Roll = 0}, 
              SlotOwner = None, 
              SlotMarker = CoverSlotMarker'TheWorld.PersistentLevel.CoverSlotMarker_3186', 
              TurnTargetPackedProperties = -1, 
              CoverTurnTargetPackedProperties = -1, 
              ExtraCost = 0, 
              LeanTraceDist = 64.0, 
              bLeanLeft = FALSE, 
              bLeanRight = FALSE, 
              bForceCanPopUp = TRUE, 
              bCanPopUp = TRUE, 
              bCanMantle = FALSE, 
              bCanClimbUp = FALSE, 
              bForceCanCoverSlip_Left = FALSE, 
              bForceCanCoverSlip_Right = FALSE, 
              bCanCoverSlip_Left = FALSE, 
              bCanCoverSlip_Right = FALSE, 
              bCanSwatTurn_Left = FALSE, 
              bCanSwatTurn_Right = FALSE, 
              bCanCoverTurn_Left = FALSE, 
              bCanCoverTurn_Right = FALSE, 
              bEnabled = TRUE, 
              bAllowPopup = TRUE, 
              bAllowMantle = FALSE, 
              bAllowCoverSlip = TRUE, 
              bAllowClimbUp = FALSE, 
              bAllowSwatTurn = TRUE, 
              bAllowCoverTurn = TRUE, 
              bForceNoGroundAdjust = TRUE, 
              bPlayerOnly = FALSE, 
              bUnsafeCover = FALSE, 
              bFailedToFindSurface = FALSE, 
              ForceCoverType = ECoverType.CT_MidLevel, 
              CoverType = ECoverType.CT_MidLevel, 
              LocationDescription = ECoverLocationDescription.CoverDesc_None
             }
            )*/

            pc.Add(new ArrayProperty<EnumProperty>("Actions")); //Actions - Enum Array of ECoverAction
            pc.Add(new ArrayProperty<StructProperty>("FireLinks")); //FireLinks - Array of FireLink (prepare for pain)
            pc.Add(new ArrayProperty<IntProperty>("ExposedCoverPackedProperties")); //ExposedCoverPackedProperties
            pc.Add(new ArrayProperty<IntProperty>("DangerCoverPackedProperties")); //DangerCoverPackedProperties
            pc.Add(new ArrayProperty<StructProperty>("SlipTarget")); //SlipTarget
            pc.Add(new ArrayProperty<StructProperty>("SlipRefs")); // SlipRefs - Array of SlotMoveRef
            pc.Add(new ArrayProperty<StructProperty>("OverlapClaims")); // OverlapClaims - Array of CoverReference
            pc.Add(MakeCoverReference("MantleTarget")); //MantleTarget
            pc.Add(CommonStructs.Vector3Prop(0, 0, 0, "LocationOffset")); // Location Offset
            pc.Add(CommonStructs.RotatorProp(0, 0, 0, "RotationOffset")); // RotationOffset Offset
            pc.Add(new ObjectProperty(null, "SlotOwner")); // SlotOwner - pretty sure this is always 0 and is only set at runtime
            pc.Add(new ObjectProperty(marker.Export, "SlotMarker")); // SlotMarker - !!! This is the coverslot

            pc.Add(new IntProperty(-1, "TurnTargetPackedProperties"));
            pc.Add(new IntProperty(-1, "CoverTurnTargetPackedProperties"));
            pc.Add(new IntProperty(0, "ExtraCost"));
            pc.Add(new FloatProperty(64, "LeanTraceDist"));
            pc.Add(new BoolProperty(false, "bLeanLeft"));
            pc.Add(new BoolProperty(false, "bLeanRight"));
            pc.Add(new BoolProperty(true, "bForceCanPopUp"));
            pc.Add(new BoolProperty(true, "bCanPopUp"));
            pc.Add(new BoolProperty(false, "bCanMantle"));
            pc.Add(new BoolProperty(false, "bCanClimbUp"));
            pc.Add(new BoolProperty(false, "bForceCanCoverSlip_Left"));
            pc.Add(new BoolProperty(false, "bForceCanCoverSlip_Right"));
            pc.Add(new BoolProperty(false, "bCanCoverSlip_Left"));
            pc.Add(new BoolProperty(false, "bCanCoverSlip_Right"));
            pc.Add(new BoolProperty(false, "bCanSwatTurn_Left"));
            pc.Add(new BoolProperty(false, "bCanSwatTurn_Right"));
            pc.Add(new BoolProperty(false, "bCanCoverTurn_Left"));
            pc.Add(new BoolProperty(false, "bCanCoverTurn_Right"));

            pc.Add(new BoolProperty(true, "bEnabled"));
            pc.Add(new BoolProperty(true, "bAllowPopup"));
            pc.Add(new BoolProperty(false, "bAllowMantle"));
            pc.Add(new BoolProperty(true, "bAllowCoverSlip"));
            pc.Add(new BoolProperty(false, "bAllowClimbUp"));
            pc.Add(new BoolProperty(true, "bAllowSwatTurn"));
            pc.Add(new BoolProperty(true, "bAllowCoverTurn"));
            pc.Add(new BoolProperty(true, "bForceNoGroundAdjust"));
            pc.Add(new BoolProperty(false, "bPlayerOnly"));
            pc.Add(new BoolProperty(false, "bUnsafeCover"));
            pc.Add(new BoolProperty(false, "bFailedToFindSurface"));

            pc.Add(new EnumProperty("CT_MidLevel", "ECoverType", marker.Export.Game, "ForceCoverType"));
            pc.Add(new EnumProperty("CT_MidLevel", "ECoverType", marker.Export.Game, "CoverType"));
            pc.Add(new EnumProperty("CoverDesc_None", "ECoverLocationDescription", marker.Export.Game, "LocationDescription"));

            return new StructProperty("CoverSlot", pc, isImmutable: true);
        }


        private StructProperty MakeCoverReference(string name)
        {
            PropertyCollection pc = new PropertyCollection();
            // This is for null reference:
            pc.Add(new IntProperty(-1, "SlotIdx"));
            pc.Add(new IntProperty(0, "Direction"));
            pc.Add(CommonStructs.GuidProp(Guid.Empty, "Guid"));
            pc.Add(new ObjectProperty(null, "Actor"));

            return new StructProperty("CoverReference", pc, name, isImmutable: true);

        }
    }
}
