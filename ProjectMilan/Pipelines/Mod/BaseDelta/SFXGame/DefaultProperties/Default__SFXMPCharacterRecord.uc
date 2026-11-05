// MILAN CHANGE - 2026/11/01
// Mgamerz
// Replaces colors with packed hex numbers that correspond to the original palette ID colors
// This is for future work where you can tune colors more.
// These are the colors the vanilla default IDs pointed at:
// Tint1 ID 0 = #7A0001, Tint2 ID 45 = #000000, PatternColor ID 47 = #FFFFFF
// Phong ID 45 = #000000, Emissive ID 9 = #FFFFFF, SkinTone ID 9 = #FFFFFF
// Tint1 must be set, as its its vanilla default 0 meant palette ID 0, but a packed
// value of 0 is black.
defaultproperties
{
    Tint1ID = 7995393
    Tint2ID = 0
    PatternColorID = 16777215
    PhongID = 0
    EmissiveID = 16777215
    SkinToneID = 16777215
    LeveledUp = TRUE
}
