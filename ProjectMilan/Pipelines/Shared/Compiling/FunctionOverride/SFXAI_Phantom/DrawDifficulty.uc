public function DrawDifficulty(BioCheatManager CM)
{
    local SFXDifficultyHandler DH;
    local Name ParamName;
    local Name CategoryName;
    local SFXModule_Damage DmgMod;
    local SFXShield_Base PawnShield;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        CategoryName = 'Phantom';
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
            CM.DrawProfileHeaderText("Barriers: ");
            ParamName = 'MaxBarriers';
            CM.DrawProfileText(PawnShield.GetMaxShields() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileText("Max Shield Recharge: ");
            ParamName = 'MaxEnemyShieldRecharge';
            CM.DrawProfileText(PawnShield.GetMaxShields() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("Damage Reduction On Shield Break: ");
            ParamName = 'AIEnergyShieldGatePct';
            // MILAN CHANGE 08/29/2026 - Mgamerz
            // Changed to scaled float so must access through .Value
            CM.DrawProfileText(PawnShield.AIEnergyShieldGatePct.Value @ "(" @ DH.GetMinFloat('AIEnergyShieldGatePct', 'Global') @ ":" @ DH.GetMaxFloat('AIEnergyShieldGatePct', 'Global') @ ")");
            CM.DrawProfileHeaderText("What Percent of Shields Regen Per Second: ");
            ParamName = 'ShieldRegenPct';
            CM.DrawProfileText(PawnShield.ShieldRegenPct @ "(" @ DH.GetMinFloat('AIShieldRegenPct', 'Phantom') @ ":" @ DH.GetMaxFloat('AIShieldRegenPct', 'Phantom') @ ")");
            CM.DrawProfileHeaderText("How Long Before Shields Start To Regenerate: ");
            ParamName = 'ShieldRegenDelay';
            CM.DrawProfileText(PawnShield.ShieldRegenDelay.Value @ "(" @ DH.GetMinFloat('AIShieldRegenDelay', 'Phantom') @ ":" @ DH.GetMaxFloat('AIShieldRegenDelay', 'Phantom') @ ")");
            CM.DrawProfileText(" ");
        }
        CM.DrawProfileHeaderText("CancelFirePct: ");
        ParamName = 'CancelFirePct';
        CM.DrawProfileText(CancelFirePct @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("MaxFireWaitTime: ");
        ParamName = 'MaxFireWaitTime';
        CM.DrawProfileText(MaxFireWaitTime @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeHealthThreshold: ");
        CM.DrawProfileText(string(EvadeHealthThreshold));
        CM.DrawProfileHeaderText("EvadeDamagePctLow: ");
        ParamName = 'EvadeDamagePctLow';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeDamagePctHigh: ");
        ParamName = 'EvadeDamagePctHigh';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeFrequency: ");
        ParamName = 'EvadeFrequency';
        CM.DrawProfileText(EvadeFrequency @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeResetDuration: ");
        ParamName = 'EvadeResetDuration';
        CM.DrawProfileText(EvadeResetDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("EvadeDamageScalePct: ");
        ParamName = 'EvadeDamageScalePct';
        CM.DrawProfileText(EvadeDamageScalePct @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ShieldDamageScalePct: ");
        ParamName = 'ShieldDamageScalePct';
        CM.DrawProfileText(ShieldDamageScalePct @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("PartialLeanPct: ");
        ParamName = 'PartialLeanPct';
        CM.DrawProfileText(PartialLeanPct @ "(" @ DH.GetFloat(ParamName, CategoryName) @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("PowerEvadeChance: ");
        ParamName = 'PowerEvadeChance';
        CM.DrawProfileText(PowerEvadeChance @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("FlankReactionTime: ");
        ParamName = 'FlankReactionTime';
        CM.DrawProfileText(FlankReactionTime @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("CloakHealthPct: ");
        ParamName = 'CloakHealthPct';
        CM.DrawProfileText(CloakHealthPct @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("VortexDamageWindow: ");
        ParamName = 'VortexDamageWindow';
        CM.DrawProfileText(VortexDamageWindow @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("VortexFrequency: ");
        ParamName = 'VortexFrequency';
        CM.DrawProfileText(VortexFrequency @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ShieldFrequency: ");
        ParamName = 'ShieldFrequency';
        CM.DrawProfileText(ShieldFrequency @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("AggressiveFrequency: ");
        ParamName = 'AggressiveFrequency';
        CM.DrawProfileText(AggressiveFrequency @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("MeleeAttackInterval: ");
        ParamName = 'MeleeAttackInterval';
        CM.DrawProfileText(MeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("SyncMeleeAttackInterval: ");
        ParamName = 'SyncMeleeAttackInterval';
        CM.DrawProfileText(SyncMeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
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