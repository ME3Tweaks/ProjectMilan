Class SFXDamageType_FlameThrower_Player extends SFXDamageType_HeavyWeapon
    config(Weapon);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=DamagedFFWave
    End Template
    HitReactions = ({BodyPart = 'None', ReactionChance = 0.850000024, bIgnoreShields = TRUE, Reaction = EReactionTypes.Reaction_Fire, MaxRange = EHitReactRange.HitReactRange_Invalid},
                    {BodyPart = 'None', ReactionChance = 0.75, bIgnoreShields = TRUE, Reaction = EReactionTypes.Reaction_Fire, MaxRange = EHitReactRange.HitReactRange_Invalid}
                   )
    // Triple damage to armor
    Resistance = {Shield = 1.0, Armour = 3.0, Biotic = 1.0}
    ShieldHitFFWaveform = DamagedFFWave
    CE_DeathEffect = RvrClientEffect'BioVFX_C_Fire.VCFX.Fire_Death_VCFX'
    bCausesNormalizedDamage = FALSE
    bIgnoreDamageGating = TRUE
    DamagedFFWaveform = DamagedFFWave
    KilledFFWaveform = DamagedFFWave
}
