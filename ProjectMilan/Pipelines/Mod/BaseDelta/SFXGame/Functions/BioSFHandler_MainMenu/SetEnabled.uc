// MILAN CHANGE - 10/15/2026 - Mgamerz
// None check to prevent errors in log
// Removal of the right computer seems to be the trigger here.
// This cleans up the log
public function SetEnabled(bool bVal)
{
    local SFXGUI_MainMenu_RTT_RC DisplayComputer;
    
    Super(SFXGUIMovie).SetEnabled(bVal);
    if (MenuComputer != None)
    {
        MenuComputer.SetEnabled(bVal);
    }
    if (MessagingComputer != None)
    {
        DisplayComputer = MessagingComputer.GetDisplayComputer();
        if (DisplayComputer != None)
        {
            DisplayComputer.SetEnabled(bVal);
        }
    }
}