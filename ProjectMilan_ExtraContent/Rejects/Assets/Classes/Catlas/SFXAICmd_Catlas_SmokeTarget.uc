Class SFXAICmd_Catlas_SmokeTarget extends SFXAICmd_SmokeBase within SFXAI_Core;

var float SmokeDistPct;
var const float DefaultSmokeDistance;

public function ComputeSmokeLocation()
{
    local Vector HitLoc;
    local Vector HitNormal;
    local Vector End;
    
    if (SmokeTarget != None)
    {
        SmokeLocation = Outer.MyBP.location + (SmokeTarget.location - Outer.MyBP.location) * SmokeDistPct;
        End = SmokeLocation;
        End.Z -= 500.0;
        if (Outer.MyBP.Trace(HitLoc, HitNormal, End, SmokeLocation, , , , ) != None)
        {
            SmokeLocation = HitLoc;
        }
    }
    else
    {
        SmokeLocation = Outer.MyBP.location + Vector(Outer.MyBP.Rotation) * DefaultSmokeDistance;
    }
    SmokeLocation.Z -= Outer.MyBP.CylinderComponent.CollisionHeight * 1.25;
}
public function Vector GetFireLocation()
{
    local SFXPawn_Catlas Atlas;
    
    Atlas = SFXPawn_Catlas(Outer.Pawn);
    if (Atlas != None)
    {
        return Atlas.GetSmokeLauncherFireLoc();
    }
    return Outer.MyBP.location;
}
public static function bool SmokeBetweenUs(SFXAI_Core AI, Actor ChkTarget, optional float DistPct = 0.75)
{
    local SFXAICmd_Catlas_SmokeTarget Cmd;
    
    if (AI != None)
    {
        Cmd = new (AI) Class'SFXAICmd_Catlas_SmokeTarget';
        if (Cmd != None)
        {
            Cmd.SmokeTarget = ChkTarget;
            Cmd.SmokeDistPct = DistPct;
            AI.PushCommand(Cmd);
        }
    }
    return TRUE;
}

auto state SmokeTheTarget 
{
    
Begin:
    ComputeSmokeLocation();
    Outer.AimOverrideLoc = SmokeLocation;
    Outer.Pawn.LockDesiredRotation(FALSE);
    Outer.SetDesiredRotation(Rotator(Outer.AimOverrideLoc - Outer.MyBP.location), TRUE, TRUE, 0.100000001);
    SFXPawn_Catlas(Outer.MyBP).OpenLauncherPort();
    Outer.FinishRotation();
    Outer.Sleep(0.5);
    FireSmokeGrenade();
    Outer.SetTimer(1.5, FALSE, 'CloseLauncherPort', Outer.MyBP);
    Outer.PopCommand(Self);
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    DefaultSmokeDistance = 1250.0
    ProjectileClass = Class'SFXProjectile_CatlasSmoke'
}