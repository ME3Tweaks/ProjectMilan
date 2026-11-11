// MILAN CHANGE - Mgamerz - 2026-11-05
// Latent Kismet action that tells whether the player's view is inside any of the volumes attached to it
class SFXSeqAct_CameraInVolumes extends SeqAct_Latent;

var() Name InsideCameraTag;

// -1 until the first check, then 1 inside or 0 outside
var transient int LastInside;

public event function Activated()
{
    LastInside = -1;
}

public event function bool Update(float DeltaTime)
{
    local int Inside;

    Inside = 0;
    if (IsViewInside())
    {
        Inside = 1;
    }
    if (Inside != LastInside)
    {
        LastInside = Inside;
        if (Inside == 1)
        {
            ActivateOutputLink(0);
        }
        else
        {
            ActivateOutputLink(1);
        }
    }
    return TRUE;
}

public function bool IsViewInside()
{
    local PlayerController PC;
    local Vector ViewLocation;
    local Rotator ViewRotation;
    local Volume CheckVolume;
    local int i;

    PC = GetWorldInfo().GetALocalPlayerController();
    if (PC == None)
    {
        return FALSE;
    }
    if (InsideCameraTag != 'None' && PC.PlayerCamera != None && PC.PlayerCamera.ViewTarget.Target != None && PC.PlayerCamera.ViewTarget.Target.Tag == InsideCameraTag)
    {
        return TRUE;
    }

    PC.GetPlayerViewPoint(ViewLocation, ViewRotation);
    for (i = 0; i < Targets.Length; i++)
    {
        CheckVolume = Volume(Targets[i]);
        if (CheckVolume != None && CheckVolume.EncompassesPoint(ViewLocation))
        {
            return TRUE;
        }
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    InsideCameraTag = 'MilanMenu_TerminalCam'
    LastInside = -1
    bCallHandler = FALSE
    bAutoActivateOutputLinks = FALSE
    InputLinks = ({LinkDesc = "Start"})
    OutputLinks = ({LinkDesc = "Inside"}, {LinkDesc = "Outside"})
    VariableLinks = ({
                      LinkedVariables = (),
                      LinkDesc = "Volumes",
                      ExpectedType = Class'SeqVar_Object',
                      PropertyName = 'Targets',
                      MinVars = 1,
                      MaxVars = 255
                     }
                    )
}
