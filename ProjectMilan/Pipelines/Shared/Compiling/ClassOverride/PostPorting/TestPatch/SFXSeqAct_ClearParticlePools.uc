// Source: ME3, Patch_SFXSeqAct_ClearParticlePools
// Decompiled 11/17/2026 7:38:42 AM against BioD_End001_765ReaperDoor.pcc
Class SFXSeqAct_ClearParticlePools extends SequenceAction;

public event function Activated()
{
    local WorldInfo WI;
    local SFXGRI GRI;
    
    WI = GetWorldInfo();
    if (WI != None)
    {
        GRI = SFXGRI(WI.GRI);
        if (GRI != None)
        {
            if (GRI.ObjectPool != None)
            {
                GRI.ObjectPool.CleanUpPools(TRUE);
            }
        }
        Class'RvrClientEffectManager'.static.GetClientEffectManager().CleanUpPools();
        WI.RescheduleGarbageCollectionTimer(0.0);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    VariableLinks = ()
}