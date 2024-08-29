# Welcome to Project Milan
Project Milan is the compilation tool for the Project Milan mod for Mass Effect 3 Legendary Edition game.


## Setup directions
Setting up the development environment for Project Milan requires several steps. You will need the following things:

- Visual Studio 2022
- UNMODDED Mass Effect 3 (2012)
- Mass Effect Legendary Edition (LE3 preferably unmodded)
- Custom installation of UDK (ONLY for Project Milan's use)
- ME3Tweaks Mod Manager Beta
- Wwise for LE

### Configure build settings
In Visual Studio, once the repository has been cloned and the correct branches set, you will need to define variables in your MilanSettings<username> class.



## Project Structure
The layout of this repository is as follows:

### Project: ProjectMilan
Contains the main content for this mod, with the direct port of main multiplayer from Mass Effect 3. This is the master project and will produce the final result of the application

Project Milan pipelines folders include:

- Audio
  - Audio pipeline, which converts ME3 Wwise objects into LE3 Wwise objects 
- Finalize
  - Conformance pipeline, which makes all package files have unique netindex for reliable replication
- Init
  - Init pipeline, which validates settings, loads object databases, syncs files from ME3Tweaks.com, and registers shared donors objects 
- Kits
   - Kits pipeline, builds player kits 
- Levels
   - Levels pipeline, builds vanilla multiplayer maps (including unreleased), and MPLobby   
- Materials
   - MaterialDonorPipeline, builds donor materials/materialinstances that are used in later pipelines. Donors are built from source .uc files using LEC compilers. Includes source textures to build into materials as references, and shader overrides that can override shader bytecode for materials.
     - Contains cached build data: /Pipelines/Materials/Build. This folder can be safely deleted.
     - Contains the RenderDoc tool, which can be used with RenderDoc to edit DX11 shaders in snapshots.
- MP4NewEnemies
   - Pipeline for building the Collector Trooper, which depends on output from the Weapons pipeline. It will not work in NonStartup. 
- Startups
   - Pipelines for MPCommon, NonStartups.
      - MPCommon - Builds BioP_MP_COMMON, which is required for nearly all other pipelines
      - NonStartups - Files that are loose loaded - most enemies, gear mods, objectives, etc. Does not include DLC weapons.  
- StaticLighting
  - Contains pipelines for static lighting import and export to UDK for lightmap baking.
- Texture
   - Contains texture pipeline, which externalizes textures for performance (and required for lightmaps), and compacts TFC files. 
- TLK
   - Merges TLK data into the compiled mod 
- Verify
   - Performs various verification processes such as finding broken materials 
- Weapons
   - Builds DLC-only weapons. ME3 MP had different named weapon classes; this rebuilds SP DLC weapons into MP versions so config data continues to work. 


### Project: ProjectMilan_ExtraContent
Contains the additional mod content for this mod, namely Mass Effect 3: Redemption and Mass Effect 3: Rejection pipelines. ProjectMilan can run these pipelines if you turn them on in your settings, or you can directly run this project to build individual DLC mods for them to improve iteration time. Do not mix a full build of Milan with the individual modules.

DLC_MOD_PMR2 = Rejection, extra enemy faction
DLC_MOD_PMR3 = Redemption, extra playable maps

