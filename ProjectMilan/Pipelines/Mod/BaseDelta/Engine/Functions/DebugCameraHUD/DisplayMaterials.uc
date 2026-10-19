// MILAN CHANGE 10/15/2026 - Mgamerz
// Add ME3Tweaks Dev Mods 'Better Debug Camera'
// It shows the component name of what's hit to make it easier to find the item.
public function bool DisplayMaterials(float X, out float Y, float DY, MeshComponent MeshComp)
{
    local int MaterialIndex;
    local bool bDisplayedMaterial;
    local MaterialInterface Material;
    
    bDisplayedMaterial = FALSE;
    if (MeshComp != None)
    {
        Canvas.DrawText(("Hit component: '" $ MeshComp.Name) $ "'");
        Y += DY;
        for (MaterialIndex = 0; MaterialIndex < MeshComp.GetNumElements(); ++MaterialIndex)
        {
            Material = MeshComp.GetMaterial(MaterialIndex);
            if (Material != None)
            {
                Y += DY;
                Canvas.SetPos(X + DY, Y);
                Canvas.DrawText(("Material: '" $ Material.Name) $ "'");
                bDisplayedMaterial = TRUE;
            }
        }
    }
    return bDisplayedMaterial;
}