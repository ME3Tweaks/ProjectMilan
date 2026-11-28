
// NEW to Milan - 11/17/2026 - Mgamerz
// New gear that pulses your healthbar to provide regen after you don't take damage for a brief moment
class SFXGameEffect_MatchConsumable_Gear_Regen extends SFXGameEffect_MatchConsumable_Gear
    config(Game);

// Ranks array - time to set the next 'soft regen' recalc
var config float PulseInterval[5];
var transient float NextPulseTime;
// Last known health and shields, for comparing when we last took damage
var transient float LastHealth;
var transient float LastShields;
var transient bool bTrackingDamage;

public function OnApplied()
{
    Super.OnApplied();
    if (Owner != None && Owner.WorldInfo != None)
    {
        // Init the first pulse time
        NextPulseTime = Owner.WorldInfo.GameTimeSeconds + GetPulseInterval();
    }
}

public function OnUpdate(float DeltaSeconds)
{
    local SFXPawn_PlayerMP Player;
    local SFXGRIMP GRI;
    local SFXModule_DamagePlayer DamageModule;
    local SFXModule_GameEffectManager Effects;
    local float Now;
    local float Interval;
    local float Health;
    local float MaxHealth;
    local float Shields;

    Super.OnUpdate(DeltaSeconds);
    Player = SFXPawn_PlayerMP(Owner);
    // Player and authority only
    if (Player == None || Player.Role != ENetRole.ROLE_Authority || !Player.IsHumanControlled())
    {
        return;
    }

    DamageModule = Player.GetModule(Class'SFXModule_DamagePlayer');
    if (DamageModule == None)
    {
        return;
    }

    Now = Player.WorldInfo.GameTimeSeconds;
    Interval = GetPulseInterval();
    Health = DamageModule.GetCurrentHealth();
    Shields = Player.GetCurrentShields();
    if (!bTrackingDamage || Health < LastHealth || Shields < LastShields)
    {
        // Damage has been taken, reset the timer
        NextPulseTime = FMax(NextPulseTime, Now + Interval);
    }
    LastHealth = Health;
    LastShields = Shields;
    bTrackingDamage = TRUE;

    GRI = SFXGRIMP(Player.WorldInfo.GRI);
    if (GRI == None || GRI.GameStatus != EGameStatus.GS_MatchInProgress || Player.bIsDowned || Player.IsDead())
    {
        // Not a valid state to pulse
        NextPulseTime = Now + Interval;
        return;
    }

    if (Now < NextPulseTime)
    {
        // Taken damage recently
        return;
    }

    MaxHealth = DamageModule.GetMaxHealth();
    if (Health <= 0.0 || Health >= MaxHealth || Health < DamageModule.SoftMaxHealth)
    {
        return;
    }

    // Bump health up 1 point. It will then automatically start the chunk regen
    DamageModule.SetCurrentHealth(FMin(MaxHealth, Health + 1.0), TRUE);
    NextPulseTime = Now + Interval;
}

private function float GetPulseInterval()
{
    return FMax(PulseInterval[Clamp(CurrentLevel, 0, 4)], 1.0);
}

defaultproperties
{
    PulseInterval[0] = 3.5
    PulseInterval[1] = 3.0
    PulseInterval[2] = 2.5
    PulseInterval[3] = 2.0
    PulseInterval[4] = 1.5
}
