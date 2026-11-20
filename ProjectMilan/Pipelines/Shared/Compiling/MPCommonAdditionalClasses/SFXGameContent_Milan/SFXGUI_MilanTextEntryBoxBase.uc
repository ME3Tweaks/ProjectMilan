// NEW to Milan - Mgamerz - 11/17/2026
// MPLobby ONLY - base class for text-entry dialog - movie is located in MPLobby to prevent wasting global memory
Class SFXGUI_MilanTextEntryBoxBase extends SFXGUIMovieLegacyAdapter
    abstract;

public delegate function OnTextEntryComplete(bool bAccepted, string sText);

// Base method for overriding pasted text. This base version does no filtering
public delegate function string OnFilterPastedText(string sText)
{
    return sText;
}

// Shows the dialog for text input
public static function SFXGUI_MilanTextEntryBoxBase ShowTextEntry(PlayerController PC, string sMessage, string sAcceptText, string sCancelText, delegate<OnTextEntryComplete> fnDone, optional string sDefault, optional int nMaxChars = 64, optional stringref srKeyboardTitle, optional SFXGUIHelper_ConsoleKeyboard.Keyboard_Options eKeyboardOptions)
{
    local SFXGUI_MilanTextEntryBoxBase Box;

    if (PC == None)
    {
        return None;
    }
    Box = SFXGUI_MilanTextEntryBoxBase(Class'SFXGUIInteraction'.static.GetInstance().OpenMovie(PC, 'MilanTextEntry', TRUE));
    if (Box == None)
    {
        LogInternal("SFXGUI_MilanTextEntryBoxBase: could not open movie library tag MilanTextEntry (is MPLobby loaded?)", );
        return None;
    }
    if (!Box.BeginTextEntry(sMessage, sAcceptText, sCancelText, fnDone, sDefault, nMaxChars, srKeyboardTitle, eKeyboardOptions))
    {
        return None;
    }
    return Box;
}

// Implemented by SFXGUI_MilanTextEntryBox. Returns FALSE if a text entry box is already open.
public function bool BeginTextEntry(string sMessage, string sAcceptText, string sCancelText, delegate<OnTextEntryComplete> fnDone, string sDefault, int nMaxChars, stringref srKeyboardTitle, SFXGUIHelper_ConsoleKeyboard.Keyboard_Options eKeyboardOptions)
{
    return FALSE;
}

//class default properties can be edited in the Properties tab for the class's Default__ object.
defaultproperties { 

}