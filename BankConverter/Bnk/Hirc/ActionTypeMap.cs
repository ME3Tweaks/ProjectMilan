namespace BankConverter.Bnk.Hirc;

/// <summary>
/// Maps v56 AkActionType numeric values to their v134 equivalents. Both enums are built into distinct
/// numeric spaces per Wwise version; most map 1:1 by their (stable) semantic name. The exceptions:
/// v56's SetVolume_*/ResetVolume_* collapse to v134's SetBusVolume_*/ResetBusVolume_* specifically when
/// the action's target is a Bus (Wwise split "volume action on a node" vs "volume action on a bus" into
/// distinct action types at some point); SetLFE_* and SetRTPC have no v134 equivalent at all (LFE-via-action
/// and the standalone SetRTPC action type were removed) and are treated as unsupported.
/// </summary>
public static class ActionTypeMap
{
    private static readonly Dictionary<uint, string> V56IdToName = new()
    {
        { 0x0u, "None" }, { 0x1010u, "Stop_E" }, { 0x1011u, "Stop_E_O" }, { 0x1020u, "Stop_ALL" },
        { 0x1021u, "Stop_ALL_O" }, { 0x1040u, "Stop_AE" }, { 0x1041u, "Stop_AE_O" },
        { 0x2010u, "Pause_E" }, { 0x2011u, "Pause_E_O" }, { 0x2020u, "Pause_ALL" }, { 0x2021u, "Pause_ALL_O" },
        { 0x2040u, "Pause_AE" }, { 0x2041u, "Pause_AE_O" },
        { 0x3010u, "Resume_E" }, { 0x3011u, "Resume_E_O" }, { 0x3020u, "Resume_ALL" }, { 0x3021u, "Resume_ALL_O" },
        { 0x3040u, "Resume_AE" }, { 0x3041u, "Resume_AE_O" },
        { 0x4011u, "Play" }, { 0x5011u, "PlayAndContinue" },
        { 0x6010u, "Mute_M" }, { 0x6011u, "Mute_O" },
        { 0x7010u, "Unmute_M" }, { 0x7011u, "Unmute_O" }, { 0x7020u, "Unmute_ALL" }, { 0x7021u, "Unmute_ALL_O" },
        { 0x7040u, "Unmute_AE" }, { 0x7041u, "Unmute_AE_O" },
        { 0x8010u, "SetPitch_M" }, { 0x8011u, "SetPitch_O" },
        { 0x9010u, "ResetPitch_M" }, { 0x9011u, "ResetPitch_O" }, { 0x9020u, "ResetPitch_ALL" }, { 0x9021u, "ResetPitch_ALL_O" },
        { 0x9040u, "ResetPitch_AE" }, { 0x9041u, "ResetPitch_AE_O" },
        { 0xA010u, "SetVolume_M" }, { 0xA011u, "SetVolume_O" },
        { 0xB010u, "ResetVolume_M" }, { 0xB011u, "ResetVolume_O" }, { 0xB020u, "ResetVolume_ALL" }, { 0xB021u, "ResetVolume_ALL_O" },
        { 0xB040u, "ResetVolume_AE" }, { 0xB041u, "ResetVolume_AE_O" },
        { 0xC010u, "SetLFE_M" }, { 0xC011u, "SetLFE_O" },
        { 0xD010u, "ResetLFE_M" }, { 0xD011u, "ResetLFE_O" }, { 0xD020u, "ResetLFE_ALL" }, { 0xD021u, "ResetLFE_ALL_O" },
        { 0xD040u, "ResetLFE_AE" }, { 0xD041u, "ResetLFE_AE_O" },
        { 0xE010u, "SetLPF_M" }, { 0xE011u, "SetLPF_O" },
        { 0xF010u, "ResetLPF_M" }, { 0xF011u, "ResetLPF_O" }, { 0xF020u, "ResetLPF_ALL" }, { 0xF021u, "ResetLPF_ALL_O" },
        { 0xF040u, "ResetLPF_AE" }, { 0xF041u, "ResetLPF_AE_O" },
        { 0x10010u, "UseState_E" }, { 0x11010u, "UnuseState_E" }, { 0x12020u, "SetState" },
        { 0x13010u, "SetGameParameter" }, { 0x13011u, "SetGameParameter_O" },
        { 0x14010u, "ResetGameParameter" }, { 0x14011u, "ResetGameParameter_O" },
        { 0x20081u, "StopEvent" }, { 0x30081u, "PauseEvent" }, { 0x40081u, "ResumeEvent" },
        { 0x50100u, "Duck" }, { 0x60001u, "SetSwitch" }, { 0x61001u, "SetRTPC" },
        { 0x70010u, "BypassFX_M" }, { 0x70011u, "BypassFX_O" },
        { 0x80010u, "ResetBypassFX_M" }, { 0x80011u, "ResetBypassFX_O" }, { 0x80020u, "ResetBypassFX_ALL" }, { 0x80021u, "ResetBypassFX_ALL_O" },
        { 0x80040u, "ResetBypassFX_AE" }, { 0x80041u, "ResetBypassFX_AE_O" },
        { 0x90010u, "Break_E" }, { 0x90011u, "Break_E_O" },
        { 0xA0000u, "Trigger" }, { 0xA0001u, "Trigger_O" }, { 0xA0010u, "Trigger_E" }, { 0xA0011u, "Trigger_E_O" },
        { 0xB0010u, "Seek_E" }, { 0xB0011u, "Seek_E_O" }, { 0xB0020u, "Seek_ALL" }, { 0xB0021u, "Seek_ALL_O" },
        { 0xB0040u, "Seek_AE" }, { 0xB0041u, "Seek_AE_O" },
    };

    private static readonly Dictionary<string, uint> V134NameToId = new()
    {
        { "None", 0x0u }, { "Stop_E", 0x102u }, { "Stop_E_O", 0x103u }, { "Stop_ALL", 0x104u }, { "Stop_ALL_O", 0x105u },
        { "Stop_AE", 0x108u }, { "Stop_AE_O", 0x109u },
        { "Pause_E", 0x202u }, { "Pause_E_O", 0x203u }, { "Pause_ALL", 0x204u }, { "Pause_ALL_O", 0x205u },
        { "Pause_AE", 0x208u }, { "Pause_AE_O", 0x209u },
        { "Resume_E", 0x302u }, { "Resume_E_O", 0x303u }, { "Resume_ALL", 0x304u }, { "Resume_ALL_O", 0x305u },
        { "Resume_AE", 0x308u }, { "Resume_AE_O", 0x309u },
        { "Play", 0x403u }, { "PlayAndContinue", 0x503u },
        { "Mute_M", 0x602u }, { "Mute_O", 0x603u },
        { "Unmute_M", 0x702u }, { "Unmute_O", 0x703u }, { "Unmute_ALL", 0x704u }, { "Unmute_ALL_O", 0x705u },
        { "Unmute_AE", 0x708u }, { "Unmute_AE_O", 0x709u },
        { "SetPitch_M", 0x802u }, { "SetPitch_O", 0x803u },
        { "ResetPitch_M", 0x902u }, { "ResetPitch_O", 0x903u }, { "ResetPitch_ALL", 0x904u }, { "ResetPitch_ALL_O", 0x905u },
        { "ResetPitch_AE", 0x908u }, { "ResetPitch_AE_O", 0x909u },
        { "SetVolume_M", 0xA02u }, { "SetVolume_O", 0xA03u },
        { "ResetVolume_M", 0xB02u }, { "ResetVolume_O", 0xB03u }, { "ResetVolume_ALL", 0xB04u }, { "ResetVolume_ALL_O", 0xB05u },
        { "ResetVolume_AE", 0xB08u }, { "ResetVolume_AE_O", 0xB09u },
        { "SetBusVolume_M", 0xC02u }, { "SetBusVolume_O", 0xC03u },
        { "ResetBusVolume_M", 0xD02u }, { "ResetBusVolume_O", 0xD03u }, { "ResetBusVolume_ALL", 0xD04u }, { "ResetBusVolume_AE", 0xD08u },
        { "SetLPF_M", 0xE02u }, { "SetLPF_O", 0xE03u },
        { "ResetLPF_M", 0xF02u }, { "ResetLPF_O", 0xF03u }, { "ResetLPF_ALL", 0xF04u }, { "ResetLPF_ALL_O", 0xF05u },
        { "ResetLPF_AE", 0xF08u }, { "ResetLPF_AE_O", 0xF09u },
        { "UseState_E", 0x1002u }, { "UnuseState_E", 0x1102u }, { "SetState", 0x1204u },
        { "SetGameParameter", 0x1302u }, { "SetGameParameter_O", 0x1303u },
        { "ResetGameParameter", 0x1402u }, { "ResetGameParameter_O", 0x1403u },
        { "StopEvent", 0x1511u }, { "PauseEvent", 0x1611u }, { "ResumeEvent", 0x1711u },
        { "Duck", 0x1820u }, { "SetSwitch", 0x1901u },
        { "BypassFX_M", 0x1A02u }, { "BypassFX_O", 0x1A03u },
        { "ResetBypassFX_M", 0x1B02u }, { "ResetBypassFX_O", 0x1B03u }, { "ResetBypassFX_ALL", 0x1B04u }, { "ResetBypassFX_ALL_O", 0x1B05u },
        { "ResetBypassFX_AE", 0x1B08u }, { "ResetBypassFX_AE_O", 0x1B09u },
        { "Break_E", 0x1C02u }, { "Break_E_O", 0x1C03u },
        { "Trigger", 0x1D00u }, { "Trigger_O", 0x1D01u }, { "Trigger_E", 0x1D02u }, { "Trigger_E_O", 0x1D03u },
        { "Seek_E", 0x1E02u }, { "Seek_E_O", 0x1E03u }, { "Seek_ALL", 0x1E04u }, { "Seek_ALL_O", 0x1E05u },
        { "Seek_AE", 0x1E08u }, { "Seek_AE_O", 0x1E09u },
        { "Release", 0x1F02u }, { "Release_O", 0x1F03u },
        { "SetHPF_M", 0x2002u }, { "SetHPF_O", 0x2003u },
        { "PlayEvent", 0x2103u }, { "ResetPlaylist_E", 0x2202u }, { "ResetPlaylist_E_O", 0x2203u },
        { "ResetHPF_M", 0x3002u }, { "ResetHPF_O", 0x3003u }, { "ResetHPF_ALL", 0x3004u }, { "ResetHPF_ALL_O", 0x3005u },
        { "ResetHPF_AE", 0x3008u }, { "ResetHPF_AE_O", 0x3009u },
        { "SetFX_M", 0x3102u }, { "ResetSetFX_M", 0x3202u }, { "ResetSetFX_ALL", 0x3204u },
        { "NoOp", 0x4000u },
    };

    /// <summary>
    /// The 110 CAkBus object IDs present in the ME3 Init.bnk (extracted offline). v56's Action objects
    /// have no explicit "targets a bus" flag on the wire (that's new at v134); we infer it by checking
    /// whether the action's target ID is one of these known bus IDs.
    /// </summary>
    public static readonly HashSet<uint> Me3BusIds = new()
    {
        343668318u, 402936449u, 19020128u, 197922865u, 287680869u, 487410029u, 89318266u, 269880060u, 792477897u, 802503037u,
        815254859u, 947023718u, 333741196u, 380418858u, 452404991u, 211884808u, 237816789u, 467010842u, 290918709u, 377360615u,
        535664403u, 778496319u, 833690460u, 529849633u, 602750205u, 84325102u, 245800439u, 760573032u, 1005271218u, 706671637u,
        5339517u, 153969647u, 155611271u, 294253150u, 332298631u, 418476376u, 495376182u, 539299475u, 576571267u, 584658334u,
        684707941u, 883321636u, 218926220u, 364846767u, 1036955325u, 1049096353u, 956303855u, 48833537u, 55055630u, 509091888u,
        707875851u, 962318178u, 111402221u, 40167958u, 225881980u, 241460521u, 301797290u, 936260532u, 298906434u, 1049715594u,
        127897344u, 451843106u, 682899308u, 766961606u, 475663551u, 610391806u, 847619029u, 1001775861u, 1019006464u, 914176167u,
        3839855u, 9639092u, 22335218u, 85441175u, 171333450u, 177760147u, 208077236u, 225904749u, 226187177u, 341765041u,
        346903954u, 364306615u, 433531174u, 487594136u, 493105782u, 493885003u, 542665972u, 624546869u, 679227403u, 750433239u,
        756256289u, 772769101u, 794911355u, 833759326u, 882524669u, 921901715u, 921941305u, 953600190u, 1009679749u, 964701572u,
        92777953u, 150374614u, 309969274u, 390643868u, 836577006u, 836777764u, 899204371u, 881263378u, 615161265u, 985898339u,
    };

    /// <summary>Converts a v56 action type + knowledge of whether its target is a bus to the v134 numeric id. Returns null if unsupported (SetRTPC/SetLFE, no v134 equivalent).</summary>
    public static uint? ConvertType(uint v56Type, bool targetIsBus)
    {
        if (!V56IdToName.TryGetValue(v56Type, out var name)) return null;

        if (targetIsBus)
        {
            var busName = name switch
            {
                "SetVolume_M" => "SetBusVolume_M",
                "SetVolume_O" => "SetBusVolume_O",
                "ResetVolume_M" => "ResetBusVolume_M",
                "ResetVolume_O" => "ResetBusVolume_O",
                "ResetVolume_ALL" => "ResetBusVolume_ALL",
                "ResetVolume_AE" => "ResetBusVolume_AE",
                _ => name,
            };
            if (V134NameToId.TryGetValue(busName, out var busId)) return busId;
        }

        if (name is "SetLFE_M" or "SetLFE_O" or "ResetLFE_M" or "ResetLFE_O" or "ResetLFE_ALL" or "ResetLFE_ALL_O"
            or "ResetLFE_AE" or "ResetLFE_AE_O" or "SetRTPC")
        {
            return null; // no v134 equivalent
        }

        return V134NameToId.TryGetValue(name, out var id) ? id : null;
    }
}
