// Source: ME3, MPLobby
// Decompiled 10/31/2026 6:13:13 PM
// MILAN CHANGE - 11/01/2026 - Mgamerz
// Tint1, Tint2, PatternColor, Phong, Emissive and SkinTone are packed 0xRRGGBB colors instead of palette IDs

Class SFXCustomizationInstance_PlayerMP extends SFXCustomizationInstance;

var(SFXCustomizationInstance_PlayerMP) int Tint1ID;
var(SFXCustomizationInstance_PlayerMP) int Tint2ID;
var(SFXCustomizationInstance_PlayerMP) int PatternID;
var(SFXCustomizationInstance_PlayerMP) int PatternColorID;
var(SFXCustomizationInstance_PlayerMP) int EmissiveID;
var(SFXCustomizationInstance_PlayerMP) int PhongID;
var(SFXCustomizationInstance_PlayerMP) int SkinToneID;

// MILAN CHANGE - Set a packed color on the MIC if it has one
public final function SetColorParameter(MaterialInstanceConstant MIC, Name ParameterName, int Packed)
{
    if (Class'MilanColor'.static.HasColor(Packed))
    {
        MIC.SetVectorParameterValue(ParameterName, Class'MilanColor'.static.UnpackRGB(Packed));
    }
}
// END MILAN CHANGE

public function CustomizeMaterialInstance(MaterialInstanceConstant MIC)
{
    local MaterialInstanceConstant.VectorParameterValue VParam;

    // MILAN CHANGE - Colors are packed hex values - set color via unpacked
    SetColorParameter(MIC, 'Tint_Color01', Tint1ID);
    SetColorParameter(MIC, 'Tint_Color02', Tint2ID);
    // END MILAN CHANGE
    if (PatternID >= 0 && PatternID < Class'SFXPlayerCustomizationMP'.default.PatternAppearances.Length)
    {
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternAppearances[PatternID].Pattern.Stripe1Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternAppearances[PatternID].Pattern.Stripe2Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternAppearances[PatternID].Pattern.Stripe3Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
    }
    // MILAN CHANGE - Colors are packed hex values - set color via unpacked
    SetColorParameter(MIC, 'Stripe_Color_01', PatternColorID);
    SetColorParameter(MIC, 'Stripe_Color_02', PatternColorID);
    SetColorParameter(MIC, 'Stripe_Color_03', PatternColorID);
    SetColorParameter(MIC, 'Emissive', EmissiveID);
    SetColorParameter(MIC, 'Phong_Spec_Color', PhongID);
    SetColorParameter(MIC, 'SkinTone', SkinToneID);
    // END MILAN CHANGE
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    // MILAN CHANGE - Default everything to -1
    Tint1ID = -1
    Tint2ID = -1
    PatternColorID = -1
    EmissiveID = -1
    PhongID = -1
    SkinToneID = -1
    // END MILAN CHANGE
}
