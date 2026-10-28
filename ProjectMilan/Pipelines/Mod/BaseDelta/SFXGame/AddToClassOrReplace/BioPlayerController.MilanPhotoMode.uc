// MILAN CHANGE - Mgamerz - 2026-10-16
// Consume photo input locally; do not run spectating movement, pawn movement or movement RPCs.
state MilanPhotoMode extends BaseSpectating
{
    // MILAN CHANGE - Mgamerz - 2026-10-25
    // When hiding UI make it so we can still go to the next player
    public exec function MPPhotoCyclePlayer(int Direction, optional bool bReleased = FALSE)
    {
        if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None)
        {
            GameModeManager2.GetPhotoMode().MPPhotoCyclePlayer(Direction, bReleased);
        }
    }
    // END MILAN CHANGE
    public function PlayerMove(float DeltaTime)
    {
        // PlayerTick has just populated PlayerInput. Consume camera axes here, before the
        // later camera/render pass; never call BaseSpectating's movement or replication.
        if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None)
        {
            GameModeManager2.GetPhotoMode().ProcessMPPhotoInput(DeltaTime);
        }
    }
    public function UpdateRotation(float DeltaTime)
    {
    }
    public function PushedState()
    {
    }
    public function PoppedState()
    {
        // MILAN CHANGE - Mgamerz - 2026-10-17
        if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None)
        {
            GameModeManager2.GetPhotoMode().MPPhotoControllerStateEnded();
        }
        // END MILAN CHANGE
    }
    // MILAN CHANGE - Mgamerz - 2026-10-17
    public event function EndState(Name NextStateName)
    {
        if (GameModeManager2 != None && GameModeManager2.GetPhotoMode() != None)
        {
            GameModeManager2.GetPhotoMode().MPPhotoControllerStateEnded();
        }
        Super.EndState(NextStateName);
    }
    // END MILAN CHANGE
    public function ContinuedState()
    {
        // A dialog can push another state over this one. If it removed the photo movie,
        // discard this state when resumed instead of leaving an inactive camera input sink.
        if (GameModeManager2 == None || !GameModeManager2.IsActive(14))
        {
            PopState();
        }
    }
    stop;
};
// END MILAN CHANGE
