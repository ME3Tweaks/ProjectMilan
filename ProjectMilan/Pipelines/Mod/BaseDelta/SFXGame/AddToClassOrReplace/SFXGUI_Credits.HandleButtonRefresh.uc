// MILAN CHANGE DropTheSquid 11/11/2026
// added this so that we can tell the difference between controller B and keyboard B
public event function HandleButtonRefresh(bool usingGamepad)
{
    ActionScriptVoid("credits.RefreshButtonHelp");
}