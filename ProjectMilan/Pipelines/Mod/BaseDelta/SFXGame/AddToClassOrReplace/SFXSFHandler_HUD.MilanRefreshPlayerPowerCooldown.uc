// MILAN CHANGE - Mgamerz - 2026-10-17
// Relocated center cooldown clips outlive the native HUD visibility gate. Refresh
// from gameplay before their hosting movie is shown again; never tick powers here.
public final function MilanRefreshPlayerPowerCooldown(BioPawn PlayerPawn)
{
    local SFXPowerCustomActionBase Power;
    local float CooldownFraction;
    local int CooldownFrame;

    if (PlayerPawn != None && PlayerPawn.PowerManager != None)
    {
        foreach PlayerPawn.PowerManager.Powers(Power)
        {
            if (Power != None && Power.UsesSharedCooldown)
            {
                if (Power.TotalCooldownTime > 0.0)
                {
                    CooldownFraction = FClamp(Power.CurrentCooldownTime / Power.TotalCooldownTime, 0.0, 1.0);
                }
                break;
            }
        }
    }
    CooldownFrame = Clamp(int((1.0 - CooldownFraction) * 100.0), 1, 100);
    if (PlayerPowerLeft != None)
    {
        PlayerPowerLeft.GotoAndStopI(CooldownFrame);
        PlayerPowerLeft.SetVisible(CooldownFraction > 0.0);
    }
    if (PlayerPowerRight != None)
    {
        PlayerPowerRight.GotoAndStopI(CooldownFrame);
        PlayerPowerRight.SetVisible(CooldownFraction > 0.0);
    }
    // Invalidate the native display cache so its normal update/completion resumes.
    m_oShepardInfo.fCooldown = -1.0;
    m_oShepardInfo.bUpdatePower = TRUE;
}
// END MILAN CHANGE
