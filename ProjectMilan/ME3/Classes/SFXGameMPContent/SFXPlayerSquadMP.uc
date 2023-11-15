Class SFXPlayerSquadMP extends BioBaseSquad;

// Variables
var transient SFXPawn_PlayerMP LeaderPawn;
var transient SFXPawn_PlayerMP LocalPawn;

// Functions
public event simulated function int AddMember(Pawn Pawn, optional bool bCheckPlaypens = TRUE)
{
    local SFXPawn_PlayerMP member;
    local SFXPawn_PlayerMP OtherMember;
    local int idx;
    
    member = SFXPawn_PlayerMP(Pawn);
    if (member != None)
    {
        if (member.IsLocallyControlled())
        {
            if (Role == ENetRole.ROLE_Authority)
            {
                LeaderPawn = member;
            }
            LocalPawn = member;
            CachedPlayerPawn = LocalPawn;
        }
        for (idx = 0; idx < Members.Length; idx++)
        {
            OtherMember = SFXPawn_PlayerMP(Members[idx]);
            if (OtherMember != None && OtherMember != member)
            {
                OtherMember.OnSquadMemberAdded(member);
            }
        }
        if (WorldInfo != None && WorldInfo.Game != None)
        {
            WorldInfo.Game.ChangeTeam(member.Controller, 0, TRUE);
        }
    }
    return Super.AddMember(member);
}
public event function PostBeginPlay()
{
    Super(Actor).PostBeginPlay();
}
public function RemoveDyingMember(Pawn oPawn);


replication
{
    if (bNetDirty && Role == ENetRole.ROLE_Authority)
        LeaderPawn;
    
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
    bIsPlayerSquad = TRUE
    m_bCombatEnabled = TRUE
    Components = (None, SquadLines)
}