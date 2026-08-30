public function DrawDifficulty(BioCheatManager CM)
{
    local SFXDifficultyHandler DH;
    local Name ParamName;
    local Name CategoryName;
    local SFXModule_Damage DmgMod;
    local SFXPawn_Collector_Base CollectorPawn;
    
    DH = SFXGRI(WorldInfo.GRI).DifficultyHandler;
    if (DH != None)
    {
        CategoryName = 'Scion';
        CM.DrawProfileHeaderText("Health: ");
        ParamName = 'MaxHealth';
        DmgMod = MyBP.GetModule(Class'SFXModule_Damage');
        if (DmgMod != None)
        {
            CM.DrawProfileText(DmgMod.GetMaxHealth() @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        }
        CM.DrawProfileText(" ");
        CM.DrawProfileHeaderText("MeleeAttackInterval: ");
        ParamName = 'MeleeAttackInterval';
        CM.DrawProfileText(MeleeAttackInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("MaxFireWaitTime: ");
        ParamName = 'MaxFireWaitTime';
        CM.DrawProfileText(MaxFireWaitTime @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("FireDelayTimeLow: ");
        ParamName = 'FireDelayTimeLow';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("FireDelayTimeHigh: ");
        ParamName = 'FireDelayTimeHigh';
        CM.DrawProfileText("(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("BlastInterval: ");
        ParamName = 'BlastInterval';
        CM.DrawProfileText(BlastInterval @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ShardExplosionDelayLow: ");
        ParamName = 'ShardExplosionDelayLow';
        CM.DrawProfileText(DH.GetFloat('ShardExplosionDelayLow', 'Scion') @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("ShardExplosionDelayHigh: ");
        ParamName = 'ShardExplosionDelayHigh';
        CM.DrawProfileText(DH.GetFloat('ShardExplosionDelayHigh', 'Scion') @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("BlastExplosionDamage: ");
        ParamName = 'BlastExplosionDamage';
        CM.DrawProfileText(DH.GetFloat('BlastExplosionDamage', 'Scion') @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("BlastRadius: ");
        ParamName = 'BlastRadius';
        CM.DrawProfileText(DH.GetFloat('BlastRadius', 'Scion') @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("NumShardsToSpawn: ");
        ParamName = 'NumShardsToSpawn';
        CM.DrawProfileText(DH.GetFloat('NumShardsToSpawn', 'Scion') @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("Base (one player) BreachDamageThreshold: ");
        ParamName = 'BreachDamageThreshold';
        CM.DrawProfileText(DH.GetFloat(ParamName, CategoryName) @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("Actual BreachDamageThreshold: ");
        ParamName = 'BreachDamageThreshold';
        CM.DrawProfileText(string(BreachDamageThreshold));
        CM.DrawProfileHeaderText("MaxBreachDamageThreshold: ");
        ParamName = 'MaxBreachDamageThreshold';
        CM.DrawProfileText(MaxBreachDamageThreshold @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        CM.DrawProfileHeaderText("BreachDamageResetDuration: ");
        ParamName = 'BreachDamageResetDuration';
        CM.DrawProfileText(BreachDamageResetDuration @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
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
        CollectorPawn = SFXPawn_Collector_Base(Pawn);
        if (CollectorPawn != None)
        {
            CM.DrawProfileHeaderText("PossessionBonusHealthPercent: ");
            ParamName = 'PossessionBonusHealthPercent';
            CM.DrawProfileText(CollectorPawn.PossessionBonusHealthPercent @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
            CM.DrawProfileHeaderText("PossessedBarrierBonus: ");
            ParamName = 'PossessedBarrierBonus';
            CM.DrawProfileText(CollectorPawn.PossessedBarrierBonus @ "(" @ DH.GetMinFloat(ParamName, CategoryName) @ ":" @ DH.GetMaxFloat(ParamName, CategoryName) @ ")");
        }
    }
}