Class SFXSquadCombatMP extends BioBaseSquad;

// Functions
public event function int AddMember(Pawn Pawn, optional bool bCheckPlaypens = TRUE)
{
    local int nMemberIndex;
    
    nMemberIndex = Super.AddMember(Pawn, bCheckPlaypens);
    WorldInfo.Game.ChangeTeam(Pawn.Controller, 1, TRUE);
    return nMemberIndex;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BioSquadLinesComponent Name=SquadLines
        ReplacementPrimitive = None
    End Template
    Begin Template Class=CylinderComponent Name=CollisionCylinder
        ReplacementPrimitive = None
    End Template
    Components = (None, SquadLines)
}