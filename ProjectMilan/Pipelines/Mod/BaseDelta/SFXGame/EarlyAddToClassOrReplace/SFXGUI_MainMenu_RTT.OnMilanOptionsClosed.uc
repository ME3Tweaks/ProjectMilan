// MILAN CHANGE - Mgamerz - 2026-11-06
// Allows milan options to return to main menu and not just MP
public function OnMilanOptionsClosed()
{
    GetSFXUIController().ShowMainMenu(GetPC());
}
