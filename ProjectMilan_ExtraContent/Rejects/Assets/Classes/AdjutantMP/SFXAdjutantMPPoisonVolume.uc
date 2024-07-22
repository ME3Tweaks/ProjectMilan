Class SFXAdjutantMPPoisonVolume extends Volume;

var transient array<BioPawn> AffectedPawns;
var transient SFXPawn_AdjutantMP OwnerPawn;
var const RvrClientEffectInterface CE_Template;
var const WwiseEvent BeginSound;
var const WwiseEvent EndSound;
var float Lifetime;
var const float CoverDecayValue;
var float PoisonRadius;

public function Destroyed()
{
    DestroyFX();
    RemoveAllEffects();
}
public simulated function Init()
{
    local SFXPawn P;
    local CoverSlotMarker CoverSlot;
    local SFXGame GameInfo;
    
    SetTimer(Lifetime, FALSE, 'EndPoison', );
    PoisonRadius = CylinderComponent(CollisionComponent).CollisionRadius;
    OwnerPawn = SFXPawn_AdjutantMP(Owner);
    CreateFX();
    foreach WorldInfo.AllPawns(Class'SFXPawn', P, location, PoisonRadius)
    {
        Touch(P, None, P.location, P.location - location);
    }
    if (WorldInfo != None)
    {
        GameInfo = SFXGame(WorldInfo.Game);
        if (GameInfo != None)
        {
            foreach WorldInfo.RadiusNavigationPoints(Class'CoverSlotMarker', CoverSlot, location, PoisonRadius)
            {
                GameInfo.AddCoverDecay(CoverSlot, int(CoverDecayValue));
            }
        }
    }
}
public simulated function RemoveAllEffects()
{
    local int idx;
    
    for (idx = AffectedPawns.Length - 1; idx >= 0; idx--)
    {
        RemoveEffects(AffectedPawns[idx]);
    }
}
public event simulated function Touch(Actor Other, PrimitiveComponent OtherComp, Vector HitLoc, Vector HitNorm)
{
    local BioPawn OtherPawn;
    
    OtherPawn = BioPawn(Other);
    if (OwnerPawn != None && OtherPawn != None)
    {
        if (OtherPawn.IsHostile(OwnerPawn) && AffectedPawns.Find(OtherPawn) == -1)
        {
            OwnerPawn.ApplyPoisonEffects(OtherPawn, Self);
            AffectedPawns.AddItem(OtherPawn);
        }
    }
}
public event simulated function UnTouch(Actor Other)
{
    Super(Actor).UnTouch(Other);
    if (BioPawn(Other) != None)
    {
        RemoveEffects(BioPawn(Other));
    }
}
public simulated function RemoveEffects(BioPawn Target)
{
    local SFXGameEffect_AdjutantBlast Effect;
    local SFXModule_GameEffectManager GEMan;
    
    if (Target != None)
    {
        GEMan = Target.GetModule(Class'SFXModule_GameEffectManager');
        if (GEMan != None)
        {
            Effect = SFXGameEffect_AdjutantBlast(GEMan.GetFirstEffectOfType(Class'SFXGameEffect_AdjutantBlast'));
            if (Effect != None)
            {
                Effect.PoisonSources.RemoveItem(Self);
            }
        }
        AffectedPawns.RemoveItem(Target);
    }
}
public simulated function CreateFX()
{
    local Vector Params;
    
    if (CE_Template != None)
    {
        Params.X = 1.0;
        Params.Y = PoisonRadius;
        Class'RvrClientEffectManager'.static.GetClientEffectManager().Play(CE_Template, Self, Params);
    }
    if (BeginSound != None && EndSound != None)
    {
        PlaySound(BeginSound);
    }
}
public simulated function DestroyFX()
{
    if (BeginSound != None && EndSound != None)
    {
        PlaySound(EndSound);
    }
}
public simulated function EndPoison()
{
    Destroy();
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=BrushComponent Name=BrushComponent0
        ReplacementPrimitive = None
    End Template
    Begin Object Class=CylinderComponent Name=CollisionCylinder
        CollisionHeight = 250.0
        CollisionRadius = 250.0
        ReplacementPrimitive = None
        CollideActors = TRUE
        BlockZeroExtent = FALSE
    End Object
    CE_Template = RvrClientEffect'BioVFX_Exp2_Adj.VCFX.BioticSmoke_Cloud_Imp_VCFX'
    BeginSound = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Play_crt_omega_adjutant_weap_warpfield'
    EndSound = WwiseEvent'Wwise_Crt_DLC_Omega_Adjutant.Stop_crt_omega_adjutant_weap_warpfield'
    Lifetime = 5.0
    CoverDecayValue = 1000.0
    BrushComponent = BrushComponent0
    Components = (BrushComponent0, CollisionCylinder)
    CollisionComponent = CollisionCylinder
    bStatic = FALSE
    bNoDelete = FALSE
}