// MILAN CHANGE - 11/14/2026 - Mgamerz
// Add null guards
public function ShowTappingPrompt(bool bVisible, optional bool bForce = FALSE)
{
    local GFxObject DeathRoot;
    local GFxObject ButtonIcon;

    if (bTappingPromptVisible != bVisible || bForce)
    {
        DeathRoot = GetVariableObject("DeathRootInstance");
        if (DeathRoot != None)
        {
            ButtonIcon = DeathRoot.GetObject("ButtonIconInstance");
            if (ButtonIcon != None)
            {
                ButtonIcon.SetVisible(bVisible);
            }
        }
        bTappingPromptVisible = bVisible;
    }
}