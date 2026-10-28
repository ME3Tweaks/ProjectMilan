// MILAN CHANGE - Mgamerz - 2026-10-23
// Kismet action that blinks a vector or scalar parameter
class SFXSeqAct_BlinkMaterialParam extends SFXSeqAct_SetMaterialParam;

var() LinearColor OffVectorValue;
var() float OffScalarValue;
var() float BlinkInterval;

// What the running blink sets, whether it's on its on value, and the actor running its timer
var transient bool bBlinkScalar;
var transient bool bBlinkOn;
var transient Actor BlinkTimerActor;

public event function Activated()
{
    local WorldInfo WI;

    WI = GetWorldInfo();
    if (WI == None)
    {
        return;
    }
    if (BlinkTimerActor != None)
    {
        BlinkTimerActor.ClearTimer('BlinkTimer', Self);
        BlinkTimerActor = None;
    }
    if (InputLinks[2].bHasImpulse)
    {
        SetParamOnTargets(bBlinkScalar, OffVectorValue, OffScalarValue);
        bBlinkOn = FALSE;
        return;
    }
    bBlinkScalar = InputLinks[1].bHasImpulse;
    bBlinkOn = TRUE;
    SetParamOnTargets(bBlinkScalar, VectorValue, ScalarValue);
    if (WI.Game != None)
    {
        BlinkTimerActor = WI.Game;
    }
    else
    {
        BlinkTimerActor = WI.GetALocalPlayerController();
    }
    if (BlinkTimerActor != None)
    {
        BlinkTimerActor.SetTimer(FMax(BlinkInterval, 0.05), TRUE, 'BlinkTimer', Self);
    }
}

public function BlinkTimer()
{
    bBlinkOn = !bBlinkOn;
    if (bBlinkOn)
    {
        SetParamOnTargets(bBlinkScalar, VectorValue, ScalarValue);
    }
    else
    {
        SetParamOnTargets(bBlinkScalar, OffVectorValue, OffScalarValue);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    OffVectorValue = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
    BlinkInterval = 0.75
    InputLinks = ({LinkDesc = "Start Vector"}, {LinkDesc = "Start Scalar"}, {LinkDesc = "Stop"})
}
