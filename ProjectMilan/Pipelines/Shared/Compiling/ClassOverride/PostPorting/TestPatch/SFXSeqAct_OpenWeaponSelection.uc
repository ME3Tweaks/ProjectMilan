// Source: ME3, Patch_SFXSeqActOpenWpnSelection
// Decompiled 11/17/2026 7:38:43 AM against BioP_Cat002.pcc
Class SFXSeqAct_OpenWeaponSelection extends BioSequenceLatentAction;

var GFxMovieInfo WeaponSelectionMovieInfo;
var(SFXSeqAct_OpenWeaponSelection) int MaxWeapons;
var(SFXSeqAct_OpenWeaponSelection) bool ShowAllWeapons;
var bool bIsFinished;

public function Activated()
{
    local SFXGUIInteraction oGUI;
    local SFXGUI_WeaponSelection oWeapGUI;
    local BioPlayerController oPC;
    
    oGUI = Class'SFXGUIInteraction'.static.GetInstance();
    oPC = BioWorldInfo(GetWorldInfo()).GetLocalPlayerController();
    if (GetWorldInfo().GRI.IsMultiplayerGame())
    {
        oWeapGUI = oGUI.CastOpenMovie(Class'SFXGUI_WeaponSelection', oPC, oGUI.MovieTag_MPWeaponSelect, FALSE);
    }
    if (oWeapGUI == None)
    {
        oWeapGUI = oGUI.CastOpenMovie(Class'SFXGUI_WeaponSelection', oPC, oGUI.MovieTag_WeaponSelect, FALSE);
    }
    if (oWeapGUI != None)
    {
        oWeapGUI.ShowAllWeapons = ShowAllWeapons;
        oWeapGUI.AddOnMovieClosedDelegate(OnMovieClosedDelegate);
        oWeapGUI.Start();
    }
}
public function bool OnMovieClosedDelegate(SFXGUIMovie i_ScreenToClose)
{
    bIsFinished = TRUE;
    return TRUE;
}
public function bool UpdateOp(float fDeltaT)
{
    if (bIsFinished)
    {
        OutputLinks[0].bHasImpulse = TRUE;
        return TRUE;
    }
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    WeaponSelectionMovieInfo = GFxMovieInfo'GUI_SF_WeaponSelect.WeaponSelect'
    MaxWeapons = 4
    bHasTargets = FALSE
    bCallHandler = FALSE
    OutputLinks = ({
                    Links = (), 
                    LinkDesc = "Out", 
                    LinkAction = 'None', 
                    LinkedOp = None, 
                    bHasImpulse = FALSE, 
                    bDisabled = FALSE
                   }
                  )
    bManualHandleOutputs = TRUE
    bAutoActivateOutputLinks = FALSE
}