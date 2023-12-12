// MILAN CHANGE - 12/11/2013
// By Mgamerz
// Purpose: Restore MP main menu item
public function ShowList(string ListID, optional stringref SublistHeading)
{
    local MMListEntry ListEntry;
    local int ListIdx;
    
    ASClearLists();
    ListIdx = 1;
    // MILAN CHANGE - Add MP Menu -------------------------
    if (ListEntries[3].FncOnSelect == "ShowKinectTuner")
    {
        ListEntry.ListID = "RootList";
        ListEntry.FncOnSelect = "StartMultiplayerFlow";
        ListEntry.FncActiveConditional = ""; // Todo: restore conditional
        ListEntry.FncNotifyConditional = "";
        ListEntry.KmtOnSelect = "";
        ListEntry.Label = $506692;
        ListEntry.ShowNotification = FALSE;
        ListEntries[3] = ListEntry;
    }
    // END MILAN
    foreach ListEntries(ListEntry, )
    {
        if (ListEntry.ListID == ListID)
        {
            if (ListEntry.FncActiveConditional == "" || CallListFnc(Name(ListEntry.FncActiveConditional)) == TRUE)
            {
                ListEntry.ShowNotification = ListEntry.FncNotifyConditional != "" && CallListFnc(Name(ListEntry.FncNotifyConditional));
                AS_SetEntry(Cursor_SeqID != "RootSeq", ListEntry, ListIdx);
                ListIdx++;
            }
        }
    }
    if (Cursor_SeqEntry == Display_SeqEntry)
    {
        ASRefreshList();
    }
    else if (Cursor_SeqID == "RootSeq")
    {
        ASShowPrimaryList();
    }
    else
    {
        ASShowSubList(int(SublistHeading));
    }
    Display_SeqEntry = Cursor_SeqEntry;
}