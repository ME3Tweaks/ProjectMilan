// MILAN CHANGE - Mgamerz - 2026-10-18
// Support slomo
public exec function Slomo(float T)
{
    if (Outer.WorldInfo.Game == None)
    {
        LogInternal(GetFuncName() @ "can only be used by the host");
        return;
    }
    Outer.WorldInfo.Game.SetGameSpeed(FMax(T, 0.00999999978));
    LogInternal("Game speed set to" @ T @ "- effective TimeDilation including difficulty speed:" @ Outer.WorldInfo.TimeDilation);
}
