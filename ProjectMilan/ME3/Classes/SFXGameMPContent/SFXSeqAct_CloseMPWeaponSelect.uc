Class SFXSeqAct_CloseMPWeaponSelect extends SequenceAction;

// Functions
public event function Activated()
{
    local SFXPlayerControllerMP PC;
    
    PC = SFXPlayerControllerMP(BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo()).GetLocalPlayerController());
    if (PC != None && PC.__OnWeaponSelectFinishedDelegate__Delegate != None)
    {
        PC.__OnWeaponSelectFinishedDelegate__Delegate();
    }
}
public static event function int GetObjClassVersion()
{
    return Super(SequenceObject).GetObjClassVersion() + 1;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}