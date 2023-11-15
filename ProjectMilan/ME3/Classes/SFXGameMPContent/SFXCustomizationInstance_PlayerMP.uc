Class SFXCustomizationInstance_PlayerMP extends SFXCustomizationInstance;

// Variables
var(SFXCustomizationInstance_PlayerMP) int Tint1ID;
var(SFXCustomizationInstance_PlayerMP) int Tint2ID;
var(SFXCustomizationInstance_PlayerMP) int PatternID;
var(SFXCustomizationInstance_PlayerMP) int PatternColorID;
var(SFXCustomizationInstance_PlayerMP) int EmissiveID;
var(SFXCustomizationInstance_PlayerMP) int PhongID;
var(SFXCustomizationInstance_PlayerMP) int SkinToneID;

// Functions
public function CustomizeMaterialInstance(MaterialInstanceConstant MIC)
{
    local VectorParameterValue VParam;
    
    if (Tint1ID >= 0 && Tint1ID < Class'SFXPlayerCustomizationMP'.default.Tint1Appearances.Length)
    {
        VParam = Class'SFXPlayerCustomizationMP'.default.Tint1Appearances[Tint1ID].Tint.TintParam;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
    }
    if (Tint2ID >= 0 && Tint2ID < Class'SFXPlayerCustomizationMP'.default.Tint2Appearances.Length)
    {
        VParam = Class'SFXPlayerCustomizationMP'.default.Tint2Appearances[Tint2ID].Tint.TintParam;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
    }
    if (PatternID >= 0 && PatternID < Class'SFXPlayerCustomizationMP'.default.PatternAppearances.Length)
    {
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternAppearances[PatternID].Pattern.Stripe1Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternAppearances[PatternID].Pattern.Stripe2Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternAppearances[PatternID].Pattern.Stripe3Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
    }
    if (PatternColorID >= 0 && PatternColorID < Class'SFXPlayerCustomizationMP'.default.PatternColorAppearances.Length)
    {
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternColorAppearances[PatternColorID].Pattern.Stripe1Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternColorAppearances[PatternColorID].Pattern.Stripe2Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
        VParam = Class'SFXPlayerCustomizationMP'.default.PatternColorAppearances[PatternColorID].Pattern.Stripe3Param;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
    }
    if (EmissiveID >= 0 && EmissiveID < Class'SFXPlayerCustomizationMP'.default.EmissiveAppearances.Length)
    {
        VParam = Class'SFXPlayerCustomizationMP'.default.EmissiveAppearances[EmissiveID].Tint.TintParam;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
    }
    if (PhongID >= 0 && PhongID < Class'SFXPlayerCustomizationMP'.default.PhongAppearances.Length)
    {
        VParam = Class'SFXPlayerCustomizationMP'.default.PhongAppearances[PhongID].Tint.PhongParam;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
    }
    if (SkinToneID >= 0 && SkinToneID < Class'SFXPlayerCustomizationMP'.default.SkinToneAppearances.Length)
    {
        VParam = Class'SFXPlayerCustomizationMP'.default.SkinToneAppearances[SkinToneID].Tint.TintParam;
        MIC.SetVectorParameterValue(VParam.ParameterName, VParam.ParameterValue);
    }
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
}