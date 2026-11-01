defaultproperties
{
    Bindings = ({
                 Command = "Console_MPToggleReady", 
                 Name = 'XboxTypeS_RightTrigger', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_PushToTalk", 
                 Name = 'Tab', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }, 
                {
                 Command = "PC_MPToggleReady", 
                 Name = 'SpaceBar', 
                 Control = FALSE, 
                 Shift = FALSE, 
                 Alt = FALSE, 
                 bIgnoreCtrl = FALSE, 
                 bIgnoreShift = FALSE, 
                 bIgnoreAlt = FALSE
                }
               )
    bShowHUD = TRUE
    bShowHealth = FALSE
    bShowWeapon = FALSE
    bStopMovement = TRUE
    bAllowSave = TRUE
    // MILAN CHANGE 10/31/2026 DropTheSquid
    // this was not updated in LE to account for dynamic input switching; change both of these to false so that it doesn't force show the mouse cursor all the time
    bHasMouseAuthority = FALSE
    bMouseVisible = FALSE
    // END MILAN CHANGE
    bMergeNotifications = TRUE
    bAllowMessageUI = TRUE
    bRestrictToPrimaryViewport = TRUE
    Priority = EGameModePriority2.ModePriority_Menus
}