Class SFXObjective_AssassinationBase extends SFXOperationObjective
    placeable
    config(Game);

// Variables
var BioPawn CurrentTarget;
var int NumTargetsKilled;
var config int NumTargetsToKill;

// Functions
public simulated function CurrentTargetDied();

public simulated function SetCurrentTarget(BioPawn Pawn);


//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
    End Template
    Begin Template Class=StaticMeshComponent Name=MeshComp0
        ReplacementPrimitive = None
        LightEnvironment = MyLightEnvironment
    End Template
    Mesh = MeshComp0
    LightEnvironment = MyLightEnvironment
    Components = (None, MyLightEnvironment, MeshComp0)
}