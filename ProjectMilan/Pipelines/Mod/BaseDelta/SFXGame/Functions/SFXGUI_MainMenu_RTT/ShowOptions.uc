// MILAN CHANGE - Mgamerz - 2026-11-06
// Use the multiplayer settings handler and pages from both EntryMenu and its menu scenes
public final function ShowOptions()
{
    local BioSFHandler_Options oOptions;

    oOptions = BioSFHandler_Options(OpenMainMenuSubMovie(GetSFXUIController().MovieTag_MPOptions, TRUE, FALSE));
    if (oOptions != None)
    {
        oOptions.GuiMode = EOptionsGuiMode.GuiMode_Multiplayer;
        oOptions.SetOnCloseCallback(OnMilanOptionsClosed);
        oOptions.Start();
    }
}