using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.Unreal;
using LegendaryExplorerCore.Unreal.BinaryConverters;
using ProjectMilanCore;

namespace ProjectMilan.Pipelines.Mod.BaseDelta
{
    /// <summary>
    /// Sends the title screen's Press Start sound to the music bus instead of the GUI sounds bus.
    /// </summary>
    internal static class SplashStartSoundRouting
    {
        private const string LogCategory = "Milan-SplashStartSound";
        private const string EventPath = "Wwise_Generic_GUI.Play_SplashStart";
        private const string BankPath = "Wwise_Generic_GUI.Wwise_GUI_Generic";

        /// <summary>
        /// The NonSlowdown-Music bus Id
        /// </summary>
        private const uint MusicBusId = 1503374211;

        private const byte HircSound = 2;
        private const byte HircAction = 3;
        private const byte HircEvent = 4;

        /// <summary>
        /// CAkActionPlay: action type 0x04, scope 0x03
        /// </summary>
        private const ushort ActionPlay = 0x0403;

        /// <summary>
        /// Post-compile hook for the SFXGame
        /// </summary>
        internal static void Apply(IMEPackage sfxGame)
        {
            var wwiseEvent = sfxGame.FindExport(EventPath);
            var eventId = (uint)wwiseEvent.GetProperty<IntProperty>("Id").Value;
            var bankExport = sfxGame.FindExport(BankPath);
            
            int patched = 0;
            ObjectBinary.EditBinary<WwiseBank>(bankExport, bank =>
            {
                patched = Patch(bank.BnkFile, eventId);
            });
            MilanLog.Information($"Routed {patched} Press Start sound(s) in {BankPath} to the music bus", customPrefix: LogCategory);
        }

        /// <summary>
        /// Sets the output bus of every Sound the event plays directly. Returns how many were changed.
        /// </summary>
        private static int Patch(byte[] bnk, uint eventId)
        {
            var objects = ReadHirc(bnk);
            objects.TryGetValue(eventId, out var evt);

            var actionIds = ReadEventActions(bnk, evt.Start);
            int patched = 0;
            foreach (var actionId in actionIds)
            {
                if (!objects.TryGetValue(actionId, out var action) || action.Type != HircAction)
                {
                    continue;
                }
                var actionType = BitConverter.ToUInt16(bnk, action.Start + 4);
                if (actionType != ActionPlay)
                {
                    continue;
                }
                var targetId = BitConverter.ToUInt32(bnk, action.Start + 6);
                objects.TryGetValue(targetId, out var sound);
                var busOffset = GetSoundBusOffset(bnk, sound.Start);
                var currentBus = BitConverter.ToUInt32(bnk, busOffset);
                BitConverter.TryWriteBytes(bnk.AsSpan(busOffset), MusicBusId);
                patched++;
            }

            if (patched == 0)
            {
                throw new InvalidDataException($"{BankPath}: Play_SplashStart has no Play action.");
            }
            return patched;
        }

        /// <summary>
        /// The OverrideBusId of a v134 Sound whose id starts at start
        /// </summary>
        private static int GetSoundBusOffset(byte[] bnk, int start)
        {
            // Id (4), then AkBankSourceData: plugin id (4), stream type (1), source id (4), in-memory size (4), flags (1).
            var pluginId = BitConverter.ToUInt32(bnk, start + 4);
            int at = start + 4 + 14;

            // NodeInitialFxParams: override-parent flag, effect count, and if any, a bypass byte plus 7 bytes per effect.
            int fxCount = bnk[at + 1];
            at += 2;
            if (fxCount > 0)
            {
                at += 1 + 7 * fxCount;
            }

            // bOverrideAttachmentParams, then OverrideBusId.
            return at + 1;
        }

        private static List<uint> ReadEventActions(byte[] bnk, int start)
        {
            int at = start + 4;
            uint count = 0;
            int shift = 0;
            while (true)
            {
                byte b = bnk[at++];
                count |= (uint)(b & 0x7F) << shift;
                shift += 7;
                if ((b & 0x80) == 0)
                {
                    break;
                }
            }
            return Enumerable.Range(0, (int)count).Select(i => BitConverter.ToUInt32(bnk, at + 4 * i)).ToList();
        }

        /// <summary>
        /// Every HIRC object by id, mapped to its type and where its id starts
        /// </summary>
        private static Dictionary<uint, (byte Type, int Start)> ReadHirc(byte[] bnk)
        {
            int pos = 0;
            while (pos + 8 <= bnk.Length)
            {
                var tag = System.Text.Encoding.ASCII.GetString(bnk, pos, 4);
                var size = BitConverter.ToInt32(bnk, pos + 4);
                if (tag == "HIRC")
                {
                    var objects = new Dictionary<uint, (byte, int)>();
                    var count = BitConverter.ToUInt32(bnk, pos + 8);
                    int p = pos + 12;
                    for (uint i = 0; i < count; i++)
                    {
                        byte type = bnk[p];
                        var objectSize = BitConverter.ToInt32(bnk, p + 1);
                        objects[BitConverter.ToUInt32(bnk, p + 5)] = (type, p + 5);
                        p += 5 + objectSize;
                    }
                    return objects;
                }
                pos += 8 + size;
            }
            throw new InvalidDataException($"{BankPath} has no HIRC chunk.");
        }
    }
}
