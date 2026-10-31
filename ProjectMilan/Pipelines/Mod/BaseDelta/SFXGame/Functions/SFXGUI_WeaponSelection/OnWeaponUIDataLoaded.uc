public final function OnWeaponUIDataLoaded()
{
    BuildWeaponLoadout(CurrentPawnID);
    if (oWorldInfo.IsConsoleBuild(0))
    {
        AS_SelectWeaponSlot(WeaponTypeToSlotIndex(EntryWeaponGroup));
    }
    if (!IsMultiPlayerCharacter())
    {
        m_bHandleKeyPresses = TRUE;
    }
    PlayGuiSound('WeaponGUIEnter');
    AS_SetLoading(FALSE, "");
    // Milan Change 10/31/26 DropTheSquid
    // this was unconditionally making the mouse visible, which is stupid. it should only do that if we are not using a gamepad
    SetMouseVisible(!bUsingGamepad);
    // end milan change
}