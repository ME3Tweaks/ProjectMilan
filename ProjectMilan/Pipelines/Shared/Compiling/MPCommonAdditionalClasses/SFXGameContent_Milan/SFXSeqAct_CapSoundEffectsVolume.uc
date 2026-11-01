// MILAN CHANGE - Mgamerz - 2026-10-30
// Latent Kismet action that caps the sound effects volume
class SFXSeqAct_CapSoundEffectsVolume extends SeqAct_Latent;

// The highest sound effects volume
var() float MaxVolume;
// The volume last set, so the log only shows changes
var transient float AppliedVolume;

public event function Activated()
{
    ApplyCap();
}

public event function bool Update(float DeltaTime)
{
    // Reapply on every tick so if user changes settings it re-applies
    ApplyCap();
    return TRUE;
}

public function ApplyCap()
{
    local BioPlayerController PC;
    local float Volume;

    PC = BioPlayerController(GetWorldInfo().GetALocalPlayerController());
    if (PC == None || PC.ProfileSettings == None)
    {
        return;
    }
    Volume = FMin(float(PC.ProfileSettings.GetFXVolume()) * 0.01, MaxVolume);
    Class'WwiseAudioComponent'.static.SetGlobalRTPCFromScript("Volume_Sound_Effects", Volume);
    if (Volume != AppliedVolume)
    {
        // LogInternal("Capping sound effects volume at" @ Volume @ "(player setting" @ PC.ProfileSettings.GetFXVolume() $ ", cap" @ MaxVolume $ ")");
        AppliedVolume = Volume;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    MaxVolume = 0.5
    AppliedVolume = -1.0
    bCallHandler = FALSE
    InputLinks = ({LinkDesc = "Start"})
    VariableLinks = ()
}
