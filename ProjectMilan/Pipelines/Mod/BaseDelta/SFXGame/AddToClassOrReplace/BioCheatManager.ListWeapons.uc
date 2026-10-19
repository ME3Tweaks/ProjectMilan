// MILAN CHANGE - Mgamerz - 2026-10-18
// List mapped weapon candidates without loading their packages. The selected GiveItem path validates its class.
public exec function ListWeapons(optional string Filter)
{
    local SFXEngine Engine;
    local int MappingIndex;
    local int DotIndex;
    local int PathIndex;
    local string ObjectPath;
    local string WeaponName;
    local array<string> WeaponPaths;

    Engine = Class'SFXEngine'.static.GetSFXEngine();
    if (Engine == None)
    {
        return;
    }
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
        if (!(Left(WeaponName, 10) ~= "SFXWeapon_") && !(Left(WeaponName, 15) ~= "SFXHeavyWeapon_"))
        {
            continue;
        }
        if (Filter != "" && InStr(Caps(ObjectPath), Caps(Filter)) == -1)
        {
            continue;
        }
        if (WeaponPaths.Find(ObjectPath) == -1)
        {
            WeaponPaths.AddItem(ObjectPath);
        }
    }
    for (PathIndex = 0; PathIndex < WeaponPaths.Length; ++PathIndex)
    {
        LogInternal(WeaponPaths[PathIndex]);
        LogInternal(WeaponPaths[PathIndex], );
    }
    LogInternal(WeaponPaths.Length @ "mapped weapon candidates. Use GiveItem with a listed path.");
}
// END MILAN CHANGE
