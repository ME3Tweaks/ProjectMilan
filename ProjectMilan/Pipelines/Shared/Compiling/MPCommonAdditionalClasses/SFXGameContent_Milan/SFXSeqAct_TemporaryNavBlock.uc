// MILAN CHANGE - Mgamerz - 2026-10-22
// Kismet action that temporarily blocks nav points, e.g. a doorway while its door is shut. Path-following AI move in
// PHYS_PathApproximation, which turns their world collision off for the move, so a closed door (an InterpActor) doesn't
// stop them: only the path network does.
//  - Block: sets bBlocked on the Target nav points (a CoverLink is also disabled, and its slot markers blocked), makes
//    AIs whose current route goes through a blocked node re-path, and raises SFXGameInfoMP.HasTemporaryNavBlocks() for
//    code that would otherwise treat "no path" as final (the escort drone choosing its destination).
//  - Unblock: reverses it.
// The engine only checks bBlocked when it plans a path, which is why routes already planned through a blocked node
// have to be dropped. Host only: AI and the GameInfo only exist on the host.
class SFXSeqAct_TemporaryNavBlock extends SequenceAction;

// Whether this action's targets are currently blocked, so repeated Block/Unblock impulses keep the GameInfo count paired
var transient bool bBlocking;

public event function Activated()
{
    local WorldInfo WI;
    local SFXGameInfoMP Game;
    local bool bBlock;
    local int i;

    WI = GetWorldInfo();
    if (WI == None || WI.Game == None)
    {
        return;
    }
    bBlock = InputLinks[0].bHasImpulse;
    if (bBlock == bBlocking)
    {
        return;
    }
    bBlocking = bBlock;
    for (i = 0; i < Targets.Length; i++)
    {
        SetNavBlocked(NavigationPoint(Targets[i]), bBlock);
    }
    Game = SFXGameInfoMP(WI.Game);
    if (Game != None)
    {
        Game.AddTemporaryNavBlock(bBlock);
    }
    if (bBlock)
    {
        RepathBlockedAI(WI);
    }
}

public function SetNavBlocked(NavigationPoint Nav, bool bBlock)
{
    local CoverLink Link;
    local int SlotIdx;

    if (Nav == None)
    {
        return;
    }
    Nav.bBlocked = bBlock;
    Link = CoverLink(Nav);
    if (Link != None)
    {
        for (SlotIdx = 0; SlotIdx < Link.Slots.Length; SlotIdx++)
        {
            if (Link.Slots[SlotIdx].SlotMarker != None)
            {
                Link.Slots[SlotIdx].SlotMarker.bBlocked = bBlock;
            }
        }
        // Unlike CoverLink.OnToggle, SetDisabled also kicks AIs out of the link's slots and tells the CoverReplicator
        Link.SetDisabled(bBlock);
    }
    Nav.WorldInfo.Game.NotifyNavigationChanged(Nav);
}

// Sets the re-path flag SFXAICmd_MoveToGoal.MovingToGoal checks every move tick (m_bCustomActionFailed: it empties the
// route and plans a new one) on every AI that is moving to, or routed through, a blocked nav point
public function RepathBlockedAI(WorldInfo WI)
{
    local SFXAI_Core AI;
    local NavigationPoint Nav;
    local int i;

    foreach WI.AllControllers(Class'SFXAI_Core', AI)
    {
        Nav = NavigationPoint(AI.MoveTarget);
        if (Nav != None && Nav.bBlocked)
        {
            AI.m_bCustomActionFailed = TRUE;
            continue;
        }
        for (i = 0; i < AI.RouteCache.Length; i++)
        {
            if (AI.RouteCache[i] != None && AI.RouteCache[i].bBlocked)
            {
                AI.m_bCustomActionFailed = TRUE;
                break;
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    bCallHandler = FALSE
    InputLinks = ({LinkDesc = "Block"}, {LinkDesc = "Unblock"})
    VariableLinks = ({
                      LinkedVariables = (),
                      LinkDesc = "Target",
                      ExpectedType = Class'SeqVar_Object',
                      PropertyName = 'Targets',
                      MinVars = 1,
                      MaxVars = 255
                     }
                    )
}
