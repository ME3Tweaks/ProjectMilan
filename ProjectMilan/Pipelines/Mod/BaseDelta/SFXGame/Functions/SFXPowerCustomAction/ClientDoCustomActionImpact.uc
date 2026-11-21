// MILAN CHANGE - 11/20/2026 - Mgamerz
// Volus shield bug fix
public function ClientDoCustomActionImpact(Actor oActor, int ImpactCount, optional bool bFirstTarget, optional Object.Vector HitLocation, optional Object.Vector HitNormal, optional int CustomActionReactionType)
{
    DoPowerDetonatedForActor(oActor, HitLocation, HitNormal, ImpactCount, bFirstTarget);
    // MILAN CHANGE
    // Only hostile impacts play a reaction
    if (BioPawn(oActor) != None && (m_oPawn == None || BioPawn(oActor).IsHostile(m_oPawn)))
    // END MILAN CHANGE
    {
        BioPawn(oActor).ClientPlayAnimatedReaction(CustomActionReactionType);
    }
}
