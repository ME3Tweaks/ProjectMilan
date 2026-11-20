// Source: ME3, Patch_SFXGameEffectPowerComboFire
// Decompiled 11/17/2026 7:37:50 AM against BIOP_MP_COMMON.pcc
Class SFXGameEffect_PowerCombo_Fire extends SFXGameEffect_PowerCombo
    config(Game);

var config Object.Vector2D DamagePerSecond;
var config Object.Vector2D DOTDuration;
var editinline ParticleSystem PS_FlameEffect;
var config int NumFlameEffects;
var config int NumFlameEffectsMP;
var config bool bHideBodyOnDetonation;

public function bool OnImpact(Actor.EPowerResistance Resistance, Actor oImpacted, int nPreviouslyImpacted, Object.Vector HitLocation, Object.Vector HitNormal)
{
    local BioPawn oPawn;
    local SFXGameEffect_FireDamageOverTime Effect;
    local SFXModule_GameEffectManager Manager;
    local SFXDuringAsyncWorkTicker oTicker;
    local Name BoneName;
    local int nIndex;
    local Object.Vector BoneLocation;
    local int nFlameCount;
    
    oPawn = BioPawn(oImpacted);
    if (oPawn != None)
    {
        Manager = oImpacted.GetModule(Class'SFXModule_GameEffectManager');
        Effect = SFXGameEffect_FireDamageOverTime(Manager.CreateEffect(Class'SFXGameEffect_FireDamageOverTime', Name, Lerp(DOTDuration.X, DOTDuration.Y, fPowerRatio), 1, Lerp(DamagePerSecond.X, DamagePerSecond.Y, fPowerRatio)));
        if (Effect != None)
        {
            Effect.bCanCauseCombo = FALSE;
            Effect.DamageType = DamageType;
            Effect.OnApplied();
        }
        nFlameCount = SFXGRI(oPawn.WorldInfo.GRI).IsMultiplayerGame() ? NumFlameEffectsMP : NumFlameEffects;
        for (nIndex = 0; nIndex < nFlameCount; nIndex++)
        {
            BoneName = oPawn.GetRandomImpactBone();
            if (BoneName != 'None')
            {
                oTicker = SFXGRI(oPawn.WorldInfo.GRI).DuringAsyncWorker;
                if (oTicker != None)
                {
                    BoneLocation = oPawn.Mesh.GetBoneLocation(BoneName);
                    oTicker.SpawnImpactEffectAtLocation(oPawn, PS_FlameEffect, oPawn, BoneLocation, vect(0.0, 1.0, 0.0), oPawn.Mesh, BoneName, 1.0);
                }
            }
        }
    }
    return Super.OnImpact(Resistance, oImpacted, nPreviouslyImpacted, HitLocation, HitNormal);
}
public function OnPowerComboDetonated(SFXPowerCustomAction DetonationPower, Object.Vector HitLocation, Object.Vector HitNormal)
{
    if (bHideBodyOnDetonation && BioPawn(Owner).CanPlayDeathEffect())
    {
        BioPawn(Owner).SetHidden(TRUE);
    }
    Super.OnPowerComboDetonated(DetonationPower, HitLocation, HitNormal);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DamagePerSecond = {X = 20.0, Y = 50.0}
    DOTDuration = {X = 3.0, Y = 3.0}
    PS_FlameEffect = ParticleSystem'BioVFX_C_Carnage.Particles.Carnage_Dot_Damage_Permanent'
    NumFlameEffects = 3
    NumFlameEffectsMP = 1
    EffectsRemovedOnCombo = ('SFXGameEffect_PowerCombo_Fire')
    DetonationScreenShakeClass = Class'SFXShake_Power_FireCombo'
    DetonationRumbleClass = Class'SFXRumble_Power_FireCombo'
    DamageType = Class'SFXDamageType_FireExplosion'
    DetonationParameters = {ImpactPlaceables = TRUE, BlockedByObjects = TRUE}
    ComboDamage = {X = 100.0, Y = 250.0}
    ComboForce = {X = 300.0, Y = 600.0}
    ComboRadius = {X = 300.0, Y = 600.0}
    DetonationVFX = RvrClientEffect'biovfx_c_fire.VCFX.Fire_Combo_Imp_VCFX'
    DetonationSound = WwiseEvent'Wwise_Power_Shared.Play_power_shared_combo_fire'
    TargetCrustVFX = RvrClientEffect'biovfx_c_fire.VCFX.Fire_Dot_VCFX'
    MaxTargets = 4
}