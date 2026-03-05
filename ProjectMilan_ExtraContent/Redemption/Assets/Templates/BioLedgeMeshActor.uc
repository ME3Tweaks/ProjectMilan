Class BioLedgeMeshActor extends StaticMeshActor
    placeable;

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=StaticMeshComponent Name=StaticMeshComponent0
        ReplacementPrimitive = None
        RBChannel = ERBCollisionChannel.RBCC_Untitled1
        CastShadow = FALSE
        bCastDynamicShadow = FALSE
        bAcceptsLights = FALSE
        bAcceptsDynamicLights = FALSE
    End Template
    StaticMeshComponent = StaticMeshComponent0
    Components = (StaticMeshComponent0)
    CollisionComponent = StaticMeshComponent0
    bHidden = TRUE
    BlockRigidBody = FALSE
    CollisionType = ECollisionType.COLLIDE_NoCollision
}