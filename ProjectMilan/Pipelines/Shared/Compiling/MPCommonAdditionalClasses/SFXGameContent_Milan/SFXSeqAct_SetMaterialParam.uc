// MILAN CHANGE - Mgamerz - 2026-10-23
// Kismet action that sets a vector or scalar parameter on the MaterialInstanceConstant of each Target MaterialInstanceActor,
// on the host and every client
class SFXSeqAct_SetMaterialParam extends SequenceAction;

var() Name ParamName;
var() LinearColor VectorValue;
var() float ScalarValue;

public event function Activated()
{
    if (InputLinks[1].bHasImpulse)
    {
        SetParamOnTargets(TRUE, VectorValue, ScalarValue);
    }
    else
    {
        SetParamOnTargets(FALSE, VectorValue, ScalarValue);
    }
}

// Sets ParamName on every Target here
public function SetParamOnTargets(bool bScalar, LinearColor NewVectorValue, float NewScalarValue)
{
    local WorldInfo WI;
    local MaterialInstanceActor MIA;
    local SFXPlayerControllerMP PC;
    local int i;

    WI = GetWorldInfo();
    if (WI == None)
    {
        return;
    }
    for (i = 0; i < Targets.Length; i++)
    {
        MIA = MaterialInstanceActor(Targets[i]);
        if (MIA == None || MIA.MatInst == None)
        {
            continue;
        }
        if (bScalar)
        {
            MIA.MatInst.SetScalarParameterValue(ParamName, NewScalarValue);
        }
        else
        {
            MIA.MatInst.SetVectorParameterValue(ParamName, NewVectorValue);
        }
        if (WI.NetMode == ENetMode.NM_Client)
        {
            continue;
        }
        foreach WI.AllControllers(Class'SFXPlayerControllerMP', PC)
        {
            if (!PC.IsLocalPlayerController())
            {
                PC.ClientSetMaterialActorParam(MIA, ParamName, bScalar, NewVectorValue, NewScalarValue);
            }
        }
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    bCallHandler = FALSE
    VectorValue = {R = 0.0, G = 0.0, B = 0.0, A = 1.0}
    InputLinks = ({LinkDesc = "Set Vector"}, {LinkDesc = "Set Scalar"})
    VariableLinks = ({
                      LinkedVariables = (),
                      LinkDesc = "Target",
                      ExpectedType = Class'SeqVar_Object',
                      PropertyName = 'Targets',
                      MinVars = 1,
                      MaxVars = 255
                     }
                    )
}
