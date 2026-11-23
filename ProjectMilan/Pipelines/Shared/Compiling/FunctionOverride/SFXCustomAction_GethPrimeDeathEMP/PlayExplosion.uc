// MILAN CHANGE - Mgamerz - 11/21/2026
// Turn off collision when geth prime explodes. By default, it waits for animation to finish,
// which can take a few seconds, which makes it so you can't run past him, which sucks
// in a crowded area
public function PlayExplosion()
{
    local SFXPawn Victim;
    local SFXPawn_GethPrime Prime;
    
    if (m_oPawn.Role == ENetRole.ROLE_Authority)
    {
        foreach m_oPawn.WorldInfo.AllPawns(Class'SFXPawn', Victim, m_oPawn.location, EMPRadius)
        {
            if (Victim != m_oPawn && Victim.HasResistance(1))
            {
                Victim.TakeDamage(EMPShieldDamage, m_oAI, Victim.location, Normal(Victim.location - m_oPawn.location) * 50.0, Class'SFXDamageType_GethPrimeEMP');
            }
        }
    }
    // MILAN CHANGE
    m_oPawn.SetCollision(m_oPawn.bCollideActors, FALSE);
    // END MILAN CHANGE
    Prime = SFXPawn_GethPrime(m_oPawn);
    if (Prime != None)
    {
        Prime.LF_GethLensFlare01.SetHidden(TRUE);
        Prime.LF_GethLensFlare02.SetHidden(TRUE);
        Prime.LF_GethLensFlare03.SetHidden(TRUE);
        if (Prime.Weapon != None && Prime.Weapon.Mesh != None)
        {
            Prime.Weapon.Mesh.SetHidden(TRUE);
        }
    }
}