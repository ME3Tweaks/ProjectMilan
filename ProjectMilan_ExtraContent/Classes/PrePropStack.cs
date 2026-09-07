using LegendaryExplorerCore.Helpers;
using LegendaryExplorerCore.Packages;
using System;
using System.Collections.Generic;
using System.Text;

namespace ProjectMilan_ExtraContent.Classes
{
    internal class PrePropStack
    {
        public IEntry Node;

        public IEntry StateNode;

        public ulong ProbeMask;

        public ushort LatentAction;
        public List<int> StateStack; // Not sure what this is

        public int Offset;

        /// <summary>
        /// Reads a stack from an export
        /// </summary>
        /// <param name="obj"></param>
        public PrePropStack(ExportEntry obj)
        {
            var ppb = new MemoryStream(obj.GetPrePropBinary());
            Node = obj.FileRef.GetEntry(ppb.ReadInt32());
            StateNode = obj.FileRef.GetEntry(ppb.ReadInt32());
            ProbeMask = ppb.ReadUInt64();
            LatentAction = ppb.ReadUInt16();
            var stateStackLength = ppb.ReadInt32();
            StateStack = new List<int>(stateStackLength);
            for(int i = 0; i < stateStackLength; i++)
            {
                StateStack.Add(ppb.ReadInt32());
            }
            Offset = ppb.ReadInt32();
        }

        /// <summary>
        /// Generates the stack data for an export
        /// </summary>
        /// <returns></returns>
        public byte[] GeneratePreProps()
        {
            MemoryStream ms = new MemoryStream();
            ms.WriteInt32(Node?.UIndex ?? 0);
            ms.WriteInt32(StateNode?.UIndex ?? 0);
            ms.WriteUInt64(ProbeMask);
            ms.WriteUInt16(LatentAction);
            ms.WriteInt32(StateStack.Count);
            foreach(var state in StateStack)
            {
                ms.WriteInt32(state);
            }
            ms.WriteInt32(Offset);

            return ms.ToArray();
        }
    }
}
