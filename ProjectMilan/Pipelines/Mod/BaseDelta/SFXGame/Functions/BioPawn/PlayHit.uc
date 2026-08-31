public simulated function PlayHit(float Damage, Controller instigatedBy, Vector HitLocation, Class<DamageType> DamageType, Vector Momentum, TraceHitInfo HitInfo, Pawn DamageCauser)
{
    local Class<SFXDamageType> damageClass;
    local SFXCustomAction_DamageReaction Action;
    local float HealthPct;
    local SFXGRI GRI;
    local SFXWeapon ChkWeapon;
    local float DamageVocProbMod;
    local SFXModule_Wound WoundMod;
    local Name HitPart;
    local int BoneIndex;
    local SFXModule_AimAssist AimAssist;
    local bool bCanGibHead;
    local BioPlayerController BioPC;
    
    Super.PlayHit(Damage, instigatedBy, HitLocation, DamageType, Momentum, HitInfo, DamageCauser);
    if (Damage <= 0.0)
    {
        return;
    }
    BioPC = BioPlayerController(instigatedBy);
    damageClass = Class<SFXDamageType>(DamageType);
    if (damageClass == None || instigatedBy == None)
    {
        return;
    }
    HitPart = GetPartFromHit(HitInfo);
    if (Role == ENetRole.ROLE_Authority)
    {
        if (RequestWeaponReaction(instigatedBy, HitLocation, damageClass, Momentum, HitInfo))
        {
            Action = SFXCustomAction_DamageReaction(CustomActions[CurrentCustomAction]);
            if (Action != None)
            {
                BoneIndex = Mesh.MatchRefBone(HitInfo.BoneName);
                Action.Init(HitLocation, -Normal(Momentum), BoneIndex, TRUE, damageClass);
            }
            ReplicateAnimatedReaction(CurrentCustomAction, HitLocation, -Normal(Momentum), BoneIndex, damageClass);
        }
        if (GetCurrentHealth() <= 0.0 && HitPart == 'Head' && IsDead() == FALSE)
        {
            if (FRand() < damageClass.default.HeadGibChance)
            {
                // MILAN CHANGE 08/30/2026 - Mgamerz
                // Remove all checks for the input type. No clue why this was even added.
                //if (BioPC != None)
                //{
                //    if (BioPC.IsLocalPlayerController())
                //    {
                //        AimAssist = BioPC.GetModule(Class'SFXModule_AimAssist');
                //        bCanGibHead = AimAssist == None || AimAssist.CurrentAimAssistTarget == Self && AimAssist.CurrentAimAssistSoftMargin >= float(1);
                //    }
                //    else
                //    {
                //        bCanGibHead = BioPC.RemoteAimAssistActive == FALSE;
                //    }
                //}
                //if (bCanGibHead)
                //{
                    GibHead(HitLocation, -Normal(Momentum), HitInfo.BoneName, damageClass);
                //}
            }
        }
    }
    if (HasAnyShieldResistance() == FALSE)
    {
        GRI = SFXGRI(WorldInfo.GRI);
        if (GRI != None && IsDead() == FALSE)
        {
            ChkWeapon = SFXWeapon(instigatedBy.Pawn.Weapon);
            if (ChkWeapon != None && ChkWeapon.GetDamageVocProbabilityMod != None)
            {
                DamageVocProbMod = ChkWeapon.GetDamageVocProbabilityMod();
            }
            else
            {
                DamageVocProbMod = 1.0;
            }
            HealthPct = GetHealthPct();
            if (HealthPct > 0.5)
            {
                GRI.TriggerVocalizationEvent(24, Self, BioPawn(instigatedBy.Pawn), 0.0, DamageVocProbMod);
            }
            else if (HealthPct > 0.200000003)
            {
                GRI.TriggerVocalizationEvent(25, Self, BioPawn(instigatedBy.Pawn), 0.0, DamageVocProbMod);
            }
            else if (HealthPct > 0.0)
            {
                GRI.TriggerVocalizationEvent(26, Self, BioPawn(instigatedBy.Pawn), 0.0, DamageVocProbMod);
            }
            GRI.TriggerVocalizationEvent(104, BioPawn(instigatedBy.Pawn), Self, 1.0, DamageVocProbMod);
        }
        WoundMod = GetModule(Class'SFXModule_Wound');
        if (WoundMod != None)
        {
            WoundMod.CreateBestWound(HitPart, HitLocation, DamageType, Momentum);
        }
    }
    if (Physics == EPhysics.PHYS_RigidBody)
    {
        Mesh.AddImpulse(Momentum, HitLocation, HitInfo.BoneName);
        return;
    }
}