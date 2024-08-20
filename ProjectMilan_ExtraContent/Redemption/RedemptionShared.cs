using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Security.AccessControl;
using System.Text;
using System.Threading.Tasks;
using LegendaryExplorerCore.Coalesced;
using LegendaryExplorerCore.Packages;
using LegendaryExplorerCore.TLK;
using LegendaryExplorerCore.TLK.ME2ME3;
using ProjectMilan_ExtraContent.Redemption.Levels;
using ProjectMilanCore;

namespace ProjectMilan_ExtraContent.Redemption
{
    internal class RedemptionShared
    {
        /// <summary>
        /// The current mastermaplist id. This should be tuned so we know exactly where to start when building extra map content.
        /// </summary>
        private static int CurrentMapId = 30;

        /*
         *<Sections>
           	<Section name="sfxgame.sfxengine">
           		<Property name="dynamicloadmapping">
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapMars",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapCronos",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapGellix",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapTrinity",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapAxGlitch",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapAxJungle",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapAxBrimstone",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapAxPainTrain",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapAxWingman",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapAxBlasteroid",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapAxSpinZone",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapAxClassic",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapCitHubBPS1",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapProtoHydra1",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapProtoHydra2",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapNeptune2",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           			<Value type="3">(ObjectName="GUI_MPImages.MatchSettings.OptMapFallOfVancouver",SeekFreePackageName="SFXMPImagesMatchSettings")</Value>
           		</Property>
           	</Section>
           </Sections>
         */

        private static string BuildDLMForImage(string objectName, string sfPackageName = "SFXMPImagesMatchSettings_Milan")
        {
            return $"(ObjectName=\"{objectName}\", SeekFreePackageName =\"{sfPackageName}\"";
        }

        public static string GetMapBaseName(string biopName)
        {
            return biopName.Substring("BioP_MP".Length);
        }

        /// <summary>
        /// Add information to config for this map. The map name must be BioP_MP[MapName].
        /// </summary>
        /// <param name="biop"></param>
        public static void AddLevelToConfig(ECLevelInfo info)
        {
            #region ENGINE
            {
                var engine = RedemptionPipeline.CurrentConfig.GetAsset("BioEngine");
                var sfxengine = engine.GetOrAddSection("sfxgame.sfxengine");

                // Add level image for GUI
                var objName = GetMapBaseName(info.MapName);
                objName = "OptMap" + objName;
                sfxengine.AddEntry(new CoalesceProperty("dynamicloadmapping", new CoalesceValue(BuildDLMForImage(objName), CoalesceParseAction.AddUnique)));
            }
            #endregion

            #region GAME

            {
                var game = RedemptionPipeline.CurrentConfig.GetAsset("BioGame");
                var onlinegamesettings = game.GetOrAddSection("sfxonlinefoundation.sfxonlinegamesettings");

                // Add to availablemaps
                onlinegamesettings.AddEntry(new CoalesceProperty("availablemaps", new CoalesceValue(info.MapName, CoalesceParseAction.AddUnique)));

                // Add to mastermaplist
                onlinegamesettings.AddEntry(new CoalesceProperty("mastermaplist", new CoalesceValue(BuildMasterMapEntry(info), CoalesceParseAction.AddUnique)));
            }

            #endregion

            CurrentMapId++;
            if (CurrentMapId > 64)
            {
                // This is not supported due to 64 bit replication... I think? It's a bitmask
                Debugger.Break();
            }
        }

        private static string BuildMasterMapEntry(ECLevelInfo info)
        {
            return $"(ID={CurrentMapId}, " +
                   $"PackageName=\"{info.MapName}\", " +
                   $"PrettyName={AssignTLK(info.LevelNameString)}, " +
                   $"Description={AssignTLK(info.LevelDescriptionString)}, " +
                   $"Image=\"SFXMPImagesMatchSettings_Milan.OptMap{GetMapBaseName(info.MapName)}\", " +
                   $"GalaxyAtWarMapPosition=(X={info.GAWMapPosition.X},Y={info.GAWMapPosition.Y}), " +
                   $"GalaxyAtWarMapSubtitle={AssignTLK(info.GAWMapSubtitle)}, " +
                   $"MusicEventName=\"{GetMusicEventName()}\")";
        }

        private static int MusicEventNameIdx = 4; // See comment below.

        private static string[] MusicEvents =
        [
            "Set_mus_map_mpslum",
            "Set_mus_map_mpdish",
            "Set_mus_map_mprctr",
            "Set_mus_map_mpnov",
            "Set_mus_map_mptowr", // Last official map is 'Nov2' which uses mpnov.
            "Set_mus_map_mpcer",
        ];

        /// <summary>
        /// Gets the name of the music event. It loops around the array.
        /// </summary>
        /// <returns></returns>
        private static string GetMusicEventName()
        {
            return MusicEvents[MusicEventNameIdx++ % MusicEvents.Length];
        }

        #region TLK
        private static int CurrentTLKId = 65462165; // Todo: Find base
        private static Dictionary<MELocalization, ME2ME3TalkFile> Tlks;
        private static string BaseTlkName;
        private static int AssignTLK(Dictionary<MELocalization, string> localizationData)
        {
            if (Tlks == null)
                LoadTlks();

            foreach (var loc in localizationData)
            {
                Tlks[loc.Key].AddString(new TLKStringRef(CurrentTLKId,loc.Value));
            }

            return CurrentTLKId++;
        }

        private static void LoadTlks()
        {
            Tlks = new Dictionary<MELocalization, ME2ME3TalkFile>();
            var outDir = Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole");
            var tlkFiles = Directory.GetFiles(outDir, "*.tlk", SearchOption.TopDirectoryOnly);
            foreach (var tlk in tlkFiles)
            {
                BaseTlkName ??= Path.GetFileNameWithoutExtension(tlk).StripUnrealLocalization();
                var loc = tlk.GetUnrealLocalization();
                Tlks[loc] = new ME2ME3TalkFile(tlk);
            }
        }

        public static void SaveTlks()
        {
            if (Tlks == null)
                return; // No TLK data defined
            var outDir = Path.Combine(BaseBuildSettings.OutputModPath, "CookedPCConsole");
            foreach (var tlk in Tlks)
            {
                var outPath = Path.Combine(outDir, BaseTlkName + "_" + tlk.Key + ".tlk");
                HuffmanCompression.SaveToTlkFile(outPath, tlk.Value.StringRefs);
            }
        }

        #endregion
    }
}
