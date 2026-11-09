// MILAN CHANGE - Mgamerz - 2026-10-30
// Per-scene tints for the live main menu backdrops (EntryMenu_<Map>). The pipeline writes one Scenes entry per scene.
Class MilanMenuScene extends Object
    config(Game);

struct SceneTint
{
    // The scene's persistent level, e.g. EntryMenu_MPDish
    var string Map;
    var bool bTintHologram;
    // Replaces the Color parameter of every HologramMaterials entry
    var LinearColor HologramTint;
    var bool bTintUI;
    // Multiplies the menu movie's colors
    var LinearColor UITint;
};

var config array<SceneTint> Scenes;
// Memory paths of the terminal's hologram materials
var config array<string> HologramMaterials;

// Applies the current scene's tints to the terminal and the given menu movie
public static function ApplyTints(GFxMovie MenuMovie)
{
    local int Index;
    local int MaterialIndex;
    local MaterialInstanceConstant MIC;
    local ASColorTransform Tint;
    local GFxValue Root;
    local WorldInfo World;

    World = Class'WorldInfo'.static.GetWorldInfo();
    if (World == None)
    {
        return;
    }
    // MilanHost loads the scene in place of EntryMenu, so the URL names the scene
    Index = default.Scenes.Find('Map', World.GetURLMap());
    if (Index == -1)
    {
        return;
    }
    if (default.Scenes[Index].bTintHologram)
    {
        for (MaterialIndex = 0; MaterialIndex < default.HologramMaterials.Length; MaterialIndex++)
        {
            MIC = MaterialInstanceConstant(FindObject(default.HologramMaterials[MaterialIndex], Class'MaterialInstanceConstant'));
            if (MIC != None)
            {
                MIC.SetVectorParameterValue('Color', default.Scenes[Index].HologramTint);
            }
        }
    }
    if (default.Scenes[Index].bTintUI && MenuMovie != None)
    {
        Root = MenuMovie.GetVariableObject("_root");
        if (Root != None)
        {
            Tint.Multiply = default.Scenes[Index].UITint;
            Root.SetColorTransform(Tint);
        }
    }
}
