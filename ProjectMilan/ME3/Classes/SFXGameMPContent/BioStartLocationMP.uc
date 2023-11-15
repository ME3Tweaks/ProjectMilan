Class BioStartLocationMP extends Actor
    placeable;

// Variables
var(BioStartLocationMP) bool bPrimaryStart;

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Object Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 90.0
        CollisionRadius = 50.0
        ReplacementPrimitive = None
    End Object
    Components = (CollisionCylinder, None, None)
    CollisionComponent = CollisionCylinder
    bStatic = TRUE
    bHidden = TRUE
    bNoDelete = TRUE
    bForceAllowKismetModification = TRUE
}