// MILAN CHANGE 09/16/2026 - Mgamerz
// Updated GameEffectClasses and GameEffects to use SFXGameEffect_WeaponMod_WeightBonus instead of the shared version.
// This might be why ultra light materials for this breaks, but not sure. This is the only weapon mod using this specific game effect.
Class SFXWeaponMod_PistolUltraLight extends SFXWeaponMod
    config(Weapon);

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=StaticMeshComponent Name=PickupMesh
        ReplacementPrimitive = None
    End Template
    GameEffectClasses = (Class'SFXGameEffect_WeaponMod_WeightBonus')
    GameEffects = ({EffectClassName = 'SFXGameEffect_WeaponMod_WeightBonus', Level = 1, EffectValue = -0.300000012}, 
                   {EffectClassName = 'SFXGameEffect_WeaponMod_WeightBonus', Level = 2, EffectValue = -0.349999994}, 
                   {EffectClassName = 'SFXGameEffect_WeaponMod_WeightBonus', Level = 3, EffectValue = -0.400000006}, 
                   {EffectClassName = 'SFXGameEffect_WeaponMod_WeightBonus', Level = 4, EffectValue = -0.449999988}, 
                   {EffectClassName = 'SFXGameEffect_WeaponMod_WeightBonus', Level = 5, EffectValue = -0.5}
                  )
    NotificationImage = "GUI_Icons.Weapons.MOD_ultralight-material_256x128"
    LargeNotificationImage = "GUI_Codex_Weapons_Images.Weapons.MOD_ultralight-material_512x256"
    RTPCName = "Weapon_Int_Body_Mod"
    DisplayName = $747597
    FormattedName_ModName = $747598
    FormattedName_ModCategory = $633758
    Description = $747606
    bMaterialBodyColorChange = TRUE
    WeaponModCategory = EWeaponModCategory.WModCategory_Body
    PickupFactoryMesh = PickupMesh
}