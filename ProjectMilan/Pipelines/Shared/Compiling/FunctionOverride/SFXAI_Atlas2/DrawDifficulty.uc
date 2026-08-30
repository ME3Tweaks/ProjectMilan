public function DrawDifficulty(BioCheatManager CM)
{
    local SFXDifficultyHandler DH;
    local Name ParamName;
    local Name CategoryName;
    local SFXShield_Base PawnShield;
    local SFXModule_Damage DmgMod;
    local SFXModule_Armour ArmMod;
    local int idx;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        CategoryName = 'Atlas2';
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            CM.DrawProfileHeaderText("Health: ");
            ParamName = 'MaxHealth';
            CM.DrawProfileText(DmgMod.GetMaxHealth() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileText(" ");
        }
        PawnShield = SFXShield_Base(MyBP.InvManager.FindInventoryType(Class'SFXShield_Base', TRUE));
        if (PawnShield != None)
        {
            CM.DrawProfileHeaderText("Shields: ");
            ParamName = 'MaxShields';
            CM.DrawProfileText(PawnShield.GetMaxShields() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("Max Shield Recharge: ");
            ParamName = 'MaxEnemyShieldRecharge';
            CM.DrawProfileText(PawnShield.MaxEnemyShieldRecharge @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("Damage Reduction On Shield Break: ");
            ParamName = 'AIEnergyShieldGatePct';
            // MILAN CHANGE 08/29/2026 - Mgamerz
            // Changed to ScaledFloat so must access through .Value
            CM.DrawProfileText(PawnShield.AIEnergyShieldGatePct.Value @ "(" @ DH.GetMinFloat('AIEnergyShieldGatePct', 'Global') @ ":" @ DH.GetMaxFloat('AIEnergyShieldGatePct', 'Global') @ ")");
            CM.DrawProfileHeaderText("What Percent of Shields Regen Per Second: ");
            ParamName = 'ShieldRegenPct';
            CM.DrawProfileText(PawnShield.ShieldRegenPct @ "(" @ DH.GetMinFloat('AIShieldRegenPct', 'Atlas') @ ":" @ DH.GetMaxFloat('AIShieldRegenPct', 'Atlas') @ ")");
            CM.DrawProfileHeaderText("How Long Before Shields Start To Regenerate: ");
            ParamName = 'ShieldRegenDelay';
            CM.DrawProfileText(PawnShield.ShieldRegenDelay.Value @ "(" @ DH.GetMinFloat('AIShieldRegenDelay', 'Atlas') @ ":" @ DH.GetMaxFloat('AIShieldRegenDelay', 'Atlas') @ ")");
            CM.DrawProfileText(" ");
        }
        CM.DrawProfileHeaderText("Armour Health: ");
        ArmMod = MyBP.GetModule(Class'SFXModule_Armour');
        if (ArmMod != None)
        {
            for (idx = 0; idx < 12; idx++)
            {
                if (ArmMod.ActiveArmour[idx] != None && ArmMod.ActiveArmour[idx].bCanBeDamaged)
                {
                    if (ArmMod.ActiveArmour[idx].ArmourName != 'CanopyGlass')
                    {
                        ParamName = 'ArmourPieceHealth';
                    }
                    else
                    {
                        ParamName = 'GlassCockpitHealth';
                    }
                    CM.DrawProfileText(ArmMod.ActiveArmour[idx].ArmourName @ ArmMod.ActiveArmour[idx].MaxHealth @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
                }
            }
        }
        CM.DrawProfileHeaderText("MeleeAttackInterval: ");
        ParamName = 'MeleeAttackInterval';
        CM.DrawProfileText(MeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SyncMeleeAttackInterval: ");
        ParamName = 'SyncMeleeAttackInterval';
        CM.DrawProfileText(SyncMeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SmokeInterval: ");
        ParamName = 'SmokeInterval';
        CM.DrawProfileText(SmokeInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("RocketInterval: ");
        ParamName = 'RocketInterval';
        CM.DrawProfileText(RocketInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("BlockInterval: ");
        ParamName = 'BlockInterval';
        CM.DrawProfileText(BlockInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("CockpitDamageResetDuration: ");
        ParamName = 'CockpitDamageResetDuration';
        CM.DrawProfileText(CockpitDamageResetDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("CockpitBlockThreshold: ");
        ParamName = 'CockpitBlockThreshold';
        CM.DrawProfileText(CockpitBlockThreshold @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ArmourPieceDamage: ");
        ParamName = 'ArmourPieceDamage';
        CM.DrawProfileText(ArmourPieceDamage @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ArmourDestroyedStaggerChance: ");
        ParamName = 'ArmourDestroyedStaggerChance';
        CM.DrawProfileText(ArmourDestroyedStaggerChance @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SyncKillChance: ");
        ParamName = 'SyncKillChance';
        CM.DrawProfileText(SyncKillChance @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        if (MyBP != None)
        {
            CM.DrawProfileHeaderText("PowerThreshold_Standard: ");
            ParamName = 'PowerThreshold_Standard';
            CM.DrawProfileText(MyBP.PowerThreshold_Standard @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("PowerThreshold_Stagger: ");
            ParamName = 'PowerThreshold_Stagger';
            CM.DrawProfileText(MyBP.PowerThreshold_Stagger @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("PowerThreshold_Knockback: ");
            ParamName = 'PowerThreshold_Knockback';
            CM.DrawProfileText(MyBP.PowerThreshold_Knockback @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("HitReactionChanceMultiplier: ");
            ParamName = 'HitReactionChanceMultiplier';
            CM.DrawProfileText(MyBP.HitReactionChanceMultiplier @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        }
    }
}