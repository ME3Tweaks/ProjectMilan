// Source: ME3, MPLobby
Class SFXGUI_PCMPOptions extends BioSFHandler_PCOptions
    config(UI);

// MILAN CHANGE - Mgamerz - 2026-10-10
// Multiplayer Settings page. OPTION_MilanNetConfig is listed in GamePopulatedOptionPages, so the
// Options movie calls this when it builds the page (Options opening, menuLevel 0). The page is given
// itself as its only child; entering the page creates that child, which calls this again at menu
// level 1, and that opens the Multiplayer Settings screen. Options is hidden while that screen is
// open: MP Options draws over it whatever their ZOrders. When it closes Options is shown again and
// the submenu is closed so the player is back on the page list. (The movie's own "functionName" path
// for childless pages is unusable: it looks the item up by the literal member "position".)
public function BuildMilanNetConfigPage(GFxValue optionData)
{
    local GFxValue Children;

    if (optionData == None)
    {
        return;
    }
    if (oPanel.GetVariableFloat("_root.options.menuLevel") > 0.0)
    {
        if (Class'SFXGUI_MilanNetConfig'.static.ShowNetConfig(GetPC(), OnMilanNetConfigClosed) != None)
        {
            // Hidden the way Options hides the main menu (SFXGUIInteraction.HideMainMenu)
            SetEnabled(FALSE);
        }
        return;
    }
    Children = optionData.GetObject("children");
    if (Children != None)
    {
        Children.SetElementObject(0, optionData);
    }
}
public function bool OnMilanNetConfigClosed(SFXGUIMovie i_ScreenToClose)
{
    SetEnabled(TRUE);
    AS_CloseSubMenu();
    return TRUE;
}
private final function AS_CloseSubMenu()
{
    ActionScriptVoid("_root.options.SubMenuClose");
}
// END MILAN CHANGE

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties
{
    GuiMode = EOptionsGuiMode.GuiMode_Multiplayer
}
