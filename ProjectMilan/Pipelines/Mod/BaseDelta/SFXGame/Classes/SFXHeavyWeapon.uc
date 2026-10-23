Class SFXHeavyWeapon extends SFXWeapon
    placeable
    abstract
    config(Weapon);

var bool bTossOnWeaponSwitch;

// MILAN CHANGE 10/21/2026 - Mgamerz
// Add flags for concealed heavy weapons
// Concealed variants still use the normal weapon and consumable behavior.
// The bHiddenVariant is set on subclasses of heavy weapons and changes their behavior elsewhere
var bool bHiddenVariant;
var transient bool bHiddenVariantStowed;
var transient bool bHiddenVariantRequestedHidden;
// END MILAN CHANGE

public simulated function int AddAmmo(int Amount)
{
    return 0;
}
public simulated function ConsumeAmmo(byte FireModeNum)
{
    if (Instigator != None && Instigator.IsHumanControlled())
    {
        Super.ConsumeAmmo(FireModeNum);
    }
}
public simulated function PutDownWeapon()
{
    local SFXPawn_Player Player;
    local SFXWeapon LastWeapon;
    local SFXEngine Engine;
    local int idx;
    
    Player = SFXPawn_Player(Owner);
    if (CanThrow() && Player != None)
    {
        if (OutOfAmmo() || SFXGRI(WorldInfo.GRI).gameconfig.DropHeavyWeaponOnHolster || bTossOnWeaponSwitch && SFXGRI(WorldInfo.GRI).bIsMultiplayerCharacter == FALSE)
        {
            Player.Controller.StopFiring();
            LastWeapon = Player.BackupWeapon(SFXWeapon(Player.WeaponOnDeck));
            Player.SetWeaponImmediately(None);
            Player.WeaponOnDeck = LastWeapon;
            BioPlayerController(Player.Controller).SwitchWeapon(SFXWeapon(Player.WeaponOnDeck));
            Player.TossWeapon(Self);
            Engine = Class'SFXEngine'.static.GetSFXEngine();
            if (Engine != None)
            {
                Engine.PlayerLoadoutGroups.RemoveItem(5);
            }
            for (idx = 0; idx < 6; idx++)
            {
                if (-1 != InStr(string(Engine.PlayerLoadoutWeapons[idx]), "SFXWeapon_Heavy", , , ))
                {
                    Engine.PlayerLoadoutWeapons[idx] = 'None';
                    break;
                }
            }
            return;
        }
    }
}
public final function int AddHeavyAmmo(int Ammo)
{
    local int OldCount;
    
    OldCount = AmmoUsedCount;
    AmmoUsedCount = int(FMax(0.0, float(AmmoUsedCount - Ammo)));
    return AmmoUsedCount - OldCount;
}
public function DropGun()
{
    TryPutDown();
}
public simulated function int GetCurrentSpareAmmo()
{
    return 0;
}
public static function BioDefine.EAttachSlot GetStoreQualification()
{
    return 4;
}
public simulated function PlayLowAmmoVocalization();


state Active 
{
    public simulated function BeginFire(byte FireModeNum)
    {
        if (bDeleteMe == FALSE && Instigator != None && IsInPortArms() == FALSE && PendingFire(int(FireModeNum)) && HasAnyAmmo() == FALSE)
        {
            if (IsTimerActive('DropGun') == FALSE)
            {
                SetTimer(0.75, , 'DropGun', );
            }
        }
        Super.BeginFire(FireModeNum);
    }
    
    stop;
};

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    Begin Template Class=ForceFeedbackWaveform Name=ForceFeedbackWaveformBase
    End Template
    Begin Template Class=ForceFeedbackWaveform Name=OutOfAmmoRumble0
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=AmmoPowerIconHologram
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=OutOfAmmoEffect0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=ParticleSystemComponent Name=ReloadVent0
        ReplacementPrimitive = None
    End Template
    Begin Template Class=PointLightComponent Name=MuzFlashLight0
    End Template
    Begin Template Class=SFXModule_GameEffectManager Name=GEMod0
    End Template
    Begin Template Class=SFXModule_WeaponModManager Name=ModManager0
    End Template
    Begin Template Class=SkeletalMeshComponent Name=PickupMesh
        ReplacementPrimitive = None
    End Template
    Begin Template Class=SkeletalMeshComponent Name=WeaponMesh
        ReplacementPrimitive = None
    End Template
    bTossOnWeaponSwitch = TRUE
    AimModes = ({ScopeResource = 'None', ZoomFOV = 54.4000015, FrictionMultiplier = 1.0, AdhesionMultiplier = 1.0, bScoped = FALSE}
               )
    FiringShake = {
                   RotAmplitude = {X = 125.0, Y = 100.0, Z = 275.0}, 
                   RotFrequency = {X = 100.0, Y = 50.0, Z = 150.0}, 
                   LocAmplitude = {X = 4.0, Y = 0.0, Z = 0.0}, 
                   TimeDuration = 0.170000002
                  }
    PSC_OutOfAmmoEffect = OutOfAmmoEffect0
    OutOfAmmoRumble = OutOfAmmoRumble0
    WeaponFireWaveForm = ForceFeedbackWaveformBase
    PSC_ReloadVent = ReloadVent0
    LC_MuzzleFlashLight = MuzFlashLight0
    AmmoPowerPSCO = AmmoPowerHologram
    AmmoPowerIconPSCO = AmmoPowerIconHologram
    SwitchPriority = 1
    IdealTargetDistance = 2000.0
    IdealMaxRange = 5000.0
    IconRef = 15
    GUIClassName = $338205
    GUIClassDescription = $340847
    GUIWeaponOrder = 50
    AnimType = WeaponAnimType.WeaponAnimType_Rifle
    AttachSlot = EAttachSlot.EASlot_CenterBack
    bCanDropAmmo = FALSE
    bCanBlindUp = FALSE
    VocalizationType = ESFXVocalizationWeapon.SFXVocalizationWeapon_HeavyWeapon
    Mesh = WeaponMesh
    PickupFactoryMesh = PickupMesh
    Components = (WeaponMesh)
    Modules = (GEMod0, ModManager0)
}
