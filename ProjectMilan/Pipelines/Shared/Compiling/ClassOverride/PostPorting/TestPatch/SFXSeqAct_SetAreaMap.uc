// Source: ME3, Patch_SFXSeqAct_SetAreaMap
// Decompiled 11/17/2026 7:38:44 AM against BioD_CitHub_Dock.pcc
Class SFXSeqAct_SetAreaMap extends SequenceAction
    config(UI);

var(Areamap) Object.Vector RefPoint1_Image_Px;
var(Areamap) Object.Vector RefPoint2_Image_Px;
var(Areamap) int OverrideGroupID;
var Actor Ref1;
var Actor Ref2;
var GFxMovieInfo m_oAreaMapReference;
var(Areamap) SFXSFHandler_AreaMap.SFXAreaMapLayout Floor;

public function Activated()
{
    local BioWorldInfo oWorldInfo;
    local SFXGUIInteraction Manager;
    local SFXAreaMapData MapData;
    
    if (Ref1 == None || Ref2 == None)
    {
    }
    else
    {
        oWorldInfo = BioWorldInfo(Class'Engine'.static.GetCurrentWorldInfo());
        if (oWorldInfo != None)
        {
            if (oWorldInfo.GetLocalPlayerController() != None)
            {
                Manager = oWorldInfo.GetLocalPlayerController().GetSFXUIController();
                if (Manager != None)
                {
                    MapData = new Class'SFXAreaMapData';
                    MapData.Floor = Floor;
                    MapData.OverrideGroupID = OverrideGroupID;
                    MapData.RefPoint1_Image_Px = RefPoint1_Image_Px;
                    MapData.RefPoint2_Image_Px = RefPoint2_Image_Px;
                    MapData.RefPoint1_Unreal_UU.X = Ref1.location.X;
                    MapData.RefPoint1_Unreal_UU.Y = Ref1.location.Y;
                    MapData.RefPoint1_Unreal_UU.Z = 0.0;
                    MapData.RefPoint2_Unreal_UU.X = Ref2.location.X;
                    MapData.RefPoint2_Unreal_UU.Y = Ref2.location.Y;
                    MapData.RefPoint2_Unreal_UU.Z = 0.0;
                    Manager.SetAreaMapData(MapData);
                    Manager.MovieTag_AreaMap = Manager.default.MovieTag_AreaMap;
                }
            }
        }
    }
}
public static event function int GetObjClassVersion()
{
    return Super(SequenceObject).GetObjClassVersion() + 2;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    OverrideGroupID = -1
    m_oAreaMapReference = GFxMovieInfo'GUI_SF_ME2_AreaMap.ME2_AreaMap'
    bCallHandler = FALSE
    VariableLinks = ({
                      LinkedVariables = (), 
                      LinkDesc = "Map Reference Point 1", 
                      ExpectedType = Class'SeqVar_Object', 
                      LinkVar = 'None', 
                      PropertyName = 'Ref1', 
                      MinVars = 1, 
                      MaxVars = 255, 
                      CachedProperty = None, 
                      bWriteable = FALSE, 
                      bModifiesLinkedObject = FALSE, 
                      bAllowAnyType = FALSE
                     }, 
                     {
                      LinkedVariables = (), 
                      LinkDesc = "Map Reference Point 2", 
                      ExpectedType = Class'SeqVar_Object', 
                      LinkVar = 'None', 
                      PropertyName = 'Ref2', 
                      MinVars = 1, 
                      MaxVars = 255, 
                      CachedProperty = None, 
                      bWriteable = FALSE, 
                      bModifiesLinkedObject = FALSE, 
                      bAllowAnyType = FALSE
                     }
                    )
}