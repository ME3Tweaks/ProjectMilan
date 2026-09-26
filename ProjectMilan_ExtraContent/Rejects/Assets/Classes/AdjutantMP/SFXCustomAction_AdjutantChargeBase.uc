Class SFXCustomAction_AdjutantMPChargeBase extends SFXCustomAction_SingleAnim
    config(Game);

var array<Actor> HitActors;
var const float ChargeSeekTime;

public function bool NotifyBump(Actor Other, Vector HitNormal)
{
    if (!OnImpactedActor(Other))
    {
        return FALSE;
    }
    ApplyTimeline(ImpactTimeline, m_oPawn, Other);
    OnTimelineImpact(Other);
    return Super(BioCustomAction).NotifyBump(Other, HitNormal);
}
public function StartCustomAction()
{
    if (m_oAI != None)
    {
        m_oAI.Focus = m_oAI.FireTarget;
        m_oAI.SetTimer(ChargeSeekTime, FALSE, 'DisableRotation', Self);
    }
    if (TimelineTemplate != None && TimelineTemplate.Timeline[1].Type == ETimelineType.TLT_AOE)
    {
        TimelineTemplate.Timeline[1].AOEFunc = ShouldDoAOE;
    }
    Super.StartCustomAction();
}
public function ClientDoCustomActionImpact(Actor oActor, int ImpactCount, optional bool bFirstTarget, optional Vector HitLocation, optional Vector HitNormal, optional int CustomActionReactionType)
{
    local SFXModule_Timeline TimeMod;
    local BioCustomAction Action;
    
    if (m_oPawn.GetCurrentCustomAction(Action))
    {
        if (Action == Self)
        {
            TimeMod = m_oPawn.GetModule(Class'SFXModule_Timeline');
            if (TimeMod != None)
            {
                TimeMod.SpawnTimeline(ImpactTimeline, Self, m_oPawn, oActor);
            }
        }
    }
}
public function StopCustomAction()
{
    HitActors.Length = 0;
    if (m_oPawn != None)
    {
        m_oPawn.LockDesiredRotation(FALSE);
    }
    if (SFXAI_AdjutantMP(m_oAI) != None)
    {
        SFXAI_AdjutantMP(m_oAI).OnChargeComplete();
    }
    Super.StopCustomAction();
}
public function DisableRotation()
{
    if (m_oAI != None)
    {
        m_oPawn.LockDesiredRotation(TRUE);
    }
}
public final function bool OnImpactedActor(Actor Other)
{
    if (HitActors.Find(Other) != -1)
    {
        return FALSE;
    }
    HitActors.AddItem(Other);
    return TRUE;
}
public delegate function bool ShouldDoAOE(Actor ChkOwner, Actor ChkTarget)
{
    return OnImpactedActor(ChkTarget);
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    ERootMotionMode = ERootMotionMode.RMM_Accel
    bReplicateCustomAction = TRUE
    Priority = ECustomActionPriority.CA_Priority_SuperHigh
}