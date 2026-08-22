using System.Collections.Concurrent;

namespace BankConverter.Bnk;

/// <summary>
/// Maps ME3 (v56) bus IDs to their LE3 (v134) equivalents. The Init.bnk bus hierarchy was restructured
/// and renamed between Wwise versions, so this can't be derived from ID math or a Wwise project alone.
///
/// Merged from three independently-derived sources, highest priority first, with zero value conflicts
/// found between them on any shared key:
///   1. Empirical cross-reference: matching OverrideBusId on objects whose own ID is unchanged between
///      ME3 and LE3 (same name -> same hash), sampled across ~450 real bank pairs. Most trustworthy -
///      grounded directly in real compiled game bytes.
///   2. ProjectMilan/Pipelines/Audio/Wwise/BusIdMap.json - pre-existing project data (71 entries).
///   3. ProjectMilan/Pipelines/Audio/Wwise/{ME3,LE3}/SFXWwise_Init.Init.txt - two name-resolved bus
///      listings joined by bus name. Lowest priority: hand-annotated (one entry flagged "GUESS" in the
///      source, matched by content instead) and had one corrupted/oversized ID that was dropped.
/// Covers 103 of the 110 known ME3 buses (the rest were never observed referenced anywhere and have no
/// data in any source - presumably orphaned/unused). See <see cref="FallbackUses"/>.
/// </summary>
public static class BusRemap
{
    private static readonly Dictionary<uint, uint> Map = new()
    {
        { 0u, 0u },
        { 3839855u, 3707038729u }, // Ducker-Weapons-Sniper
        { 5339517u, 4244958222u }, // Env-Snd-1-Weapons-NonPlayer_Fire
        { 9639092u, 78998992u }, // Ducker-Shield-Down
        { 19020128u, 3922907557u }, // Enviromental
        { 22335218u, 1244205688u }, // Ducker-CineAnim-FastRel
        { 40167958u, 3698917345u }, // NonEnv-Snd-0-NonDucking
        { 48833537u, 3217963062u }, // SET YOUR BUS
        { 55055630u, 2724304647u }, // Env-Snd-1-Amb-NonStream
        { 78998992u, 78998992u }, // Ducker-Shield-Down
        { 84325102u, 4052811563u }, // PlayerBulletImpacts
        { 88173976u, 88173976u }, // Env-Snd-0-CineAnim
        { 89318266u, 2869960671u }, // Env-Snd-0-CineD-SkipKill
        { 92777953u, 3234900597u }, // NonSlowdown-Sound Effects
        { 111402221u, 2101962433u }, // Non-Environmental
        { 127897344u, 4267684745u }, // NonEnv-VO
        { 150374614u, 4054232556u }, // LevelTransBinks-Duck
        { 153969647u, 2262755739u }, // Env-Snd-1-Creatures
        { 155611271u, 370644045u }, // Env-Snd-1-Weapons-Foley-Expand
        { 177760147u, 1241218641u }, // Ducker-LevelUp
        { 192878726u, 192878726u }, // Env-Snd-0-ProceduralFoley
        { 197922865u, 4265682411u }, // Env-Snd-2-PlayerPowers
        { 208077236u, 4134251608u }, // Ducker-CineAnim-FastRel-12
        { 211884808u, 88325593u }, // Env-VO-Ambient-Duck
        { 218926220u, 2982121192u }, // Env-Snd-1-Bullets-Impacts
        { 225881980u, 2940937671u }, // NonEnv-Snd-0-CineAnim
        { 225904749u, 2612301291u }, // Ducker-Galaxy Map Music
        { 226187177u, 1382909311u }, // Ducker-LvlEvent-FullDuck
        { 237816789u, 1778000592u }, // Env-VO-Ambient-NonDuck
        { 241460521u, 3658140751u }, // NonEnv-Snd-0-AtlasInt
        { 245800439u, 3033195755u }, // PlayerWeapons-Env
        { 269880060u, 661759782u }, // Env-Snd-0-CineD-SkipNoKill
        { 287680869u, 2942448014u }, // Env-Snd-0-NonDucking
        { 290918709u, 3923201285u }, // Env-VO-Ambient-Critical
        { 294253150u, 3403562848u }, // Env-Snd-1-Footsteps
        { 298906434u, 3939795693u }, // NonEnv-Snd-0-CineD-SkipNoKill
        { 301797290u, 1304055404u }, // NonEnv-Snd-0-LevelEvents
        { 309969274u, 2253961981u }, // NonSlowdown-GUI Sounds
        { 332298631u, 222669541u }, // Env-Snd-1-Powers
        { 333741196u, 383753028u }, // Env-Snd-5-Critical
        { 341765041u, 1708961637u }, // Ducker-Foley-Power
        { 343668318u, 3803692087u }, // Master Audio Bus
        { 364306615u, 2774044111u }, // Ducker-Powers-HeavyDuck
        { 364846767u, 2836167243u }, // Env-Snd-1-Bullets-Whizzes
        { 373162680u, 373162680u }, // Migrated
        { 377360615u, 420012082u }, // Env-VO-Exertions
        { 380418858u, 440861076u }, // Env-Music
        { 390643868u, 2072553425u }, // NonSlowdown-PlayerCombat
        { 402936449u, 2732954577u }, // Slowdown and Bleedout Affected
        { 418476376u, 1746439591u }, // Env-Snd-1-Placeables
        { 433531174u, 3414654191u }, // Ducker-CineAnim-SlowRel
        { 451843106u, 2091861047u }, // NonEnv-VO-Radio-Critical
        { 452404991u, 2341776094u }, // Env-VO
        { 467010842u, 455854849u }, // Env-Duck-VO-Amb-NonDuck-DuckedByConvo
        { 475663551u, 3332344874u }, // Mus-0-No Ducking - Intermittent
        { 487410029u, 1428943757u }, // Env-Snd-0-CineDesign
        { 487594136u, 796533304u }, // Ducker-Weapons-PlayerBulletImpacts
        { 493885003u, 1787345229u }, // Music - Death
        { 495376182u, 2684598355u }, // Env-Snd-1-Weapons-NonPlayer_Env
        { 509091888u, 2339288502u }, // Env-Snd-1-Amb-Stream
        { 529849633u, 3964092493u }, // Env-Snd-3-CreatureCritical
        { 535664403u, 2590885273u }, // Env-VO-SoundSet-NonDuck
        { 539299475u, 3869888268u }, // Env-Snd-1-Vehicles
        { 542665972u, 4048526902u }, // Ducker-Creature-HeavyDuck
        { 576571267u, 3057727322u }, // Env-Snd-1-Weapons-Foley-Reload
        { 584658334u, 1333022690u }, // Env-Snd-1-Weapons
        { 602750205u, 2052984724u }, // Env-Snd-2-PlayerWeapons
        { 608083365u, 608083365u }, // Ducker-MutePlayerGuns
        { 610391806u, 2218411713u }, // Mus-0-No Ducking - Hubs
        { 615161265u, 1503374211u }, // NonSlowdown-Music
        { 661759782u, 661759782u }, // Env-Snd-0-CineD-SkipNoKill
        { 679227403u, 1996998374u }, // Ducker-LevelTransitions
        { 682899308u, 1589046909u }, // NonEnv-VO-Radio-Convo
        { 684707941u, 1656579942u }, // Env-Snd-1-Physics
        { 706671637u, 4023386529u }, // Env-Snd-1-Norm-FastRel
        { 707875851u, 3553752469u }, // Env-Snd-1-VFX
        { 750433239u, 3703183838u }, // Ducker-Weapons-Shotgun
        { 756256289u, 3965866029u }, // Ducker-Placeables-FullDuck
        { 760573032u, 750429206u }, // PlayerWeapons-Fire
        { 766961606u, 3366596028u }, // NonEnv-Music-Score
        { 772769101u, 1636967957u }, // Ducker-Weapons-Assault
        { 778496319u, 4260460850u }, // Env-VO-SoundSet-Duck
        { 794911355u, 3432369300u }, // Ducker-Explosion-Grenade
        { 796533304u, 796533304u }, // Ducker-Weapons-PlayerBulletImpacts
        { 802503037u, 3632094382u }, // Env-Snd-0-LevelTransitions
        { 815254859u, 192878726u }, // Env-Snd-0-ProceduralFoley
        { 833690460u, 301674290u }, // Env-VO-Conversation
        { 836577006u, 3877006278u }, // NonSlowdown-BulletWizzes
        { 836777764u, 2413696188u }, // NonSlowdown-SniperScopes
        { 847619029u, 381320459u }, // Mus-1-Moderate Ducking
        { 881263378u, 2238812953u }, // NonSlowdown-FinaleBink
        { 882524669u, 1320340349u }, // Ducker-Weapons-Pistol
        { 883321636u, 1578058874u }, // Env-Snd-1-Bullets
        { 899204371u, 3805802625u }, // NonSlowdown-ShieldDown
        { 914176167u, 1384098367u }, // Ducking Control Buses
        { 921901715u, 3131594682u }, // Ducker-MuteAmbiences
        { 921941305u, 2122765108u }, // Ducker-CreatureLarge-Proximity
        { 936260532u, 589371832u }, // NonEnv-Snd-0-CineDes
        { 947023718u, 2679493409u }, // Env-Snd-0-LevelEvents
        { 953600190u, 2665178859u }, // Ducker-LvlEvent-HeavyDuck
        { 956303855u, 2645236474u }, // Env-Snd-1-Norm-SlowRel
        { 962318178u, 1712487096u }, // Env-Snd-4-Explosions
        { 964701572u, 113282184u }, // Slowdown and Bleedout UnAffected
        { 985898339u, 2780884782u }, // NonSlowdown-Dialog
        { 1001775861u, 3402299164u }, // Mus-2-Heavy Ducking
        { 1005271218u, 4130147015u }, // PlayerWeapons-Bass
        { 1009679749u, 3594844694u }, // Ducker-Foley-Punch
        { 1019006464u, 3203258222u }, // Mus-0-No Ducking
        { 1036955325u, 896595700u }, // Env-Snd-1-Weapons-Foley-Collapse
        { 1049096353u, 3494370452u }, // Env-Snd-1-Foley
        { 1049715594u, 2042131000u }, // NonEnv-Snd-0-CineD-SkipKill
        { 1241218641u, 1241218641u }, // Ducker-LevelUp
        { 1244205688u, 1244205688u }, // Ducker-CineAnim-FastRel
        { 1304055404u, 1304055404u }, // NonEnv-Snd-0-LevelEvents
        { 1320340349u, 1320340349u }, // Ducker-Weapons-Pistol
        { 1382909311u, 1382909311u }, // Ducker-LvlEvent-FullDuck
        { 1708961637u, 1708961637u }, // Ducker-Foley-Power
        { 1996998374u, 1996998374u }, // Ducker-LevelTransitions
        { 2042131000u, 2042131000u }, // NonEnv-Snd-0-CineD-SkipKill
        { 2612301291u, 2612301291u }, // Ducker-Galaxy Map Music
        { 2665178859u, 2665178859u }, // Ducker-LvlEvent-HeavyDuck
        { 2690050209u, 2690050209u }, // Ducker-CineAnim-SlowRel-12
        { 2774044111u, 2774044111u }, // Ducker-Powers-HeavyDuck
        { 2836167243u, 2836167243u }, // Env-Snd-1-Bullets-Whizzes
        { 2869960671u, 2869960671u }, // Env-Snd-0-CineD-SkipKill
        { 2940937671u, 2940937671u }, // NonEnv-Snd-0-CineAnim
        { 2982121192u, 2982121192u }, // Env-Snd-1-Bullets-Impacts
        { 3057727322u, 3057727322u }, // Env-Snd-1-Weapons-Foley-Reload
        { 3121540630u, 3121540630u }, // Ducker-Weapons-AutoCompressor
        { 3403562848u, 3403562848u }, // Env-Snd-1-Footsteps
        { 3414654191u, 3414654191u }, // Ducker-CineAnim-SlowRel
        { 3432369300u, 3432369300u }, // Ducker-Explosion-Grenade
        { 3494370452u, 3494370452u }, // Env-Snd-1-Foley
        { 3594844694u, 3594844694u }, // Ducker-Foley-Punch
        { 3632094382u, 3632094382u }, // Env-Snd-0-LevelTransitions
        { 3658140751u, 3658140751u }, // NonEnv-Snd-0-AtlasInt
        { 3703183838u, 3703183838u }, // Ducker-Weapons-Shotgun
        { 3869888268u, 3869888268u }, // Env-Snd-1-Vehicles
        { 3939795693u, 3939795693u }, // NonEnv-Snd-0-CineD-SkipNoKill
        { 4026059347u, 4026059347u }, // Ducker-Weapons-Scorpion
        { 4048526902u, 4048526902u }, // Ducker-Creature-HeavyDuck
        { 4134251608u, 4134251608u }, // Ducker-CineAnim-FastRel-12
        { 4204195724u, 4204195724u }, // Ducker-CreatureSmall-Proximity
    };

    // !! DANGER - FALLBACK BUS TARGET !!
    // "Master Audio Bus" is the root of the v134 bus tree, with NO attenuation/ducking/volume
    // shaping applied - it plays unmodified at full/raw volume. It is used ONLY as a last-resort
    // fallback for a v56 bus ID this table has no mapping for. A passthrough of an unmapped ID is
    // guaranteed invalid at v134 (verified against the real Wwise SDK: bank loading hard-fails with
    // "Master bus structure not loaded" on any unresolved bus reference), so this fallback trades a
    // guaranteed load failure for a bank that loads but may route affected sounds LOUD AND UNMIXED.
    // Every fallback use is recorded in FallbackUses below - treat a non-empty list as a release
    // blocker requiring either a real mapping or manual review, not a shippable default.
    private const uint MasterAudioBusV134 = 3803692087u;

    /// <summary>Every (unmapped v56 bus ID -> occurrence count) that fell back to <see cref="MasterAudioBusV134"/> this run.
    /// Concurrent, since bank conversion (and therefore Remap calls) can run in parallel across multiple banks.</summary>
    public static readonly ConcurrentDictionary<uint, int> FallbackUses = new();

    public static uint Remap(uint me3BusId)
    {
        if (me3BusId == 0) return 0;
        if (Map.TryGetValue(me3BusId, out var v134Id)) return v134Id;
        FallbackUses.AddOrUpdate(me3BusId, 1, (_, count) => count + 1);
        return MasterAudioBusV134; // !! FALLBACK: unmixed, full-volume Master Audio Bus - see comment above !!
    }
}
