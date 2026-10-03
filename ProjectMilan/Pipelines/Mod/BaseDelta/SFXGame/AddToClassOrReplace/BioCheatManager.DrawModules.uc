// MILAN CHANGE - Mgamerz - 2026-10-01
// Draw the selected pawn's live module list for profile diagnostics.
public function DrawModules()
{
    local BioPawn TargetPawn;
    local SFXModule ModuleIter;
    local SFXModule_Marker MarkerModule;
    local int ModuleIndex;
    local int ModuleCount;

    TargetPawn = BioPawn(ProfileTarget);
    if (TargetPawn == None)
    {
        DrawProfileHeaderText("DrawModules requires a BioPawn target.");
        return;
    }

    DrawProfileHeaderText("Modules on" @ TargetPawn.Name @ "(" @ TargetPawn.Class.Name @ ")");
    DrawProfileText(" ");

    foreach TargetPawn.Modules(ModuleIter, ModuleIndex)
    {
        ModuleCount++;
        if (ModuleIter == None)
        {
            DrawProfileText("[" $ ModuleIndex $ "] None");
            continue;
        }

        MarkerModule = SFXModule_Marker(ModuleIter);
        if (MarkerModule != None)
        {
            DrawProfileText("[" $ ModuleIndex $ "]" @ ModuleIter.Name @ ModuleIter.Class.Name @ "Active=" @ MarkerModule.bActive);
        }
        else
        {
            DrawProfileText("[" $ ModuleIndex $ "]" @ ModuleIter.Name @ ModuleIter.Class.Name);
        }
    }

    DrawProfileText(" ");
    DrawProfileHeaderText("Module count:" @ ModuleCount);
}
// END MILAN CHANGE
