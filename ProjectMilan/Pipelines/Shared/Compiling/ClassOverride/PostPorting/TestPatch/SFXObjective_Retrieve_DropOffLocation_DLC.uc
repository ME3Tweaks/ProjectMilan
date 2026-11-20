// Source: ME3, Patch_ObjtvRtrvDropOffLocationDLC
// Decompiled 11/17/2026 7:37:53 AM against SFXEngagement_RetrieveDLC.pcc
Class SFXObjective_Retrieve_DropOffLocation_DLC extends SFXOperationObjective
    placeable
    config(Game);

var config array<int> ObjectDroppedVOLines;
var config array<int> PlayerDownedVOLines;
var Object.Vector DropZoneEmitterTranslation;
var SFXDecalActorSpawnable GroundDecal;
var SFXDecalActorSpawnable GroundDecalArchetype;
var ParticleSystem PS_DropZoneTemplate;
var SFXEmitter DropZoneEmitter;
var float DropZoneTemplateScale;
var const stringref SrDropOffObjectiveMarker;
var SFXEngagement_Retrieve_DLC_Base RetrieveWave;
var BioConversation ConvRef;
var config float InstructionReminderFrequency;
var config float LastReminderTime;

public event simulated function Destroyed()
{
    if (GroundDecal != None)
    {
        GroundDecal.Destroy();
    }
    if (DropZoneEmitter != None)
    {
        DropZoneEmitter.SetLifetime(0.100000001);
        DropZoneEmitter.ParticleSystemComponent.SetActive(FALSE);
        DropZoneEmitter.Destroy();
        DropZoneEmitter = None;
    }
    ClearTimer('PlayInstructionReminderVO');
    ClearTimer('PlayTakingTooLongVO');
    ClearTimer('PlayAlmostOutOfTimeVO');
    Super.Destroyed();
}
public simulated function PostBeginPlay()
{
    local SFXModule_MarkerObjective ObjectiveModule;
    
    Super.PostBeginPlay();
    GroundDecal = Spawn(Class'SFXDecalActorSpawnable', Self, 'AnnexDecal', location, Rotator(vect(0.0, 0.0, -1.0)), GroundDecalArchetype, TRUE, FALSE);
    ObjectiveModule = GetModule(Class'SFXModule_MarkerObjective');
    ObjectiveModule.MarkerType = "RetrieveDropOffDLC";
    ObjectiveModule.MarkerLabel = SrDropOffObjectiveMarker;
    DropZoneEmitter = Spawn(Class'SFXEmitter', Self, 'RetrieveEmitter', location + DropZoneEmitterTranslation, Rotation, , TRUE);
    if (DropZoneEmitter != None)
    {
        DropZoneEmitter.SetTemplate(PS_DropZoneTemplate);
        DropZoneEmitter.SetLifetime(0.0);
        DropZoneEmitter.ParticleSystemComponent.SetScale(DropZoneTemplateScale);
        DropZoneEmitter.ParticleSystemComponent.SetActive(TRUE);
    }
    if (Role == ENetRole.ROLE_Authority)
    {
        SetTimer(InstructionReminderFrequency, TRUE, 'PlayInstructionReminderVO', );
        SetTimer(LastReminderTime, FALSE, 'PlayAlmostOutOfTimeVO', );
    }
}
public event function Touch(Actor Other, PrimitiveComponent OtherComp, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local SFXPawn_Player Player;
    local SFXObjective_Retrieve_PickupObject_DLC PickUpObject;
    local Actor ObjectiveActor;
    
    if (Role == ENetRole.ROLE_Authority)
    {
        Player = SFXPawn_Player(Other);
        if (Player == None)
        {
            return;
        }
        if (RetrieveWave != None)
        {
            if (RetrieveWave.IsCarryingPickup(Player))
            {
                foreach RetrieveWave.ObjectiveActors(ObjectiveActor, )
                {
                    PickUpObject = SFXObjective_Retrieve_PickupObject_DLC(ObjectiveActor);
                    if (PickUpObject != None && PickUpObject.PickedUpBy == Player)
                    {
                        PickUpObject.ReplicatePickupObjectEvent(2, Player);
                        ObjectDroppedOff(PickUpObject);
                        Player.StartCustomAction(27);
                        Deactivate();
                        break;
                    }
                }
            }
        }
    }
}
public simulated function ObjectDroppedOff(SFXObjective_Retrieve_PickupObject_DLC PickUpObject)
{
    if (RetrieveWave != None)
    {
        RetrieveWave.PickupDroppedOff(PickUpObject.PickedUpBy, PickUpObject);
        PickUpObject.ObjectDroppedOff();
        if (Role == ENetRole.ROLE_Authority)
        {
            SetTimer(InstructionReminderFrequency, TRUE, 'PlayInstructionReminderVO', );
        }
        ClearTimer('PlayTakingTooLongVO');
    }
}
public function ObjectPickedUp(SFXPawn_Player Player)
{
    local SFXPawn_Player TouchingPlayer;
    
    if (Player != None)
    {
        ActivateObjective();
        ClearTimer('PlayInstructionReminderVO');
        if (Role == ENetRole.ROLE_Authority)
        {
            SetTimer(1.5, FALSE, 'PlayPickedUpVO', );
            SetTimer(InstructionReminderFrequency, TRUE, 'PlayTakingTooLongVO', );
        }
        foreach TouchingActors(Class'SFXPawn_Player', TouchingPlayer, )
        {
            if (TouchingPlayer == Player)
            {
                Touch(Player, None, vect(0.0, 0.0, 0.0), vect(0.0, 0.0, 1.0));
                break;
            }
        }
    }
}
public function PlayInstructionReminderVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('InstructionReminder');
}
public simulated function SetOwningWave(SFXWave_Operation NewOwner)
{
    Super.SetOwningWave(NewOwner);
    RetrieveWave = SFXEngagement_Retrieve_DLC_Base(NewOwner);
}
public function ObjectDropped(bool bPlayDownedVO)
{
    if (Role == ENetRole.ROLE_Authority)
    {
        if (bPlayDownedVO)
        {
            SetTimer(1.5, FALSE, 'PlayDownedVO', );
        }
        else
        {
            SetTimer(1.5, FALSE, 'PlayDroppedVO', );
        }
        ClearTimer('PlayTakingTooLongVO');
        SetTimer(InstructionReminderFrequency, TRUE, 'PlayInstructionReminderVO', );
    }
}
public function PlayDownedVO()
{
    SimpleDialogPlayer.PlayVOEventLine('Dropped', PlayerDownedVOLines[Rand(PlayerDownedVOLines.Length)]);
}
public function PlayDroppedVO()
{
    SimpleDialogPlayer.PlayVOEventLine('Dropped', ObjectDroppedVOLines[Rand(ObjectDroppedVOLines.Length)]);
}
public function PlayPickedUpVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('PickedUp');
}
public function PlayTakingTooLongVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('TakingTooLong');
}
public function PlayAlmostOutOfTimeVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('AlmostOutOfTime');
}
public function PlayWaveInstructionsVO()
{
    SimpleDialogPlayer.PlayVOEventRandomLine('CustomWaveStartedInstructions');
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=BioSimpleDialog Name=SimpleDialog0
        DialogLinesMale = ({srText = $711874, pCue = None}, 
                           {srText = $711875, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711875_m_Play'}, 
                           {srText = $711876, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711876_m_Play'}, 
                           {srText = $711877, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711877_m_Play'}, 
                           {srText = $711878, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711878_m_Play'}, 
                           {srText = $711879, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711879_m_Play'}, 
                           {srText = $711880, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711880_m_Play'}, 
                           {srText = $711881, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711881_m_Play'}, 
                           {srText = $711882, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711882_m_Play'}, 
                           {srText = $711883, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711883_m_Play'}, 
                           {srText = $711884, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711884_m_Play'}, 
                           {srText = $711885, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711885_m_Play'}, 
                           {srText = $711886, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711886_m_Play'}, 
                           {srText = $711887, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711887_m_Play'}, 
                           {srText = $711888, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711888_m_Play'}, 
                           {srText = $711889, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711889_m_Play'}, 
                           {srText = $711890, pCue = None}, 
                           {srText = $711891, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711891_m_Play'}, 
                           {srText = $711892, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711892_m_Play'}, 
                           {srText = $711893, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711893_m_Play'}, 
                           {srText = $711894, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711894_m_Play'}, 
                           {srText = $711895, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711895_m_Play'}, 
                           {srText = $711896, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711896_m_Play'}, 
                           {srText = $711897, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711897_m_Play'}, 
                           {srText = $711898, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711898_m_Play'}, 
                           {srText = $711899, pCue = None}, 
                           {srText = $711900, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711900_m_Play'}, 
                           {srText = $711901, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711901_m_Play'}, 
                           {srText = $711902, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711902_m_Play'}, 
                           {srText = $711903, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711903_m_Play'}, 
                           {srText = $711904, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711904_m_Play'}, 
                           {srText = $711905, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711905_m_Play'}, 
                           {srText = $711906, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711906_m_Play'}, 
                           {srText = $711907, pCue = None}, 
                           {srText = $711908, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711908_m_Play'}, 
                           {srText = $711909, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711909_m_Play'}, 
                           {srText = $711910, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711910_m_Play'}, 
                           {srText = $711911, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711911_m_Play'}, 
                           {srText = $711912, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711912_m_Play'}, 
                           {srText = $711913, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711913_m_Play'}, 
                           {srText = $711914, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711914_m_Play'}, 
                           {srText = $711915, pCue = None}, 
                           {srText = $711916, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711916_m_Play'}, 
                           {srText = $711917, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711917_m_Play'}, 
                           {srText = $711918, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711918_m_Play'}, 
                           {srText = $711919, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711919_m_Play'}, 
                           {srText = $711920, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711920_m_Play'}, 
                           {srText = $711921, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711921_m_Play'}, 
                           {srText = $711922, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711922_m_Play'}, 
                           {srText = $711923, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711923_m_Play'}, 
                           {srText = $711924, pCue = None}, 
                           {srText = $711925, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711925_m_Play'}, 
                           {srText = $711926, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711926_m_Play'}, 
                           {srText = $711927, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711927_m_Play'}, 
                           {srText = $711928, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711928_m_Play'}, 
                           {srText = $711929, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711929_m_Play'}, 
                           {srText = $711930, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711930_m_Play'}, 
                           {srText = $711931, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711931_m_Play'}, 
                           {srText = $711932, pCue = None}, 
                           {srText = $711933, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711933_m_Play'}, 
                           {srText = $711934, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711934_m_Play'}, 
                           {srText = $711935, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711935_m_Play'}, 
                           {srText = $711936, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711936_m_Play'}, 
                           {srText = $711937, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711937_m_Play'}, 
                           {srText = $711938, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711938_m_Play'}, 
                           {srText = $711939, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711939_m_Play'}, 
                           {srText = $711940, pCue = None}, 
                           {srText = $711941, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711941_m_Play'}, 
                           {srText = $711942, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711942_m_Play'}, 
                           {srText = $711943, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711943_m_Play'}, 
                           {srText = $711944, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711944_m_Play'}, 
                           {srText = $711945, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711945_m_Play'}, 
                           {srText = $711946, pCue = None}, 
                           {srText = $711947, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711947_m_Play'}, 
                           {srText = $711948, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711948_m_Play'}, 
                           {srText = $711949, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711949_m_Play'}, 
                           {srText = $711950, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711950_m_Play'}, 
                           {srText = $711951, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711951_m_Play'}, 
                           {srText = $711952, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711952_m_Play'}, 
                           {srText = $711953, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711953_m_Play'}, 
                           {srText = $711954, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711954_m_Play'}, 
                           {srText = $711955, pCue = None}, 
                           {srText = $711956, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711956_m_Play'}, 
                           {srText = $711957, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711957_m_Play'}, 
                           {srText = $711958, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711958_m_Play'}, 
                           {srText = $711959, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711959_m_Play'}, 
                           {srText = $711960, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711960_m_Play'}, 
                           {srText = $711961, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711961_m_Play'}, 
                           {srText = $711962, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711962_m_Play'}, 
                           {srText = $711963, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711963_m_Play'}, 
                           {srText = $711964, pCue = None}, 
                           {srText = $711965, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711965_m_Play'}, 
                           {srText = $711966, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711966_m_Play'}, 
                           {srText = $711967, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711967_m_Play'}, 
                           {srText = $711968, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711968_m_Play'}, 
                           {srText = $711969, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711969_m_Play'}, 
                           {srText = $711970, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711970_m_Play'}, 
                           {srText = $711971, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711971_m_Play'}, 
                           {srText = $711972, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711972_m_Play'}, 
                           {srText = $711973, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711973_m_Play'}, 
                           {srText = $711974, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711974_m_Play'}, 
                           {srText = $711975, pCue = None}, 
                           {srText = $711976, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711976_m_Play'}, 
                           {srText = $711977, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711977_m_Play'}, 
                           {srText = $711978, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711978_m_Play'}, 
                           {srText = $711979, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711979_m_Play'}, 
                           {srText = $711980, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711980_m_Play'}, 
                           {srText = $711981, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711981_m_Play'}, 
                           {srText = $711982, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711982_m_Play'}, 
                           {srText = $711983, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711983_m_Play'}, 
                           {srText = $711984, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711984_m_Play'}, 
                           {srText = $711985, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711985_m_Play'}
                          )
        DialogLinesFemale = ({srText = $711874, pCue = None}, 
                             {srText = $711875, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711875_f_Play'}, 
                             {srText = $711876, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711876_f_Play'}, 
                             {srText = $711877, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711877_f_Play'}, 
                             {srText = $711878, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711878_f_Play'}, 
                             {srText = $711879, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711879_f_Play'}, 
                             {srText = $711880, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711880_f_Play'}, 
                             {srText = $711881, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711881_f_Play'}, 
                             {srText = $711882, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711882_f_Play'}, 
                             {srText = $711883, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711883_f_Play'}, 
                             {srText = $711884, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711884_f_Play'}, 
                             {srText = $711885, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711885_f_Play'}, 
                             {srText = $711886, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711886_f_Play'}, 
                             {srText = $711887, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711887_f_Play'}, 
                             {srText = $711888, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711888_f_Play'}, 
                             {srText = $711889, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711889_f_Play'}, 
                             {srText = $711890, pCue = None}, 
                             {srText = $711891, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711891_f_Play'}, 
                             {srText = $711892, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711892_f_Play'}, 
                             {srText = $711893, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711893_f_Play'}, 
                             {srText = $711894, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711894_f_Play'}, 
                             {srText = $711895, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711895_f_Play'}, 
                             {srText = $711896, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711896_f_Play'}, 
                             {srText = $711897, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711897_f_Play'}, 
                             {srText = $711898, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711898_f_Play'}, 
                             {srText = $711899, pCue = None}, 
                             {srText = $711900, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711900_f_Play'}, 
                             {srText = $711901, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711901_f_Play'}, 
                             {srText = $711902, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711902_f_Play'}, 
                             {srText = $711903, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711903_f_Play'}, 
                             {srText = $711904, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711904_f_Play'}, 
                             {srText = $711905, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711905_f_Play'}, 
                             {srText = $711906, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711906_f_Play'}, 
                             {srText = $711907, pCue = None}, 
                             {srText = $711908, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711908_f_Play'}, 
                             {srText = $711909, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711909_f_Play'}, 
                             {srText = $711910, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711910_f_Play'}, 
                             {srText = $711911, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711911_f_Play'}, 
                             {srText = $711912, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711912_f_Play'}, 
                             {srText = $711913, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711913_f_Play'}, 
                             {srText = $711914, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711914_f_Play'}, 
                             {srText = $711915, pCue = None}, 
                             {srText = $711916, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711916_f_Play'}, 
                             {srText = $711917, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711917_f_Play'}, 
                             {srText = $711918, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711918_f_Play'}, 
                             {srText = $711919, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711919_f_Play'}, 
                             {srText = $711920, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711920_f_Play'}, 
                             {srText = $711921, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711921_f_Play'}, 
                             {srText = $711922, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711922_f_Play'}, 
                             {srText = $711923, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711923_f_Play'}, 
                             {srText = $711924, pCue = None}, 
                             {srText = $711925, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711925_f_Play'}, 
                             {srText = $711926, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711926_f_Play'}, 
                             {srText = $711927, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711927_f_Play'}, 
                             {srText = $711928, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711928_f_Play'}, 
                             {srText = $711929, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711929_f_Play'}, 
                             {srText = $711930, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711930_f_Play'}, 
                             {srText = $711931, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711931_f_Play'}, 
                             {srText = $711932, pCue = None}, 
                             {srText = $711933, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711933_f_Play'}, 
                             {srText = $711934, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711934_f_Play'}, 
                             {srText = $711935, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711935_f_Play'}, 
                             {srText = $711936, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711936_f_Play'}, 
                             {srText = $711937, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711937_f_Play'}, 
                             {srText = $711938, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711938_f_Play'}, 
                             {srText = $711939, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711939_f_Play'}, 
                             {srText = $711940, pCue = None}, 
                             {srText = $711941, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711941_f_Play'}, 
                             {srText = $711942, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711942_f_Play'}, 
                             {srText = $711943, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711943_f_Play'}, 
                             {srText = $711944, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711944_f_Play'}, 
                             {srText = $711945, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711945_f_Play'}, 
                             {srText = $711946, pCue = None}, 
                             {srText = $711947, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711947_f_Play'}, 
                             {srText = $711948, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711948_f_Play'}, 
                             {srText = $711949, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711949_f_Play'}, 
                             {srText = $711950, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711950_f_Play'}, 
                             {srText = $711951, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711951_f_Play'}, 
                             {srText = $711952, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711952_f_Play'}, 
                             {srText = $711953, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711953_f_Play'}, 
                             {srText = $711954, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711954_f_Play'}, 
                             {srText = $711955, pCue = None}, 
                             {srText = $711956, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711956_f_Play'}, 
                             {srText = $711957, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711957_f_Play'}, 
                             {srText = $711958, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711958_f_Play'}, 
                             {srText = $711959, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711959_f_Play'}, 
                             {srText = $711960, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711960_f_Play'}, 
                             {srText = $711961, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711961_f_Play'}, 
                             {srText = $711962, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711962_f_Play'}, 
                             {srText = $711963, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711963_f_Play'}, 
                             {srText = $711964, pCue = None}, 
                             {srText = $711965, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711965_f_Play'}, 
                             {srText = $711966, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711966_f_Play'}, 
                             {srText = $711967, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711967_f_Play'}, 
                             {srText = $711968, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711968_f_Play'}, 
                             {srText = $711969, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711969_f_Play'}, 
                             {srText = $711970, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711970_f_Play'}, 
                             {srText = $711971, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711971_f_Play'}, 
                             {srText = $711972, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711972_f_Play'}, 
                             {srText = $711973, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711973_f_Play'}, 
                             {srText = $711974, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711974_f_Play'}, 
                             {srText = $711975, pCue = None}, 
                             {srText = $711976, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711976_f_Play'}, 
                             {srText = $711977, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711977_f_Play'}, 
                             {srText = $711978, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711978_f_Play'}, 
                             {srText = $711979, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711979_f_Play'}, 
                             {srText = $711980, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711980_f_Play'}, 
                             {srText = $711981, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711981_f_Play'}, 
                             {srText = $711982, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711982_f_Play'}, 
                             {srText = $711983, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711983_f_Play'}, 
                             {srText = $711984, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711984_f_Play'}, 
                             {srText = $711985, pCue = WwiseEvent'ss_mp_retrieve_narr_v1_D.Audio.VO_711985_f_Play'}
                            )
        SimpleVOEvents = ({
                           Lines = ($711875, 
                                    $711876, 
                                    $711877, 
                                    $711878, 
                                    $711879, 
                                    $711880, 
                                    $711881, 
                                    $711882, 
                                    $711883, 
                                    $711884, 
                                    $711885, 
                                    $711886, 
                                    $711887, 
                                    $711888, 
                                    $711889
                                   ), 
                           EventName = 'CustomMissionIntro', 
                           ReplyLine = $711986
                          }, 
                          {
                           Lines = ($711891, 
                                    $711892, 
                                    $711893, 
                                    $711894, 
                                    $711895, 
                                    $711896, 
                                    $711897, 
                                    $711898
                                   ), 
                           EventName = 'CustomWaveStartedInstructions', 
                           ReplyLine = $711987
                          }, 
                          {
                           Lines = ($711900, $711901, $711902, $711903, $711904, $711905, $711906), 
                           EventName = 'InstructionReminder', 
                           ReplyLine = $711988
                          }, 
                          {
                           Lines = ($711908, $711909, $711910, $711911, $711912, $711913, $711914), 
                           EventName = 'PickedUp', 
                           ReplyLine = $711989
                          }, 
                          {
                           Lines = ($711916, 
                                    $711917, 
                                    $711918, 
                                    $711919, 
                                    $711920, 
                                    $711921, 
                                    $711922, 
                                    $711923
                                   ), 
                           EventName = 'Dropped', 
                           ReplyLine = $711990
                          }, 
                          {
                           Lines = ($711925, $711926, $711927, $711928, $711929, $711930, $711931), 
                           EventName = 'TakingTooLong', 
                           ReplyLine = $711991
                          }, 
                          {
                           Lines = ($711933, $711934, $711935, $711936, $711937, $711938, $711939), 
                           EventName = 'AlmostOutOfTime', 
                           ReplyLine = $711992
                          }, 
                          {
                           Lines = ($711941, $711942, $711943, $711944, $711945), 
                           EventName = 'WaveFailed', 
                           ReplyLine = $711993
                          }, 
                          {
                           Lines = ($711947, 
                                    $711948, 
                                    $711949, 
                                    $711950, 
                                    $711951, 
                                    $711952, 
                                    $711953, 
                                    $711954
                                   ), 
                           EventName = 'PickupDroppedOff', 
                           ReplyLine = $711994
                          }
                         )
    End Object
    Begin Object Class=CylinderComponent Name=CollisionCylinder0
        CollisionHeight = 200.0
        CollisionRadius = 800.0
        ReplacementPrimitive = None
        CollideActors = TRUE
        BlockZeroExtent = FALSE
        CanBlockCamera = FALSE
    End Object
    Begin Template Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
    End Template
    Begin Object Class=SFXModule_MarkerObjective Name=ObjectiveModule0
        MarkerOffset = {X = 0.0, Y = 0.0, Z = 100.0}
    End Object
    Begin Template Class=StaticMeshComponent Name=MeshComp0
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Template
    DropZoneEmitterTranslation = {X = 25.0, Y = 50.0, Z = -100.0}
    GroundDecalArchetype = SFXDecalActorSpawnable'BioVFX_MP_Annex.Archetypes.MP_Annex_Hill_Decal_Arc_02'
    PS_DropZoneTemplate = ParticleSystem'BioVFX_MP_Disarm.Particles.Disarm_Hill'
    DropZoneTemplateScale = 1.0
    SrDropOffObjectiveMarker = $599452
    ConvRef = BioConversation'ss_mp_retrieve_narr_v1_D.ss_mp_retrieve_narr_v1_dlg'
    OwnerWaveClassName = 'SFXEngagement_Retrieve_DLC_Base'
    SimpleDialogPlayer = SimpleDialog0
    Mesh = MeshComp0
    LightEnvironment = MyLightEnvironment
    Components = (None, MyLightEnvironment, MeshComp0, CollisionCylinder0)
    Modules = (ObjectiveModule0)
    CollisionComponent = CollisionCylinder0
    bAlwaysRelevant = TRUE
    bOnlyDirtyReplication = TRUE
    bMovable = FALSE
    bCollideActors = TRUE
    RemoteRole = ENetRole.ROLE_SimulatedProxy
}