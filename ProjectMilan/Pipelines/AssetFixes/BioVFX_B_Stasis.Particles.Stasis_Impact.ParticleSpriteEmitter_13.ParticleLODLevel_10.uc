properties
{
    Modules = (ParticleModuleLifetime'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleLifetime_122', 
               ParticleModuleSize'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleSize_122', 
               ParticleModuleColorOverLife'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleColorOverLife_118', 
               ParticleModuleSizeMultiplyLife'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleSizeMultiplyLife_112', 
               ParticleModuleMeshRotation'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleMeshRotation_29', 
               ParticleModuleLocation'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleLocation_51', 
               ParticleModuleSizeMultiplyLife'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleSizeMultiplyLife_2', 
               BioParticleModuleSound'BioVFX_B_Stasis.Particles.Stasis_Impact.BioParticleModuleSound_0', 
               BioParticleModuleSound'BioVFX_B_Stasis.Particles.Stasis_Impact.BioParticleModuleSound_1'
              )
    TypeDataModule = ParticleModuleTypeDataMesh'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleTypeDataMesh_25'
    SpawnModule = ParticleModuleSpawn'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleSpawn_21234'
    RequiredModule = ParticleModuleRequired'BioVFX_B_Stasis.Particles.Stasis_Impact.ParticleModuleRequired_122'
    Level = 1
    PeakActiveParticles = 3
    // MILAN CHANGE 10/28/2026 - Mgamerz
    // Enable LOD - its what plays the audio
    // LE disabled it for some reason
    bEnabled = TRUE
    // END MILAN CHANGE
}