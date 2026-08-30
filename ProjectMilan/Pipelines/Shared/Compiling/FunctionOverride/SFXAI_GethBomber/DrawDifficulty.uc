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
        CategoryName = 'GethBomber';
        CM.DrawProfileHeaderText("Health: ");
        ParamName = 'MaxHealth';
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            CM.DrawProfileText(DmgMod.GetMaxHealth() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        }
        CM.DrawProfileText(" ");
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
            // AIEnergyShieldGatePct is now a ScaledFloat so must be accessed with .Value to compile
            CM.DrawProfileText(PawnShield.AIEnergyShieldGatePct.Value @ "(" @ DH.GetMinFloat('AIEnergyShieldGatePct', 'Global') @ ":" @ DH.GetMaxFloat('AIEnergyShieldGatePct', 'Global') @ ")");
            CM.DrawProfileHeaderText("What Percent of Shields Regen Per Second: ");
            ParamName = 'ShieldRegenPct';
            CM.DrawProfileText(PawnShield.ShieldRegenPct @ "(" @ DH.GetMinFloat('AIShieldRegenPct', 'Centurion') @ ":" @ DH.GetMaxFloat('AIShieldRegenPct', 'Centurion') @ ")");
            CM.DrawProfileHeaderText("How Long Before Shields Start To Regenerate: ");
            ParamName = 'ShieldRegenDelay';
            CM.DrawProfileText(PawnShield.ShieldRegenDelay.Value @ "(" @ DH.GetMinFloat('AIShieldRegenDelay', 'Centurion') @ ":" @ DH.GetMaxFloat('AIShieldRegenDelay', 'Centurion') @ ")");
            CM.DrawProfileText(" ");
        }
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
        CM.DrawProfileHeaderText("PowerEvadeChance: ");
        ParamName = 'PowerEvadeChance';
        CM.DrawProfileText(PowerEvadeChance @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("MeleeAttackInterval: ");
        ParamName = 'MeleeAttackInterval';
        CM.DrawProfileText(MeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("GlobalBombingRunInterval: ");
        ParamName = 'GlobalBombingRunInterval';
        CM.DrawProfileText(GlobalBombingRunInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("BombingRunInterval: ");
        ParamName = 'BombingRunInterval';
        CM.DrawProfileText(BombingRunInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("NumGrenadesToDrop: ");
        ParamName = 'NumGrenadesToDrop';
        CM.DrawProfileText(NumGrenadesToDrop @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
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