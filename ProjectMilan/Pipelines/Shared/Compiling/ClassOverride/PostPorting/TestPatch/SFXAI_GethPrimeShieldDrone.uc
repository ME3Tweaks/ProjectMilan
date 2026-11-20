// Source: ME3, Patch_SFXAI_GethPrimeShieldDrone
// Decompiled 11/17/2026 7:37:39 AM against BioD_Gth001_600Core.pcc
Class SFXAI_GethPrimeShieldDrone extends SFXAI_Core
    placeable
    config(AI);

var Name RocketPowerName;

public event function BioClearCrossLevelReferences(Level ClearedLevel)
{
    local SFXPawn_GethPrimeShieldDrone Drone;
    
    Super.BioClearCrossLevelReferences(ClearedLevel);
    Drone = SFXPawn_GethPrimeShieldDrone(Pawn);
    if (Drone != None && Drone.Outer != None && Drone.Outer.Outer == ClearedLevel)
    {
        Drone.OnDroneKilled = None;
    }
}
public function Initialize()
{
    local SFXDifficultyHandler DH;
    local SFXModule_Damage DmgMod;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            DmgMod.NormalizedHealth = DH.GetFloatNormalized('ShieldDrone_MaxHealth', 'GethPrime');
            DmgMod.LevelScaledHealth = DH.GetFloat('ShieldDrone_MaxHealth', 'GethPrime');
            DmgMod.InitializeMaxHealth(DmgMod.LevelScaledHealth);
        }
    }
    Super.Initialize();
}
public function DrawDifficulty(BioCheatManager CM)
{
    local SFXDifficultyHandler DH;
    local Name ParamName;
    local Name CategoryName;
    local SFXModule_Damage DmgMod;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        CategoryName = 'GethPrime';
        CM.DrawProfileHeaderText("Health: ");
        ParamName = 'ShieldDrone_MaxHealth';
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            CM.DrawProfileText(DmgMod.GetMaxHealth() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        }
        CM.DrawProfileText(" ");
    }
}
public final function bool ShouldFireRocket()
{
    local SFXPowerCustomAction Power;
    
    Power = SFXPowerCustomAction(MyBP.PowerManager.GetPower(RocketPowerName));
    if (Power != None && Power.CanUsePower(FireTarget))
    {
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    RocketPowerName = 'CombatDroneRocket'
    DefaultCommand = Class'SFXAICmd_Base_GethPrimeShieldDrone'
}