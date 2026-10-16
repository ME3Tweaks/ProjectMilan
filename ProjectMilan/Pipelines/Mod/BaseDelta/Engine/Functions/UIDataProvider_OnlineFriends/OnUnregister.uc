// MILAN CHANGE - 10/15/2026 - Mgamerz
// None check to prevent errors in log
public event function OnUnregister()
{
    local OnlineSubsystem OnlineSub;
    local OnlinePlayerInterface PlayerInterface;
    
    OnlineSub = Class'GameEngine'.static.GetOnlineSubsystem();
    if (OnlineSub != None)
    {
        PlayerInterface = OnlineSub.PlayerInterface;
        if (PlayerInterface != None)
        {
            // MILAN CHANGE
            // None check to prevent errors in log
            PlayerInterface.ClearReadFriendsCompleteDelegate(byte(Player != None ? Player.ControllerId : 0), OnFriendsReadComplete);
            // END MILAN CHANGE
            PlayerInterface.ClearLoginChangeDelegate(OnLoginChange);
        }
    }
    Super.OnUnregister();
}