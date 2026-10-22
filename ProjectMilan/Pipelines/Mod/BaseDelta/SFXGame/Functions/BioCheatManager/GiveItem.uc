public exec function GiveItem(string sTarget, Name nmItemLabel)
{
    local BioPawn oPawn;
    local Class<SFXWeapon> cWeapon;
    local SFXWeapon Weapon;
    local SFXEngine Engine;
    local SFXModule_GameEffectManager GEManager;
    local SFXGameEffect GameEffect;
    local BioGlobalVariableTable VarTable;
    // MILAN CHANGE - Mgamerz - 2026-10-18
    // Resolve DLC weapon names from the live mapping without fixed package paths.
    local int MappingIndex;
    local int DotIndex;
    local int SeparatorIndex;
    local int MatchRank;
    local int BestMatchRank;
    local string ObjectPath;
    local string WeaponName;
    local string ShortName;
    local string ItemLabel;
    local array<string> MatchingPaths;
    // END MILAN CHANGE
    
    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
    if (Outer.Role != ENetRole.ROLE_Authority)
    {
        Outer.DispatchCommand("GiveItem" @ sTarget @ nmItemLabel);
    }
    else
    {
        oPawn = BioPawn(GetActorFromString(sTarget));
        if (oPawn == None)
        {
            return;
        }
        cWeapon = FindWeaponClass(string(nmItemLabel));
        if (cWeapon == None)
        {
            cWeapon = FindWeaponClass("SFXGameContent." $ nmItemLabel);
        }
        if (cWeapon == None)
        {
            cWeapon = FindWeaponClass("SFXGameContent.SFXWeapon_" $ nmItemLabel);
        }
        if (cWeapon == None)
        {
            cWeapon = FindWeaponClass("SFXGameContent.SFXWeapon_Heavy_" $ nmItemLabel);
        }
        if (cWeapon == None)
        {
            cWeapon = FindWeaponClass("SFXGameContent.SFXWeapon_AssaultRifle_" $ nmItemLabel);
        }
        if (cWeapon == None)
        {
            cWeapon = FindWeaponClass("SFXGameContent.SFXWeapon_Shotgun_" $ nmItemLabel);
        }
        if (cWeapon == None)
        {
            cWeapon = FindWeaponClass("SFXGameContent.SFXWeapon_SniperRifle_" $ nmItemLabel);
        }
        if (cWeapon == None)
        {
            cWeapon = FindWeaponClass("SFXGameContent.SFXWeapon_Pistol_" $ nmItemLabel);
        }
        if (cWeapon == None)
        {
            cWeapon = FindWeaponClass("SFXGameContent.SFXWeapon_SMG_" $ nmItemLabel);
        }
        // MILAN CHANGE - Mgamerz - 2026-10-18
        // Look at dynamic loading mapping if the object wasn't found, use SFXWeapon_ and SFXHeavyWeapon_ prefixes
        // to try and find the object.
        if (cWeapon == None)
        {
            ItemLabel = string(nmItemLabel);
            BestMatchRank = 4;
            for (MappingIndex = 0; MappingIndex < Engine.DynamicLoadMapping.Length; ++MappingIndex)
            {
                ObjectPath = Engine.DynamicLoadMapping[MappingIndex].ObjectName;
                WeaponName = ObjectPath;
                DotIndex = InStr(WeaponName, ".");
                while (DotIndex != -1)
                {
                    WeaponName = Mid(WeaponName, DotIndex + 1);
                    DotIndex = InStr(WeaponName, ".");
                }
                if (Left(WeaponName, 10) ~= "SFXWeapon_")
                {
                    ShortName = Mid(WeaponName, 10);
                }
                else if (Left(WeaponName, 15) ~= "SFXHeavyWeapon_")
                {
                    ShortName = Mid(WeaponName, 15);
                }
                else
                {
                    continue;
                }
                MatchRank = 4;
                if (ObjectPath ~= ItemLabel)
                {
                    MatchRank = 0;
                }
                else if (WeaponName ~= ItemLabel)
                {
                    MatchRank = 1;
                }
                else if (ShortName ~= ItemLabel)
                {
                    MatchRank = 2;
                }
                else
                {
                    SeparatorIndex = InStr(ShortName, "_");
                    if (SeparatorIndex != -1 && Mid(ShortName, SeparatorIndex + 1) ~= ItemLabel)
                    {
                        MatchRank = 3;
                    }
                }
                if (MatchRank < BestMatchRank)
                {
                    MatchingPaths.Length = 0;
                    BestMatchRank = MatchRank;
                }
                if (MatchRank < 4 && MatchRank == BestMatchRank && MatchingPaths.Find(ObjectPath) == -1)
                {
                    MatchingPaths.AddItem(ObjectPath);
                }
            }
            if (MatchingPaths.Length > 1)
            {
                LogInternal("Ambiguous weapon" @ nmItemLabel $ "; use a full class name or path:");
                for (MappingIndex = 0; MappingIndex < MatchingPaths.Length; ++MappingIndex)
                {
                    LogInternal(MatchingPaths[MappingIndex]);
                }
                return;
            }
            if (MatchingPaths.Length == 1)
            {
                cWeapon = FindWeaponClass(MatchingPaths[0]);
            }
        }
        // END MILAN CHANGE
        if (cWeapon == None)
        {
            LogInternal("Unable to find weapon" @ nmItemLabel, );
            return;
        }
        LogInternal("Giving weapon" @ nmItemLabel @ "to" @ oPawn, );
        if (SFXPawn_Player(oPawn) != None)
        {
            if (Engine.GetPlayerVariable(Name(PathName(cWeapon))) < 1)
            {
                Engine.SetPlayerVariable(Name(PathName(cWeapon)), 1);
            }
            Weapon = Outer.Spawn(cWeapon);
            if (Weapon.WeaponAcquiredID != 0 && BioWorldInfo(Outer.WorldInfo) != None)
            {
                VarTable = BioWorldInfo(Outer.WorldInfo).GetGlobalVariables();
                if (VarTable != None)
                {
                    VarTable.SetBool(Weapon.WeaponAcquiredID, TRUE, FALSE);
                }
            }
            GEManager = SFXPawn_Player(oPawn).GetModule(Class'SFXModule_GameEffectManager');
            if (GEManager != None)
            {
                foreach GEManager.GameEffects(GameEffect, )
                {
                    if (SFXGameEffect_PassiveWeaponBonus(GameEffect) != None)
                    {
                        SFXGameEffect_PassiveWeaponBonus(GameEffect).ApplyBonus(Weapon);
                    }
                }
            }
            SFXPawn_Player(oPawn).GiveWeaponToPlayer(Weapon);
        }
        else
        {
            oPawn.CreateWeapon(cWeapon);
            oPawn.SetWeaponImmediatelyByClass(cWeapon);
        }
    }
}

