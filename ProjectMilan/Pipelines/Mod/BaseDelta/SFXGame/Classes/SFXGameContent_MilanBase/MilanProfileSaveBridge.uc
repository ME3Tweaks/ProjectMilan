// MILAN CHANGE - Mgamerz - 2026-10-10
// MilanHost intercepts this bridge and returns success only after MP_Profile is
// committed. Without the matching ASI, fail safely and preserve pending changes.
class MilanProfileSaveBridge extends Object;

public static function bool WriteProfile()
{
    LogInternal("Local profile save bridge requires the matching MilanHost ASI", );
    return FALSE;
}
// END MILAN CHANGE
