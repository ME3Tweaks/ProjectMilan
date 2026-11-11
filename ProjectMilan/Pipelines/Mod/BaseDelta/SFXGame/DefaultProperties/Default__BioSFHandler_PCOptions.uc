// Full replace of the vanilla LE3 Default__BioSFHandler_PCOptions.
// Stripped out some SP only stuff we don't care about
// Shared gameplay aliases are edited as PC-only bindings by MilanHost.
// Change: Quick Slot 7 (PC_HotKey7) propagates its keys to PC_UseRevivePower in GameMode_Dying,
// so secondary medigel binding works.
// As described in MILAN-BUG-0001
defaultproperties
{
    AliasMap = ({
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337733, 
                 bCategory = TRUE, 
                 Alias = "", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "PC_MoveForward", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "PC_MoveForward", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "PC_MoveForward", GameMode = EGameModes.GameMode_DreamSequence}, 
                                 {bAllGameModes = FALSE, Alias = "PC_MoveForward", GameMode = EGameModes.GameMode_InjuredShepard}, 
                                 {bAllGameModes = FALSE, Alias = "PC_GUIControlUp", GameMode = EGameModes.GameMode_GUI}
                                ), 
                 Name = $337894, 
                 bCategory = FALSE, 
                 Alias = "PC_MoveForward", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "PC_MoveBackward", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "PC_MoveBackward", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "PC_MoveBackward", GameMode = EGameModes.GameMode_DreamSequence}, 
                                 {bAllGameModes = FALSE, Alias = "PC_MoveBackward", GameMode = EGameModes.GameMode_InjuredShepard}, 
                                 {bAllGameModes = FALSE, Alias = "PC_GUIControlDown", GameMode = EGameModes.GameMode_GUI}
                                ), 
                 Name = $337895, 
                 bCategory = FALSE, 
                 Alias = "PC_MoveBackward", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "PC_StrafeLeft", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "PC_StrafeLeft", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "PC_StrafeLeft", GameMode = EGameModes.GameMode_DreamSequence}, 
                                 {bAllGameModes = FALSE, Alias = "PC_StrafeLeft", GameMode = EGameModes.GameMode_InjuredShepard}, 
                                 {bAllGameModes = FALSE, Alias = "PC_GUIControlLeft", GameMode = EGameModes.GameMode_GUI}
                                ), 
                 Name = $337896, 
                 bCategory = FALSE, 
                 Alias = "PC_StrafeLeft", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "PC_StrafeRight", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "PC_StrafeRight", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "PC_StrafeRight", GameMode = EGameModes.GameMode_DreamSequence}, 
                                 {bAllGameModes = FALSE, Alias = "PC_StrafeRight", GameMode = EGameModes.GameMode_InjuredShepard}, 
                                 {bAllGameModes = FALSE, Alias = "PC_GUIControlRight", GameMode = EGameModes.GameMode_GUI}
                                ), 
                 Name = $337897, 
                 bCategory = FALSE, 
                 Alias = "PC_StrafeRight", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $174852, 
                 bCategory = FALSE, 
                 Alias = "Walking", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "Shared_Action", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "Shared_Action", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "Shared_Action", GameMode = EGameModes.GameMode_InjuredShepard}
                                ), 
                 Name = $337962, 
                 bCategory = FALSE, 
                 Alias = "Shared_Action", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = TRUE, Alias = "PC_ShowMap", GameMode = EGameModes.GameMode_Default}, 
                                 {bAllGameModes = FALSE, Alias = "PC_HideMap", GameMode = EGameModes.GameMode_GUI}, 
                                 {bAllGameModes = FALSE, Alias = "PC_ShowMap", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "PC_ShowMap", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "PC_ShowMap", GameMode = EGameModes.GameMode_InjuredShepard}
                                ), 
                 Name = $708554, 
                 bCategory = FALSE, 
                 Alias = "PC_ShowMap", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $708967, 
                 bCategory = FALSE, 
                 Alias = "PC_CoverTurn", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                // MILAN CHANGE - Add chat button
                {
                 Keys[0] = {Name = 'None'}, 
                 Keys[1] = {Name = 'None'}, 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "PC_Talk", GameMode = EGameModes.GameMode_Dying}, 
                                 {bAllGameModes = FALSE, Alias = "PC_Talk", GameMode = EGameModes.GameMode_Spectator}, 
                                 {bAllGameModes = FALSE, Alias = "PC_Talk", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "PC_Talk", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "PC_Talk", GameMode = EGameModes.GameMode_GUI}, 
                                 {bAllGameModes = FALSE, Alias = "PC_Talk", GameMode = EGameModes.GameMode_Photo}, 
                                 {bAllGameModes = FALSE, Alias = "PC_Talk", GameMode = EGameModes.GameMode_Lobby}
                                ), 
                 Name = $49875981, 
                 bCategory = FALSE, 
                 Alias = "PC_Talk", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                // MILAN CHANGE - Remove QuickSave
                // {
                //  Keys[0] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  Keys[1] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  KeysLocName[0] = "", 
                //  KeysLocName[1] = "", 
                //  Subordinates = ({bAllGameModes = FALSE, Alias = "Shared_QuickSave", GameMode = EGameModes.GameMode_InjuredShepard}
                //                 ), 
                //  Name = $282869, 
                //  bCategory = FALSE, 
                //  Alias = "Shared_QuickSave", 
                //  GameMode = EGameModes.GameMode_Default
                // }, 
                // MILAN CHANGE - Remove QuickLoad
                // {
                //  Keys[0] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  Keys[1] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  KeysLocName[0] = "", 
                //  KeysLocName[1] = "", 
                //  Subordinates = ({bAllGameModes = FALSE, Alias = "PC_QuickLoad", GameMode = EGameModes.GameMode_InjuredShepard}
                //                 ), 
                //  Name = $282870, 
                //  bCategory = FALSE, 
                //  Alias = "PC_QuickLoad", 
                //  GameMode = EGameModes.GameMode_Default
                // }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337781, 
                 bCategory = TRUE, 
                 Alias = "", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "Shared_Shoot", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "Shared_Shoot", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "Shared_Shoot", GameMode = EGameModes.GameMode_IllusiveManConflict}, 
                                 {bAllGameModes = FALSE, Alias = "Shared_Shoot", GameMode = EGameModes.GameMode_InjuredShepard}
                                ), 
                 Name = $337963, 
                 bCategory = FALSE, 
                 Alias = "Shared_Shoot", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "Shared_Aim", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "Shared_Aim", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "PC_CommandToggleCam", GameMode = EGameModes.GameMode_Command}, 
                                 {bAllGameModes = FALSE, Alias = "Shared_Aim", GameMode = EGameModes.GameMode_InjuredShepard}
                                ), 
                 Name = $282873, 
                 bCategory = FALSE, 
                 Alias = "Shared_Aim", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "PC_Reload", GameMode = EGameModes.GameMode_Atlas}, 
                                 {bAllGameModes = FALSE, Alias = "PC_Reload", GameMode = EGameModes.GameMode_Vehicle}, 
                                 {bAllGameModes = FALSE, Alias = "PC_Reload", GameMode = EGameModes.GameMode_InjuredShepard}
                                ), 
                 Name = $282875, 
                 bCategory = FALSE, 
                 Alias = "PC_Reload", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "Shared_Melee", GameMode = EGameModes.GameMode_Atlas}
                                ), 
                 Name = $282877, 
                 bCategory = FALSE, 
                 Alias = "Shared_Melee", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337964, 
                 bCategory = FALSE, 
                 Alias = "PC_SwapWeapon", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $282872, 
                 bCategory = FALSE, 
                 Alias = "PC_NextWeapon", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $282871, 
                 bCategory = FALSE, 
                 Alias = "PC_PrevWeapon", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                // MILAN CHANGE DropTheSquid 11/2/2026
                // we removed the slightly broken tactics HUD, so we should also remove the keybind. 
                // {
                //  Keys[0] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  Keys[1] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  KeysLocName[0] = "", 
                //  KeysLocName[1] = "", 
                //  Subordinates = ({bAllGameModes = FALSE, Alias = "PC_EnterCommandMenu", GameMode = EGameModes.GameMode_Vehicle}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_EnterCommandMenu", GameMode = EGameModes.GameMode_Atlas}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_ExitCommandMenu", GameMode = EGameModes.GameMode_Command}
                //                 ), 
                //  Name = $282856, 
                //  bCategory = FALSE, 
                //  Alias = "PC_EnterCommandMenu", 
                //  GameMode = EGameModes.GameMode_Default
                // }, 
                // END MILAN CHANGE
                // MILAN CHANGE - Remove Squad commands
                // {
                //  Keys[0] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  Keys[1] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  KeysLocName[0] = "", 
                //  KeysLocName[1] = "", 
                //  Subordinates = ({bAllGameModes = FALSE, Alias = "PC_SquadFollow", GameMode = EGameModes.GameMode_Vehicle}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_SquadFollow", GameMode = EGameModes.GameMode_Atlas}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_SquadFollow", GameMode = EGameModes.GameMode_Command}
                //                 ), 
                //  Name = $337965, 
                //  bCategory = FALSE, 
                //  Alias = "PC_SquadFollow", 
                //  GameMode = EGameModes.GameMode_Default
                // }, 
                // {
                //  Keys[0] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  Keys[1] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  KeysLocName[0] = "", 
                //  KeysLocName[1] = "", 
                //  Subordinates = ({bAllGameModes = FALSE, Alias = "PC_SquadMove1", GameMode = EGameModes.GameMode_Vehicle}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_SquadMove1", GameMode = EGameModes.GameMode_Atlas}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_SquadMove1", GameMode = EGameModes.GameMode_Command}
                //                 ), 
                //  Name = $337966, 
                //  bCategory = FALSE, 
                //  Alias = "PC_SquadMove1", 
                //  GameMode = EGameModes.GameMode_Default
                // }, 
                // {
                //  Keys[0] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  Keys[1] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  KeysLocName[0] = "", 
                //  KeysLocName[1] = "", 
                //  Subordinates = ({bAllGameModes = FALSE, Alias = "PC_SquadMove2", GameMode = EGameModes.GameMode_Vehicle}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_SquadMove2", GameMode = EGameModes.GameMode_Atlas}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_SquadMove2", GameMode = EGameModes.GameMode_Command}
                //                 ), 
                //  Name = $337967, 
                //  bCategory = FALSE, 
                //  Alias = "PC_SquadMove2", 
                //  GameMode = EGameModes.GameMode_Default
                // }, 
                // {
                //  Keys[0] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  Keys[1] = {
                //             Command = "", 
                //             Name = 'None', 
                //             Control = FALSE, 
                //             Shift = FALSE, 
                //             Alt = FALSE, 
                //             bIgnoreCtrl = FALSE, 
                //             bIgnoreShift = FALSE, 
                //             bIgnoreAlt = FALSE
                //            }, 
                //  KeysLocName[0] = "", 
                //  KeysLocName[1] = "", 
                //  Subordinates = ({bAllGameModes = FALSE, Alias = "PC_SquadAttack", GameMode = EGameModes.GameMode_Vehicle}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_SquadAttack", GameMode = EGameModes.GameMode_Atlas}, 
                //                  {bAllGameModes = FALSE, Alias = "PC_SquadAttack", GameMode = EGameModes.GameMode_Command}
                //                 ), 
                //  Name = $708968, 
                //  bCategory = FALSE, 
                //  Alias = "PC_SquadAttack", 
                //  GameMode = EGameModes.GameMode_Default
                // }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337973, 
                 bCategory = FALSE, 
                 Alias = "PC_HotKey1", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337974, 
                 bCategory = FALSE, 
                 Alias = "PC_HotKey2", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337975, 
                 bCategory = FALSE, 
                 Alias = "PC_HotKey3", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337976, 
                 bCategory = FALSE, 
                 Alias = "PC_HotKey4", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337977, 
                 bCategory = FALSE, 
                 Alias = "PC_HotKey5", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337978, 
                 bCategory = FALSE, 
                 Alias = "PC_HotKey6", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = ({bAllGameModes = FALSE, Alias = "PC_UseRevivePower", GameMode = EGameModes.GameMode_Dying}
                                 ), 
                 Name = $337979, 
                 bCategory = FALSE, 
                 Alias = "PC_HotKey7", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $337980, 
                 bCategory = FALSE, 
                 Alias = "PC_HotKey8", 
                 GameMode = EGameModes.GameMode_Default
                },
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $687215, 
                 bCategory = TRUE, 
                 Alias = "", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $687216, 
                 bCategory = FALSE, 
                 Alias = "Shared_ExitAtlas", 
                 GameMode = EGameModes.GameMode_Atlas
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $687431, 
                 bCategory = TRUE, 
                 Alias = "", 
                 GameMode = EGameModes.GameMode_Default
                }, 
                {
                 Keys[0] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 Keys[1] = {
                            Command = "", 
                            Name = 'None', 
                            Control = FALSE, 
                            Shift = FALSE, 
                            Alt = FALSE, 
                            bIgnoreCtrl = FALSE, 
                            bIgnoreShift = FALSE, 
                            bIgnoreAlt = FALSE
                           }, 
                 KeysLocName[0] = "", 
                 KeysLocName[1] = "", 
                 Subordinates = (), 
                 Name = $687432, 
                 bCategory = FALSE, 
                 Alias = "Shared_ExitMountedGun", 
                 GameMode = EGameModes.GameMode_Vehicle
                }
               )
    KeyHasBeenBound = $337982
    KeyHasBeenUnbound = $337983
    ResetPCBindingsText = $338327
    ConfirmResetPCBindingsText = $163219
    CancelResetPCBindingsText = $163220
    CannotBindConstantKey = $346979
    DisplayChangeText = $723099
    ConfirmDisplayChangeText = $163219
    CancelDisplayChangeText = $163220
    RebindWarning = $817931
    DisplayChangeTimeoutSeconds = 10
    ScreenLayout = GUILayout.GUILayout_PC
}
