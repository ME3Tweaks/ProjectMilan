![image](https://github.com/Mgamerz/ProjectMilan/assets/2738836/ec0e7d94-27f6-40eb-99f2-3ec4ecec55b5)

Project Milan is a port of the multiplayer component of Mass Effect 3 (2012) to Mass Effect 3 Legendary Edition (2021). This is a very large-scope project and requires significant resources to compile.


## How to compile mod component
You will need:
 - Visual Studio 2022
 - .NET 8 SDK
 - ME3Tweaks Mod Manager 8.2 or higher
 - VANILLA Mass Effect 3
 - VANILLA Mass Effect 3 Legendary Edition (can have Milan installed but nothing else should be)

There are surely more steps than this:

1. [Download](https://discord.com/channels/1172375877636587530/1177816109500612638/1183974009709281391) and import the Project Milan mod template into ME3Tweaks Mod Manager
2. In Visual Studio, choose the correct configuration for Project Milan with your setup. If you are not listed, add a new configuration and modify Program.cs to use your own settings file. Look at other users for examples on how to use it.
3. In Legendary Explorer Nightly, make an Object Database for ME3 and LE3 when they are in a FULLY VANILLA STATE - NO MODS OF ANY KIND. Experiments > Object Database > ME3/LE3. You need a version made after May 15, 2024
4. Run the Project Milan project
5. Install MilanHost.asi (build or use precompiled from d00t)

