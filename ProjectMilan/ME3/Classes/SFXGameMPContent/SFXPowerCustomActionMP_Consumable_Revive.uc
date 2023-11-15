Class SFXPowerCustomActionMP_Consumable_Revive extends SFXPowerCustomActionMP_Consumable
    config(Game);

// Variables
var config float ImmunityDuration;

// Functions
public function bool CanUsePower(Actor oTarget)
{
    local SFXPawn_Player Player;
    
    Player = SFXPawn_Player(m_oPawn);
    if (!Player.bIsDowned || Player.bIsDead)
    {
        return FALSE;
    }
    return Super.CanUsePower(oTarget);
}
public function bool OnImpact(EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Vector HitLocation, Vector HitNormal)
{
    local SFXPawn_PlayerMP Player;
    local SFXModule_DamagePlayer DamageMod;
    
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        Player = SFXPawn_PlayerMP(m_oPawn);
        if (Player != None)
        {
            Player.Resurrect(1.0, FALSE);
        }
    }
    SFXPawn_PlayerMP(m_oPawn).ClearTimer('PermaDeath');
    UseConsumable();
    ApplyTemporaryGameEffect(Player, Class'SFXGameEffect_DamageImmunity', ImmunityDuration, 0.0, Name, Player.Controller);
    if (m_oPawn.IsLocallyControlled())
    {
        Class'SFXGUIInteraction'.static.GetInstance().PlayGuiSound('MPSelfRevive');
    }
    DamageMod = Player.GetModule(Class'SFXModule_DamagePlayer');
    if (DamageMod != None)
    {
        DamageMod.RecoverFromBleedout();
    }
    return TRUE;
}
public function StartPower()
{
    m_oTargetToAimAt = m_oPawn;
    Super(SFXPowerCustomAction).StartPower();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ImmunityDuration = 4.0
    CapacityPlayerVariable = 'MPCapacity_Revive'
    CE_CasterCrustTemplate = RvrClientEffect'BioVFX_T_TechPowers.06_Heal.VCFX.Heal_VCFX_TargetCrust'
    CastSound = WwiseEvent'Wwise_Power_Soldier_Fortif.Play_power_soldier_P_fortif_cast'
    HenchmanCastSound = WwiseEvent'Wwise_Power_Soldier_Fortif.Play_power_soldier_NP_fortif_cast'
    PowerName = 'Consumable_Revive'
    PowerCustomActionID = 67
    DisplayName = $661168
    Description = $661169
    Icon = 92
    TalentDescription = $661169
}