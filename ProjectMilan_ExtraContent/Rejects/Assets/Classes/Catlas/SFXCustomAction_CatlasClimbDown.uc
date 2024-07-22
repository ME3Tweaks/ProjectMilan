Class SFXCustomAction_CatlasClimbDown extends SFXCustomAction_LargeCoverClimbDown
    config(Game);

public function BlockMoveEndPoints()
{
    local SFXPawn_Atlas Atlas;
    
    Atlas = SFXPawn_Atlas(m_oPawn);
    Super(SFXCustomAction_SimpleMoveBase).BlockMoveEndPoints();
    if (Atlas != None && Atlas.AtlasDriver != None && BlockingStartCylinder != None && BlockingEndCylinder != None)
    {
        BlockingStartCylinder.PawnsToIgnore[1] = Atlas.AtlasDriver;
        BlockingEndCylinder.PawnsToIgnore[1] = Atlas.AtlasDriver;
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    BS_Anim = {
               AnimName = ('CB_StepDownCover')
              }
    MoveDistance = 285.0
}