// MILAN CHANGE - 2026-10-27
// Change polonium rounds damage calculation to not stack as much
public function AddPoloniumDamage(float AddedDamage, float NewDuration)
{
    if (AddedDamage > float(0) && NewDuration > float(0))
    {
        EffectValue = (EffectValue * (Duration - CurrentTime) + AddedDamage) / NewDuration;
        Duration = NewDuration;
        CurrentTime = 0.0;
    }
}
// END MILAN CHANGE
